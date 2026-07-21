#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
APP_NAME="nodaysidle.app"
SOURCE="$ROOT/$APP_NAME"
TARGET="/Applications/$APP_NAME"

bash "$ROOT/Scripts/package_app.sh" release

osascript -e 'tell application "nodaysidle" to quit' >/dev/null 2>&1 || true
sleep 0.5

rm -rf "$TARGET"
ditto "$SOURCE" "$TARGET"
xattr -cr "$TARGET" 2>/dev/null || true
codesign --verify --deep --strict --verbose=2 "$TARGET"

# Refresh Finder / Dock icon cache for the installed bundle.
touch "$TARGET"
if [[ -x /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister ]]; then
  /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$TARGET"
fi
killall Dock >/dev/null 2>&1 || true

echo "Installed $TARGET"
