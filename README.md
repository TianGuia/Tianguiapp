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
Android es la plataforma móvil configurada en este repositorio.

```text
lib/
  config/       Tema visual y configuración de Supabase
  models/       Modelos de datos del dominio
  screens/      Pantallas y pestañas de Flutter
  services/     Autenticación y operaciones del dominio
supabase/       Script de seguridad y funciones; datos de ejemplo opcionales
android/        Aplicación Android y configuración de compilación
```

## Ejecución local

### Requisitos previos

Instala Flutter en su canal estable y Android Studio con el SDK de Android.
Agrega el directorio `bin` de Flutter a tu `PATH`. Para compilar en Android,
Flutter utiliza el JDK incluido en Android Studio.

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

Los flujos de datos requieren una base de datos compatible en Supabase. El
[directorio supabase](supabase/) contiene políticas de seguridad, funciones y
datos de ejemplo opcionales. Estos scripts trabajan sobre tablas existentes;
el repositorio todavía no incluye el SQL que crea esas tablas, sus columnas,
relaciones y tipos personalizados. Para utilizar un proyecto nuevo de Supabase,
primero es necesario proporcionar esa estructura de base de datos.
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
`release` utilizan la configuración de firma de depuración del proyecto;
configura una firma de distribución antes de publicar en una tienda.

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
```

Incluye las pruebas pertinentes al agregar o modificar comportamientos y describe
las verificaciones manuales que requieran un dispositivo o un backend
configurado. Evita incluir credenciales y datos personales de usuarios en
incidencias, capturas de pantalla y commits.

## Licencia

Todavía no se ha agregado un archivo de licencia. Los responsables del proyecto
deben establecer los términos de reutilización y redistribución.
