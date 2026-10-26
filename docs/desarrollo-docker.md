# Desarrollo opcional con Docker

Este entorno usa Debian 13 slim e instala Flutter 3.47.8 (incluye Dart), Java 21
y las herramientas de Android. Sirve para analizar, probar, compilar APK y ejecutar la
app en Android o mediante web-server. No necesitas Flutter ni Android Studio
en el host para estos comandos. La primera construcción descarga varios GB.
Al construir la imagen aceptas las [licencias del SDK de Android](https://developer.android.com/studio/terms).

Compose limita cada contenedor a 4 CPU, 4 GB de RAM y hasta 1 GB adicional de
swap, si el host lo permite. Estos límites se aplican a la ejecución, no a la
construcción de la imagen. Una compilación que exceda el límite puede fallar;
cambiar la distribución base no elimina el consumo de Flutter y Gradle.
Puedes cambiar la cuota de CPU con la variable `TIANGUIA_CPUS`.

## Preparación

- Docker Engine en Linux con Compose v2, o Docker Desktop 4.34+ en Windows/macOS,
  usando contenedores Linux. La imagen usa Linux amd64; en Apple Silicon se
  ejecuta con emulación y puede ser lenta.
- Para usar un teléfono: [Android SDK Platform-Tools](https://developer.android.com/tools/releases/platform-tools)
  en el host. El script busca `adb` en PATH o en la ubicación habitual del SDK;
  también admite `ANDROID_HOME` o `ANDROID_SDK_ROOT`.
- En Docker Desktop, activa **Settings > Resources > Network > Enable host
  networking** una sola vez para Android. No se necesita para pruebas o web.

En Windows ejecuta los scripts desde PowerShell con Docker Desktop. Si usas
Docker Engine dentro de WSL, ejecuta el script Bash y ADB también dentro de WSL;
el ADB de Windows no comparte su localhost con ese motor de Docker.

## Comandos

Desde la raíz del repositorio, en PowerShell:

```powershell
./scripts/dev.ps1 doctor
./scripts/dev.ps1 analyze
./scripts/dev.ps1 test
./scripts/dev.ps1 apk --debug
./scripts/dev.ps1 web
./scripts/dev.ps1 run
./scripts/dev.ps1 stop
```

En Linux/macOS, sustituye `./scripts/dev.ps1` por `bash scripts/dev.sh`.
Los argumentos adicionales se pasan a Flutter, por ejemplo:

```powershell
./scripts/dev.ps1 run -d <id-dispositivo> --dart-define=SUPABASE_URL=<url> --dart-define=SUPABASE_KEY=<clave-publica>
```

Los APK se copian a `build/docker/`. El backend se configura según el README y
[Toldo](https://github.com/Tianguia/Toldo). `localhost` dentro de la app Android
se refiere al teléfono, no a la computadora: usa una dirección del backend
accesible desde el dispositivo.

Los APK se compilan para ARM64 por defecto, separados por ABI para evitar incluir
bibliotecas nativas de otras arquitecturas. Por ejemplo, el APK de depuración es
`build/docker/app-arm64-v8a-debug.apk`. Las demás arquitecturas se solicitan
explícitamente:

```powershell
./scripts/dev.ps1 apk --debug --target-platform android-arm
./scripts/dev.ps1 apk --debug --target-platform android-x64
./scripts/dev.ps1 apk --debug --target-platform "android-arm,android-arm64,android-x64"
```

`android-arm` corresponde a ARM de 32 bits; `android-x64`, a x86 de 64 bits.
Flutter no ofrece x86 de 32 bits entre los destinos de este comando.
`run` usa la arquitectura del dispositivo seleccionado. Para iterar sobre
la app, usa `run` y hot reload en lugar de generar un APK nuevo por cada cambio.
Docker habilita la compilación incremental de Kotlin y la caché de Gradle; el
ajuste de Kotlin para las rutas de Windows permanece intacto en el host.

## Teléfono y hot reload

1. Activa la depuración USB en Android, conecta el teléfono y acepta su diálogo
   de autorización. Windows puede necesitar el controlador USB del fabricante.
2. Ejecuta `./scripts/dev.ps1 devices` para comprobar la conexión.
3. Ejecuta `./scripts/dev.ps1 run`; con varios dispositivos, agrega `-d <id>`.
4. Edita el código en tu editor habitual. Espera aproximadamente un segundo y
   pulsa `r` para hot reload o `R` para reiniciar. Sal con `q`.

El script inicia ADB en el host; el cliente del contenedor usa ese mismo
servidor mediante la red del host. No abre ADB a la red local, no comparte USB
con el contenedor ni requiere privilegios de Docker adicionales. ADB permanece
disponible al salir, para no interrumpir Android Studio u otras herramientas.
Si aparece `unauthorized`, acepta la autorización en el teléfono; si no se ven
dispositivos desde Docker, revisa primero **Enable host networking**.

Para depuración inalámbrica, empareja una vez con las herramientas del host:
`adb pair IP:PUERTO_EMPAREJAMIENTO` y después `adb connect IP:PUERTO_CONEXION`.
Android muestra ambos puertos en Depuración inalámbrica. No necesariamente son
iguales. Luego usa el mismo comando `run`. Si ADB informa versiones incompatibles,
actualiza Platform-Tools en el host y reconstruye la imagen (`docker compose build --no-cache dev`).

## Navegador e iOS

`web` publica el servidor solo en `http://localhost:8080`. Ábrelo en Chrome,
Chromium, Brave u otro navegador del host. Web-server tiene
[depuración limitada](https://docs.flutter.dev/platform-integration/web/setup);
no sustituye completamente a `flutter run -d chrome` nativo. El destino web se
genera únicamente en la copia del contenedor si todavía no existe en el repo.

La imagen no incluye Chromium. Los comandos normales deshabilitan web dentro
del contenedor para que `doctor` no lo pida; `web` lo habilita durante su ejecución.
No se modifica la configuración de Flutter del host: quienes usan Chrome pueden
seguir trabajando con su instalación habitual. No se habilitan destinos de
escritorio. Sin un teléfono conectado, `doctor` puede indicar que no hay
dispositivos; eso no impide analizar, probar o compilar APK.

iOS requiere macOS, Xcode y Flutter nativos; Docker Linux no puede compilarlo.
`bash scripts/dev.sh ios -d <id>` delega en ese Flutter y utiliza el proyecto
oficial de `ios/`. El [workflow por tags](versiones.md) lo compila en un runner
macOS y genera el IPA sin firmar.

## Archivos y cachés

El contenedor lee el repositorio y sincroniza una copia en un volumen. Conserva
Pub, Gradle y los productos de compilación en volúmenes separados de los del
host. Durante `run` y `web` sincroniza cambios cada segundo; las rutas locales
del SDK y los archivos generados de Flutter del host no se copian.

Los scripts reutilizan el contenedor y mantienen Gradle activo entre comandos
del mismo flujo. Al cambiar de flujo detienen los servicios que no se usan.
Ejecuta `./scripts/dev.ps1 stop` (o `bash scripts/dev.sh stop`) al terminar para
liberar memoria sin borrar las cachés. La primera compilación necesita preparar
dependencias; las siguientes pueden reutilizar el trabajo anterior. La imagen
no precarga artefactos para desarrollo interno del motor de Flutter.
El wrapper descarga Gradle `bin`, que contiene las herramientas de compilación
sin las fuentes ni la documentación del paquete `all`.

Usa una sesión a la vez: los servicios comparten la copia de trabajo. Cambios en
dependencias o plugins pueden requerir salir y volver a ejecutar el comando.
Para borrar las cachés del entorno opcional usa `docker compose down --volumes`;
esto no borra el código ni los APK ya copiados a `build/docker/`.
