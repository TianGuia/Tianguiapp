#!/usr/bin/env bash
set -euo pipefail

# Copia nueva por ejecución: sin SDK, cachés ni archivos generados del host.
# La fuente se monta de solo lectura; solo Pub persiste entre ejecuciones.
rsync -rlt --delete \
  --exclude=/.git --exclude=/.dart_tool --exclude=/build \
  --exclude=/.flutter-plugins --exclude=/.flutter-plugins-dependencies \
  --exclude=/android/local.properties --exclude=/.pub-cache \
  --exclude=.gradle --exclude=.kotlin --exclude=.cxx \
  --exclude=.externalNativeBuild --exclude=node_modules --exclude=.venv \
  --exclude=/tmp --exclude=/Toldo --exclude=/.agents --exclude=/.codex \
  --exclude=/.env --exclude='/.env.*' \
  /source/ /workspace/
cd /workspace
exec bash scripts/verify.sh
