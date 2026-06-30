# Engineering Principles

I Hate PDFs is intentionally a small native macOS app. Future work should preserve that constraint unless there is a documented, user-visible reason to do otherwise.

## Native First

- Build features with Swift, SwiftUI, AppKit, PDFKit, and other system frameworks that ship with macOS.
- Do not replace the app with Electron, Chromium, a web runtime, a bundled JavaScript app shell, or a cross-platform UI toolkit.
- Do not bundle a PDF renderer, OCR engine, database, scripting runtime, or large framework when a macOS system API can satisfy the requirement.
- Prefer native macOS controls and document behaviors over custom reimplementations when they meet the product need.

## Small By Default

Every change should aim for the smallest final app that still delivers the required fluidity, reliability, and functionality.

- Keep third-party dependencies at or near zero. Any new package must justify its shipped size, runtime cost, maintenance cost, and why system APIs are insufficient.
- Keep assets minimal. Avoid large raster images, fonts, sample PDFs, videos, model files, or generated resources in the app bundle.
- Keep build outputs out of source and releases unless they are intentional release artifacts.
- Prefer dynamic links to Apple system frameworks over vendored libraries.
- Avoid storing duplicate PDF data, rendered page caches, or annotation indexes unless profiling shows they are required for fluid interaction.
- Favor targeted updates over whole-document rescans for common interactions such as editing, replying, filtering, hovering, and sidebar refreshes.

## Size Budget

The release DMG should stay as small as practical. Treat size growth as a product regression, not just a packaging detail.

Hard release-size budget: each direct-download per-architecture installer must be under 400 KB, measured as fewer than 400,000 bytes. Universal builds may be larger, but they do not satisfy the small-download budget. Run `scripts/make-tiny-archives.sh` before release; it builds and checks `IHatePDFs-v<version>-macos-arm64.tar.xz` and `IHatePDFs-v<version>-macos-x86_64.tar.xz` by default.

Before merging release-impacting work, compare:

```sh
scripts/build-app.sh
scripts/make-dmg.sh
du -sh "dist/I Hate PDFs.app" \
  "dist/I Hate PDFs.app/Contents/MacOS/IHatePDFs" \
  "dist/I Hate PDFs.app/Contents/Resources/AppIcon.icns" \
  dist/IHatePDFs-v*-macos.dmg
```

If a change materially increases the app bundle or DMG size, document why in the PR or commit notes. A useful rule of thumb: any dependency addition, bundled asset addition, or release-size increase above roughly 10% needs explicit justification.

## Performance Budget

Small size should not come at the expense of reader fluidity.

- Opening, scrolling, zooming, searching, annotating, saving, and sidebar navigation should remain responsive on long PDFs.
- Optimize around measured user workflows instead of speculative micro-optimizations.
- Keep expensive work page-scoped or lazy when possible.
- Use `swift test` plus the PDF verification scripts after behavior changes:

```sh
swift test
swift scripts/verify-sample-pdf.swift
swift scripts/verify-pdf-annotations.swift
```

## Release Packaging

Release builds should use the existing lightweight packaging path:

```sh
scripts/build-app.sh
scripts/make-dmg.sh
```

`scripts/build-app.sh` strips release binaries by default to reduce shipped size. Use `STRIP_RELEASE=0 scripts/build-app.sh` only when a symbol-rich release build is needed for debugging.

Universal `arm64` + `x86_64` builds are the default for public releases. Single-architecture builds are acceptable for local testing:

```sh
ARCHS="" scripts/build-app.sh
```
