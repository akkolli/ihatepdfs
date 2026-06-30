# Mac App Store Release

Bundle ID: `net.akkolli.ihatepdfs`

Current App Store build values:

- `CFBundleShortVersionString`: `0.4.0`
- `CFBundleVersion`: `6`
- Privacy policy URL: `https://www.akkolli.net/ihatepdfs/privacy`
- Marketing/support URL: `https://www.akkolli.net/ihatepdfs`

Paste-ready metadata, review notes, privacy answers, and screenshot guidance live in `docs/APP_STORE_COPY.md`.
The general release checklist is in `docs/RELEASE.md`.

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

The package is written to `dist/IHatePDFs-v0.4-macos-appstore.pkg`.

The script derives the App Store application identifier and team identifier from the provisioning profile before signing. It builds the App Store app in a temporary staging directory, so the direct-download `dist/I Hate PDFs.app` remains a clean app bundle without an embedded provisioning profile. It also clears download quarantine metadata from the staged bundle before packaging, because App Store Connect rejects packages that contain quarantine extended attributes.

If macOS opens a Keychain private-key access prompt during `codesign`, approve it, preferably with Always Allow for the selected signing certificate, and rerun the command. The build cannot finish unattended until the private key for the selected application signing certificate is allowed.

Before uploading, verify that the package matches the current build number:

```sh
REQUIRE_APP_STORE_PKG=1 scripts/verify-release-artifacts.sh
```

This catches stale package files, bundle-ID mismatches, missing embedded provisioning profiles, missing sandbox/user-selected-file entitlements, and app/package version mismatches.

Use `pkgutil --check-signature` and App Store Connect or Transporter validation for this App Store package. A local `spctl -t install` assessment is a Developer ID distribution check and may reject a package signed with the Mac App Store `3rd Party Mac Developer Installer` identity even when the package signature is valid for App Store upload.

## Upload

Upload the `.pkg` with Transporter. You can also set `VALIDATE_WITH_ALTOOL=1` when running `scripts/make-app-store-pkg.sh` if you want the script to perform an `altool` validation after packaging. After App Store Connect processes the build, select it in the app version, finish metadata, answer App Privacy, fill review notes, and submit for review.

Keep `CFBundleShortVersionString` as `0.4.0` and `CFBundleVersion` as `6` for the next upload. Increment `BUILD_NUMBER` in `scripts/release-version.sh` before uploading another build for the same version.
