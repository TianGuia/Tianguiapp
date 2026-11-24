# Iconos de la app

El original es `assets/icon/logo.svg`, que es cuadrado.

Instala el renderizador una vez, desde la raíz del repositorio (queda en una
carpeta que Git ignora):

```powershell
python -m pip install --target build/icon-tools -r scripts/requirements-icons.txt
```

Después de editar el SVG, regenera los iconos en Windows:

```powershell
./scripts/generate-icons.ps1
```

Para usar otro archivo: `./scripts/generate-icons.ps1 -SourceSvg assets/icon.svg`.
Necesita Python y PowerShell con System.Drawing.

El script saca una imagen de 2048 × 2048 en `build/icons/source.png` y a partir
de ella genera los PNG de Android e iOS, los recursos adaptativos de Android y
las imágenes de `assets/icon/`. Deja margen para que el launcher no recorte el
diseño, y los de iOS van en RGB sin transparencia.

El color de fondo es `#0754AD`. Si lo cambias, cámbialo también en el script y en
`flutter_launcher_icons` de `pubspec.yaml`.

También se pueden regenerar los recursos nativos a partir de las imágenes de
`assets/icon/` con `dart run flutter_launcher_icons`.

Para ver el cambio hay que compilar e instalar la app otra vez (iOS necesita
macOS y Xcode). Esto solo cambia el icono de la app: el logo de dentro y la
pantalla de arranque tienen sus propios recursos.
