# Changelog

## Version 0.3.0 (build 4) - 2026-06-24

Version 0.3 is focused on making annotation work feel reliable enough for real PDF review: clearer highlights, better comment behavior, safer saving, and release packaging for the Mac App Store.

### Highlights

- Added a Settings window for highlight and comment colors, including opacity.
- Added drag-and-drop opening when no PDF is open.
- Highlighting selected text now creates a highlight immediately instead of opening an empty comment box.
- Pressing Return now saves comments and replies; Shift-Return inserts a new line.
- Saved text comments now remain visible in macOS Preview and Adobe Acrobat.
- Added Mac App Store packaging for bundle ID `net.akkolli.ihatepdfs`.

### Annotation And Comment Improvements

- Highlight and comment colors now have stronger default contrast.
- Custom highlight and comment colors keep a minimum readable opacity.
- New comment popovers focus the text box immediately, so the text cursor appears before typing.
- Clicking commented or underlined text reopens the editor more accurately.
- Clicking nearby whitespace or the line below a comment no longer opens the popover by mistake.
- Empty newly created selected-text comments and free-text notes are discarded when closed, so they do not leave behind blank annotations.
- Plain highlights and underlines can remain empty without being deleted.
- Comments imported from other PDF readers are shown even when the app-specific comment field is missing.

### Saving, Sharing, And Document Safety

- The app now prompts before closing, replacing, or quitting with unsaved annotation changes.
- The window uses the native macOS edited-document indicator while annotations or reply drafts are unsaved.
- Save is disabled when there is nothing to save.
- Save, Save As, and Share warn before omitting an unsent sidebar reply draft.
- Share avoids redundant save prompts when the current PDF is already saved.
- Save-before-close prompts name the file that would be overwritten.

### Comments Sidebar

- The comments sidebar now handles replies, filters, collapsed page groups, and search more consistently.
- Matching replies keep their parent thread visible in search results.
- Filters that hide every comment now show a clear empty state with a Clear Filters action.
- Starting a new reply no longer silently discards a draft for another comment.
- Sidebar hover and selection highlights now clear when filters, collapsed groups, or sidebar visibility hide the selected row.
- Selecting a sidebar reply scrolls to and highlights the visible parent annotation instead of a hidden reply marker.

### Search And Navigation

- Closing PDF search clears match highlights from the document.
- Editing the search field clears stale match highlights until the new search is submitted.
- Search now reports the current match number while stepping through results.
- Page navigation disables unavailable previous/next controls and recovers cleanly from invalid page-number entries.

### Packaging And Release

- The app version is now `0.3.0`, build `4`.
- Release scripts now build a v0.3 DMG filename by default.
- Added a shared release-version script so app bundle versions, DMG names, and App Store package names stay aligned.
- Added App Store sandbox entitlements for user-selected PDF read/write access.
- Added a signed Mac App Store `.pkg` build path.
- Added release QA, App Store packaging, and engineering-size documentation.

### Tests

- Added tests for color preference storage and minimum opacity.
- Added tests for tighter text-markup hit testing.
- Added tests for PDF drag-and-drop file selection.
- Added tests for Return versus Shift-Return commit behavior.
- Expanded PDF annotation export tests for Preview-compatible comments, popup cleanup, configured colors, replies, and imported annotations.

## Version 0.2.0 - 2026-06-18

### Fixed

- Opening a PDF from Finder Open With now opens in its own window state instead of mirroring into an existing window.
- Zoom toolbar and menu commands now apply to the focused PDF window instead of another open window.
- Pressing Return in a new comment editor now saves the comment without requiring the mouse.
- Page and comments sidebar toolbar icons remain visible in narrow windows.

### Changed

- Sidebar toolbar controls are grouped together in the leading toolbar area for better visibility.

## Version 0.1.0

- Initial native macOS SwiftUI/PDFKit release.
- Local PDF opening, reading, zoom, fit width, fit page, page navigation, and search.
- Highlight, underline, selection-bound comment, free-text annotation, comments sidebar, Save, Save As, and Share workflows.
