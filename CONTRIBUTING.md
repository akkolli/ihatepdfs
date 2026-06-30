# Contributing To I Hate PDFs

I Hate PDFs is a native macOS app for local PDF reading and annotation. Contributions should preserve that direction: small bundle, native system frameworks, local files, no account requirement, no analytics, and no cloud upload.

By contributing, you agree that your contribution is licensed under GNU General Public License version 2 only.

This project is vibe coded and maintained with AI agents. Feature requests are welcome; the maintainer will get to them as time allows. Agent-assisted pull requests are welcome too, but vibe coded does not mean unreviewed: every change must be understandable, documented, tested at the right level, and held to the same strict QA bar as hand-written code.

## Before You Start

- Check existing issues and pull requests before starting duplicate work.
- Open an issue first for large UI changes, new dependencies, release-process changes, or features that affect PDF saving/export behavior.
- Read `docs/QA.md` before changing a user workflow.
- Read `docs/RELEASE.md` before preparing a release.

## Development

Requirements:

- macOS 13 or newer
- Xcode 15 or newer with command line tools
- Swift Package Manager

Useful local commands:

```sh
swift run IHatePDFs
swift test
swift build -c release
scripts/build-app.sh
scripts/make-dmg.sh
scripts/verify-release-artifacts.sh
```

Run the checks that match your change and list them in the pull request. If you skip a relevant check, say why.

## Engineering Policy

- Build with Swift, SwiftUI, AppKit, PDFKit, and system frameworks that ship with macOS.
- Do not replace the app with Electron, Chromium, a web runtime, a bundled JavaScript shell, or a cross-platform UI toolkit.
- Do not bundle a PDF renderer, OCR engine, database, scripting runtime, or large framework when a macOS system API can satisfy the requirement.
- Keep third-party dependencies at or near zero. Any new package must justify shipped size, runtime cost, maintenance cost, and why system APIs are insufficient.
- Keep assets minimal. Avoid large raster images, fonts, sample PDFs, videos, model files, or generated resources in the app bundle.
- Keep expensive work page-scoped or lazy when possible.
- Treat release-size growth as a product regression. Each direct-download per-architecture installer must stay under 400,000 bytes.
- Run `scripts/make-tiny-archives.sh` before release-impacting changes; it builds and checks the per-architecture archives.

## Pull Request Policy

- Keep each pull request focused on one behavior, bug fix, or documentation change.
- Explain the user-visible behavior change, not only the implementation detail.
- For vibe coded changes, say so in the pull request and describe what you reviewed manually before opening it.
- Link the issue when one exists.
- Update `CHANGELOG.md` for user-visible changes.
- Avoid unrelated formatting churn.
- Do not add a new dependency, bundled asset, PDF engine, runtime, or release artifact without explaining the size and maintenance impact.
- Preserve the app's local-first privacy model.
- Document the before/after behavior clearly enough that a maintainer can review the intent without reverse-engineering the diff.
- Include the QA commands and manual checks that prove the change works.

## UI Screenshot Policy

Every pull request that changes visible UI must include screenshots or a short screen recording in the pull request description.

For UI changes:

- Include before and after screenshots when changing an existing screen.
- Include at least one screenshot when adding a new screen, state, toolbar item, sidebar, popover, dialog, menu, or empty state.
- Cover light and dark mode when the change affects colors, contrast, icons, materials, or selection states.
- Cover narrow window behavior when the change affects layout or toolbar/sidebar density.
- Keep every screenshot, recording, and committed media file under 1 MB.

If a UI change cannot be captured meaningfully, explain that in the pull request.

## Size Policy

The app is intentionally small. Pull requests should keep source, assets, and release artifacts lean.

- Each committed screenshot, recording, fixture image, or other media file added or changed in a pull request must be less than 1 MB.
- Prefer cropped screenshots that show the changed UI instead of full-desktop captures.
- Prefer compressed PNG, JPEG, or WebP where appropriate.
- Do not commit raw screen recordings, large sample PDFs, generated archives, `.app` bundles, `.dmg` files, or App Store packages.
- Explain any app-size increase caused by assets, dependencies, or release packaging changes.

The `media-size.yml` workflow checks changed media files in pull requests. PR description attachments are still governed by this policy even though GitHub Actions cannot inspect them.

## Review Expectations

Maintainers may ask for smaller scope, screenshots, reduced assets, additional tests, or release-size justification before merging. Release submission and App Store upload decisions stay with the maintainers.
