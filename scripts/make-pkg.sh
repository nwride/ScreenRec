#!/bin/bash
# Crea build/ScreenRec-<version>.pkg: instalador que coloca ScreenRec.app en
# /Applications. Al terminar, deja la app lista (el usuario la abre desde Launchpad
# o Aplicaciones).
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="ScreenRec"
BUNDLE_ID="io.github.nwride.ScreenRec"
VERSION="1.0.0"
BUILD_DIR="build"
APP="$BUILD_DIR/$APP_NAME.app"
PKG="$BUILD_DIR/$APP_NAME-$VERSION.pkg"

# Asegura que la .app está construida y al día.
bash scripts/build-app.sh

# "root" con la jerarquía de instalación: /Applications/ScreenRec.app
ROOT="$(mktemp -d)"
trap 'rm -rf "$ROOT"' EXIT
mkdir -p "$ROOT/Applications"
# ditto copia el bundle preservando la firma sin crear sidecars AppleDouble (._*).
ditto "$APP" "$ROOT/Applications/$APP_NAME.app"

rm -f "$PKG"
pkgbuild \
  --root "$ROOT" \
  --identifier "$BUNDLE_ID" \
  --version "$VERSION" \
  --install-location "/" \
  "$PKG" >/dev/null

echo "OK → $PKG"
echo "Para instalar: abre el .pkg y sigue el asistente (instala en /Applications)."
