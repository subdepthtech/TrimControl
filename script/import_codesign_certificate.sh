#!/usr/bin/env bash
set -euo pipefail

: "${APPLE_CERTIFICATE_P12:?Set APPLE_CERTIFICATE_P12 to a base64-encoded Developer ID Application .p12.}"
: "${APPLE_CERTIFICATE_PASSWORD:?Set APPLE_CERTIFICATE_PASSWORD.}"

KEYCHAIN_PASSWORD="${KEYCHAIN_PASSWORD:-$(uuidgen)}"
KEYCHAIN_PATH="${RUNNER_TEMP:-/tmp}/trimcontrol-signing.keychain-db"
CERTIFICATE_PATH="${RUNNER_TEMP:-/tmp}/trimcontrol-developer-id.p12"

cleanup() {
  status=$?
  rm -f "$CERTIFICATE_PATH"

  if [[ "$status" -ne 0 && -f "$KEYCHAIN_PATH" ]]; then
    security delete-keychain "$KEYCHAIN_PATH" >/dev/null 2>&1 || rm -f "$KEYCHAIN_PATH"
  fi

  exit "$status"
}
trap cleanup EXIT

if [[ -f "$KEYCHAIN_PATH" ]]; then
  security delete-keychain "$KEYCHAIN_PATH" >/dev/null 2>&1 || rm -f "$KEYCHAIN_PATH"
fi

if printf '%s' "$APPLE_CERTIFICATE_P12" | /usr/bin/base64 --decode >"$CERTIFICATE_PATH" 2>/dev/null; then
  :
else
  printf '%s' "$APPLE_CERTIFICATE_P12" | /usr/bin/base64 -D >"$CERTIFICATE_PATH"
fi

security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
security set-keychain-settings -lut 21600 "$KEYCHAIN_PATH"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
security import "$CERTIFICATE_PATH" \
  -P "$APPLE_CERTIFICATE_PASSWORD" \
  -T /usr/bin/codesign \
  -T /usr/bin/security \
  -t cert \
  -f pkcs12 \
  -k "$KEYCHAIN_PATH"
security set-key-partition-list \
  -S apple-tool:,apple:,codesign: \
  -s \
  -k "$KEYCHAIN_PASSWORD" \
  "$KEYCHAIN_PATH"

existing_keychains=()
while IFS= read -r keychain; do
  existing_keychains+=("$keychain")
done < <(security list-keychains -d user | sed 's/^ *//; s/"//g')
security list-keychains -d user -s "$KEYCHAIN_PATH" "${existing_keychains[@]}"
security find-identity -v -p codesigning "$KEYCHAIN_PATH"

{
  echo "TRIMCONTROL_SIGNING_KEYCHAIN_PATH=$KEYCHAIN_PATH"
} >>"${GITHUB_ENV:-/dev/null}"

echo "Imported Developer ID certificate into $KEYCHAIN_PATH"
