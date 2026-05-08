#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_APP="$ROOT/dist/TrimControl.app"
INSTALL_APP="/Applications/TrimControl.app"
LEGACY_APP="/Applications/OpenWithNeovim.app"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"

cd "$ROOT"

"$ROOT/script/build_app.sh"
"$ROOT/script/verify_defaults.sh" --app "$DIST_APP"

if [[ -d "$LEGACY_APP" ]]; then
  LEGACY_BACKUP="/Applications/OpenWithNeovim.app.backup-$TIMESTAMP"
  echo "Backing up $LEGACY_APP to $LEGACY_BACKUP"
  ditto "$LEGACY_APP" "$LEGACY_BACKUP"
fi

if [[ -d "$INSTALL_APP" ]]; then
  INSTALLED_BACKUP="/Applications/TrimControl.app.backup-$TIMESTAMP"
  echo "Backing up existing $INSTALL_APP to $INSTALLED_BACKUP"
  ditto "$INSTALL_APP" "$INSTALLED_BACKUP"
  rm -rf "$INSTALL_APP"
fi

echo "Installing $INSTALL_APP"
ditto "$DIST_APP" "$INSTALL_APP"
"$ROOT/script/sign_app.sh" "$INSTALL_APP"

BIN_PATH="$(swift build --show-bin-path)"
TOOL="$BIN_PATH/trimcontrol-tool"

"$TOOL" register-app --app "$INSTALL_APP"
"$TOOL" apply-defaults --app "$INSTALL_APP" --groups all

"$ROOT/script/verify_defaults.sh"

echo "Installed $INSTALL_APP"
