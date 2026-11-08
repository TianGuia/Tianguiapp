#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

python3 -m unittest discover -s .github/scripts -p 'test_*.py'
flutter --no-version-check pub get --enforce-lockfile
flutter --no-version-check analyze --no-pub
flutter --no-version-check test --no-pub
