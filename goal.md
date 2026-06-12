# Project Goal

Build an open-source macOS desktop application for professors to read, annotate, and share academic PDFs using standard PDF annotations that remain visible and interactive when opened by other people in common PDF readers.

The application must let a professor open a local PDF, add comments attached to selected text, highlights, and underlines, save those annotations directly into the PDF file, and share the resulting PDF with students, colleagues, or publishers. The recipient must be able to see the annotations and open the associated comment popups without needing this application.

## Core Requirement

Annotations must be written as standards-compliant PDF annotations, not stored in a separate database, sidecar file, hidden metadata format, or app-specific layer.

A PDF annotated in this app must preserve its comments when opened in:

- macOS Preview
- Adobe Acrobat Reader
- Common browser PDF viewers where supported

## Primary Users

The primary user is a professor reading academic PDFs such as journal articles, book chapters, working papers, syllabi, dissertations, and scanned course readings.

The professor needs to:

- Read PDFs comfortably on macOS
- Highlight passages
- Attach explanatory comments to highlighted text
- Attach comments to selected text from the toolbar, comments sidebar, or right-click menu
- Save and share the annotated PDF
- Trust that another person can open the file and see the comments

## Platform

The first version must run on macOS only.

Minimum supported version should be explicitly chosen before development. Recommended target:

- macOS 13 Ventura or newer
- Apple Silicon and Intel Macs
- Distributed as a downloadable `.dmg`
- Open-source repository with build instructions

## License

The project should use a permissive open-source license unless there is a specific reason not to. Recommended:

- MIT License or Apache 2.0

## Required Features

## Design and macOS User Experience

The app must feel like a polished, modern macOS application, not a generic cross-platform document viewer.

The user interface must follow Apple's Human Interface Guidelines for macOS where practical, including native-feeling window behavior, toolbar placement, sidebar behavior, menus, keyboard shortcuts, typography, spacing, focus states, and system color usage.

The app must be aesthetically restrained, calm, and pleasant for long academic reading sessions. The visual design should prioritize readability, focus, and low cognitive load over decorative styling.

The app must support:

- Light mode
- Dark mode
- Automatic appearance matching the user's macOS system setting
- Native macOS toolbar behavior
- Native macOS menu bar commands
- Native macOS keyboard shortcuts where applicable
- Smooth scrolling and zooming
- Crisp rendering on Retina displays
- Clear hover, selected, active, disabled, and focus states
- Accessible contrast for text, icons, controls, highlights, and annotation markers
- Subdued annotation colors that remain visible without looking like high-contrast demo markup

The app should use system typography, system colors, native controls, and familiar macOS interaction patterns unless there is a specific reason not to.

The PDF reading area must be visually quiet. Controls should not distract from the document. Toolbars, sidebars, popovers, and annotation panels must be useful, compact, and consistent with macOS conventions.

Annotation markers, comment icons, reply icons, and sidebar selection states must match the restrained macOS visual theme in both light mode and dark mode. They should be legible, but not harsh, neon, or visually louder than the PDF text.

The app must avoid:

- Cluttered toolbars
- Unnecessary branding inside the reading interface
- Bright or harsh color palettes
- Oversaturated comment/reply colors that clash with native macOS light or dark appearance
- Web-app-style controls that feel out of place on macOS
- Decorative gradients, oversized cards, or marketing-style layouts
- Custom UI patterns that conflict with standard macOS behavior
- Animations that slow down reading, annotation, or navigation

The app should feel appropriate for professors, researchers, graduate students, and academic professionals who spend long periods reading dense documents.

## Current UI Audit and Revised Design Direction

The current implementation is functionally promising but visually and interaction-wise off target. The screenshot evidence shows the app behaving more like a debug/admin interface around a PDF than a polished academic reading tool. The core PDF interoperability work remains valuable, but the user experience must be redesigned before the app can be considered complete.

### Current UI Problems

The current UI is wrong in these specific ways:

- Too much chrome is open by default. The page thumbnail sidebar and comments sidebar both appear immediately, leaving the PDF squeezed between panels.
- The default view does not prioritize reading. The PDF should dominate the window; sidebars should support the reading task, not frame the entire experience at all times.
- The comments sidebar is too dashboard-like. Search fields, segmented filters, type pickers, author pickers, status pickers, refresh buttons, and grouped metadata are all visible before the user asks for a review workflow.
- The app exposes a refresh button in the comments panel, which makes comments feel stale or manually synchronized. Comments must update live when annotations are created, edited, deleted, or selected.
- The comment creation flow feels like filling out a form. Adding a comment to selected text or a highlight should feel anchored, immediate, lightweight, and dismissible.
- It is unclear where to type a comment after selecting text. The app needs an obvious anchored comment popover, not a separate form-like editor whose relationship to the highlighted text is ambiguous.
- The highlight/comment workflow is too indirect. A professor should be able to select text, click highlight, immediately type a comment in context, press Command-Return or click away, and continue reading.
- The comments sidebar does not visibly update as part of the annotation action. A newly created or edited comment should appear immediately without requiring refresh.
- The PDF margins and surrounding gray space feel accidental and oversized. Page spacing should be tuned for reading: enough separation to orient the user, but not large dead zones.
- Toolbar controls are too dense and visually equal. Primary actions, reading controls, annotation tools, search, and save are competing for attention.
- Sidebars feel heavy. They use too much width and visual weight for routine reading.
- The right comments sidebar is open even when there is only one comment or no active review task.
- The left sidebar shows large empty vertical regions and thumbnail spacing that make the app feel unfinished.
- The annotation list and comments review views duplicate concepts without clear mode distinction.
- The selected text context menu can obscure the annotation workflow; the app should make its own annotation affordance more obvious than the system text context menu.
- The visible layout does not feel calm enough for long academic reading sessions.

### Revised Product Design Principle

The app is primarily a reading surface, not an annotation database.

The default experience after opening a PDF must be:

- A large, centered, comfortable PDF reading area.
- No right comments sidebar by default.
- No left thumbnail sidebar by default unless the user explicitly opens it or the window is wide enough and the user has previously enabled it.
- A compact native toolbar with only the most important controls visible.
- Annotation tools that are obvious but not visually dominant.
- Icon-only controls should explain their action on hover with native macOS help/tooltips.
- Toolbar icons should be visually distinct without stacked custom arrows or ambiguous overlays.
- A comments review panel that appears only when requested, when clicking a comments button, or when entering review mode.
- Automatic live updates everywhere; no manual refresh button for comments.

### Target First-Run and Open-PDF Layout

When no PDF is open:

- Show a quiet native empty state with one primary "Open PDF" action.
- Do not show disabled annotation controls as a dominant visual element.
- Keep the window simple and restrained.

When a PDF is open:

- The PDF occupies the center and most of the window.
- The default layout is single-pane reading mode.
- The toolbar contains compact groups:
  - Open/save/share
  - page navigation
  - zoom/fit
  - annotation tools
  - search
  - sidebar toggles
- Two-page continuous view should stay available from the View menu and keyboard shortcut, not as a persistent toolbar icon.
- The thumbnail sidebar is hidden by default and opens with a sidebar button or keyboard shortcut.
- The comments review sidebar is hidden by default and opens with a comments button or keyboard shortcut.
- The app remembers whether the user last had sidebars open for that document/window size.
- On narrow windows, opening one sidebar should not automatically force both sidebars into view.

### Target Commenting Interaction

Commenting must be immediate, anchored, and selection-based.

There must not be two primary kinds of comment posts. A user-facing comment is a message attached to selected PDF text or to an existing text markup annotation. The app must not present "Add a comment" as a loose page-marker creation flow that waits for the user to click somewhere on the page.

Required highlight comment flow:

1. The user selects text.
2. The user clicks Highlight or presses the highlight shortcut.
3. The text is highlighted immediately.
4. A small native popover appears near the highlight or in the nearest margin.
5. The popover contains a focused comment text area with placeholder text such as "Add comment".
6. The user types a comment.
7. The comment is saved automatically when the popover closes, when focus leaves the popover, or when the user presses Command-Return.
8. The comments sidebar, if open, updates immediately.
9. The user continues reading without navigating away from the PDF.

The user must not have to understand a separate form, save button, manual refresh button, or detached editor window just to attach a comment to highlighted text.

Required selected-text comment flow:

1. The user selects text with the mouse.
2. The user clicks Comment, uses the comments sidebar add-comment affordance, or right-clicks and chooses Comment.
3. The selected text receives a restrained standard PDF text markup annotation.
4. A small anchored popover opens immediately for the comment text.
5. The comment appears in the comments sidebar as one normal comment row, not as a separate post type.
6. Hovering the sidebar comment temporarily highlights the referenced text in the PDF without navigating away from the current reading position.
7. The comment saves automatically and remains standard PDF annotation contents.

Standalone page-placement comments are not a version 1 commenting flow. The app may preserve existing annotations from other readers and may use standard PDF text annotations for replies where PDFKit requires them, but the ordinary "add comment" path must be selection-bound.

Required edit flow:

- Clicking an existing highlight, underline, selection-bound comment, reply, or free-text annotation opens the anchored comment popover.
- Editing is inline and live-updating.
- Deleting an annotation is available from the popover through a clear but secondary destructive action.
- The comments sidebar can also edit comments, but it is not the primary creation experience.

### Target Comments Sidebar

The comments sidebar is a review mode, not the default annotation input surface.

The sidebar should read like a clean document-review conversation stream, closer to a native comments/chat inspector than a database table. Comments should be easy to scan in sequence, with a clear comment icon or author marker, author/time metadata, the full comment text, compact reply actions, and visible thread structure for replies.

It should:

- Be hidden by default.
- Open from a comments toolbar button, View menu command, or keyboard shortcut.
- Show a compact header with total comment count.
- Update automatically as annotations change.
- Never require or expose a manual refresh button in ordinary use.
- Group comments by page.
- Show author, date, review state, and full comment text.
- Use the row's circular marker icon to differentiate comments, highlights, underlines, and replies; do not duplicate that icon in the metadata row.
- Let users change review state directly from a compact Reviewed/Not reviewed chip in each comment row.
- Include search and filters, but hide advanced filters behind a compact filter menu or disclosure control.
- Keep replies visually subordinate to their parent comment.
- Replies should appear in the comments sidebar thread and should not create additional visible page icons on the PDF.
- Draw subtle vertical connector lines that make reply threads visually clear, like a clean comments/chat section.
- Navigate to and select the associated PDF annotation when a parent comment or reply is clicked.
- Temporarily highlight the referenced PDF text when a comment row or reply row is hovered.
- Feel like a native macOS inspector/sidebar, not a web dashboard.

The comments sidebar may have a refresh command only as a hidden/debug or menu-level recovery action if PDFKit state becomes inconsistent. It must not be a primary visible control.

### Target Annotation Sidebar and Thumbnail Sidebar

The left sidebar must have clear purpose:

- Thumbnail mode is for navigation.
- Annotation list mode is for scanning annotations.
- The app should not show both the left navigation sidebar and right comments review sidebar by default.
- If both are open, widths must be compact and the PDF must remain the dominant visual element.
- Thumbnail spacing should be dense enough to feel native and useful.
- Empty sidebar regions should be avoided.

### Visual Density, Margins, and Reading Comfort

The PDF view should feel like a high-quality macOS document reader.

Requirements:

- Page margins and inter-page spacing must be deliberately tuned.
- Fit-to-width should use available space efficiently without huge dead zones.
- Actual-size mode should not be the default if it creates awkward margins for common slides or articles.
- The background around pages should be a subtle system color, not a visually heavy gray field.
- Sidebars should use compact row spacing and native materials.
- Buttons should use icon-only labels where the meaning is standard, with accessibility labels and tooltips.
- Search should not consume excessive toolbar width.
- Annotation colors should be readable and restrained.
- There should be no visible decorative branding inside the reading interface.

### Path to Fixing the Current UI

The UI must be fixed in this order:

1. Change the default open-PDF layout to single-pane reading mode with both sidebars hidden.
2. Add a compact comments button that toggles the comments review sidebar.
3. Remove the visible comments refresh button and make annotation changes update the sidebar automatically.
4. Replace the form-like comment editor with an anchored popover tied to the selected highlight, selection-bound comment, underline, or free-text annotation.
5. Make highlight creation open the comment popover immediately after creating the PDF annotation.
6. Make selected-text comment creation available from the toolbar, comments sidebar, and right-click menu, then open the anchored comment popover immediately.
7. Tune PDF page margins, page-break spacing, and fit behavior so documents use available space well.
8. Simplify and regroup the toolbar around reading and annotation tasks.
9. Make advanced comment filters collapsible or menu-based.
10. Redesign comment rows to feel like a clean threaded review/chat stream, including visible connector lines for replies and click-to-navigate behavior on comments and replies.
11. Reduce sidebar widths and row spacing.
12. Add visual QA screenshots for:
    - no document open
    - PDF open in default reading mode
    - highlight comment popover
    - selected-text comment popover
    - comments review sidebar open
    - dark mode reading
13. Run a design review using real academic PDFs, lecture slides, scanned readings, and long journal articles.

### Revised UI Acceptance Standard

The app is not visually acceptable until a user can open a PDF and immediately understand:

- where the document is,
- how to highlight selected text,
- where to type the comment,
- how to close the comment and keep reading,
- how to reopen the comment,
- how to show or hide all comments,
- and how to save/share the annotated PDF.
- how comment replies belong to a parent comment in the review sidebar.

No default screen should make the user feel like they are managing a database of comments before they have started reading.

### 1. PDF Opening

The app must allow the user to open a local `.pdf` file from disk.

The app must support:

- Text-based PDFs
- Scanned/image-based PDFs
- Multi-page PDFs
- Large academic PDFs of at least 500 pages

### 2. Reading Interface

The app must provide:

- Page scrolling
- Zoom in and zoom out
- Fit to width
- Fit to page
- Page number navigation
- Search within selectable text PDFs
- Sidebar with page thumbnails
- Sidebar toggle

### 3. Annotation Types

The app must support at minimum:

- Highlight annotation with optional comment
- Selection-bound comment created from selected text, including right-click Comment
- Underline annotation with optional comment
- Free-text annotation placed directly on the page

The first version does not need standalone page-placement comments, drawing, shapes, stamps, audio annotations, collaboration, OCR, or AI features.

### 4. Comment Popups

For every annotation that has a comment, the user must be able to open a popup displaying the comment text.

The popup must support:

- Viewing the full comment
- Editing the comment
- Closing the popup
- Reopening the popup by clicking the annotation

When the PDF is saved and opened in another PDF reader, the comment must still be associated with the annotation and must be openable there.

### 5. Saving

The app must support:

- Save annotations into the original PDF
- Save As a new annotated copy
- Warn before overwriting the original file
- Preserve existing PDF content
- Preserve existing annotations from other PDF readers whenever possible

### 6. Interoperability

The app must not rely on proprietary annotation storage.

A successful export means:

- Highlighted text remains highlighted
- Selection-bound comments remain visible and readable as standard PDF annotations
- Comments remain readable as popup annotation contents
- The PDF can be emailed or uploaded to an LMS without losing comments

### 7. Annotation Sidebar

The app must include an annotation list showing:

- Page number
- Annotation type
- Author name
- Date created
- First line of comment text

Clicking an item in the list must navigate to that annotation.

### 8. Comments Review Sidebar

The app must include an Adobe Acrobat-style comments review sidebar for quickly reviewing and responding to annotations across the whole PDF.

This is separate from one-off annotation popups. It should provide a persistent document-level comments panel that can be opened beside the PDF reading area.

The comments sidebar must support:

- Total comment count for the current PDF
- Comments grouped by page
- Collapsible page groups
- Search within comments
- Filtering comments by annotation type, author, and status where practical
- Author name for each comment
- Date and time created or modified
- Full comment text, not only a truncated preview
- Reply threads attached to an existing annotation comment
- Adding a reply from the sidebar
- Editing the user's own comments from the sidebar
- Deleting the user's own comments from the sidebar
- Clicking a comment to navigate to the corresponding page and annotation
- Selecting the associated annotation in the PDF view when a comment is selected

Threaded replies should be saved using standards-compliant PDF annotation reply relationships where supported by PDFKit or the chosen PDF-writing layer. If full reply interoperability is limited by common PDF readers, the app must still preserve the primary annotation comment as standard PDF annotation contents and document the known limitations.

The comments sidebar should feel native to macOS: compact, quiet, keyboard-navigable, accessible, and suitable for long review sessions.

The app must not require AI features for comment review. Any future summary feature must be optional and out of scope for version 1 unless explicitly added later.

### 9. Professor-Focused Workflow

The app should make academic annotation fast.

Required workflow:

- Open PDF
- Select text
- Click highlight
- Type optional comment
- Continue reading
- Save annotated PDF
- Share file

The app should not require accounts, cloud sync, project setup, import libraries, or document conversion.

## Out of Scope for Version 1

The following are explicitly not required:

- Real-time collaboration
- Cloud storage
- User accounts
- LMS integration
- Citation management
- OCR
- AI summarization
- Handwriting recognition
- iPad support
- Windows/Linux support
- Browser extension
- Mobile app
- Custom proprietary comment system

## Acceptance Criteria

The project is complete when:

1. A professor can open a PDF on macOS, highlight text, add a comment, save the file, and reopen it with the annotation still present.
2. A second person can open that saved PDF in macOS Preview or Adobe Acrobat Reader and see the highlight and open the comment popup.
3. Selection-bound comments created in the app remain visible as standard PDF annotations in other readers.
4. Existing PDF text, images, layout, bookmarks, and prior annotations are not destroyed during save.
5. The app can be built from source using documented commands.
6. The GitHub repository includes installation instructions, development setup instructions, license, screenshots, and a basic roadmap.
7. The app visually fits on macOS, supports light and dark mode, uses native-feeling controls and keyboard shortcuts, and remains pleasant to use during long PDF reading sessions.
8. The app includes a persistent comments review sidebar that shows the document comment count, groups comments by page, supports search/filtering, supports replies where interoperable, highlights referenced text on hover, and navigates from a sidebar comment to the matching PDF annotation.
9. The app passes a design review against Apple's macOS Human Interface Guidelines before the first public release.

## One-Sentence Version

Build an open-source, polished, native-feeling macOS PDF reader and annotation app for professors that saves highlights, underlines, and selection-bound comments as standard embedded PDF annotations so annotated PDFs can be shared and viewed with pop-up comments in common PDF readers without requiring the app.
