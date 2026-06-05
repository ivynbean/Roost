# App Store Readiness

This repo can build a local Roost macOS app bundle, but App Store submission
still requires Apple Developer assets that are not stored in git.

## Prepared in repo

- App sandbox entitlement template: `entitlements/AppStore.entitlements`
- Privacy manifest: `Sources/Roost/Resources/PrivacyInfo.xcprivacy`
- App icon: `Sources/Roost/Resources/Roost.icns`
- Bundle metadata in `script/build_and_run.sh`
- Local validation via `./script/build_and_run.sh --verify`

## Required before upload

- Apple Developer Program membership.
- App Store Connect app record for bundle ID `com.ivynbean.Roost`.
- Mac App Store provisioning profile for the app.
- Distribution signing identity available in Keychain.
- Final review of rights/license for the Vecteezy icon artwork:
  `vecteezy_cartoon-cute-chicks-running-in-newly-hatched-eggs_10793847.png`.

## Signing notes

For Mac App Store distribution, sign the app with the App Sandbox entitlement
template and the correct distribution identity/provisioning profile from Apple.

After signing, validate:

```bash
codesign -dvvv --entitlements :- dist/Roost.app
spctl -a -vv dist/Roost.app
plutil -p dist/Roost.app/Contents/Info.plist
```

Persistent file reopening from saved file paths should be tested under sandbox.
If it needs to reopen files after relaunch, store security-scoped bookmarks
instead of plain paths.
