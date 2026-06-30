# Workflow Audit

Date: 2026-06-29

This file records the intended v0.4 user flow. It is the source of truth when checking whether a feature matches the product workflow before changing or releasing it.

## Current Capabilities

1. Open local PDFs from an open panel, drag/drop, recent documents, and file URLs.
2. Start each opened PDF in focused reading: sidebars hidden, PDF fit to available width, previous document sidebar state ignored.
3. Read with PDFKit scrolling, page navigation, zoom, fit width, fit page, two-page continuous view, and search.
4. Use a responsive layout across compact, regular, and wide Mac windows.
5. Use the left sidebar for page thumbnails and annotation marks.
6. Use the right sidebar for Comments, Highlights, and Bookmarks; the right-sidebar toolbar button is a visibility toggle for the active right mode.
7. Highlight selected text, use highlighter mode, and choose highlight colors.
8. Add selected-text comments, underline comments, and free-text annotations.
9. Use PDF-view shortcuts `H`, `U`, and `C` without conflicting with Command-C.
10. Edit/delete annotations and comment threads through anchored popovers and sidebar controls.
11. Review comments with search, filters, page grouping, collapsed groups, review state, replies, hover highlighting, edit/delete, and navigation.
12. Review highlights sorted by color or page.
13. Add, remove, and navigate per-document bookmarks.
14. Configure highlight and comment colors in Settings.
15. Save, Save As, Share, warn for unsent reply drafts, discard empty temporary editors, and warn before overwriting originals.
16. Package a small native app through the release scripts, DMG script, tiny archive script, and App Store package script.

## Removed From v0.4

The experimental Fill & Sign, custom form-field navigation, form choice popover, PDF signing, signature inspection, signed-document save safeguards, signature QA scripts, and related tests were removed from v0.4. Revisit that work later as a smaller design from scratch.

## Workflow Decisions

- Opened PDFs intentionally reset to focused single-pane reading with sidebars hidden. Opening a PDF should maximize the reading area and leave comments, highlights, bookmarks, page thumbnails, and annotation marks closed until the user asks for them.
- Plain Highlight is standalone. Selected-text Comment and Underline open the anchored editor.
- The visible Save toolbar icon is intentionally absent. Save remains available from the File menu and keyboard shortcut; Share remains visible.
- Compact windows intentionally make left and right sidebars mutually exclusive to preserve usable PDF width.
- Sidebar resize handles should be easy to grab through hover/cursor affordance without becoming large visual dividers.

## Regression Coverage

- Focused reading layout after opening a PDF.
- Returning to the empty-window workflow after closing a PDF.
- Compact one-sidebar-at-a-time behavior.
- Page sidebar toggle closing the active Marks sidebar instead of switching to Pages first.
- Right-sidebar toolbar toggle closing and reopening the current right mode without switching tabs.
- Regular-width ability to show navigation and review sidebars together.
- Save availability for clean, dirty, and reply-draft-only states.

## Manual QA Gaps

- Real Finder drag/drop, menu disabled states, visual Settings interaction, alert button flows, native share picker, popover text focus, and sidebar resize affordances need UI automation or manual QA.
- Preview, Acrobat Reader, and browser PDF-viewer checks remain external interoperability gates even though raw PDF structure checks exist.
- Cross-reader reply-thread display is not fully proven because PDFKit public APIs do not provide reliable object-valued `/IRT` writing. Primary annotation comments remain standard `/Contents`.
- Screenshot docs still need recapture before public marketing or release use.
