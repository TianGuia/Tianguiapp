# Uso: ./scripts/dev.ps1 run -d <dispositivo> --dart-define=...
$ErrorActionPreference = 'Stop'
$task = if ($args.Count) { $args[0] } else { 'doctor' }
$flutterArgs = if ($args.Count -gt 1) { $args[1..($args.Count - 1)] } else { @() }
if ($task -notin @('doctor', 'devices', 'analyze', 'test', 'apk', 'run', 'web', 'ios', 'stop')) {
    throw 'Comandos: doctor, devices, analyze, test, apk, run, web, ios, stop'
}
if ($task -eq 'ios') { throw 'iOS requiere macOS, Xcode y Flutter nativos. Usa scripts/dev.sh ios en macOS.' }
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    throw 'Instala Docker Desktop con contenedores Linux y Docker Compose.'
}
Push-Location (Split-Path $PSScriptRoot -Parent)
try {
    $dockerOS = & docker info --format '{{.OSType}}' 2>$null
    if ($LASTEXITCODE -or $dockerOS -ne 'linux') { throw 'Inicia Docker Desktop con contenedores Linux.' }
    if ($task -eq 'stop') {
        & docker compose stop
        if ($LASTEXITCODE) { throw 'No se pudo detener el entorno.' }
        return
    }
    New-Item -ItemType Directory -Force build/docker | Out-Null
    $service = 'dev'
    if ($task -in @('run', 'devices')) {
        $service = 'android'
        $adb = (Get-Command adb -ErrorAction SilentlyContinue).Source
        if (-not $adb) {
            $sdk = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } elseif ($env:ANDROID_SDK_ROOT) { $env:ANDROID_SDK_ROOT } else { "$env:LOCALAPPDATA/Android/Sdk" }
            $adb = Join-Path $sdk 'platform-tools/adb.exe'
        }
        if (-not (Test-Path -LiteralPath $adb)) {
            throw 'No se encontró ADB. Instala Android SDK Platform-Tools y agrega su carpeta al PATH.'
        }
        & $adb start-server
        if ($LASTEXITCODE) { throw 'No se pudo iniciar ADB.' }
        & $adb devices -l
    }
    if ($task -eq 'web') { $service = 'web' }
    $otherServices = @('dev', 'android', 'web') | Where-Object { $_ -ne $service }
    & docker compose stop @otherServices
    if ($LASTEXITCODE) { throw 'No se pudieron detener los servicios sin usar.' }
    & docker compose up -d --build $service
    if ($LASTEXITCODE) { throw 'No se pudo preparar el contenedor.' }
    & docker compose exec $service tianguia-dev $task @flutterArgs
    if ($LASTEXITCODE) { throw "El comando terminó con código $LASTEXITCODE." }
} finally { Pop-Location }
