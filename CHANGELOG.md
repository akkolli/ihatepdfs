# Changelog

## Unreleased

### Repository

- Added README badges for release, license, platform, Swift, contributions, and media-size policy.
- Added contribution, support, security, issue, and pull request policies for open-source contributors.
- Added a pull request media-size policy requiring UI screenshots or recordings and limiting each screenshot, recording, or committed media file to less than 1 MB.
- Renamed source, test, and signing directories to lowercase paths.
- Removed duplicate release/planning docs, stale screenshot targets, and the unused duplicate icon image.
- Removed redundant support/App Store copy docs and trimmed repository screenshots to one representative image.
- Consolidated release helper scripts by folding size checks into tiny archive creation and sample PDF generation into PDF annotation verification.
- Consolidated workflow audit guidance into the manual QA document.
- Consolidated engineering guidance into contributing docs and App Store packaging into release docs.
- Documented that vibe coded pull requests are welcome when they include clear change documentation, strict QA, and UI screenshots or recordings when relevant.
- Documented `https://www.akkolli.net/ihatepdfs` as the project website and `akshaykolli@hotmail.com` as the support contact.

## Version 0.4.0 (build 6) - 2026-06-25

Version 0.4 removes the experimental Fill & Sign, form-field navigation, and PDF signing implementation from the shipping app. The release is back to a small native reader and annotation tool while preserving the size target.

### Removed

- Prepared the release metadata for app version `0.4.0`, build `6`.
- Removed the Fill & Sign panel, menu commands, settings, flat fill-mark factory, form scanner/navigation, custom form choice popover, PDF signing pipeline, and related QA scripts/tests.
- Removed the SecurityInterface link from the app target.
- Preserved the size target by returning to the existing lightweight native stack: SwiftUI, AppKit, PDFKit, and Foundation.

### Reliability

- Cleaned up PDFKit page/selection observers when reattaching a PDF view and when app state is released, avoiding stale observer callbacks in long app sessions.
- Re-ran the core test suite, release build, annotation verification, and release artifact verification for the 0.4 prep pass.

## Version 0.3.0 (build 5) - 2026-06-25

Build 5 is a release-candidate polish build for signatures, Recent PDFs, and release metadata. Complete the manual Acrobat and Preview signature checks before public distribution.

### Fill And Sign

- Added a Fill & Sign toolbar/menu workflow for placing flat PDF fill marks without adding a bundled PDF engine.
- Added text, checkbox, date, initials, and typed signature-appearance marks as standard printable `/FreeText` annotations with app metadata.
- Added AcroForm widget scanning so PDFs with form fields report field counts in the reader/status UI.
- Added native form-field navigation from the Fill & Sign strip, Annotate menu, Tab, and Shift-Tab.
- Captured choice/list field options and export values through PDFKit's public form APIs.
- Added a compact native choice/list popover for PDFKit-backed combo and list fields.
- Kept visual signature appearances separate from real digital signatures; cryptographic signing still goes through Keychain-backed File > Sign PDF....
- Typed signature appearances can now be reused as the visible widget appearance for a real digital signature.
- Added unit coverage for Fill & Sign models, form scanning, choice/list options and fallback values, unsupported fields, form-value save/reopen behavior, form-scan performance, fill mark metadata, page clamping, visible signature appearance reuse, and signature-appearance non-detection as a digital signature.

### PDF Signatures

- Added digital PDF signing from File > Sign PDF..., using macOS Keychain identities and detached CMS signatures.
- Signed output is written as an incremental PDF update, preserving original PDF bytes instead of rewriting through PDFKit.
- Added invisible signatures and click-to-place visible signature boxes.
- Visible signatures are now drawn into page content as well as the signature widget appearance, so macOS Preview renders the signer text instead of a blank signature box.
- Added signature detection and status reporting for signed PDFs.
- Added a compact signature inspector from the status bar with signer, status, date, reason, location, format, and ByteRange details.
- Normal Save is disabled for signed PDFs; Save As creates an unsigned edited copy instead.
- Added CMS validation for signed PDFs, including separate reporting for invalid signatures and untrusted certificates.
- Added CMS parsing support for macOS Security's indefinite-length CMS output, so real Keychain-signed PDFs validate after signing.
- Added performance-budget coverage for large-document annotation snapshots, page-scoped annotation refresh, and large PDF signature scanning.
- Added opt-in Keychain signature QA that can either use an installed identity or create a temporary QA identity, then writes invisible and visible signed PDFs and checks Poppler `pdfsig` recognition when available.
- Added an Acrobat QA handoff script that verifies signed QA files and prints the exact remaining Acrobat Reader checks.
- Fixed signature QA fixtures to emit valid classic xref offsets, avoiding parser reconstruction warnings and Preview rejection.
- Added unit coverage for signature scanning, incremental writing, field construction, ByteRange/Contents patching, and validator parsing.

### Reader Polish

- Added compact Recent PDFs shortcuts in the empty window and File > Open Recent, backed by macOS's native recent-document list.
- Added paste-ready App Store metadata, review notes, privacy answers, and screenshot guidance.
- Added a bitmap Preview screenshot showing visible signed-PDF output for external-reader QA.
- Added isolated App Store package staging so Mac App Store builds no longer overwrite the direct-download app bundle in `dist`.
- Strengthened release artifact verification for bundle IDs, App Store package signing, embedded provisioning profiles, and expected sandbox entitlements.
- Removed SVG mock screenshots from the documentation assets.

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
