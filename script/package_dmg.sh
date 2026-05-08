#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/dist/TrimControl.app"
RELEASE_DIR="$ROOT/dist/release"
STAGE_PARENT="$RELEASE_DIR/stage"
SKIP_BUILD=0
VERSION="${TRIMCONTROL_VERSION:-}"
ARCHITECTURE="${TRIMCONTROL_RELEASE_ARCH:-$(uname -m)}"

usage() {
  cat <<'USAGE'
usage: script/package_dmg.sh [--version <version>] [--arch <arch>] [--skip-build]

Builds TrimControl.app, stages a drag-install DMG, verifies it, and writes:
  dist/release/TrimControl-<version>-<arch>.dmg
  dist/release/TrimControl-<version>-<arch>.dmg.sha256

Environment:
  TRIMCONTROL_VERSION              Bundle short version and default DMG version.
  TRIMCONTROL_BUILD_NUMBER         Bundle build number. Defaults to 1.
  TRIMCONTROL_BUILD_CONFIGURATION  SwiftPM configuration. Defaults to release here.
  TRIMCONTROL_SIGN_IDENTITY        codesign identity passed through build_app.sh.
  TRIMCONTROL_RELEASE_ARCH         DMG filename architecture label. Defaults to uname -m.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)
      VERSION="$2"
      shift 2
      ;;
    --arch)
      ARCHITECTURE="$2"
      shift 2
      ;;
    --skip-build)
      SKIP_BUILD=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown argument $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

cd "$ROOT"

if [[ -z "$VERSION" ]]; then
  if git describe --tags --exact-match >/dev/null 2>&1; then
    VERSION="$(git describe --tags --exact-match | sed 's/^v//')"
  elif [[ -d "$APP" ]]; then
    VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
  else
    VERSION="0.1.0"
  fi
fi

if [[ -z "${TRIMCONTROL_BUILD_NUMBER:-}" ]]; then
  export TRIMCONTROL_BUILD_NUMBER=1
fi
export TRIMCONTROL_VERSION="$VERSION"

if [[ "$SKIP_BUILD" -eq 0 ]]; then
  TRIMCONTROL_BUILD_CONFIGURATION="${TRIMCONTROL_BUILD_CONFIGURATION:-release}" "$ROOT/script/build_app.sh"
fi

if [[ ! -d "$APP" ]]; then
  echo "error: app not found: $APP" >&2
  exit 1
fi

"$ROOT/script/verify_defaults.sh" --app "$APP"
codesign --verify --deep --strict "$APP"

APP_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
if [[ "$APP_VERSION" != "$VERSION" ]]; then
  echo "error: app version $APP_VERSION does not match release version $VERSION" >&2
  exit 1
fi

mkdir -p "$RELEASE_DIR" "$STAGE_PARENT"
STAGE_DIR="$STAGE_PARENT/TrimControl-$VERSION-$ARCHITECTURE"
DMG="$RELEASE_DIR/TrimControl-$VERSION-$ARCHITECTURE.dmg"
SHA_FILE="$DMG.sha256"

rm -rf "$STAGE_DIR" "$DMG" "$SHA_FILE"
mkdir -p "$STAGE_DIR"
ditto "$APP" "$STAGE_DIR/TrimControl.app"
ln -s /Applications "$STAGE_DIR/Applications"

hdiutil create \
  -volname "TrimControl $VERSION" \
  -srcfolder "$STAGE_DIR" \
  -fs HFS+ \
  -format UDZO \
  -ov \
  "$DMG"

hdiutil verify "$DMG"
shasum --algorithm 256 "$DMG" | tee "$SHA_FILE"

echo "Packaged $DMG"
