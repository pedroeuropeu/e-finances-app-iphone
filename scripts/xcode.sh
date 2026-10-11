#!/bin/sh
# Gera o projeto do Xcode (EFinances.xcodeproj) a partir do project.yml e abre no Xcode.
# Precisa do Xcode instalado (App Store) e do XcodeGen (brew install xcodegen).
set -e
cd "$(dirname "$0")/.."
if ! xcodebuild -version >/dev/null 2>&1; then
  echo "O Xcode não está instalado ou não está selecionado."
  echo "1) Instale o Xcode pela App Store"
  echo "2) Rode: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
  exit 1
fi
if ! command -v xcodegen >/dev/null 2>&1; then
  echo "Falta o XcodeGen. Instale com: brew install xcodegen"
  exit 1
fi
xcodegen generate --spec project.yml
[ "$1" = "--no-open" ] || open EFinances.xcodeproj
