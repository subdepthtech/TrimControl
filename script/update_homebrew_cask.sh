#!/usr/bin/env bash
set -euo pipefail

TAP_PATH="${TAP_PATH:-}"
VERSION="${VERSION:-${TRIMCONTROL_VERSION:-}}"
SHA256="${SHA256:-}"
DOWNLOAD_URL="${DOWNLOAD_URL:-}"
CASK_PATH="${CASK_PATH:-Casks/trimcontrol.rb}"
HOMEPAGE_URL="${HOMEPAGE_URL:-https://github.com/subdepthtech/TrimControl}"

if [[ $# -gt 0 ]]; then
  TAP_PATH="$1"
fi

: "${TAP_PATH:?Set TAP_PATH or pass the tap checkout path.}"
: "${VERSION:?Set VERSION.}"
: "${SHA256:?Set SHA256.}"
: "${DOWNLOAD_URL:?Set DOWNLOAD_URL.}"

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "VERSION must be stable semantic version like 0.1.0." >&2
  exit 1
fi

if [[ ! "$SHA256" =~ ^[a-f0-9]{64}$ ]]; then
  echo "SHA256 must be a lowercase 64-character hex digest." >&2
  exit 1
fi

if [[ ! "$DOWNLOAD_URL" == "https://github.com/"*"/releases/download/v${VERSION}/"* ]]; then
  echo "DOWNLOAD_URL must point at the GitHub release for v${VERSION}." >&2
  exit 1
fi

case "$CASK_PATH" in
  /* | *..*)
    echo "CASK_PATH must be a relative path inside the tap checkout." >&2
    exit 1
    ;;
esac

ruby_literal() {
  ruby -e 'puts ARGV.fetch(0).dump' "$1"
}

VERSION_LITERAL="$(ruby_literal "$VERSION")"
SHA256_LITERAL="$(ruby_literal "$SHA256")"
DOWNLOAD_URL_LITERAL="$(ruby_literal "$DOWNLOAD_URL")"
HOMEPAGE_URL_LITERAL="$(ruby_literal "$HOMEPAGE_URL")"

FULL_CASK_PATH="$TAP_PATH/$CASK_PATH"
mkdir -p "$(dirname "$FULL_CASK_PATH")"

cat >"$FULL_CASK_PATH" <<CASK
cask "trimcontrol" do
  version $VERSION_LITERAL
  sha256 $SHA256_LITERAL

  url $DOWNLOAD_URL_LITERAL
  name "TrimControl"
  desc "Open source and text files in Neovim from Finder"
  homepage $HOMEPAGE_URL_LITERAL

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: ">= :sonoma"
  depends_on arch: :arm64

  app "TrimControl.app"

  uninstall quit: "com.subdepthtech.trimcontrol"

  zap trash: "~/Library/Preferences/com.subdepthtech.trimcontrol.plist"

  caveats <<~EOS
    Open TrimControl after installation and use Apply all defaults to register
    Finder file-type handlers for this user.
  EOS
end
CASK

ruby -c "$FULL_CASK_PATH"
echo "Wrote $FULL_CASK_PATH"
