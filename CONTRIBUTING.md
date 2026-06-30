# Contributing To I Hate PDFs

I Hate PDFs is a native macOS app for local PDF reading and annotation. Contributions should preserve that direction: small bundle, native system frameworks, local files, no account requirement, no analytics, and no cloud upload.

By contributing, you agree that your contribution is licensed under GNU General Public License version 2 only.

## Before You Start

- Check existing issues and pull requests before starting duplicate work.
- Open an issue first for large UI changes, new dependencies, release-process changes, or features that affect PDF saving/export behavior.
- Read `docs/ENGINEERING.md` before adding dependencies, bundled assets, PDF engines, runtimes, or broad architectural changes.
- Read `docs/WORKFLOW_AUDIT.md` before changing a user workflow.
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

## Pull Request Policy

- Keep each pull request focused on one behavior, bug fix, or documentation change.
- Explain the user-visible behavior change, not only the implementation detail.
- Link the issue when one exists.
- Update `CHANGELOG.md` for user-visible changes.
- Avoid unrelated formatting churn.
- Do not add a new dependency, bundled asset, PDF engine, runtime, or release artifact without explaining the size and maintenance impact.
- Preserve the app's local-first privacy model.

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
