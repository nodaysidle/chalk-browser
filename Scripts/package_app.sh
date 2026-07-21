#!/usr/bin/env bash
set -euo pipefail

CONF=${1:-release}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

APP_NAME=${APP_NAME:-nodaysidle}
BUNDLE_ID=${BUNDLE_ID:-com.nodaysidle.browser}
MACOS_MIN_VERSION=${MACOS_MIN_VERSION:-14.0}

if [[ -f "$ROOT/version.env" ]]; then
  # shellcheck disable=SC1091
  source "$ROOT/version.env"
else
  MARKETING_VERSION=${MARKETING_VERSION:-0.1.0}
  BUILD_NUMBER=${BUILD_NUMBER:-1}
fi

HOST_ARCH=$(uname -m)
bash "$ROOT/Scripts/build_icon.sh"
swift build -c "$CONF" --arch "$HOST_ARCH"

APP="$ROOT/${APP_NAME}.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

BUILD_DIR=".build/${HOST_ARCH}-apple-macosx/${CONF}"
BINARY="$BUILD_DIR/nodaysidle"
if [[ ! -f "$BINARY" ]]; then
  BINARY=".build/${CONF}/nodaysidle"
fi

cp "$BINARY" "$APP/Contents/MacOS/${APP_NAME}"
chmod +x "$APP/Contents/MacOS/${APP_NAME}"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key><string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
    <key>CFBundleExecutable</key><string>${APP_NAME}</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>${MARKETING_VERSION}</string>
    <key>CFBundleVersion</key><string>${BUILD_NUMBER}</string>
    <key>LSMinimumSystemVersion</key><string>${MACOS_MIN_VERSION}</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>CFBundleIconFile</key><string>Icon</string>
</dict>
</plist>
PLIST

if [[ -f "$ROOT/Assets/Icon.icns" ]]; then
  cp "$ROOT/Assets/Icon.icns" "$APP/Contents/Resources/Icon.icns"
elif [[ -f "$ROOT/Icon.icns" ]]; then
  cp "$ROOT/Icon.icns" "$APP/Contents/Resources/Icon.icns"
fi

xattr -cr "$APP" 2>/dev/null || true
codesign --force --sign "-" "$APP"

echo "Created $APP"
