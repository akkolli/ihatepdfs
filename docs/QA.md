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
2. Close the PDF, then drag a `.pdf` file onto the empty no-document window and verify it opens.
3. Open Settings from File > Settings... and with Command-, then verify highlight color, comment color, and opacity changes can be edited and reset.
4. Select text and add a highlight; verify no comment popover opens.
5. Select text and add a comment; verify the comment color matches the Settings value.
6. In the comment box, press Shift-Return and verify it inserts a new line, then press Return and verify the comment is saved.
7. Add an underline with a comment.
8. Select text, right-click, and add a comment from the context menu.
9. Add free text directly on the page.
10. Open the comments sidebar and verify count, grouping, search, filters, edit, delete, reply, and click-to-navigate.
11. Quit and reopen the same PDF at the same approximate window width and verify the app restores that PDF's sidebar state; then open a different PDF and verify it starts in focused single-pane reading unless that document has its own saved state.
12. Add at least one reply and verify the comments sidebar presents the thread like a clean review/chat stream, with a visible connector line from the parent comment to the reply.
13. Hover a comment row and verify the corresponding PDF text is highlighted; click both the parent comment text and the reply text in the sidebar and verify the PDF view navigates to and selects the corresponding annotation.
14. Click on commented text and underlined text and verify the comment popover opens; then click the line below or nearby whitespace and verify no popover opens.
15. Verify highlights, comment markers, hidden page-level replies, and selected sidebar rows use muted native-feeling colors in light mode and do not visually overpower the document.
16. Switch the app to dark mode and verify the reading background, comments sidebar, editor popover, connector lines, selected rows, text fields, and annotation markers remain legible and restrained.
17. Save As an annotated copy.
18. Reopen the annotated copy in I Hate PDFs and verify the annotations and comments remain.
19. Save over a disposable original and verify the overwrite warning appears.
20. Add an annotation and verify the window shows the native macOS unsaved/edited document indicator until the PDF is saved.
21. Search for a word, close the search toolbar, and verify the match highlights disappear; repeat after opening a different PDF to confirm stale search highlights do not carry over.
22. Type an invalid page number and an out-of-range page number in the page field, and verify the app restores the current page number with a clear status message; also verify previous/next page controls disable at the first and last pages.
23. Apply comment filters or search text that hide every comment, verify the empty state offers Clear Filters, and verify page counts include visible replies.
24. Collapse a page group in the comments sidebar, search for a comment on that page, and verify the matching results are shown while the filter is active.
25. Start typing a sidebar reply, click Reply on a different comment, and verify the original draft remains until you send or cancel it.
26. Click one comment row, then click Reply on a different comment or reply, and verify the sidebar selection and PDF highlight move to the reply target.
27. Click one comment row, then click Edit or the review-status chip on a different row, and verify the sidebar selection and PDF highlight move to the edited or reviewed row.
28. Set a comments-sidebar filter and collapse a page group, then open another PDF and verify the comments sidebar starts unfiltered with page groups expanded.
29. In Settings, choose very low-opacity highlight and comment colors, add each annotation type, and verify saved annotations remain visibly readable.
30. Start typing a sidebar reply without sending it, then close or replace the PDF and verify the app asks before discarding the draft and the window shows the edited indicator while the draft exists.
31. Start typing a sidebar reply without sending it, choose Share, and verify the app warns that the draft will not be included unless it is sent first.
32. Start typing a sidebar reply, delete the comment thread it belongs to, and verify the app asks before discarding the reply draft.
33. Add replies to a comment, delete the parent comment from both the sidebar and the popover path in separate runs, and verify the whole thread is removed each time.
34. Hover a comment row until the matching PDF annotation highlights, then hide the comments sidebar or apply a filter that removes the row and verify the hover highlight clears.
35. Hover and click a sidebar reply, and verify the PDF scrolls to and highlights the visible parent annotation rather than jumping to a hidden reply marker.
36. Search for a word with matches, edit the search field without pressing Return, and verify old PDF match highlights clear and previous/next search buttons disable until the new query is submitted.
37. Start typing a sidebar reply without sending it, choose Save As, and verify the app warns that the draft will not be included unless it is sent first.
38. Create a new selected-text comment or free text, leave its popover empty, choose Save before closing the popover, and verify the temporary empty annotation is discarded instead of saved.
39. Start typing a sidebar reply with no other unsaved annotation changes and verify the status bar shows a reply draft instead of presenting the PDF as clean.
40. Search for a word with matches, step through results, and verify the status bar reports the current match position; then search for text that is not present and verify PDF match highlights clear.
41. Open comments search and verify the field is focused immediately; enter a search, hide the search controls, and verify the search icon still indicates an active hidden filter.
42. Select a comment row, apply a comments-sidebar filter or search that hides that row, and verify the PDF selection highlight clears instead of lingering on the page.
43. Create a new selected-text comment or free text, leave its popover empty, choose Share, and verify the temporary empty annotation is discarded before any Save and Share output is written.
44. Select a comment or annotation row, hide the only sidebar that shows that row, and verify the PDF selection highlight clears; repeat while the left Annotations sidebar is visible and verify the selection stays visible there.
45. Select a comment row, collapse its page group in the comments sidebar, and verify the PDF selection highlight clears; then search/filter comments and verify matching page groups expand while filtering.

## External Readers

Before manual reader checks, run the automated PDF structure checks:

```sh
swift scripts/verify-sample-pdf.swift
swift scripts/verify-pdf-annotations.swift
```

These checks generate an annotated PDF, reopen it with PDFKit, and inspect the raw PDF annotation dictionaries for standard `/Highlight`, `/Underline`, `/Text`, `/FreeText`, `/Contents`, `/QuadPoints`, `/IRT`, `/RT`, and `/Parent` entries.

For Preview interoperability, exported markup comments should keep the comment text on the parent annotation's standard `/Contents` key and should not depend on PDFKit-generated `/Popup` links for highlights or underlines.

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

PDFKit rejects object-valued `/IRT` reply relationships through its public API. Replies created in this app are saved as standard `/Text` annotations with string `/IRT` and `/RT` reply keys, but the reply annotation is hidden on the PDF page so it appears as a threaded sidebar reply instead of a second page icon. Full cross-reader reply-thread presentation must be verified and improved with a lower-level PDF writer if needed.
