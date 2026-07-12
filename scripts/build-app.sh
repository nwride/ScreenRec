#!/bin/bash
# Compila ScreenRec con SPM y ensambla build/ScreenRec.app
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="ScreenRec"
BUNDLE_ID="io.github.nwride.ScreenRec"
VERSION="1.1.0"
BUILD_DIR="build"
APP="$BUILD_DIR/$APP_NAME.app"

# Compilación directa con swiftc: los Command Line Tools de esta máquina no
# traen el "platform path" que necesita `swift build` (SPM). No hay dependencias
# externas, así que swiftc es suficiente. Con Xcode completo, Package.swift
# también funciona.
ARCH="$(uname -m)"
mkdir -p "$BUILD_DIR"
swiftc -O -target "$ARCH-apple-macos13.0" \
  $(find Sources -name '*.swift' | sort) \
  -o "$BUILD_DIR/$APP_NAME-bin"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BUILD_DIR/$APP_NAME-bin" "$APP/Contents/MacOS/$APP_NAME"

# Icono: se genera una sola vez y se reutiliza
if [ ! -f "$BUILD_DIR/AppIcon.icns" ]; then
  swift scripts/make-icon.swift "$BUILD_DIR/AppIcon.icns" || echo "aviso: no se pudo generar el icono (no es crítico)"
fi
if [ -f "$BUILD_DIR/AppIcon.icns" ]; then
  cp "$BUILD_DIR/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
fi

cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleName</key><string>$APP_NAME</string>
	<key>CFBundleDisplayName</key><string>$APP_NAME</string>
	<key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
	<key>CFBundleExecutable</key><string>$APP_NAME</string>
	<key>CFBundleShortVersionString</key><string>$VERSION</string>
	<key>CFBundleVersion</key><string>1</string>
	<key>CFBundlePackageType</key><string>APPL</string>
	<key>LSMinimumSystemVersion</key><string>13.0</string>
	<key>LSUIElement</key><true/>
	<key>NSHighResolutionCapable</key><true/>
	<key>CFBundleIconFile</key><string>AppIcon</string>
	<key>NSHumanReadableCopyright</key><string>© 2026 nwride</string>
</dict>
</plist>
EOF

# Firma: certificado local "ScreenRec Dev" si existe (permiso de pantalla estable
# entre builds); si no, firma ad-hoc.
if security find-identity -v -p codesigning 2>/dev/null | grep -q "ScreenRec Dev"; then
  codesign --force --sign "ScreenRec Dev" "$APP"
  echo "Firmado con certificado local 'ScreenRec Dev'"
else
  codesign --force --sign - "$APP"
  echo "Firmado ad-hoc (macOS puede volver a pedir el permiso de grabación tras recompilar; ver scripts/make-signing-cert.sh)"
fi

echo "OK → $APP"
