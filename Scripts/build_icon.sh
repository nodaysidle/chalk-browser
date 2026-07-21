#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
SVG="$ROOT/Assets/icon.svg"
ICONSET="$ROOT/Assets/icon.iconset"
ICNS="$ROOT/Assets/Icon.icns"
MASTER="$ROOT/Assets/icon-1024.png"

if [[ ! -f "$SVG" ]]; then
  echo "Missing $SVG" >&2
  exit 1
fi

render_master() {
  if command -v rsvg-convert >/dev/null 2>&1; then
    rsvg-convert -w 1024 -h 1024 "$SVG" -o "$MASTER"
    return
  fi
  if command -v magick >/dev/null 2>&1; then
    magick -background none -density 384 "$SVG" -resize 1024x1024 "$MASTER"
    return
  fi
  if command -v convert >/dev/null 2>&1; then
    convert -background none -density 384 "$SVG" -resize 1024x1024 "$MASTER"
    return
  fi
  qlmanage -t -s 1024 -o "$ROOT/Assets" "$SVG" >/dev/null 2>&1
  mv "$ROOT/Assets/$(basename "$SVG").png" "$MASTER"
}

rm -rf "$ICONSET"
mkdir -p "$ICONSET"
render_master

make_icon() {
  local size="$1"
  local name="$2"
  sips -z "$size" "$size" "$MASTER" --out "$ICONSET/$name" >/dev/null
}

make_icon 16 icon_16x16.png
make_icon 32 icon_16x16@2x.png
make_icon 32 icon_32x32.png
make_icon 64 icon_32x32@2x.png
make_icon 128 icon_128x128.png
make_icon 256 icon_128x128@2x.png
make_icon 256 icon_256x256.png
make_icon 512 icon_256x256@2x.png
make_icon 512 icon_512x512.png
make_icon 1024 icon_512x512@2x.png

iconutil -c icns "$ICONSET" -o "$ICNS"
rm -rf "$ICONSET"
rm -f "$MASTER"

echo "Created $ICNS"
