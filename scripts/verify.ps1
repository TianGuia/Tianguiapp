# Funciona desde cualquier directorio; usa Docker de WSL si no hay CLI nativa.
$ErrorActionPreference = 'Stop'
Push-Location (Split-Path $PSScriptRoot -Parent)
try {
    $composeArgs = @('compose', '-f', 'compose.verify.yaml', 'run', '--build', '--rm', '-T', 'verify')
    if (Get-Command docker -ErrorAction SilentlyContinue) {
        & docker @composeArgs
    } elseif (Get-Command wsl -ErrorAction SilentlyContinue) {
        & wsl --exec docker @composeArgs
    } else {
        throw 'Necesitas Docker con Compose v2, en el host o en WSL.'
    }
    if ($LASTEXITCODE) { throw "La verificación falló (código $LASTEXITCODE)." }
} finally { Pop-Location }
