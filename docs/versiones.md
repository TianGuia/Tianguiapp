# Compilar releases

El workflow `Compilar releases` se ejecuta al subir un tag SemVer o al aumentar
el código de `pubspec.yaml` en la rama predeterminada. Por ejemplo, admite tags
`v0.1.0`, `0.2.0` o `v0.3.0-beta.1`. Utiliza dos runners en paralelo:

- Linux: un APK universal firmado que incluye ARM32 (`armeabi-v7a`), ARM64
  (`arm64-v8a`) y x86_64. Flutter no admite x86 de 32 bits como destino de APK.
- macOS: compila la app oficial de `ios/` para dispositivo y genera un IPA sin
  firmar. Este archivo necesita refirmarse antes de instalarse; no es un IPA de
  App Store ni de TestFlight.

Ambas plataformas usan `mx.udg.alumnos.tianguia` como identificador. Android
usaba anteriormente `mx.udg.tianguia`; los APK con el identificador nuevo son
una aplicación distinta para el sistema.

## Versiones y números de compilación

El tag determina la versión visible. `v0.2.0` produce `versionName=0.2.0` en
Android y `CFBundleShortVersionString=0.2.0` en iOS. Si el tag lleva un sufijo
como `-beta.1`, Android lo conserva; iOS utiliza la parte numérica `X.Y.Z` y el
nombre del artefacto conserva el tag completo.

Antes de compilar, el workflow lee `pubspec.yaml` de la rama predeterminada,
incrementa su número de compilación y guarda `version: <tag sin v>+<numero>` en
un commit de esa rama. La base actual es `0.0.1-beta.2+2`; el siguiente tag nuevo
recibe el código 3. No se utiliza el contador de ejecuciones de Actions.
El número se aplica a `versionCode` de Android y `CFBundleVersion` de iOS.

`.github/release-versions.json` registra el código reservado para cada tag.
Reintentar una ejecución conserva su número, incluso si ya se publicó un tag
posterior. Las ejecuciones fallidas pueden dejar saltos. Dos releases simultáneas
se coordinan mediante pushes normales: si otra modifica la rama primero, se
vuelve a leer el contador antes de reintentar. No se mueve ni reescribe el tag.
Ambas plataformas reciben los mismos metadatos y actualizan su copia de
`pubspec.yaml` antes de compilar el código del tag. Después de una release,
actualiza tu checkout con `git pull` para que las compilaciones locales usen
esa misma versión. El sufijo `+numero` de los tags automáticos identifica el
código de compilación; el nombre visible lo excluye. No se admiten otros sufijos
`+build`. El script valida el límite compartido de 9999.

También puedes editar directamente `pubspec.yaml` y subir, por ejemplo,
`version: 0.0.1-beta.3+3`. Se compara con la versión anterior al push: solo un
código mayor inicia las compilaciones y publicaciones habituales. Cambiar
dependencias, modificar únicamente el nombre visible, mantener el código o
reducirlo no crea una release. Solo la rama predeterminada publica por esta vía.
Se usa exactamente el código indicado, sin incrementarlo de nuevo, siempre que
sea mayor que los códigos ya reservados. Si otra release ya avanzó el contador,
se omite el código obsoleto.

Esta vía crea un tag `v0.0.1-beta.3+3` apuntando al commit del push y registra el
código en la rama predeterminada. Tag y registro se guardan en un push atómico.
Los reintentos reutilizan la misma asignación; el mismo tag no puede apuntar a
otro commit. Los tags y commits hechos con `GITHUB_TOKEN` no disparan otra
ejecución, por lo que el flujo no se duplica.

Los archivos publicados usan `<app>-<version>+<codigo>.<ext>`, por ejemplo:

- `tianguia-0.0.1-beta.3+3.apk`
- `tianguia-0.0.1-beta.3+3.ipa`

No llevan sufijos de arquitectura ni de tipo de compilación. El APK universal
es mayor que un APK separado por arquitectura. El IPA sigue sin firmar.

## Firma Android

El job necesita estos Secrets del repositorio:

- `ANDROID_KEYSTORE_BASE64`: el archivo PKCS12 codificado en base64.
- `ANDROID_KEYSTORE_PASSWORD`: contraseña del almacén.
- `ANDROID_KEY_ALIAS`: alias de la clave.
- `ANDROID_KEY_PASSWORD`: contraseña de la clave.

Ya se configuraron para este repositorio. La copia local de la clave está en
`.signing/tianguia-release.p12`, con sus datos de acceso en
`.signing/android-signing.json`. Esa carpeta es privada, está excluida de Git y
no se sincroniza con el entorno de desarrollo Docker. Guarda una copia de
seguridad de ambos archivos en un lugar seguro: se necesita conservar la misma
clave para distribuir actualizaciones de los APK.

## Crear una versión

Primero incorpora y sube los cambios del workflow y de la aplicación. Después,
desde el commit que quieras distribuir:

```sh
git tag v0.1.0
git push origin v0.1.0
```

La primera plataforma que termina correctamente crea un **Release** para el
tag con notas automáticas. Android adjunta su APK universal firmado e iOS adjunta
su IPA sin firmar. Cada publicación depende únicamente de su propia compilación:
si una plataforma falla, se conservan los binarios publicados por la otra.
Los tags con sufijo como `-beta.1` se publican como **prerelease**. Si el Release
ya existe, una nueva ejecución actualiza los binarios de esa plataforma sin
borrar los de la otra ni cambiar las notas. Los dos jobs de publicación comparten
un bloqueo por ejecución para evitar que intenten crear el mismo Release a la vez.
Los jobs de publicación y de reserva de versión tienen permiso `contents: write`;
utilizan el token automático de GitHub Actions y no necesitan un token personal
adicional. La rama predeterminada debe permitir el push del bot; si sus reglas
lo impiden, la reserva falla antes de compilar. El commit de versión hecho con
`GITHUB_TOKEN` no inicia otro workflow por push.

Ambas plataformas conservan además sus artefactos en
**Actions → Compilar releases
→ ejecución → Artifacts**. El artefacto Android contiene el APK universal
y el de iOS contiene el archivo `.ipa`. El IPA del Release también
está sin firmar: necesita refirmarse para instalarse y no se envía a TestFlight
ni a App Store.

Crear un tag solo localmente no inicia el workflow: hay que subirlo a GitHub.
El tag debe apuntar a un commit que ya incluya este workflow de publicación.

Los jobs también ejecutan el análisis y las pruebas de Dart. El de iOS realiza
una compilación real con Xcode; no crea otro proyecto de ejemplo ni utiliza un
simulador. Las pruebas de funcionamiento en teléfonos siguen siendo manuales.
