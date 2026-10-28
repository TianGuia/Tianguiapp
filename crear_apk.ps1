# Genera el APK de TianGuía. Se ejecuta desde la carpeta del proyecto.
Set-Location $PSScriptRoot

# Valores del proyecto Supabase (la clave "publishable" es pública, es seguro dejarla aquí).
# Si algún día cambias de proyecto, edita estas dos líneas.
$url = "https://ijnvztoyhizdwtzagrvy.supabase.co"
$key = "sb_publishable_C4i-Lm08t35unAMETI36uw_0pH9hSc1"

flutter build apk --release --split-per-abi `
  "--dart-define=SUPABASE_URL=$url" `
  "--dart-define=SUPABASE_KEY=$key"

if ($LASTEXITCODE -eq 0) {
  Write-Host ""
  Write-Host "LISTO. Manda por WhatsApp/Drive: app-arm64-v8a-release.apk" -ForegroundColor Green
  explorer.exe "build\app\outputs\flutter-apk"
} else {
  Write-Host "Algo falló. Copia el error de arriba y mándamelo." -ForegroundColor Red
}
