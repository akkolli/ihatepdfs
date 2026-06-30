# Release Notes

## I Hate PDFs v0.4.0

Version 0.4 is focused on keeping the app small, fast, and reader-first. The experimental Fill & Sign, form-field navigation, and PDF signing work has been removed from this release line and will be revisited later from scratch.

### What's New

- Focused document opening: PDFs open in the reader with sidebars hidden and the page fit to available width.
- Smaller app surface area after removing the experimental Fill & Sign/signing implementation.
- Recent PDFs in the empty window and File > Open Recent.
- Settings for highlight and comment colors, including opacity.
- Standalone highlights that do not open a comment editor.
- Return saves a comment or reply; Shift-Return inserts a new line.
- Mac App Store packaging for `net.akkolli.ihatepdfs`.

### Reliability Fixes

- Comment text survives when saved PDFs are opened in macOS Preview and Adobe Acrobat.
- The comment editor focuses correctly when a new selected-text comment is created.
- Comment popovers open from the actual annotated text instead of nearby whitespace.
- The app warns before unsaved annotations or reply drafts are lost.
- Search highlights clear correctly when search is closed or edited.
- The comments sidebar keeps threads, filters, replies, and selected highlights in sync.
- PDFKit page/selection observers are cleaned up when the reader view is reattached.
- Sidebar toggles now close the active sidebar mode directly instead of switching modes first.

### Version

- App version: `0.4.0`
- Build number: `6`
- Direct-download DMG name: `IHatePDFs-v0.4-macos.dmg`
- Mac App Store package name: `IHatePDFs-v0.4-macos-appstore.pkg`
