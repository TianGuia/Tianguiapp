#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
task=${1:-doctor}
shift || true
case "$task" in
  ios)
    [[ $(uname -s) == Darwin ]] || { echo 'iOS requiere macOS y Xcode.' >&2; exit 1; }
    command -v flutter >/dev/null || { echo 'Instala Flutter en macOS para iOS.' >&2; exit 1; }
    # Usar el proyecto nativo versionado; no regenerarlo implícitamente.
    [[ -d ios ]] || { echo 'Falta configurar el destino iOS en el proyecto (flutter create --platforms=ios .).' >&2; exit 1; }
    exec flutter run "$@"
    ;;
  doctor|devices|analyze|test|apk|run|web|stop) ;;
  *) echo 'Comandos: doctor, devices, analyze, test, apk, run, web, ios, stop' >&2; exit 2 ;;
esac
command -v docker >/dev/null || { echo 'Instala Docker con Docker Compose.' >&2; exit 1; }
if ! docker info >/dev/null 2>&1; then
  echo 'No se puede acceder a Docker. Inicia el motor y revisa los permisos de tu usuario.' >&2
  exit 1
fi
if [[ "$task" == stop ]]; then exec docker compose stop; fi
mkdir -p build/docker
service=dev
# Permitir exportar APK aunque el usuario del host no tenga UID 1000.
chmod g+w build/docker
export TIANGUIA_HOST_GID="$(id -g)"
if [[ "$task" == run || "$task" == devices ]]; then
  service=android
  adb_bin=$(command -v adb || true)
  if [[ -z "$adb_bin" ]]; then
    sdk=${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}
    if [[ -z "$sdk" && $(uname -s) == Darwin ]]; then sdk="$HOME/Library/Android/sdk"; fi
    adb_bin="${sdk:-$HOME/Android/Sdk}/platform-tools/adb"
  fi
  [[ -x "$adb_bin" ]] || { echo 'Instala Android SDK Platform-Tools y agrega adb al PATH.' >&2; exit 1; }
  "$adb_bin" start-server
  "$adb_bin" devices -l
fi
if [[ "$task" == web ]]; then service=web; fi
other_services=()
for candidate in dev android web; do
  if [[ "$candidate" != "$service" ]]; then other_services+=("$candidate"); fi
done
docker compose stop "${other_services[@]}"
docker compose up -d --build "$service"
exec docker compose exec "$service" tianguia-dev "$task" "$@"
