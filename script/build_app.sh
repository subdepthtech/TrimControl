#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/dist/TrimControl.app"
CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"
ICON_SOURCE="$ROOT/Assets/TrimControlIcon.png"
ICONSET="$ROOT/.build/TrimControl.iconset"

cd "$ROOT"

CONFIGURATION="${TRIMCONTROL_BUILD_CONFIGURATION:-debug}"
BUILD_FLAGS=(--configuration "$CONFIGURATION")

echo "Building SwiftPM products..."
swift build "${BUILD_FLAGS[@]}" --product TrimControl
swift build "${BUILD_FLAGS[@]}" --product trimcontrol-tool

BIN_PATH="$(swift build "${BUILD_FLAGS[@]}" --show-bin-path)"
TOOL="$BIN_PATH/trimcontrol-tool"
EXECUTABLE="$BIN_PATH/TrimControl"

if [[ ! -x "$EXECUTABLE" ]]; then
  echo "error: missing SwiftPM executable at $EXECUTABLE" >&2
  exit 1
fi

rm -rf "$APP"
mkdir -p "$MACOS" "$RESOURCES"

ditto "$EXECUTABLE" "$MACOS/TrimControl"
chmod 755 "$MACOS/TrimControl"

if [[ ! -f "$ICON_SOURCE" ]]; then
  echo "error: missing app icon source at $ICON_SOURCE" >&2
  exit 1
fi

rm -rf "$ICONSET"
mkdir -p "$ICONSET"
sips -z 16 16 "$ICON_SOURCE" --out "$ICONSET/icon_16x16.png" >/dev/null
sips -z 32 32 "$ICON_SOURCE" --out "$ICONSET/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$ICON_SOURCE" --out "$ICONSET/icon_32x32.png" >/dev/null
sips -z 64 64 "$ICON_SOURCE" --out "$ICONSET/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$ICON_SOURCE" --out "$ICONSET/icon_128x128.png" >/dev/null
sips -z 256 256 "$ICON_SOURCE" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$ICON_SOURCE" --out "$ICONSET/icon_256x256.png" >/dev/null
sips -z 512 512 "$ICON_SOURCE" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$ICON_SOURCE" --out "$ICONSET/icon_512x512.png" >/dev/null
sips -z 1024 1024 "$ICON_SOURCE" --out "$ICONSET/icon_512x512@2x.png" >/dev/null
iconutil -c icns "$ICONSET" -o "$RESOURCES/TrimControl.icns"

"$TOOL" generate-info-plist --output "$CONTENTS/Info.plist"
plutil -lint "$CONTENTS/Info.plist"

"$ROOT/script/sign_app.sh" "$APP"
codesign --verify --deep --strict "$APP"

echo "Built $APP"
