#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
flutter --version
flutter pub get --enforce-lockfile
# Upstream has pre-existing stylistic infos; errors and warnings remain fatal.
flutter analyze --no-fatal-infos
flutter test --reporter expanded
python3 scripts/check_native_locales.py
