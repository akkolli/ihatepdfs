# Manual PDF Interoperability QA

Run this checklist before tagging a public release.

## Latest v0.4 Automated QA Run

Completed on 2026-06-29:

- `swift build`
- `swift test`

Before release, also run:

```sh
swift scripts/verify-sample-pdf.swift
swift scripts/verify-pdf-annotations.swift
swift build -c release --product IHatePDFs
scripts/build-app.sh
scripts/make-dmg.sh
scripts/make-tiny-archives.sh
scripts/verify-release-artifacts.sh
```

## Test Files

Use at least:

- A selectable-text journal article.
- A scanned/image-only course reading.
- A long PDF near or above 500 pages.
- A PDF that already contains annotations from Preview or Acrobat.
- A PDF with bookmarks or an outline.

## App Workflow

1. Open a PDF and verify it starts in focused single-pane reading: the PDF is fit to the available window width and all sidebars are hidden.
2. Close the PDF, then drag a `.pdf` file onto the empty window and verify it opens.
3. Open one or more PDFs, close the current PDF, and verify recent PDFs appear in the empty window and File > Open Recent.
4. Open Settings from File > Settings... and with Command-, then verify highlight and comment colors can be edited and reset.
5. Select text and add a highlight; verify no comment popover opens.
6. Select text and add a comment; verify the comment color matches the Settings value.
7. In the comment box, press Shift-Return and verify it inserts a new line, then press Return and verify the comment is saved.
8. Add an underline with a comment.
9. Select text, right-click, and add a comment from the context menu.
10. Add free text directly on the page.
11. Open the comments sidebar and verify count, grouping, search, filters, edit, delete, reply, and click-to-navigate.
12. Open Pages, Marks, Comments, Highlights, and Bookmarks sidebars, then close and reopen the PDF; verify the reopened document returns to focused single-pane reading with sidebars hidden.
13. Open Bookmarks, click the right-sidebar toolbar icon, and verify the right sidebar closes instead of switching to Comments; click it again and verify Bookmarks reopens.
14. Resize the same document through compact, regular, and wide widths; verify compact windows keep sidebars mutually exclusive while regular and wide windows can show both sidebars without shrinking the PDF below a usable reading width.
15. Hover and drag the divider between the PDF and each sidebar and verify the resize cursor/hover affordance is easy to grab without an oversized visual handle.
16. Add at least one reply and verify the comments sidebar presents the thread clearly.
17. Hover a comment row and verify the corresponding PDF text is highlighted; click parent and reply rows and verify the PDF navigates correctly.
18. Click commented text and underlined text and verify the comment popover opens; click nearby whitespace and verify no popover opens.
19. Switch the app to dark mode and verify the reading background, sidebars, editor popover, selected rows, text fields, and annotation markers remain legible.
20. Save As an annotated copy.
21. Reopen the annotated copy in I Hate PDFs and verify annotations and comments remain.
22. Save over a disposable original and verify the overwrite warning appears.
23. Add an annotation and verify the window shows the native macOS unsaved/edited document indicator until the PDF is saved.
24. Search for a word, close the search toolbar, and verify match highlights disappear.
25. Type invalid and out-of-range page numbers and verify the app restores the current page number with a clear status message.
26. Apply comment filters or search text that hide every comment, verify the empty state offers Clear Filters, and verify page counts include visible replies.
27. Start typing a sidebar reply, click Reply on a different comment, and verify the original draft remains until sent or canceled.
28. Hide a sidebar or apply a filter that removes the selected row and verify the PDF selection highlight clears.
29. Start typing a sidebar reply without sending it, then close, replace, save, or share the PDF and verify the app warns before omitting or discarding the draft.
30. Create a new selected-text comment or free text, leave its popover empty, choose Save or Share, and verify the temporary empty annotation is discarded.

## External Readers

Before manual reader checks, run the automated PDF structure checks:

```sh
swift scripts/verify-sample-pdf.swift
swift scripts/verify-pdf-annotations.swift
```

These checks generate an annotated PDF, reopen it with PDFKit, and inspect raw PDF annotation dictionaries for standard `/Highlight`, `/Underline`, `/Text`, `/FreeText`, `/Contents`, `/QuadPoints`, `/IRT`, `/RT`, and `/Parent` entries.

For Preview, Acrobat Reader, and browser PDF viewers, verify exported markup comments keep their comment text on the parent annotation's standard `/Contents` key and do not depend on PDFKit-generated `/Popup` links for highlights or underlines.
