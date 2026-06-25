# Mac App Store Release

Bundle ID: `net.akkolli.ihatepdfs`

Current App Store build values:

- `CFBundleShortVersionString`: `0.3.0`
- `CFBundleVersion`: `4`
- Privacy policy URL: `https://www.akkolli.net/ihatepdfs/privacy`

## Required Apple Developer Items

- An explicit macOS App ID for `net.akkolli.ihatepdfs`.
- An App Store provisioning profile for that App ID.
- An application signing certificate installed in Keychain, usually named `Apple Distribution: ...` or `3rd Party Mac Developer Application: ...`.
- An installer signing certificate installed in Keychain, usually named `3rd Party Mac Developer Installer: ...`. Apple may label this certificate type as Mac Installer Distribution in the developer portal or Xcode.

The app only needs these sandbox entitlements right now:

- `com.apple.security.app-sandbox`
- `com.apple.security.files.user-selected.read-write`

Do not add network, Apple Events, Downloads-folder, or bookmark entitlements unless the app gains a feature that requires them.

## Build The Upload Package

Download the App Store provisioning profile from Apple Developer, then run:

```sh
APP_SIGNING_IDENTITY="3rd Party Mac Developer Application: Your Name (TEAMID)" \
INSTALLER_SIGNING_IDENTITY="3rd Party Mac Developer Installer: Your Name (TEAMID)" \
PROVISIONING_PROFILE="$HOME/Downloads/IHatePDFs_AppStore.provisionprofile" \
scripts/make-app-store-pkg.sh
```

The package is written to `dist/IHatePDFs-v0.3-macos-appstore.pkg`.

The script derives the App Store application identifier and team identifier from the provisioning profile before signing. It also clears download quarantine metadata from the bundle before packaging, because App Store Connect rejects packages that contain quarantine extended attributes.

## Upload

Upload the `.pkg` with Transporter. You can also set `VALIDATE_WITH_ALTOOL=1` when running `scripts/make-app-store-pkg.sh` if you want the script to perform an `altool` validation after packaging. After App Store Connect processes the build, select it in the app version, finish metadata, answer App Privacy, fill review notes, and submit for review.

Keep `CFBundleShortVersionString` as `0.3.0` and `CFBundleVersion` as `4` for this upload. Increment `BUILD_NUMBER` in `scripts/release-version.sh` before uploading another build for the same version.
