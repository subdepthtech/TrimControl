#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="/Applications/TrimControl.app"
EXPLICIT_APP=0
REQUIRE_DEFAULTS=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --app)
      APP="$2"
      EXPLICIT_APP=1
      shift 2
      ;;
    --require-defaults)
      REQUIRE_DEFAULTS=1
      shift
      ;;
    --no-defaults)
      REQUIRE_DEFAULTS=0
      shift
      ;;
    *)
      echo "error: unknown argument $1" >&2
      exit 1
      ;;
  esac
done

if [[ "$EXPLICIT_APP" -eq 0 ]]; then
  REQUIRE_DEFAULTS=1
fi

cd "$ROOT"

if [[ ! -d "$APP" ]]; then
  echo "error: app not found: $APP" >&2
  exit 1
fi

swift build --product trimcontrol-tool
BIN_PATH="$(swift build --show-bin-path)"
TOOL="$BIN_PATH/trimcontrol-tool"
INFO_PLIST="$APP/Contents/Info.plist"
EXECUTABLE="$APP/Contents/MacOS/TrimControl"

if [[ ! -f "$INFO_PLIST" ]]; then
  echo "error: missing Info.plist at $INFO_PLIST" >&2
  exit 1
fi

if [[ ! -x "$EXECUTABLE" ]]; then
  echo "error: missing native executable at $EXECUTABLE" >&2
  exit 1
fi

FILE_OUTPUT="$(/usr/bin/file "$EXECUTABLE")"
case "$FILE_OUTPUT" in
  *Mach-O*)
    echo "ok: native executable: $FILE_OUTPUT"
    ;;
  *)
    echo "error: executable is not Mach-O: $FILE_OUTPUT" >&2
    exit 1
    ;;
esac

if grep -q "<string>ts</string>" "$INFO_PLIST"; then
  echo "error: Info.plist advertises .ts, which v1 must not claim" >&2
  exit 1
fi
echo "ok: Info.plist does not advertise .ts"

"$TOOL" verify-bundle --app "$APP"

if [[ "$REQUIRE_DEFAULTS" -eq 1 ]]; then
  "$TOOL" verify-defaults --app "$APP" --require-defaults
else
  "$TOOL" verify-defaults --app "$APP"
fi
