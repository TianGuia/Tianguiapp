# Iconos de la app

El original vectorial es `assets/icon/logo.svg` (viewBox cuadrado).
Para instalar el renderizador en una carpeta local ignorada por Git, ejecuta
una vez desde la raíz del repositorio:

```powershell
python -m pip install --target build/icon-tools -r scripts/requirements-icons.txt
```

Después de editar el SVG, regenera los iconos en Windows:

```powershell
./scripts/generate-icons.ps1
```

Para usar otra ruta: `./scripts/generate-icons.ps1 -SourceSvg assets/icon.svg`.
Requiere Python y PowerShell con System.Drawing. El SVG se rasteriza con resvg
a 2048 × 2048 en `build/icons/source.png` antes de generar los tamaños nativos.
El color de fondo `#0754AD` coincide con el SVG; si lo cambias, actualízalo
también en el script y en `flutter_launcher_icons` de `pubspec.yaml`.

El script genera los PNG de Android e iOS, los recursos adaptativos de Android
y las imágenes de `assets/icon/`. Añade margen alrededor del diseño para
protegerlo de los recortes del launcher. Los iconos de iOS se guardan en RGB,
sin canal alfa. El original permanece intacto.

Con Flutter también se pueden regenerar los recursos nativos desde las imágenes
ya preparadas de `assets/icon/` con `dart run flutter_launcher_icons`.

Compila e instala de nuevo la app para ver el cambio. La compilación de iOS
requiere macOS y Xcode. La interfaz usa `assets/icon/icon.png`. La pantalla de arranque usa la misma
imagen; regenera sus recursos con `dart run flutter_native_splash:create`.
`dart run flutter_launcher_icons` también genera el favicon y los iconos web.
