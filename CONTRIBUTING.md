# Contributing

Thanks for helping improve TrimControl.

## Local Setup

TrimControl is a SwiftPM-based macOS app with no third-party Swift packages.

```sh
swift test
swift build
script/build_app.sh
script/verify_defaults.sh --app dist/TrimControl.app
```

Use `TRIMCONTROL_SIGN_IDENTITY=-` for ad-hoc local signing. Do not run `script/install_app.sh` unless you intentionally want to replace the installed app and update LaunchServices defaults on your Mac.

## Pull Requests

- Keep changes small and focused.
- Preserve the native macOS utility behavior.
- Add or update tests for behavior changes.
- Update docs when commands, release behavior, or user-visible workflows change.
- Run `git diff --check` before opening a PR.

## LaunchServices Safety

LaunchServices defaults are host-local user state. Tests and scripts should avoid changing system defaults unless the command is explicitly named as an install or defaults operation.
