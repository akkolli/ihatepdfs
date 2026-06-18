# I Hate PDFs

I Hate PDFs is an open-source macOS PDF reader for anyone who hates adobe. I think adobe is worth of any sentient being's disdain.

## Status

This app is entirely vibe coded, but will somehow still be better than adobe acrobat soon.

Minimum supported macOS version: macOS 13 Ventura.

Supported Mac architectures: Apple Silicon and Intel, subject to the local Swift/Xcode toolchain used to build.

## Latest Release

Download the v0.2 macOS DMG from the GitHub release page:

<https://github.com/akkolli/ihatepdfs/releases/tag/v0.2>

Use `IHatePDFs-v0.2-macos.dmg` for normal app installation. Open the DMG, then drag `I Hate PDFs.app` into `/Applications`.

Signing status for v0.2: the DMG is ad-hoc signed, but it is not Developer ID signed or Apple-notarized yet. macOS Gatekeeper may require opening the app from Finder with Control-click, then Open, on first launch.

## Features

- Open local `.pdf` files from disk.
- Read with smooth PDFKit scrolling, Retina rendering, zoom, fit-to-width, fit-to-page, and page navigation.
- Search selectable text PDFs from a compact toolbar control.
- Start in a focused single-pane reading layout, with thumbnail and comments sidebars hidden until requested.
- Remember thumbnail and comments sidebar visibility per PDF and coarse window size.
- Toggle a compact page thumbnail/sidebar inspector.
- Create selection-bound comments from highlighted PDF text.
- Create highlight annotations with anchored optional comments.
- Create underline annotations with optional comments.
- Create free-text annotations directly on the page.
- Click annotations in the PDF to reopen and edit the comment in place.
- Save annotations directly into the original PDF after an overwrite warning.
- Save As a new annotated copy.
- Share the annotated PDF through the native macOS share picker.
- Review annotations in a compact list with page number, type, author, date, and first comment line.
- Use an Acrobat-style comments sidebar with total count, page grouping, collapsible groups, an add-comment affordance, comment search, collapsed type/author/status filters, full text, replies, edit/delete, and click-to-navigate.

### Download Releases

https://github.com/akkolli/ihatepdfs/releases/tag/v0.2


## Build From Source

Requirements:

- macOS 13 or newer
- Xcode 15 or newer with command line tools
- Swift Package Manager

Build and run the debug executable:

```sh
swift run IHatePDFs
```

Run tests:

```sh
swift test
```

Build a release `.app` bundle:

```sh
scripts/build-app.sh
```

Release app builds default to a universal `arm64` + `x86_64` executable. To build only the current architecture during development, run:

```sh
ARCHS="" scripts/build-app.sh
```

Create a downloadable `.dmg`:

```sh
scripts/make-dmg.sh
```

The packaged app is written to `dist/I Hate PDFs.app`; the disk image is written to `dist/IHatePDFs-v0.2-macos.dmg`.

## Installation

Download `IHatePDFs-v0.2-macos.dmg` from the latest GitHub release, open it, and move `I Hate PDFs.app` into `/Applications`.

For v0.2 and local development builds, the app is not Developer ID signed or notarized. If macOS blocks first launch, open Finder, Control-click `I Hate PDFs.app`, choose Open, then confirm.

## Development

The project is a Swift Package with two targets:

- `IHatePDFsCore`: PDF annotation models and factory helpers.
- `IHatePDFs`: SwiftUI macOS app, PDFKit bridge, toolbar, menus, sidebars, anchored comment popovers, opening, saving, sharing, and search.

Useful checks:

```sh
swift test
swift build -c release
swift scripts/verify-sample-pdf.swift
swift scripts/verify-pdf-annotations.swift
```

The PDF verification scripts generate and inspect standard highlight, underline, selected-text comment, reply, free-text, and popup annotation dictionaries.

Manual release QA for Preview, Acrobat Reader, and browser PDF viewers is documented in `docs/QA.md`. The macOS design review is documented in `docs/DESIGN_REVIEW.md`.

## Screenshots

Screenshots live in `docs/screenshots`.

Current repository screenshots:

- `docs/screenshots/no-document.png`
- `docs/screenshots/default-reading.png`
- `docs/screenshots/highlight-comment-popover.png`
- `docs/screenshots/main-window.png`
- `docs/screenshots/comments-sidebar.png`
- `docs/screenshots/dark-mode-reading.png`

![No document open](docs/screenshots/no-document.png)

![Default reading mode](docs/screenshots/default-reading.png)

![Highlight comment popover](docs/screenshots/highlight-comment-popover.png)

![Comments sidebar](docs/screenshots/comments-sidebar.png)

![Dark mode reading](docs/screenshots/dark-mode-reading.png)

## License

MIT. See `LICENSE`.
