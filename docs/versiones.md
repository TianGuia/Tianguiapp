# Versiones desde tags

Cuando se sube un tag como `v0.1.0`, `0.2.0` o `v0.3.0-beta.1`, el workflow
`Compilar versiones etiquetadas` corre dos jobs en paralelo:

- Linux: tres APK firmados, para ARM32 (`armeabi-v7a`), ARM64 (`arm64-v8a`) y
  x86_64. Flutter no hace APK para x86 de 32 bits.
- macOS: compila la app de `ios/` y saca un IPA sin firmar. Hay que firmarlo de
  nuevo para instalarlo, no sirve para TestFlight ni App Store.

El identificador de la app es `mx.udg.alumnos.tianguia`. Antes en Android era
`mx.udg.tianguia`, y para el sistema son apps distintas.

## Versión y número de compilación

La versión sale del tag: `v0.2.0` da `versionName=0.2.0` en Android y
`CFBundleShortVersionString=0.2.0` en iOS. Con un sufijo como `-beta.1`, Android
lo conserva y iOS usa solo `X.Y.Z`.

El número de compilación es `RELEASE_BUILD_BASE + GITHUB_RUN_NUMBER - 1`, con
base 1 (igual que el `+1` de `pubspec.yaml`). Se usa como `versionCode` en
Android y `CFBundleVersion` en iOS, y los tres APK comparten el mismo. Si una
ejecución falla puede haber saltos, no importa. No hace falta cambiar
`pubspec.yaml` en cada tag ni bajar la base.

## Firma de Android

El job usa estos Secrets del repositorio, que ya están configurados:

- `ANDROID_KEYSTORE_BASE64`: el archivo PKCS12 en base64
- `ANDROID_KEYSTORE_PASSWORD`: contraseña del almacén
- `ANDROID_KEY_ALIAS`: alias de la clave
- `ANDROID_KEY_PASSWORD`: contraseña de la clave

La copia local de la clave está en `.signing/` (fuera de Git). Guarda una copia
en un lugar seguro: para actualizar los APK hay que firmar siempre con la misma.

## Sacar una versión

Con los cambios ya subidos, desde el commit que quieras publicar:

```sh
git tag v0.1.0
git push origin v0.1.0
```

Un tag solo local no hace nada, hay que subirlo. Además el commit tiene que
incluir el workflow.

La primera plataforma que termine crea el **Release** con notas automáticas y le
agrega sus archivos. Si una falla, la otra se publica igual. Los tags con sufijo
como `-beta.1` salen como prerelease. Si el Release ya existe, una nueva
ejecución actualiza los archivos de esa plataforma sin tocar los de la otra.

Los archivos también quedan en **Actions > Compilar versiones etiquetadas >
ejecución > Artifacts**.

Los jobs también corren el análisis y las pruebas de Dart. Probar en teléfonos
reales sigue siendo manual.
