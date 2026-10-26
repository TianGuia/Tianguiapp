# Compilar versiones desde tags

El workflow `Compilar versiones etiquetadas` se ejecuta al subir un tag SemVer:
`v0.1.0`, `0.2.0` o `v0.3.0-beta.1`, por ejemplo. Utiliza dos runners en paralelo:

- Linux: tres APK de distribución firmados, para ARM32 (`armeabi-v7a`), ARM64
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

El número de compilación se calcula con el contador `GITHUB_RUN_NUMBER` de este
workflow: `RELEASE_BUILD_BASE + GITHUB_RUN_NUMBER - 1`. La base es `1`, igual al
`+1` actual de `pubspec.yaml`: la primera ejecución usa 1 y la segunda 2. Se
aplica a `versionCode` de Android y `CFBundleVersion` de iOS. Los APK de las tres
arquitecturas comparten ese número, sin el incremento por ABI que añade Flutter
normalmente.

Reintentar una ejecución conserva su número. Las ejecuciones fallidas pueden
dejar saltos; no se necesita cambiar `pubspec.yaml` por cada tag. La base no debe
reducirse ni actualizarse por cada versión. El script valida los formatos y el
límite de cuatro dígitos del contador compartido con iOS.

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

Al terminar, descarga los artefactos en **Actions → Compilar versiones
etiquetadas → ejecución → Artifacts**. El artefacto Android contiene los tres
APK separados y el de iOS contiene el archivo `*-unsigned.ipa`.

Los jobs también ejecutan el análisis y las pruebas de Dart. El de iOS realiza
una compilación real con Xcode; no crea otro proyecto de ejemplo ni utiliza un
simulador. Las pruebas de funcionamiento en teléfonos siguen siendo manuales.
