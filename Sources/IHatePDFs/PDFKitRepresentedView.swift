import AppKit
import IHatePDFsCore
import PDFKit
import SwiftUI

final class AcademicPDFView: PDFView {
    var onAnnotationClick: ((PDFAnnotation, PDFPage) -> Void)?
    var onPlacementClick: ((PDFPage, CGPoint) -> Void)?
    var onSelectionComment: (() -> Void)?
    var onPreviousPageKey: (() -> Void)?
    var onNextPageKey: (() -> Void)?
    var placementTool: AnnotationPlacementTool? {
        didSet {
            guard oldValue != placementTool else { return }
            window?.invalidateCursorRects(for: self)
        }
    }
    private var handledAnnotationMouseDown = false

    override var acceptsFirstResponder: Bool { true }

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

        if placementTool != nil {
            addCursorRect(bounds, cursor: .crosshair)
        }
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        commentMenu(from: super.menu(for: event))
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
           let editable = editableParent(for: direct, on: page) {
            return editable
        }

        for annotation in page.annotations.reversed() {
            guard let editable = editableParent(for: annotation, on: page) else { continue }

            if annotation.bounds.insetBy(dx: -8, dy: -8).contains(point) {
                return editable
            }

            if let popup = editable.popup,
               popup.bounds.insetBy(dx: -10, dy: -10).contains(point) {
                return editable
            }

            if isTextMarkup(editable),
               textMarkupInteractionBounds(for: editable, on: page).contains(point) {
                return editable
            }
        }

        return nil
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

    private func textMarkupInteractionBounds(
        for annotation: PDFAnnotation,
        on page: PDFPage
    ) -> CGRect {
        var bounds = annotation.bounds.insetBy(dx: -48, dy: -48)

        if let popup = annotation.popup {
            bounds = bounds.union(popup.bounds.insetBy(dx: -16, dy: -16))
        }

        let pageBounds = page.bounds(for: displayBox).insetBy(dx: -64, dy: -64)
        return bounds.intersection(pageBounds)
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
        AnnotationKeys.annotation(annotation, hasSubtype: .highlight)
            || AnnotationKeys.annotation(annotation, hasSubtype: .underline)
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
        view.onSelectionComment = {
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
        appState.attachPDFView(view)
        return view
    }

    func updateNSView(_ view: AcademicPDFView, context: Context) {
        if view.document !== appState.document {
            view.document = appState.document
        }
        view.placementTool = appState.placementTool
        view.highlightedSelections = appState.searchResults.isEmpty ? nil : appState.searchResults
        context.coordinator.sync(editor: appState.activeEditor, in: view, appState: appState)
    }

    @MainActor
    final class Coordinator: NSObject, NSPopoverDelegate {
        private var popover: NSPopover?
        private var model: CommentPopoverModel?
        private var editorID: UUID?
        private var isClosing = false
        private weak var appState: AppState?

        func sync(
            editor context: AnnotationEditorContext?,
            in view: AcademicPDFView,
            appState: AppState
        ) {
            self.appState = appState

            guard let context else {
                if !isClosing {
                    dismissCurrent(commit: false)
                }
                return
            }

            if editorID == context.id, popover?.isShown == true {
                return
            }

            dismissCurrent(commit: true)
            show(context, in: view, appState: appState)
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
            self.isClosing = false

            let anchor = anchorRect(for: context, in: view)
            popover.show(
                relativeTo: anchor,
                of: view,
                preferredEdge: preferredEdge(for: anchor, in: view)
            )
        }

        private func dismissCurrent(commit: Bool) {
            guard let popover else {
                cleanup()
                return
            }

            if commit {
                model?.commit()
            }

            if popover.isShown {
                popover.performClose(nil)
            } else {
                cleanup()
            }
        }

        func popoverWillClose(_ notification: Notification) {
            isClosing = true
            model?.commit()
        }

        func popoverDidClose(_ notification: Notification) {
            let closedEditorID = editorID
            let currentAppState = appState
            cleanup()

            if currentAppState?.activeEditor?.id == closedEditorID {
                currentAppState?.activeEditor = nil
            }
        }

        private func cleanup() {
            popover?.delegate = nil
            popover = nil
            model = nil
            editorID = nil
            isClosing = false
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
