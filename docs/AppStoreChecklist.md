# App Store Readiness

This repo can build a local Roost macOS app bundle, but App Store submission
still requires Apple Developer assets that are not stored in git.

## Prepared in repo

- App sandbox entitlement template: `entitlements/AppStore.entitlements`
- Privacy manifest: `Sources/Roost/Resources/PrivacyInfo.xcprivacy`
- App icon: `Sources/Roost/Resources/Roost.icns`
- Bundle metadata in `script/build_and_run.sh`
- Release packaging helper: `script/package_app_store.sh`
- Local validation via `./script/build_and_run.sh --verify`

## Required before upload

- Apple Developer Program membership.
- App Store Connect app record for bundle ID `com.ivynbean.Roost`.
- Mac App Store provisioning profile for the app.
- Distribution signing identity available in Keychain.
- Installer signing identity available in Keychain for the upload package.
- Final review of rights/license for the Vecteezy icon artwork:
  `vecteezy_cartoon-cute-chicks-running-in-newly-hatched-eggs_10793847.png`.

## Signing notes

For Mac App Store distribution, build the release bundle, embed the Mac App
Store provisioning profile, sign the app with the App Sandbox entitlement
template, then create a signed `.pkg` for upload:

```bash
APP_STORE_PROVISIONING_PROFILE="/path/to/profile.provisionprofile" \
APP_SIGN_IDENTITY="Apple Distribution: Your Team Name (TEAMID)" \
APP_INSTALLER_IDENTITY="3rd Party Mac Developer Installer: Your Team Name (TEAMID)" \
./script/package_app_store.sh
```

The helper writes:

- `dist/Roost.app`
- `dist/Roost-AppStore.pkg`

After signing, validate:

```bash
codesign -dvvv --entitlements :- dist/Roost.app
codesign --verify --strict --verbose=2 dist/Roost.app
spctl -a -vv dist/Roost.app
plutil -p dist/Roost.app/Contents/Info.plist
productbuild --check-signature dist/Roost-AppStore.pkg
```

Upload `dist/Roost-AppStore.pkg` with Transporter, Xcode Organizer, or App
Store Connect tooling.

Persistent file reopening should be tested under sandbox. Roost stores
security-scoped bookmark data when macOS grants file access, but manually typed
paths may still require the user to reselect files.

Screenshot capture is opt-in for new installs because sandboxed App Store apps
should not try to monitor Desktop or arbitrary screenshot folders on first
launch.
