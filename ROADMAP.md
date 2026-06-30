# Roadmap

## Version 0.1

- Native macOS SwiftUI/PDFKit app.
- Local PDF opening.
- Reading controls: scrolling, zoom, fit width, fit page, page navigation, search.
- Focused default reading mode with optional page thumbnail sidebar.
- Highlight, underline, selection-bound comment, and free-text annotations.
- Anchored comment popovers from newly created selected-text comments, underlines, free text, and clicked comment-capable annotations; plain highlights remain standalone.
- Annotation list sidebar.
- Optional comments review sidebar with grouping, collapsed filtering, replies, and navigation.
- Save, Save As, and native macOS sharing with standard PDF annotation writing.
- `.app` and `.dmg` build scripts.
- Visual QA screenshots for empty, reading, popover, comments, and dark-mode states.

## Shipped In Version 0.3

- Settings for highlight and comment colors.
- Higher-contrast default highlights and comments.
- Standalone highlights that do not open a comment editor.
- Drag-and-drop PDF opening from the empty app window.
- Return-to-save and Shift-Return-for-newline comment behavior.
- Preview-compatible exported comments for selected-text markup.
- Safer close/open/quit prompts for unsaved annotations and reply drafts.
- Mac App Store packaging path for `net.akkolli.ihatepdfs`.

## Preparing Version 0.4

- Keep the reader focused on open: sidebars are hidden and the PDF is fit to the available width.
- Preserve the lightweight annotation workflow: highlight, underline, selected-text comments, free text, replies, search, bookmarks, and native sharing.
- Remove the experimental Fill & Sign, form-field navigation, and PDF signing implementation from v0.4.
- Keep the direct-download DMG and per-architecture archives under the release size budget.
- Release metadata, docs, and packaging names prepared for `0.4.0` build `6`.

## Next

- More explicit visual selection handles for the active annotation.
- Better undo/redo integration for annotation edits.
- Optional author identity preferences.
- More granular sidebar and inspector layout memory for complex multi-window workflows.
- Fully standards-compliant reply-thread relationships through a lower-level PDF writer if PDFKit continues rejecting object-valued `/IRT`.
- Stronger interoperability test corpus covering Preview, Acrobat Reader, and browser PDF viewers.
- Import/export verification fixtures for existing annotated PDFs.
- Revisit form fill and signing later as a smaller, cleaner design.

## Later

- Optional OCR for scanned readings.
- Optional citation metadata display.
- Optional AI summaries or question prompts.
- iPad companion app.
- LMS integrations.
