#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: script/notarize_dmg.sh <dmg-path>" >&2
  exit 2
fi

DMG="$1"

if [[ ! -f "$DMG" ]]; then
  echo "error: DMG not found: $DMG" >&2
  exit 1
fi

if [[ -n "${APP_STORE_CONNECT_KEY_ID:-}" || -n "${APP_STORE_CONNECT_ISSUER_ID:-}" || -n "${APP_STORE_CONNECT_KEY_PATH:-}" ]]; then
  : "${APP_STORE_CONNECT_KEY_ID:?Set APP_STORE_CONNECT_KEY_ID.}"
  : "${APP_STORE_CONNECT_ISSUER_ID:?Set APP_STORE_CONNECT_ISSUER_ID.}"
  : "${APP_STORE_CONNECT_KEY_PATH:?Set APP_STORE_CONNECT_KEY_PATH.}"

  xcrun notarytool submit "$DMG" \
    --key "$APP_STORE_CONNECT_KEY_PATH" \
    --key-id "$APP_STORE_CONNECT_KEY_ID" \
    --issuer "$APP_STORE_CONNECT_ISSUER_ID" \
    --wait
elif [[ -n "${APPLE_ID:-}" || -n "${APPLE_APP_SPECIFIC_PASSWORD:-}" || -n "${APPLE_TEAM_ID:-}" ]]; then
  : "${APPLE_ID:?Set APPLE_ID.}"
  : "${APPLE_APP_SPECIFIC_PASSWORD:?Set APPLE_APP_SPECIFIC_PASSWORD.}"
  : "${APPLE_TEAM_ID:?Set APPLE_TEAM_ID.}"

  xcrun notarytool submit "$DMG" \
    --apple-id "$APPLE_ID" \
    --password "$APPLE_APP_SPECIFIC_PASSWORD" \
    --team-id "$APPLE_TEAM_ID" \
    --wait
else
  echo "error: notarization credentials are missing." >&2
  echo "Set App Store Connect API key env vars or Apple ID notarytool env vars." >&2
  exit 1
fi

xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"

echo "Notarized and stapled $DMG"
