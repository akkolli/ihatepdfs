# macOS Design Review

This review checks the current app against Apple's Human Interface Guidelines before a public release.

References:

- Apple HIG overview: https://developer.apple.com/design/human-interface-guidelines
- Designing for macOS: https://developer.apple.com/design/human-interface-guidelines/designing-for-macos
- Toolbars: https://developer.apple.com/design/human-interface-guidelines/toolbars
- Sidebars: https://developer.apple.com/design/human-interface-guidelines/sidebars
- Menus and the menu bar: https://developer.apple.com/design/human-interface-guidelines/menus and https://developer.apple.com/design/human-interface-guidelines/the-menu-bar
- Color: https://developer.apple.com/design/human-interface-guidelines/color
- Typography: https://developer.apple.com/design/human-interface-guidelines/typography

## Result

Status: Pass for the current version 1 implementation direction, with manual visual QA still required on physical Intel and Apple Silicon Macs before a tagged release.

## Checks

- Platform fit: The app is macOS-only, targets macOS 13 or newer, uses SwiftUI/AppKit/PDFKit, and ships as a normal `.app` bundle inside a `.dmg`.
- Window and toolbar: Primary document controls live in the titlebar toolbar, grouped by opening/sharing, navigation, zoom, annotation, search, and saving.
- Menus and shortcuts: File, View, and Annotate commands are available through native command menus with standard keyboard shortcuts where appropriate.
- Sidebars: Page thumbnails, annotation list, and comments review are optional sidebars. The default open-PDF state is single-pane reading, and sidebars open only when requested.
- Responsive layout: Compact windows use a compact toolbar/status treatment and keep sidebars mutually exclusive; regular and wide windows can show both sidebars while preserving a usable PDF reading width.
- Comments review: The comments sidebar uses a compact review-stream layout with a visible total count, add-comment affordance, collapsible page groups, hidden search/filter controls, and connected reply threads.
- Color and appearance: The UI uses system colors and materials, so light mode, dark mode, and automatic appearance inherit from macOS.
- Typography: Text uses system fonts and native SwiftUI controls; no custom brand typography is used in the reading interface.
- Reading focus: The PDF view remains the central, quiet surface; controls are compact and document-oriented.
- Accessibility basics: Native controls supply focus states and keyboard access; colors use system palettes with restrained highlight/note colors.
- Academic workflow: The open, select, highlight, comment, continue reading, save, and share path is available without accounts, sync, projects, or conversion.

## Release QA Still Required

- Run the app on both Apple Silicon and Intel hardware.
- Verify contrast and focus states in light and dark mode.
- Verify toolbar and sidebar behavior at compact, regular, and wide window sizes.
- Verify keyboard-only operation for opening, searching, navigating, annotating, saving, and reviewing comments.
- Verify VoiceOver labels for toolbar buttons and sidebar controls.
