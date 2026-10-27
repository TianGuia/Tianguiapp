# TianGuía

TianGuía es la plataforma que conecta a vendedores y compradores en tu tianguis
más cercano. Un lugar para descubrir lo que buscas, encontrar a tus tiangueros
favoritos y seguir apoyando al comercio local.

Tianguiapp es el código de la app para móviles, hecha con ❤️ en Flutter.
La estamos construyendo en comunidad para que puedas:

- Encontrar productos y puestos abiertos en el tianguis.
- Consultar dónde se instaló tu vendedor favorito ese día.
- Compartir tu catálogo, disponibilidad y ofertas si eres tianguero.
- Platicar con vendedores, proponer un precio y pedir un apartado.
- Guardar favoritos y enterarte de ofertas y días de tianguis.
- Compartir tu experiencia y ayudar a cuidar la comunidad.

La compra se acuerda y se paga directamente en el puesto. La app te ayuda a
llegar, preguntar y conectar; el encuentro sucede en el tianguis.

¿Te gustaría sumar algo? Las ideas, las experiencias del tianguis y las
contribuciones al código son bienvenidas. En el tablero del proyecto puedes ver
lo que estamos preparando.

## Tecnologías y estructura del repositorio

La aplicación utiliza Flutter y Dart, con Supabase para autenticación,
datos en PostgreSQL, almacenamiento de imágenes y mensajería en tiempo real.
Android e iOS tienen su estructura nativa configurada en este repositorio.

```text
lib/
  config/       Tema visual y configuración de Supabase
  models/       Modelos de datos del dominio
  screens/      Pantallas y pestañas de Flutter
  services/     Autenticación y operaciones del dominio
android/        Aplicación Android y configuración de compilación
ios/            Aplicación iOS, proyecto de Xcode y permisos
test/           Pruebas automatizadas de la aplicación
```

El backend se mantiene en [Toldo](https://github.com/Tianguia/Toldo), con sus
migraciones, permisos, datos de ejemplo y pruebas de base de datos.

## Ejecución local

Puedes usar el [entorno opcional con Docker](docs/desarrollo-docker.md) para
Android y web-server sin instalar Flutter ni el SDK completo en tu equipo.
Incluye scripts para pruebas, compilación y conexión con el ADB del host.
La instalación nativa sigue disponible con las instrucciones siguientes.

### Requisitos previos

Instala Flutter en su canal estable y Android Studio con el SDK de Android.
Agrega el directorio `bin` de Flutter a tu `PATH`. Para compilar en Android,
Flutter utiliza por defecto el JDK incluido en Android Studio. Para este proyecto
puedes seleccionar Temurin 21 (compatible con Gradle 9.3.1) y evitar los avisos
de acceso nativo restringido de JDK 24 o posterior:

```powershell
flutter config --jdk-dir='C:/Program Files/Eclipse Adoptium/jdk-21.0.11.10-hotspot'
```

Sustituye la ruta por tu instalación de JDK 21. Esta preferencia se aplica a todos
los proyectos de Flutter del usuario; reinicia el IDE después de cambiarla.

```sh
git clone https://github.com/Tianguia/Tianguiapp.git
cd Tianguiapp
flutter doctor -v
flutter pub get
```

### Configuración del backend

La aplicación lee `SUPABASE_URL` y `SUPABASE_KEY` mediante parámetros de
compilación de Dart en [SupabaseConfig](lib/config/supabase_config.dart). El
archivo incluye una configuración predeterminada; puedes sustituirla mediante
parámetros para conectarte a tu propio backend de desarrollo. Utiliza una clave
pública de cliente (`publishable` o `anon`) y mantén las claves privilegiadas
`service_role` fuera de la aplicación.

Los flujos de datos requieren una base de datos compatible en Supabase.
Esta versión requiere el esquema ER de Toldo y la migración de retiro de puestos
`20261027000300_client_operations.sql`. Ofertas, compradores, participantes y productos
ya utilizan esas relaciones; coordina la actualización de la app con el backend.
La [matriz del contrato de dominio](docs/contrato-dominio.md) documenta las clases,
operaciones, equivalencias con los diagramas y pruebas.
Consulta las instrucciones de [Toldo](https://github.com/Tianguia/Toldo) para las
migraciones y la preparación del backend. Toldo ya verifica la restauración de
la base y algunos permisos en Docker; la configuración completa de autenticación
y almacenamiento para un entorno nuevo todavía está en desarrollo.
Los SQL antiguos de este repositorio se conservan en el historial de Git.
La autenticación utiliza acceso anónimo para compradores y códigos de un solo
uso (OTP) por correo para vendedores y administradores; habilita estos métodos
en tu backend.

### Ejecución en Android

Conecta un teléfono con la depuración USB habilitada o inicia un emulador de
Android:

```sh
flutter devices
flutter run -d <id-dispositivo> --dart-define=SUPABASE_URL=<url-proyecto> --dart-define=SUPABASE_KEY=<clave-publica>
```

Las mismas opciones `--dart-define` pueden utilizarse al compilar:

```sh
flutter build apk --debug
flutter build apk --release
```

Los archivos APK se generan en `build/app/outputs/flutter-apk/`. Las compilaciones
locales `release` conservan la firma de depuración si no se proporciona una
clave de distribución; el workflow por tags utiliza la clave estable de Secrets.

### Versiones e iOS

Al subir un tag como `v0.1.0`, Actions compila un APK universal firmado y un IPA sin
firmar en runners Linux y macOS. La versión sale del tag y el número de
compilación aumenta automáticamente. También puedes publicar aumentando el
código de `pubspec.yaml` en la rama predeterminada. Los archivos se llaman
`tianguia-<version>+<codigo>.apk` y `.ipa`. Consulta la [guía de versiones](docs/versiones.md)
para descargar los artefactos y conservar la clave de firma.

Para trabajar con iOS localmente necesitas macOS, Xcode y Flutter. El proyecto
oficial está en `ios/`; `bash scripts/dev.sh ios -d <id-dispositivo>` usa esa
instalación nativa.

<details>
<summary>Notas de configuración para Windows y Android</summary>

Las notas del entorno local registran Flutter 3.47.8, SDK de compilación de
Android 36 y NDK 28.2.13676358. La configuración de Gradle toma las versiones del
SDK y del NDK del SDK de Flutter instalado. Instala el NDK solicitado desde
Android Studio en **SDK Manager > SDK Tools > Show Package Details >
NDK (Side by side)**.

Con la CLI más reciente de Android, el comando de instalación registrado es:

```powershell
& "$env:LOCALAPPDATA\Android\Sdk\cmdline-tools\latest\bin\android.exe" sdk install 'ndk/28.2.13676358'
flutter doctor --android-licenses
```

Si `sdkmanager.bat` falla cuando Gradle solicita `ndk;28.2.13676358`, prueba el
comando directo con `android.exe` anterior, si tienes instalada esa CLI.

`android/gradle.properties` deshabilita la compilación incremental de Kotlin para
evitar problemas de caché cuando el repositorio y la caché de Pub están en
unidades distintas de Windows. La carga de trabajo de C++ de Visual Studio solo
es necesaria para desarrollar la versión de escritorio para Windows.

</details>

<details>
<summary>Desarrollo en navegador con Brave</summary>

En un entorno con el destino web de Flutter configurado, puedes seleccionar
Brave mediante `CHROME_EXECUTABLE`. Define la ruta sin comillas adicionales
dentro de su valor:

```powershell
$browserPath = "$env:ProgramFiles\BraveSoftware\Brave-Browser\Application\brave.exe"
[Environment]::SetEnvironmentVariable('CHROME_EXECUTABLE', $browserPath, 'User')
$env:CHROME_EXECUTABLE = $browserPath
flutter run -d chrome
```

Reinicia las terminales y los IDE abiertos después de modificar variables de
entorno persistentes.

</details>

## Cómo contribuir

Puedes ayudar con código, documentación, accesibilidad, diseño o ideas. Si vas al
tianguis a comprar o vender, tu experiencia también cuenta: cuéntanos qué te
gustaría encontrar en la app y qué haría más fácil tu día.

1. Revisa el documento de requisitos y el tablero del proyecto, y consulta las
   [incidencias existentes](https://github.com/Tianguia/Tianguiapp/issues) para
   identificar trabajo relacionado.
2. Abre una incidencia para describir un error o discutir un cambio importante.
   Si reportas un error, incluye los pasos para reproducirlo, el comportamiento
   esperado y el dispositivo o plataforma utilizados.
3. Trabaja en una rama dedicada al cambio y envía una solicitud de incorporación
   (*pull request*) que explique el problema, la solución y cómo la verificaste.
   Vincula la incidencia y el requisito correspondiente cuando aplique; incluye
   capturas de pantalla si modificas la interfaz.

Antes de enviar cambios en Dart, aplica el formato y ejecuta el análisis
estático:

```sh
dart format lib
flutter analyze
flutter test
```

GitHub Actions ejecuta el análisis estático y las pruebas en cada push y pull
request. Las pruebas de la app usan respuestas HTTP simuladas, sin conectarse al
Supabase compartido. Las pruebas de base de datos se ejecutan por separado en Toldo.

Las [notas de implementación](docs/notas-implementacion.md) incluyen recorridos
manuales para las funciones de puestos, productos, propuestas y apartados.

Incluye las pruebas pertinentes al agregar o modificar comportamientos y describe
las verificaciones manuales que requieran un dispositivo o un backend
configurado. Evita incluir credenciales y datos personales de usuarios en
incidencias, capturas de pantalla y commits.

## Licencia

Este proyecto se distribuye bajo la licencia [BSD de 3 cláusulas](LICENSE)
(`BSD-3-Clause`).
