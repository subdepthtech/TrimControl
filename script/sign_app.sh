#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: script/sign_app.sh <app-path>" >&2
  exit 2
fi

APP="$1"
SIGN_IDENTITY="${TRIMCONTROL_SIGN_IDENTITY:--}"
REQUIRE_IDENTITY="${TRIMCONTROL_REQUIRE_SIGN_IDENTITY:-0}"

if [[ -z "$SIGN_IDENTITY" ]]; then
  SIGN_IDENTITY="-"
fi

if [[ "$SIGN_IDENTITY" == "-" ]]; then
  if [[ "$REQUIRE_IDENTITY" == "1" ]]; then
    echo "error: TRIMCONTROL_SIGN_IDENTITY must name a Developer ID identity for release signing" >&2
    exit 1
  fi

  codesign --force --deep --sign - "$APP"
  exit 0
fi

if security find-identity -v -p codesigning | grep -F "\"$SIGN_IDENTITY\"" >/dev/null; then
  codesign --force --deep --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP"
else
  if [[ "$REQUIRE_IDENTITY" == "1" ]]; then
    echo "error: required signing identity not found: $SIGN_IDENTITY" >&2
    exit 1
  fi
  echo "warning: signing identity not found: $SIGN_IDENTITY" >&2
  echo "warning: falling back to ad-hoc signing" >&2
  codesign --force --deep --sign - "$APP"
fi
