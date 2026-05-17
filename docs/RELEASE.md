# Release

TrimControl releases are built from tags through GitHub Actions. The public
artifact contract is:

```text
TrimControl-<version>-arm64.dmg
TrimControl-<version>-arm64.dmg.sha256
```

## Required GitHub Configuration

Repository variables:

- `TRIMCONTROL_SIGN_IDENTITY`: Developer ID Application signing identity name.
- `HOMEBREW_TAP_REPOSITORY`: Homebrew tap repository, for example `subdepthtech/homebrew-trimcontrol`.

Repository secrets:

- `APPLE_CERTIFICATE_P12`: base64-encoded Developer ID Application `.p12`.
- `APPLE_CERTIFICATE_PASSWORD`: password for the `.p12`.
- `APP_STORE_CONNECT_PRIVATE_KEY`: App Store Connect API private key contents.
- `APP_STORE_CONNECT_KEY_ID`: App Store Connect API key ID.
- `APP_STORE_CONNECT_ISSUER_ID`: App Store Connect issuer ID.
- `HOMEBREW_TAP_TOKEN`: token with push access to the Homebrew tap.

## Local Preflight

Run these before tagging:

```sh
swift test
swift build
script/build_app.sh
script/verify_defaults.sh --app dist/TrimControl.app
```

For a local release artifact smoke test:

```sh
TRIMCONTROL_SIGN_IDENTITY=- script/package_dmg.sh --version 0.1.0 --arch arm64
hdiutil verify dist/release/TrimControl-0.1.0-arm64.dmg
shasum --algorithm 256 --check dist/release/TrimControl-0.1.0-arm64.dmg.sha256
```

Ad-hoc signing is only for local validation. Public releases should use the
Developer ID identity imported by the release workflow.

## Tag Release

1. Update `CHANGELOG.md` and replace `Unreleased` with the release date.
2. Commit the release prep changes.
3. Create and push a stable semver tag:

```sh
git tag v0.1.0
git push origin v0.1.0
```

The `Release` workflow will:

- import the Developer ID certificate
- run `swift test`
- build `dist/release/TrimControl-<version>-arm64.dmg`
- notarize and staple the DMG
- publish the GitHub release with the DMG and SHA-256 file
- update the Homebrew cask in the configured tap

## Manual Workflow Dispatch

The release workflow also supports `workflow_dispatch` with a `version` input.
Use this only when you intentionally want the workflow to create the release
from the selected commit instead of an existing tag.

## Post-Release Verification

After the workflow finishes:

```sh
gh release view v0.1.0 --repo subdepthtech/TrimControl
brew audit --cask subdepthtech/trimcontrol/trimcontrol
brew install --cask subdepthtech/trimcontrol/trimcontrol
```

Then launch the installed app and verify the settings window, terminal backend
selection, sample-file open path, and Finder defaults workflow.
