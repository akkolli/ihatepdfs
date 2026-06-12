# Manual PDF Interoperability QA

Run this checklist before tagging a public release.

## Test Files

Use at least:

- A selectable-text journal article.
- A scanned/image-only course reading.
- A long PDF near or above 500 pages.
- A PDF that already contains annotations from Preview or Acrobat.
- A PDF with bookmarks or an outline.

## App Workflow

1. Open the PDF in I Hate PDFs.
2. Select text and add a highlight.
3. Add a comment to the highlight.
4. Add an underline with a comment.
5. Select text, right-click, and add a comment from the context menu.
6. Add free text directly on the page.
7. Open the comments sidebar and verify count, grouping, search, filters, edit, delete, reply, and click-to-navigate.
8. Quit and reopen the same PDF at the same approximate window width and verify the app restores that PDF's sidebar state; then open a different PDF and verify it starts in focused single-pane reading unless that document has its own saved state.
9. Add at least one reply and verify the comments sidebar presents the thread like a clean review/chat stream, with a visible connector line from the parent comment to the reply.
10. Hover a comment row and verify the corresponding PDF text is highlighted; click both the parent comment text and the reply text in the sidebar and verify the PDF view navigates to and selects the corresponding annotation.
11. Verify highlights, comment markers, reply icons, and selected sidebar rows use muted native-feeling colors in light mode and do not visually overpower the document.
12. Switch the app to dark mode and verify the reading background, comments sidebar, editor popover, connector lines, selected rows, text fields, and annotation markers remain legible and restrained.
13. Save As an annotated copy.
14. Reopen the annotated copy in I Hate PDFs and verify the annotations and comments remain.
15. Save over a disposable original and verify the overwrite warning appears.

## External Readers

Before manual reader checks, run the automated PDF structure checks:

```sh
swift scripts/verify-sample-pdf.swift
swift scripts/verify-pdf-annotations.swift
```

These checks generate an annotated PDF, reopen it with PDFKit, and inspect the raw PDF annotation dictionaries for standard `/Highlight`, `/Underline`, `/Text`, `/FreeText`, `/Popup`, `/Contents`, `/QuadPoints`, `/IRT`, `/RT`, and `/Parent` entries.

Open the saved annotated copy in:

- macOS Preview
- Adobe Acrobat Reader
- Safari, Chrome, and Firefox PDF viewers where annotations are supported

Verify:

- Highlighted text remains highlighted.
- Underlined text remains underlined.
- Selected-text comments remain attached to the referenced text.
- Highlight and selected-text comments can be opened.
- Free text remains visible on the page.
- Existing text, images, layout, bookmarks, and prior annotations remain intact.

## Visual QA Screenshots

Capture current screenshots in `docs/screenshots` for:

- `no-document.png`
- `default-reading.png`
- `highlight-comment-popover.png`
- `selected-text-comment-popover.png`
- `comments-sidebar.png`, including at least one reply thread with a visible connector line
- `dark-mode-reading.png`

## Known Version 1 Limitation

PDFKit rejects object-valued `/IRT` reply relationships through its public API. Replies created in this app are saved as visible standard `/Text` annotations, while full cross-reader reply-thread presentation must be verified and improved with a lower-level PDF writer if needed.
