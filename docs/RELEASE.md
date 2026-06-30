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
swift scripts/verify-sample-pdf.swift
swift scripts/verify-pdf-annotations.swift
scripts/build-app.sh
BUILD_APP=0 scripts/make-dmg.sh
scripts/make-tiny-archives.sh
scripts/verify-release-artifacts.sh
```

`scripts/make-tiny-archives.sh` builds per-architecture direct-download archives and
fails if either archive is `>= 400,000` bytes.

For signature changes, also run:

```sh
USE_TEMP_SIGNING_KEYCHAIN=1 scripts/verify-pdf-signatures.sh
scripts/prepare-acrobat-qa.sh
```

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

Use `docs/APP_STORE.md` for signing identities, provisioning profile setup, and the
upload package command. After building the App Store package, run:

```sh
REQUIRE_APP_STORE_PKG=1 scripts/verify-release-artifacts.sh
```

Do not change App Store entitlements unless a shipped feature requires the new
capability.
