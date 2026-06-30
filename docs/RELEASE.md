# Release Workflow

Use this checklist when preparing a new public version.

## Version Source

The release version lives in one place:

```sh
scripts/release-version.sh
```

For a new app version, update `APP_VERSION` and reset or increment `BUILD_NUMBER`.
For another upload of the same app version, leave `APP_VERSION` alone and increment
`BUILD_NUMBER`.

`RELEASE_VERSION` defaults to the app version without a trailing `.0`, so `0.4.0`
produces release artifacts named with `v0.4`.

## Required Checks

Run these before tagging or uploading:

```sh
swift test
swift scripts/verify-pdf-annotations.swift
scripts/build-app.sh
BUILD_APP=0 scripts/make-dmg.sh
scripts/make-tiny-archives.sh
scripts/verify-release-artifacts.sh
```

`scripts/make-tiny-archives.sh` builds per-architecture direct-download archives and
fails if either archive is `>= 400,000` bytes.

Finish the manual reader checks in `docs/QA.md` before public distribution.

## Direct Download

The direct-download release artifacts are generated under `dist/`:

- `I Hate PDFs.app`
- `IHatePDFs-v<release>-macos.dmg`
- `IHatePDFs-v<release>-macos-arm64.tar.xz`
- `IHatePDFs-v<release>-macos-x86_64.tar.xz`

`dist/` and root package/archive extensions are ignored so generated outputs do not
pollute source control.

## App Store

Bundle ID: `net.akkolli.ihatepdfs`

Project website: `https://www.akkolli.net/ihatepdfs`

Support email: `akshaykolli@hotmail.com`

Required Apple Developer items:

- Explicit macOS App ID for `net.akkolli.ihatepdfs`.
- App Store provisioning profile for that App ID.
- Application signing certificate installed in Keychain.
- Installer signing certificate installed in Keychain.

The app only needs these sandbox entitlements right now:

- `com.apple.security.app-sandbox`
- `com.apple.security.files.user-selected.read-write`

Do not add network, Apple Events, Downloads-folder, or bookmark entitlements unless a shipped feature requires them.

Build the upload package:

```sh
APP_SIGNING_IDENTITY="3rd Party Mac Developer Application: Your Name (TEAMID)" \
INSTALLER_SIGNING_IDENTITY="3rd Party Mac Developer Installer: Your Name (TEAMID)" \
PROVISIONING_PROFILE="$HOME/Downloads/IHatePDFs_AppStore.provisionprofile" \
scripts/make-app-store-pkg.sh
```

After building the App Store package, run:

```sh
REQUIRE_APP_STORE_PKG=1 scripts/verify-release-artifacts.sh
```

Upload the `.pkg` with Transporter or App Store Connect tooling. Keep `APP_VERSION` and `BUILD_NUMBER` in `scripts/release-version.sh` aligned with App Store Connect before submitting.
