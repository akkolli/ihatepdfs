# Roadmap

## Version 0.1

- Native macOS SwiftUI/PDFKit app.
- Local PDF opening.
- Reading controls: scrolling, zoom, fit width, fit page, page navigation, search.
- Focused default reading mode with optional page thumbnail sidebar.
- Highlight, underline, selection-bound comment, and free-text annotations.
- Anchored comment popovers from newly created selected-text comments, highlights, underlines, free text, and clicked annotations.
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

## Next

- More explicit visual selection handles for the active annotation.
- Better undo/redo integration for annotation edits.
- Optional author identity preferences.
- More granular sidebar and inspector layout memory for complex multi-window workflows.
- Fully standards-compliant reply-thread relationships through a lower-level PDF writer if PDFKit continues rejecting object-valued `/IRT`.
- Stronger interoperability test corpus covering Preview, Acrobat Reader, and browser PDF viewers.
- Import/export verification fixtures for existing annotated PDFs.

## Later

- Optional OCR for scanned readings.
- Optional citation metadata display.
- Optional AI summaries or question prompts.
- iPad companion app.
- LMS integrations.
