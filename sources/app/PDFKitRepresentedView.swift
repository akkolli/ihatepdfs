import AppKit
import IHatePDFsCore
import PDFKit
import SwiftUI

final class AcademicPDFView: PDFView {
    var onAnnotationClick: ((PDFAnnotation, PDFPage) -> Void)?
    var onPlacementClick: ((PDFPage, CGPoint) -> Void)?
    var onCancelActiveMode: (() -> Void)?
    var onSelectionComment: (() -> Void)?
    var onHighlighterSelection: (() -> Void)?
    var onToggleHighlighterKey: (() -> Void)?
    var onUnderlineSelectionKey: (() -> Void)?
    var onCommentSelectionKey: (() -> Void)?
    var onPreviousPageKey: (() -> Void)?
    var onNextPageKey: (() -> Void)?
    var onDeleteSelectedAnnotationKey: (() -> Void)?
    var placementTool: AnnotationPlacementTool? {
        didSet {
            guard oldValue != placementTool else { return }
            window?.invalidateCursorRects(for: self)
        }
    }
    var isHighlighterModeActive = false {
        didSet {
            guard oldValue != isHighlighterModeActive else { return }
            window?.invalidateCursorRects(for: self)
            if mouseIsInside {
                applyToolCursorIfNeeded()
            }
        }
    }
    private var handledAnnotationMouseDown = false

    override var acceptsFirstResponder: Bool { true }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        backgroundColor = NSColor.underPageBackgroundColor
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        handledAnnotationMouseDown = false
        let point = convert(event.locationInWindow, from: nil)

        if let page = page(for: point, nearest: false) ?? page(for: point, nearest: true) {
            closeNativePopups(on: page)
            let pagePoint = convert(point, to: page)
            if placementTool != nil {
                onPlacementClick?(page, pagePoint)
                return
            }

            if let annotation = editableAnnotation(on: page, at: pagePoint) {
                handledAnnotationMouseDown = true
                closeNativePopups(on: page)
                onAnnotationClick?(annotation, page)
                return
            }
        }

        super.mouseDown(with: event)
        window?.makeFirstResponder(self)
        DispatchQueue.main.async { [weak self] in
            guard let self,
                  let page = self.page(for: point, nearest: false)
            else {
                return
            }
            self.closeNativePopups(on: page)
        }
    }

    override func mouseUp(with event: NSEvent) {
        if handledAnnotationMouseDown {
            handledAnnotationMouseDown = false
            return
        }

        let point = convert(event.locationInWindow, from: nil)
        let page = page(for: point, nearest: false) ?? page(for: point, nearest: true)
        let pagePoint = page.map { convert(point, to: $0) }

        super.mouseUp(with: event)

        if isHighlighterModeActive, hasCommentableSelection {
            DispatchQueue.main.async { [weak self] in
                guard self?.hasCommentableSelection == true else { return }
                self?.onHighlighterSelection?()
            }
            return
        }

        guard let page else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            let clickedAnnotation = pagePoint.flatMap {
                self.editableAnnotation(on: page, at: $0)
            }
            let target = clickedAnnotation ?? self.openNativePopupOwner(on: page)

            self.closeNativePopups(on: page)
            if let target {
                self.onAnnotationClick?(target, page)
            }
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        guard hasCommentableSelection else {
            super.rightMouseDown(with: event)
            return
        }

        let menu = commentMenu(from: super.menu(for: event))
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53, placementTool != nil || isHighlighterModeActive {
            onCancelActiveMode?()
            return
        }

        if [51, 117].contains(event.keyCode),
           event.modifierFlags.intersection([.command, .control, .option, .shift]).isEmpty {
            onDeleteSelectedAnnotationKey?()
            return
        }

        if !event.isARepeat,
           event.modifierFlags.intersection([.command, .control, .option]).isEmpty,
           let key = event.charactersIgnoringModifiers?.lowercased() {
            switch key {
            case "h":
                onToggleHighlighterKey?()
                return
            case "u":
                onUnderlineSelectionKey?()
                return
            case "c":
                onCommentSelectionKey?()
                return
            default:
                break
            }
        }

        let pageNavigationModifiers: NSEvent.ModifierFlags = [.command, .control, .option, .shift]
        guard event.modifierFlags.intersection(pageNavigationModifiers).isEmpty else {
            super.keyDown(with: event)
            return
        }

        switch event.keyCode {
        case 123, 126:
            onPreviousPageKey?()
        case 124, 125:
            onNextPageKey?()
        default:
            super.keyDown(with: event)
        }
    }

    override func resetCursorRects() {
        super.resetCursorRects()

        if isHighlighterModeActive {
            addCursorRect(bounds, cursor: Self.highlighterCursor)
        } else if placementTool != nil {
            addCursorRect(bounds, cursor: .crosshair)
        }
    }

    override func cursorUpdate(with event: NSEvent) {
        if applyToolCursorIfNeeded() {
            return
        }
        super.cursorUpdate(with: event)
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        applyToolCursorIfNeeded()
    }

    override func mouseDragged(with event: NSEvent) {
        super.mouseDragged(with: event)
        applyToolCursorIfNeeded()
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        commentMenu(from: super.menu(for: event))
    }

    @discardableResult
    private func applyToolCursorIfNeeded() -> Bool {
        if isHighlighterModeActive {
            Self.highlighterCursor.set()
            return true
        }
        if placementTool != nil {
            NSCursor.crosshair.set()
            return true
        }
        return false
    }

    private var mouseIsInside: Bool {
        guard let window else { return false }
        return bounds.contains(convert(window.mouseLocationOutsideOfEventStream, from: nil))
    }

    private static let highlighterCursor: NSCursor = {
        let size = NSSize(width: 36, height: 36)
        let image = highResolutionCursorImage(size: size) {
            NSGraphicsContext.current?.imageInterpolation = .high
            NSGraphicsContext.current?.shouldAntialias = true

            let outline = NSColor.black.withAlphaComponent(0.58)
            let bodyTint = NSColor(red: 1.0, green: 0.86, blue: 0.28, alpha: 0.98)
            let bodyShade = NSColor(red: 1.0, green: 0.58, blue: 0.12, alpha: 0.98)
            let nibColor = NSColor(red: 0.16, green: 0.07, blue: 0.02, alpha: 0.96)

            let highlightTrail = NSBezierPath(roundedRect: NSRect(x: 4.5, y: 3.6, width: 17.5, height: 5.2), xRadius: 2.6, yRadius: 2.6)
            NSColor(red: 1.0, green: 0.93, blue: 0.28, alpha: 0.34).setFill()
            highlightTrail.fill()

            let shadow = NSShadow()
            shadow.shadowOffset = NSSize(width: 0.7, height: -1.1)
            shadow.shadowBlurRadius = 2.4
            shadow.shadowColor = NSColor.black.withAlphaComponent(0.24)

            let body = NSBezierPath()
            body.move(to: NSPoint(x: 10.4, y: 9.2))
            body.line(to: NSPoint(x: 21.9, y: 23.5))
            body.curve(
                to: NSPoint(x: 25.3, y: 23.8),
                controlPoint1: NSPoint(x: 22.8, y: 24.4),
                controlPoint2: NSPoint(x: 24.2, y: 24.5)
            )
            body.line(to: NSPoint(x: 28.8, y: 20.8))
            body.curve(
                to: NSPoint(x: 28.1, y: 17.5),
                controlPoint1: NSPoint(x: 29.7, y: 20.0),
                controlPoint2: NSPoint(x: 29.3, y: 18.4)
            )
            body.line(to: NSPoint(x: 15.2, y: 4.1))
            body.curve(
                to: NSPoint(x: 11.7, y: 4.3),
                controlPoint1: NSPoint(x: 13.9, y: 3.1),
                controlPoint2: NSPoint(x: 12.4, y: 3.0)
            )
            body.line(to: NSPoint(x: 8.7, y: 6.8))
            body.curve(
                to: NSPoint(x: 10.4, y: 9.2),
                controlPoint1: NSPoint(x: 8.9, y: 7.7),
                controlPoint2: NSPoint(x: 9.5, y: 8.6)
            )
            body.close()
            body.lineJoinStyle = .round

            NSGraphicsContext.saveGraphicsState()
            shadow.set()
            NSGradient(colors: [bodyTint, bodyShade])?.draw(in: body, angle: 38)
            NSGraphicsContext.restoreGraphicsState()

            outline.setStroke()
            body.lineWidth = 1.05
            body.stroke()

            let grip = NSBezierPath()
            grip.move(to: NSPoint(x: 17.2, y: 10.4))
            grip.line(to: NSPoint(x: 25.0, y: 18.6))
            grip.lineWidth = 1.0
            NSColor(red: 0.58, green: 0.27, blue: 0.02, alpha: 0.22).setStroke()
            grip.stroke()

            let shine = NSBezierPath()
            shine.move(to: NSPoint(x: 15.2, y: 9.5))
            shine.curve(
                to: NSPoint(x: 25.0, y: 20.7),
                controlPoint1: NSPoint(x: 18.8, y: 12.6),
                controlPoint2: NSPoint(x: 22.1, y: 17.8)
            )
            shine.lineWidth = 1.05
            NSColor.white.withAlphaComponent(0.46).setStroke()
            shine.stroke()

            let nib = NSBezierPath()
            nib.move(to: NSPoint(x: 5.3, y: 6.0))
            nib.line(to: NSPoint(x: 10.6, y: 9.2))
            nib.curve(
                to: NSPoint(x: 14.4, y: 4.6),
                controlPoint1: NSPoint(x: 11.8, y: 9.4),
                controlPoint2: NSPoint(x: 13.6, y: 4.9)
            )
            nib.line(to: NSPoint(x: 8.6, y: 3.1))
            nib.close()
            nibColor.setFill()
            nib.fill()
            outline.setStroke()
            nib.lineWidth = 0.9
            nib.stroke()
        }
        return NSCursor(image: image, hotSpot: NSPoint(x: 8, y: 29))
    }()

    private static func highResolutionCursorImage(
        size: NSSize,
        scale: CGFloat = 2,
        draw: () -> Void
    ) -> NSImage {
        let image = NSImage(size: size)
        guard let representation = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width * scale),
            pixelsHigh: Int(size.height * scale),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ),
        let context = NSGraphicsContext(bitmapImageRep: representation)
        else {
            return image
        }

        representation.size = size
        let previousContext = NSGraphicsContext.current
        NSGraphicsContext.current = context
        NSGraphicsContext.saveGraphicsState()
        context.cgContext.scaleBy(x: scale, y: scale)
        draw()
        NSGraphicsContext.restoreGraphicsState()
        NSGraphicsContext.current = previousContext
        image.addRepresentation(representation)
        return image
    }

    private var hasCommentableSelection: Bool {
        guard let selection = currentSelection,
              !selection.pages.isEmpty,
              selection.string?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        else {
            return false
        }

        return true
    }

    private func commentMenu(from baseMenu: NSMenu?) -> NSMenu {
        let menu = baseMenu ?? NSMenu()
        guard hasCommentableSelection else { return menu }
        guard !menu.items.contains(where: { $0.action == #selector(commentOnSelectionFromMenu(_:)) }) else {
            return menu
        }

        let item = NSMenuItem(
            title: "Comment",
            action: #selector(commentOnSelectionFromMenu(_:)),
            keyEquivalent: ""
        )
        item.target = self
        menu.insertItem(item, at: 0)
        if menu.items.count > 1 {
            menu.insertItem(.separator(), at: 1)
        }
        return menu
    }

    @objc private func commentOnSelectionFromMenu(_ sender: Any?) {
        onSelectionComment?()
    }

    private func editableAnnotation(on page: PDFPage, at point: CGPoint) -> PDFAnnotation? {
        if let direct = page.annotation(at: point),
           let editable = editableParent(for: direct, on: page),
           isInteractionPoint(point, on: direct, editable: editable) {
            return editable
        }

        for annotation in page.annotations.reversed() {
            guard let editable = editableParent(for: annotation, on: page) else { continue }

            if isInteractionPoint(point, on: annotation, editable: editable) {
                return editable
            }
        }

        return nil
    }

    private func isInteractionPoint(
        _ point: CGPoint,
        on annotation: PDFAnnotation,
        editable: PDFAnnotation
    ) -> Bool {
        if AnnotationKeys.annotation(annotation, hasSubtype: .popup) {
            return annotation.bounds.insetBy(dx: -10, dy: -10).contains(point)
        }

        if isTextMarkup(editable) {
            return AnnotationHitTesting.containsTextMarkupPoint(point, in: editable)
        }

        if annotation.bounds.insetBy(dx: -8, dy: -8).contains(point) {
            return true
        }

        if let popup = editable.popup,
           popup.bounds.insetBy(dx: -10, dy: -10).contains(point) {
            return true
        }

        return false
    }

    private func editableParent(for annotation: PDFAnnotation, on page: PDFPage) -> PDFAnnotation? {
        if let owner = popupOwner(for: annotation, on: page) {
            return isEditableAcademicAnnotation(owner) ? owner : nil
        }

        let parent = AnnotationFactory.parentAnnotation(for: annotation)
        return isEditableAcademicAnnotation(parent) ? parent : nil
    }

    private func popupOwner(for annotation: PDFAnnotation, on page: PDFPage) -> PDFAnnotation? {
        guard AnnotationKeys.annotation(annotation, hasSubtype: .popup) else { return nil }

        if let parent = annotation.value(forAnnotationKey: .parent) as? PDFAnnotation {
            return parent
        }

        return page.annotations.first { candidate in
            candidate.popup === annotation
        }
    }

    private func openNativePopupOwner(on page: PDFPage) -> PDFAnnotation? {
        for annotation in page.annotations.reversed() {
            if annotation.popup?.isOpen == true,
               isEditableAcademicAnnotation(annotation) {
                return annotation
            }

            guard AnnotationKeys.annotation(annotation, hasSubtype: .popup),
                  annotation.isOpen,
                  let owner = popupOwner(for: annotation, on: page),
                  isEditableAcademicAnnotation(owner)
            else {
                continue
            }

            return owner
        }

        return nil
    }

    private func isTextMarkup(_ annotation: PDFAnnotation) -> Bool {
        AnnotationKeys.annotation(annotation, hasSubtype: .highlight)
            || AnnotationKeys.annotation(annotation, hasSubtype: .underline)
    }

    private func closeNativePopups(on page: PDFPage) {
        for annotation in page.annotations {
            if AnnotationKeys.annotation(annotation, hasSubtype: .popup) {
                annotation.isOpen = false
            }
            annotation.popup?.isOpen = false
        }
        annotationsChanged(on: page)
    }

    private func isEditableAcademicAnnotation(_ annotation: PDFAnnotation) -> Bool {
        if AnnotationKeys.annotation(annotation, hasSubtype: .highlight) {
            let isSelectionComment = annotation.value(forAnnotationKey: AnnotationKeys.appKind) as? String
                == AnnotationKeys.appKindComment
            let hasCommentText = !AnnotationKeys.commentText(for: annotation)
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty
            return isSelectionComment || hasCommentText
        }

        return AnnotationKeys.annotation(annotation, hasSubtype: .underline)
            || AnnotationKeys.annotation(annotation, hasSubtype: .text)
            || AnnotationKeys.annotation(annotation, hasSubtype: .freeText)
    }
}

struct PDFKitRepresentedView: NSViewRepresentable {
    @EnvironmentObject private var appState: AppState

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> AcademicPDFView {
        let view = AcademicPDFView()
        view.onAnnotationClick = { annotation, page in
            Task { @MainActor in
                appState.openAnnotationFromPDF(annotation, page: page)
            }
        }
        view.onPlacementClick = { page, point in
            Task { @MainActor in
                appState.placePendingAnnotation(on: page, near: point)
            }
        }
        view.onCancelActiveMode = {
            Task { @MainActor in
                appState.cancelActiveMode()
            }
        }
        view.onSelectionComment = {
            Task { @MainActor in
                appState.addComment()
            }
        }
        view.onHighlighterSelection = {
            Task { @MainActor in
                appState.addHighlightFromHighlighterMode()
            }
        }
        view.onToggleHighlighterKey = {
            Task { @MainActor in
                appState.toggleHighlighterMode()
            }
        }
        view.onUnderlineSelectionKey = {
            Task { @MainActor in
                appState.addUnderline()
            }
        }
        view.onCommentSelectionKey = {
            Task { @MainActor in
                appState.addComment()
            }
        }
        view.onPreviousPageKey = {
            Task { @MainActor in
                appState.goToPreviousPage()
            }
        }
        view.onNextPageKey = {
            Task { @MainActor in
                appState.goToNextPage()
            }
        }
        view.onDeleteSelectedAnnotationKey = {
            Task { @MainActor in
                appState.deleteSelectedAnnotation()
            }
        }
        appState.attachPDFView(view)
        return view
    }

    func updateNSView(_ view: AcademicPDFView, context: Context) {
        if view.document !== appState.document {
            view.document = appState.document
        }
        view.placementTool = appState.placementTool
        view.isHighlighterModeActive = appState.isHighlighterModeActive
        view.highlightedSelections = appState.searchResults.isEmpty ? nil : appState.searchResults
        context.coordinator.sync(
            editor: appState.activeEditor,
            in: view,
            appState: appState
        )
    }

    @MainActor
    final class Coordinator: NSObject, NSPopoverDelegate {
        private enum PopoverKind {
            case comment
        }

        private var popover: NSPopover?
        private var model: CommentPopoverModel?
        private var editorID: UUID?
        private var popoverKind: PopoverKind?
        private var isClosing = false
        private var commitsCommentOnClose = true
        private weak var appState: AppState?

        func sync(
            editor context: AnnotationEditorContext?,
            in view: AcademicPDFView,
            appState: AppState
        ) {
            self.appState = appState

            if let context {
                if popoverKind == .comment,
                   editorID == context.id,
                   popover?.isShown == true {
                    return
                }

                dismissCurrent(commit: true)
                show(context, in: view, appState: appState)
                return
            }

            if !isClosing {
                dismissCurrent(commit: false)
            }
        }

        private func show(
            _ context: AnnotationEditorContext,
            in view: AcademicPDFView,
            appState: AppState
        ) {
            guard view.window != nil else { return }

            let model = CommentPopoverModel(context: context, appState: appState)
            let controller = NSHostingController(rootView: CommentEditorView(model: model))
            let popover = NSPopover()
            popover.behavior = .semitransient
            popover.animates = true
            popover.contentSize = NSSize(width: 340, height: 258)
            popover.contentViewController = controller
            popover.delegate = self

            self.model = model
            self.popover = popover
            self.editorID = context.id
            self.popoverKind = .comment
            self.isClosing = false
            self.commitsCommentOnClose = true

            let anchor = anchorRect(for: context, in: view)
            popover.show(
                relativeTo: anchor,
                of: view,
                preferredEdge: preferredEdge(for: anchor, in: view)
            )
            focusCommentEditor(in: controller.view)
        }

        private func focusCommentEditor(in view: NSView) {
            Self.focusFirstTextView(in: view)

            DispatchQueue.main.async { [weak view] in
                guard let view else { return }
                Self.focusFirstTextView(in: view)
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak view] in
                guard let view else { return }
                Self.focusFirstTextView(in: view)
            }
        }

        private static func focusFirstTextView(in view: NSView) {
            view.layoutSubtreeIfNeeded()
            guard let textView = firstTextView(in: view) else { return }

            textView.window?.makeFirstResponder(textView)
            textView.setSelectedRange(NSRange(location: textView.string.utf16.count, length: 0))
            textView.insertionPointColor = .labelColor
            textView.needsDisplay = true
        }

        private static func firstTextView(in view: NSView) -> NSTextView? {
            if let textView = view as? NSTextView {
                return textView
            }

            for subview in view.subviews {
                if let textView = firstTextView(in: subview) {
                    return textView
                }
            }

            return nil
        }

        private func dismissCurrent(commit: Bool) {
            guard let popover else {
                cleanup()
                return
            }

            if commit {
                model?.commit()
            }
            commitsCommentOnClose = commit

            if popover.isShown {
                popover.performClose(nil)
            } else {
                cleanup()
            }
        }

        func popoverWillClose(_ notification: Notification) {
            isClosing = true
            if popoverKind == .comment, commitsCommentOnClose {
                model?.commit()
            }
        }

        func popoverDidClose(_ notification: Notification) {
            let closedEditorID = editorID
            let closedPopoverKind = popoverKind
            let currentAppState = appState
            cleanup()

            if closedPopoverKind == .comment,
               currentAppState?.activeEditor?.id == closedEditorID {
                currentAppState?.activeEditor = nil
            }
        }

        private func cleanup() {
            popover?.delegate = nil
            popover = nil
            model = nil
            editorID = nil
            popoverKind = nil
            isClosing = false
            commitsCommentOnClose = true
        }

        private func anchorRect(for context: AnnotationEditorContext, in view: AcademicPDFView) -> NSRect {
            guard let annotation = context.primaryAnnotation,
                  let page = context.primaryPage ?? annotation.page
            else {
                return centeredAnchor(in: view)
            }

            let rect = view.convert(annotation.bounds, from: page).insetBy(dx: -4, dy: -4)
            guard rect.width.isFinite,
                  rect.height.isFinite,
                  rect.width > 0,
                  rect.height > 0
            else {
                return centeredAnchor(in: view)
            }

            return rect.intersection(view.bounds).isNull ? centeredAnchor(in: view) : rect
        }

        private func centeredAnchor(in view: AcademicPDFView) -> NSRect {
            NSRect(x: view.bounds.midX - 1, y: view.bounds.midY - 1, width: 2, height: 2)
        }

        private func preferredEdge(for anchor: NSRect, in view: AcademicPDFView) -> NSRectEdge {
            anchor.midX > view.bounds.midX ? .minX : .maxX
        }
    }
}

struct PDFThumbnailRepresentedView: NSViewRepresentable {
    @EnvironmentObject private var appState: AppState

    func makeNSView(context: Context) -> PDFThumbnailView {
        let view = PDFThumbnailView()
        view.thumbnailSize = CGSize(width: 88, height: 116)
        view.backgroundColor = .clear
        view.maximumNumberOfColumns = 1
        view.labelFont = NSFont.systemFont(ofSize: 11)
        view.allowsDragging = false
        view.pdfView = appState.pdfView
        return view
    }

    func updateNSView(_ view: PDFThumbnailView, context: Context) {
        view.pdfView = appState.pdfView
    }
}
