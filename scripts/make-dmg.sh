#!/bin/bash
# Crea build/ScreenRec.dmg: imagen de disco de arrastrar-a-Aplicaciones.
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="ScreenRec"
VERSION="1.0.0"
VOL_NAME="$APP_NAME"
BUILD_DIR="build"
APP="$BUILD_DIR/$APP_NAME.app"
DMG="$BUILD_DIR/$APP_NAME-$VERSION.dmg"

# Asegura que la .app está construida y al día.
bash scripts/build-app.sh

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

# ditto copia el bundle preservando la firma sin crear sidecars AppleDouble (._*).
ditto "$APP" "$STAGE/$APP_NAME.app"
ln -s /Applications "$STAGE/Applications"

# Icono de volumen = icono de la app (detalle bonito al montar).
if [ -f "$BUILD_DIR/AppIcon.icns" ]; then
  cp "$BUILD_DIR/AppIcon.icns" "$STAGE/.VolumeIcon.icns"
  SetFile -a C "$STAGE" 2>/dev/null || true
fi

rm -f "$DMG"
hdiutil create \
  -volname "$VOL_NAME" \
  -srcfolder "$STAGE" \
  -fs HFS+ \
  -format UDZO \
  -imagekey zlib-level=9 \
  -ov \
  "$DMG" >/dev/null

echo "OK → $DMG"
echo "Para instalar: abre el .dmg y arrastra $APP_NAME a la carpeta Aplicaciones."
