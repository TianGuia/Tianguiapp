#!/usr/bin/env bash
set -euo pipefail

# Mantener el entorno y el daemon de Gradle entre comandos del desarrollador.
if [[ ${1:-} == idle ]]; then exec sleep infinity; fi

# La versión está fijada por la imagen; no buscar actualizaciones en cada comando.
flutter() { /opt/flutter/bin/flutter --no-version-check "$@"; }

# No compartir cachés ni rutas SDK generadas por Flutter del host.
sync_source() {
  rsync -rlt --delete \
    --exclude=.git --exclude=.dart_tool --exclude=build --exclude=.gradle \
    --exclude=.kotlin --exclude=.cxx --exclude=.externalNativeBuild \
    --exclude=local.properties --exclude=.flutter-plugins-dependencies --exclude=.flutter-plugins \
    --exclude=.pub-cache --exclude=.idea --exclude=.env --exclude='.env.*' --exclude=/web \
    --exclude=.agents --exclude=.codex --exclude=.aws --exclude=.ssh --exclude=/supabase \
    /source/ /workspace/
  if [[ -d /source/web ]]; then rsync -rlt --delete /source/web/ /workspace/web/; fi
}
sync_source
printf 'sdk.dir=/opt/android-sdk\nflutter.sdk=/opt/flutter\n' > android/local.properties
# El proyecto permite 8 GB en el host; usar un límite más modesto en Docker.
printf 'org.gradle.jvmargs=-Xmx2G -XX:MaxMetaspaceSize=1G -XX:ReservedCodeCacheSize=256m\nkotlin.daemon.jvmargs=-Xmx1G\nkotlin.incremental=true\norg.gradle.workers.max=2\norg.gradle.caching=true\n' > /home/dev/.gradle/gradle.properties

command=${1:-doctor}
shift || true
watcher=''
cleanup() {
  if [[ -n "$watcher" ]]; then kill "$watcher" 2>/dev/null || true; wait "$watcher" 2>/dev/null || true; fi
  # El siguiente comando vuelve a habilitar web solo si lo necesita.
  flutter config --no-enable-web >/dev/null 2>&1 || true
}
trap cleanup EXIT
flutter config --no-enable-web >/dev/null

case "$command" in
  doctor) flutter doctor -v ;;
  devices) adb devices -l; flutter devices ;;
  test|analyze)
    flutter pub get --enforce-lockfile
    flutter "$command" --no-pub "$@"
    ;;
  apk)
    explicit_platform=false
    for argument in "$@"; do
      case "$argument" in --target-platform|--target-platform=*) explicit_platform=true ;; esac
    done
    if [[ "$explicit_platform" == false ]]; then set -- --target-platform android-arm64 "$@"; fi
    flutter pub get --enforce-lockfile
    # Borrar solo las entregas anteriores; conservar los productos intermedios.
    mkdir -p build/app/outputs/flutter-apk
    find build/app/outputs/flutter-apk -maxdepth 1 -type f -name '*.apk' -delete
    # Los splits también filtran bibliotecas nativas de dependencias por ABI.
    flutter build apk --no-pub --split-per-abi "$@"
    cp build/app/outputs/flutter-apk/*.apk /artifacts/
    ;;
  run|web)
    flutter pub get --enforce-lockfile
    if [[ "$command" == web ]]; then
      flutter config --enable-web >/dev/null
      # Solo la copia del contenedor recibe el soporte web generado.
      if [[ ! -d web ]]; then flutter create --platforms=web --no-pub .; fi
    else
      adb devices -l
      if ! adb devices | awk 'NR>1 && $2=="device" {found=1} END {exit !found}'; then
        echo 'No hay un teléfono autorizado. Revisa ADB en el host y autoriza la depuración.' >&2
        echo 'En Docker Desktop, comprueba Settings > Resources > Network > Enable host networking.' >&2
        exit 1
      fi
    fi
    # Los cambios del editor llegan antes de pulsar r/R en Flutter.
    (while sleep 1; do sync_source; done) &
    watcher=$!
    if [[ "$command" == web ]]; then
      echo 'Abre http://localhost:8080 en el navegador del host.'
      flutter run --no-pub -d web-server --web-hostname=0.0.0.0 --web-port=8080 "$@"
    else
      flutter run --no-pub "$@"
    fi
    ;;
  *) echo 'Comandos: doctor, devices, analyze, test, apk, run, web' >&2; exit 2 ;;
esac
