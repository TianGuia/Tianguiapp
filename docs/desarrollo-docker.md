# Desarrollo con Docker

Es opcional. Sirve para analizar, probar y compilar sin instalar Flutter, Java ni
el SDK de Android en tu equipo.

## Verificar un cambio

Solo necesitas Docker con Compose v2 y contenedores Linux:

```powershell
./scripts/verify.ps1
```

En Windows usa el Docker del host o, si no hay, `wsl --exec docker`. En
Linux/macOS: `bash scripts/check.sh`. Los dos corren el mismo comando que
GitHub Actions:

```sh
docker compose -f compose.verify.yaml run --build --rm -T verify
```

`scripts/verify.sh` hace, en orden: las pruebas de versionado (Python),
`flutter pub get --enforce-lockfile`, `flutter analyze --no-pub` y
`flutter test --no-pub`. Si algo falla, se detiene.

La imagen (`docker/verify.Dockerfile`) trae solo Flutter 3.47.8, Python y las
librerías de Linux necesarias, con versiones fijas para que no cambien al
reconstruir. El código se monta de solo lectura y se copia a un contenedor nuevo
cada vez. Solo se guarda la caché de Pub, en el volumen `verify-pub-cache`. La
primera vez tarda porque descarga Flutter. En ARM corre con emulación amd64.

Para borrar esa caché:

```sh
docker compose -f compose.verify.yaml down --volumes
```

Si actualizas Flutter, cambia la revisión y el tag en `docker/verify.Dockerfile`
y mantén iguales las versiones del contenedor de desarrollo y de los workflows
de releases. Las pruebas de base de datos de Toldo, la compilación nativa y las
pruebas en dispositivos quedan fuera.

## Entorno completo

Usa Debian 13 slim con Flutter 3.47.8, Java 21 y las herramientas de Android.
Permite analizar, probar, compilar APK y correr la app en Android o como
web-server. La primera construcción baja varios GB, y al construirla aceptas las
[licencias del SDK de Android](https://developer.android.com/studio/terms).

Cada contenedor tiene 4 CPU, 4 GB de RAM y hasta 1 GB de swap (la cuota de CPU
se cambia con `TIANGUIA_CPUS`). Si una compilación se pasa, puede fallar.

### Lo que necesitas

- Docker Engine con Compose v2 en Linux, o Docker Desktop 4.34+ en
  Windows/macOS, con contenedores Linux. En Apple Silicon va con emulación y es
  lento.
- Para usar un teléfono: [Platform-Tools](https://developer.android.com/tools/releases/platform-tools)
  en tu equipo. El script busca `adb` en el `PATH`, en `ANDROID_HOME` o en
  `ANDROID_SDK_ROOT`.
- En Docker Desktop, activa una vez **Settings > Resources > Network > Enable
  host networking** (solo para Android).

En Windows corre los scripts desde PowerShell con Docker Desktop. Si usas Docker
Engine dentro de WSL, corre el script Bash y ADB también dentro de WSL.

### Comandos

```powershell
./scripts/dev.ps1 doctor
./scripts/dev.ps1 analyze
./scripts/dev.ps1 test
./scripts/dev.ps1 apk --debug
./scripts/dev.ps1 web
./scripts/dev.ps1 run
./scripts/dev.ps1 stop
```

En Linux/macOS cambia `./scripts/dev.ps1` por `bash scripts/dev.sh`. Lo que
agregues se pasa a Flutter:

```powershell
./scripts/dev.ps1 run -d <id-dispositivo> --dart-define=SUPABASE_URL=<url> --dart-define=SUPABASE_KEY=<clave-publica>
```

Los APK quedan en `build/docker/`. Se compilan para ARM64 por defecto, por
ejemplo `build/docker/app-arm64-v8a-debug.apk`. Para otras arquitecturas:

```powershell
./scripts/dev.ps1 apk --debug --target-platform android-arm
./scripts/dev.ps1 apk --debug --target-platform android-x64
./scripts/dev.ps1 apk --debug --target-platform "android-arm,android-arm64,android-x64"
```

`android-arm` es ARM de 32 bits y `android-x64` es x86 de 64. Para ir probando
cambios es mejor `run` con hot reload que armar un APK cada vez.

`localhost` dentro de la app Android es el teléfono, no tu computadora. Usa una
dirección del backend que el teléfono pueda alcanzar.

### Teléfono y hot reload

1. Activa la depuración USB, conecta el teléfono y acepta el permiso. En Windows
   puede hacer falta el controlador del fabricante.
2. `./scripts/dev.ps1 devices` para ver que lo detecta.
3. `./scripts/dev.ps1 run`, o con `-d <id>` si hay varios dispositivos.
4. Edita el código, espera como un segundo y pulsa `r` para hot reload o `R`
   para reiniciar. `q` para salir.

Si sale `unauthorized`, acepta el permiso en el teléfono. Si Docker no ve
dispositivos, revisa **Enable host networking**.

Para depuración inalámbrica, empareja una vez con `adb pair IP:PUERTO_EMPAREJAMIENTO`
y luego `adb connect IP:PUERTO_CONEXION`. Los dos puertos aparecen en
Depuración inalámbrica y no son iguales. Después usa el mismo `run`. Si ADB
dice que las versiones son incompatibles, actualiza Platform-Tools y reconstruye
con `docker compose build --no-cache dev`.

### Navegador e iOS

`web` abre el servidor en `http://localhost:8080`. Entra desde cualquier
navegador de tu equipo. La depuración de web-server es
[limitada](https://docs.flutter.dev/platform-integration/web/setup), no
reemplaza a `flutter run -d chrome`. La imagen no trae Chromium. Sin un teléfono
conectado, `doctor` puede decir que no hay dispositivos, pero igual puedes
analizar, probar y compilar APK.

iOS necesita macOS, Xcode y Flutter instalados: Docker Linux no lo puede
compilar. `bash scripts/dev.sh ios -d <id>` usa ese Flutter y el proyecto de
`ios/`. El [workflow por tags](versiones.md) lo compila en macOS y saca el IPA
sin firmar.

### Archivos y cachés

El contenedor copia el repositorio a un volumen y guarda Pub, Gradle y la
compilación en volúmenes aparte de los de tu equipo. Con `run` y `web` se
sincronizan los cambios cada segundo. Usa una sesión a la vez, porque comparten
la copia de trabajo. Si cambias dependencias o plugins, quizá tengas que cerrar y
volver a correr el comando.

Al terminar, `./scripts/dev.ps1 stop` (o `bash scripts/dev.sh stop`) libera
memoria sin borrar cachés. Para borrarlas usa `docker compose down --volumes`,
que no toca el código ni los APK de `build/docker/`.
