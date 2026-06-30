# Functionality Audit

Date: 2026-06-29

## Current Build Scope

I Hate PDFs v0.4 is a small native macOS PDF reader and annotation app. The shipping scope is:

- Local PDF opening, recent documents, drag/drop, close-current-PDF, and focused reader startup.
- PDFKit reading, page navigation, zoom, fit controls, search, and responsive sidebars.
- Highlights, underline comments, selected-text comments, free text, replies, review state, filters, grouped comments, bookmarks, and highlight sorting.
- Settings for highlight and comment colors.
- Save, Save As, native Share, overwrite warnings, unsent reply-draft warnings, and empty temporary annotation cleanup.
- Lightweight release packaging with `.app`, `.dmg`, tiny per-architecture archives, and App Store package scripts.

## Removed Scope

The experimental Fill & Sign and PDF signing work has been removed from source, tests, scripts, settings, menus, and release docs for v0.4. This includes custom flat fill marks, form-field scanning/navigation, form choice editing, Keychain-backed PDF signing, signature validation/inspection, and signed-document save branching.

## Verification

Run before release:

```sh
swift build
swift test
swift scripts/verify-sample-pdf.swift
swift scripts/verify-pdf-annotations.swift
scripts/build-app.sh
scripts/make-dmg.sh
scripts/make-tiny-archives.sh
scripts/verify-release-artifacts.sh
```

Manual QA remains documented in `docs/QA.md`.
