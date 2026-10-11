#!/bin/sh
# Compila o app para o simulador (sem assinar). Uso: scripts/build.sh [Demo|Local|Release]
set -e
cd "$(dirname "$0")/.."
CONFIG="${1:-Demo}"
case "$CONFIG" in Demo) SCHEME="EFinances Demo" ;; Local) SCHEME="EFinances Local" ;; *) SCHEME="EFinances" ;; esac
[ -d EFinances.xcodeproj ] || scripts/xcode.sh --no-open
xcodebuild -project EFinances.xcodeproj -scheme "$SCHEME" -configuration "$CONFIG" \
  -destination 'generic/platform=iOS Simulator' -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO build | tail -20
echo "App: build/DerivedData/Build/Products/$CONFIG-iphonesimulator/EFinances.app"
