# TianGuía

App móvil para encontrar puestos y productos en el tianguis. El comprador ve qué
puestos están abiertos y dónde se pusieron ese día, y el vendedor maneja su
catálogo, sus horarios y sus ofertas desde el celular.

Este repositorio es la app, hecha con Flutter. El backend está en
[Toldo](https://github.com/Tianguia/Toldo).

Con la app se puede:

- buscar productos y ver en un mapa los puestos abiertos
- guardar favoritos
- chatear con el vendedor, proponerle un precio o pedirle que te aparte algo
- si eres vendedor, abrir y cerrar tu puesto, publicar productos y ofertas
- calificar un puesto después de visitarlo, y reportar lo que rompa las reglas

La app no cobra nada. El pago se arregla directo con el vendedor en el tianguis.

## Cómo está organizado

Usamos Flutter y Dart. Supabase se encarga de la sesión, la base de datos
(PostgreSQL), las fotos y los mensajes en tiempo real.

```text
lib/
  config/       tema y configuración de Supabase
  models/       las clases del diagrama
  screens/      pantallas y pestañas
  services/     sesión y conexión con Supabase
  widgets/      piezas que se repiten en varias pantallas
android/        proyecto Android
ios/            proyecto iOS
test/           pruebas
docs/           guías extra
```

Si buscas dónde está una clase del diagrama, mira
[docs/guia-del-codigo.md](docs/guia-del-codigo.md). Cada lugar del código que
cumple un requisito tiene un comentario que empieza con `rf-` y el número, por
ejemplo `rf-01`.

## Probar que todo funciona

La forma más fácil es con Docker (con Compose v2 y contenedores Linux). No hace
falta tener Flutter, Python, Java ni Android Studio instalados.

```powershell
./scripts/verify.ps1
```

En Windows usa el Docker de WSL si no hay uno nativo. En Linux o macOS:
`bash scripts/check.sh`. Los dos hacen lo mismo que este comando, que es el que
corre GitHub Actions:

```sh
docker compose -f compose.verify.yaml run --build --rm -T verify
```

Primero corre las 5 pruebas de versionado, luego instala las dependencias según
`pubspec.lock`, analiza el código y corre las pruebas de Flutter. Si algo falla
se detiene ahí. Usa Flutter 3.47.8 y no descarga el SDK de Android.

La primera vez tarda porque descarga Flutter y arma la imagen. Después va mucho
más rápido. Las pruebas usan respuestas HTTP simuladas, así que no tocan Supabase,
pero sí hace falta internet para bajar las dependencias. Esto no compila ni
prueba la app en un Android o iPhone real. Más detalles en la
[guía de Docker](docs/desarrollo-docker.md#verificar-un-cambio), que
también explica cómo armar un entorno completo para Android sin instalar nada.

## Correrla en tu computadora

### Lo que necesitas

Flutter (canal estable) y Android Studio con el SDK de Android. Agrega la carpeta
`bin` de Flutter a tu `PATH`. Para compilar en Android, Flutter usa el JDK que
trae Android Studio.

```sh
git clone https://github.com/Tianguia/Tianguiapp.git
cd Tianguiapp
flutter doctor -v
flutter pub get
```

### Backend

La app lee `SUPABASE_URL` y `SUPABASE_KEY` desde
[SupabaseConfig](lib/config/supabase_config.dart). El archivo ya trae valores
por defecto, pero puedes cambiarlos con `--dart-define` para usar tu propio
backend de pruebas. Usa solo la clave pública (`publishable` o `anon`). La
`service_role` nunca debe estar en la app.

Para que funcione necesitas una base de Supabase con las migraciones de
[Toldo](https://github.com/Tianguia/Toldo). La configuración completa de
autenticación y almacenamiento para un proyecto nuevo todavía no está lista.
En el backend hay que activar el acceso anónimo (lo usan los compradores) y los
códigos por correo (los usan vendedores y administradores).

### Android

Conecta un teléfono con la depuración USB activada, o abre un emulador:

```sh
flutter devices
flutter run -d <id-dispositivo> --dart-define=SUPABASE_URL=<url-proyecto> --dart-define=SUPABASE_KEY=<clave-publica>
```

Los mismos `--dart-define` sirven para compilar:

```sh
flutter build apk --debug
flutter build apk --release
```

El APK queda en `build/app/outputs/flutter-apk/`. Si compilas `release` en tu
equipo sin una clave de distribución, se firma con la de depuración. La clave
real solo la usa el workflow de tags.

### Versiones e iOS

Cuando se sube un tag como `v0.1.0`, GitHub Actions compila tres APK firmados y
un IPA sin firmar. La versión sale del tag y el número de compilación sube solo.
Cómo descargar los archivos y cuidar la clave de firma está en
[docs/versiones.md](docs/versiones.md).

Para trabajar en iOS necesitas una Mac con Xcode y Flutter. El proyecto está en
`ios/` y se corre con `bash scripts/dev.sh ios -d <id-dispositivo>`.

<details>
<summary>Notas para Windows y Android</summary>

Estamos usando Flutter 3.47.8, SDK de compilación de Android 36 y NDK
28.2.13676358. Gradle toma las versiones del SDK y del NDK del Flutter que
tengas instalado. El NDK se instala desde Android Studio en
**SDK Manager > SDK Tools > Show Package Details > NDK (Side by side)**.

Con la CLI nueva de Android se instala así:

```powershell
& "$env:LOCALAPPDATA\Android\Sdk\cmdline-tools\latest\bin\android.exe" sdk install 'ndk/28.2.13676358'
flutter doctor --android-licenses
```

Si `sdkmanager.bat` falla cuando Gradle pide `ndk;28.2.13676358`, usa el comando
de arriba con `android.exe`.

En `android/gradle.properties` está desactivada la compilación incremental de
Kotlin. Sin eso daba errores de caché cuando el proyecto y la caché de Pub están
en discos distintos de Windows. La carga de trabajo de C++ de Visual Studio solo
hace falta para la versión de escritorio de Windows.

</details>

<details>
<summary>Correrla en el navegador con Brave</summary>

Si ya tienes configurado el destino web de Flutter, puedes elegir Brave con la
variable `CHROME_EXECUTABLE`:

```powershell
$browserPath = "$env:ProgramFiles\BraveSoftware\Brave-Browser\Application\brave.exe"
[Environment]::SetEnvironmentVariable('CHROME_EXECUTABLE', $browserPath, 'User')
$env:CHROME_EXECUTABLE = $browserPath
flutter run -d chrome
```

Cierra y vuelve a abrir las terminales y el editor para que tomen la variable.

</details>

## Colaborar

Mira [CONTRIBUTING.md](CONTRIBUTING.md). Si vas al tianguis, también nos sirve
que nos cuentes qué te gustaría que hiciera la app.

## Licencia

BSD de 3 cláusulas, está en [LICENSE](LICENSE).
