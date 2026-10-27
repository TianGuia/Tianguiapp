# Regenera los iconos nativos desde el SVG, sin requerir Flutter (Windows).
param([string] $SourceSvg = 'assets/icon/logo.svg')
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$repoRoot = Split-Path $PSScriptRoot -Parent
$rasterPath = Join-Path $repoRoot 'build/icons/source.png'
& python (Join-Path $PSScriptRoot 'render-icon.py') (Join-Path $repoRoot $SourceSvg) $rasterPath
if ($LASTEXITCODE) { throw 'No se pudo rasterizar el SVG del icono.' }
$source = [System.Drawing.Image]::FromFile($rasterPath)
$background = [System.Drawing.ColorTranslator]::FromHtml('#0754AD')

function Write-Icon([string] $RelativePath, [int] $Size, [double] $ContentScale = 0.86, [switch] $Transparent) {
    $path = Join-Path $repoRoot $RelativePath
    [System.IO.Directory]::CreateDirectory((Split-Path $path -Parent)) | Out-Null
    $pixelFormat = if ($Transparent) { [System.Drawing.Imaging.PixelFormat]::Format32bppArgb } else { [System.Drawing.Imaging.PixelFormat]::Format24bppRgb }
    $bitmap = [System.Drawing.Bitmap]::new($Size, $Size, $pixelFormat)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    try {
        if ($Transparent) { $graphics.Clear([System.Drawing.Color]::Transparent) }
        else { $graphics.Clear($background) }
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $side = [int][Math]::Round($Size * $ContentScale)
        $offset = [int][Math]::Floor(($Size - $side) / 2)
        $graphics.DrawImage($source, $offset, $offset, $side, $side)
        $bitmap.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    } finally {
        $graphics.Dispose()
        $bitmap.Dispose()
    }
}

try {
    Write-Icon 'assets/icon/icon.png' 1024
    # El lienzo adaptativo de Android se recorta con distintas mascaras.
    # El cuadrado central queda dentro del circulo seguro, incluso en esquinas.
    Write-Icon 'assets/icon/icon_foreground.png' 432 0.44 -Transparent
    $densities = [ordered]@{mdpi = 48; hdpi = 72; xhdpi = 96; xxhdpi = 144; xxxhdpi = 192}
    foreach ($density in $densities.GetEnumerator()) {
        Write-Icon "android/app/src/main/res/mipmap-$($density.Key)/ic_launcher.png" $density.Value
        Write-Icon "android/app/src/main/res/drawable-$($density.Key)/ic_launcher_foreground.png" ($density.Value * 108 / 48) 0.44 -Transparent
    }
    $adaptiveDirectory = Join-Path $repoRoot 'android/app/src/main/res/mipmap-anydpi-v26'
    [System.IO.Directory]::CreateDirectory($adaptiveDirectory) | Out-Null
    $adaptiveXml = @'
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background" />
    <foreground android:drawable="@drawable/ic_launcher_foreground" />
</adaptive-icon>
'@
    [System.IO.File]::WriteAllText((Join-Path $adaptiveDirectory 'ic_launcher.xml'), $adaptiveXml)
    # flutter_launcher_icons usa colors.xml; comparte su definicion para evitar duplicados.
    $colorsPath = Join-Path $repoRoot 'android/app/src/main/res/values/colors.xml'
    [xml] $colorsXml = if (Test-Path $colorsPath) { Get-Content $colorsPath -Raw } else { '<resources />' }
    $launcherColor = $colorsXml.SelectSingleNode('/resources/color[@name="ic_launcher_background"]')
    if ($null -eq $launcherColor) {
        $launcherColor = $colorsXml.CreateElement('color')
        $launcherColor.SetAttribute('name', 'ic_launcher_background')
        $colorsXml.DocumentElement.AppendChild($launcherColor) | Out-Null
    }
    $launcherColor.InnerText = '#0754AD'
    $colorsXml.Save($colorsPath)
    $catalog = 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
    $contents = Get-Content (Join-Path $repoRoot "$catalog/Contents.json") -Raw | ConvertFrom-Json
    foreach ($entry in $contents.images) {
        $points = [double]::Parse(($entry.size -split 'x')[0], [System.Globalization.CultureInfo]::InvariantCulture)
        $scale = [double]::Parse($entry.scale.TrimEnd('x'), [System.Globalization.CultureInfo]::InvariantCulture)
        Write-Icon "$catalog/$($entry.filename)" ([int]($points * $scale))
    }
    Write-Output "Iconos de Android e iOS regenerados desde $SourceSvg."
} finally {
    $source.Dispose()
}
