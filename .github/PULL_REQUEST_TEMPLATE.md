## Summary

-

## Verification

- [ ] `swift test`
- [ ] `swift build`
- [ ] `script/build_app.sh`
- [ ] `script/verify_defaults.sh --app dist/TrimControl.app`

## Release And Defaults Safety

- [ ] User-visible behavior or docs were updated where needed.
- [ ] This change avoids mutating LaunchServices defaults except in explicitly named install/defaults flows.
- [ ] Signing, notarization, DMG, or Homebrew changes were tested against the documented release path when touched.
