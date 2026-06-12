import AppKit
import Foundation
import IHatePDFsCore
import PDFKit
import SwiftUI

enum SidebarMode: String, CaseIterable, Identifiable {
    case pages
    case annotations

    var id: String { rawValue }
}

enum CommentFilter: String, CaseIterable, Identifiable {
    case all
    case withComments
    case withoutComments

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "All"
        case .withComments: return "With Comments"
        case .withoutComments: return "No Comment"
        }
    }
}

enum AnnotationPlacementTool: Equatable {
    case freeText
}

private enum AppDefaults {
    static let documentSidebarStates = "IHatePDFs.documentSidebarStates.v1"

    static func sidebarPreference(for key: String) -> SidebarPreference? {
        guard let data = UserDefaults.standard.data(forKey: documentSidebarStates),
              let states = try? JSONDecoder().decode([String: SidebarPreference].self, from: data)
        else {
            return nil
        }

        return states[key]
    }

    static func setSidebarPreference(_ preference: SidebarPreference, for key: String) {
        let existingData = UserDefaults.standard.data(forKey: documentSidebarStates)
        var states = existingData
            .flatMap { try? JSONDecoder().decode([String: SidebarPreference].self, from: $0) }
            ?? [:]
        states[key] = preference

        guard let data = try? JSONEncoder().encode(states) else { return }
        UserDefaults.standard.set(data, forKey: documentSidebarStates)
    }
}

private enum SidebarWidthBucket: String {
    case compact
    case regular
    case wide

    init(width: CGFloat) {
        if width < 960 {
            self = .compact
        } else if width < 1280 {
            self = .regular
        } else {
            self = .wide
        }
    }
}

private struct SidebarPreference: Codable, Equatable {
    var showLeftSidebar: Bool
    var showCommentsSidebar: Bool

    static let defaultReading = SidebarPreference(showLeftSidebar: false, showCommentsSidebar: false)
}

struct AnnotationEditorContext: Identifiable {
    let id = UUID()
    let title: String
    let annotations: [PDFAnnotation]
    let pages: [PDFPage]
    let isNewAnnotation: Bool
    let allowsDelete: Bool
    let initialText: String
    let initialAuthor: String

    var primaryAnnotation: PDFAnnotation? { annotations.first }
    var primaryPage: PDFPage? { pages.first }
}

@MainActor
final class AppState: NSObject, ObservableObject {
    @Published var document: PDFDocument?
    @Published var documentURL: URL?
    @Published var pdfView: PDFView?
    @Published var annotations: [AnnotationSnapshot] = []
    @Published var selectedAnnotationID: String?
    @Published var activeEditor: AnnotationEditorContext?
    @Published var placementTool: AnnotationPlacementTool?
    @Published var showLeftSidebar = false {
        didSet {
            persistSidebarPreferenceIfNeeded()
        }
    }
    @Published var showCommentsSidebar = false {
        didSet {
            persistSidebarPreferenceIfNeeded()
        }
    }
    @Published var sidebarMode: SidebarMode = .pages
    @Published var searchText = ""
    @Published var showToolbarSearch = false
    @Published var searchResults: [PDFSelection] = []
    @Published var currentSearchIndex = 0
    @Published var pageText = "1"
    @Published var currentPageIndex = 0
    @Published var commentSearchText = ""
    @Published var commentFilter: CommentFilter = .all
    @Published var selectedKindFilter: AcademicAnnotationKind?
    @Published var selectedAuthorFilter = "All Authors"
    @Published var selectedStatusFilter = ReviewState.allStatuses
    @Published var collapsedPageIndexes: Set<Int> = []
    @Published var statusMessage = "Open a PDF to begin."

    private var pageObserver: NSObjectProtocol?
    private var selectionObserver: NSObjectProtocol?
    private var sidebarWidthBucket: SidebarWidthBucket = .regular
    private var isApplyingSidebarPreference = false
    private var hoveredAnnotationID: String?

    var displayTitle: String {
        documentURL?.lastPathComponent ?? "I Hate PDFs"
    }

    var pageCount: Int {
        document?.pageCount ?? 0
    }

    var authors: [String] {
        let values = Set(annotations.map(\.author).filter { !$0.isEmpty })
        return ["All Authors"] + values.sorted()
    }

    var statuses: [String] {
        let values = Set(annotations.map { ReviewState.label(for: $0.status) }.filter { !$0.isEmpty })
        let preferred = [ReviewState.notReviewed, ReviewState.reviewed].filter(values.contains)
        let custom = values.subtracting(preferred).sorted()
        return [ReviewState.allStatuses] + preferred + custom
    }

    var filteredAnnotations: [AnnotationSnapshot] {
        annotations.filter { item in
            switch commentFilter {
            case .all:
                break
            case .withComments:
                guard item.hasComment else { return false }
            case .withoutComments:
                guard !item.hasComment else { return false }
            }

            if let selectedKindFilter, item.kind != selectedKindFilter {
                return false
            }

            if selectedAuthorFilter != "All Authors", item.author != selectedAuthorFilter {
                return false
            }

            if !ReviewState.matches(item.status, filter: selectedStatusFilter) {
                return false
            }

            let query = commentSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !query.isEmpty {
                let haystack = [
                    item.contents,
                    item.author,
                    item.kind.displayName,
                    item.pageLabel
                ].joined(separator: " ")
                guard haystack.localizedCaseInsensitiveContains(query) else { return false }
            }

            return true
        }
    }

    var topLevelComments: [AnnotationSnapshot] {
        filteredAnnotations.filter { !$0.isReply }
    }

    var repliesByParent: [String: [AnnotationSnapshot]] {
        Dictionary(grouping: filteredAnnotations.filter(\.isReply), by: \.parentID!)
    }

    func attachPDFView(_ view: PDFView) {
        if pdfView === view { return }

        pdfView = view
        configure(view)
        view.document = document

        pageObserver = NotificationCenter.default.addObserver(
            forName: .PDFViewPageChanged,
            object: view,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.updateCurrentPageState() }
        }

        selectionObserver = NotificationCenter.default.addObserver(
            forName: .PDFViewSelectionChanged,
            object: view,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard self?.placementTool == nil else { return }
                self?.statusMessage = "Selection ready for annotation."
            }
        }
    }

    func updateWindowWidth(_ width: CGFloat) {
        guard width.isFinite, width > 0 else { return }

        let bucket = SidebarWidthBucket(width: width)
        guard bucket != sidebarWidthBucket else { return }

        sidebarWidthBucket = bucket
        applySidebarPreferenceForCurrentDocument()
    }

    func openDocument() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.title = "Open PDF"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        loadDocument(from: url)
    }

    func loadDocument(from url: URL) {
        guard let pdf = PDFDocument(url: url) else {
            showAlert(title: "Unable to Open PDF", message: "The selected file could not be opened as a PDF.")
            return
        }

        document = pdf
        documentURL = url
        applySidebarPreferenceForCurrentDocument()
        pdfView?.document = pdf
        pdfView?.goToFirstPage(nil)
        pageText = "1"
        currentPageIndex = 0
        searchText = ""
        showToolbarSearch = false
        searchResults = []
        selectedAnnotationID = nil
        activeEditor = nil
        placementTool = nil
        refreshAnnotations()
        statusMessage = "Opened \(url.lastPathComponent)."
    }

    func closeDocument() {
        persistSidebarPreferenceIfNeeded()
        document = nil
        documentURL = nil
        annotations = []
        selectedAnnotationID = nil
        activeEditor = nil
        placementTool = nil
        searchResults = []
        searchText = ""
        showToolbarSearch = false
        pageText = "1"
        currentPageIndex = 0
        pdfView?.document = nil
        applySidebarPreference(.defaultReading)
        statusMessage = "Open a PDF to begin."
    }

    func saveDocument() {
        guard let document else { return }

        if let url = documentURL {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "Overwrite Original PDF?"
            alert.informativeText = "Annotations will be written directly into \(url.lastPathComponent). Use Save As to create a separate annotated copy."
            alert.addButton(withTitle: "Save")
            alert.addButton(withTitle: "Cancel")
            guard alert.runModal() == .alertFirstButtonReturn else { return }

            write(document, to: url)
        } else {
            saveDocumentAs()
        }
    }

    func saveDocumentAs() {
        guard let document else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.canCreateDirectories = true
        panel.title = "Save Annotated PDF"
        panel.nameFieldStringValue = suggestedAnnotatedFilename()

        guard panel.runModal() == .OK, let url = panel.url else { return }
        write(document, to: url)
        documentURL = url
        persistSidebarPreferenceIfNeeded()
    }

    func shareDocument() {
        guard let document else { return }
        guard let url = documentURL else {
            saveDocumentAs()
            return
        }

        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "Share Annotated PDF?"
        alert.informativeText = "Save annotations to \(url.lastPathComponent) before sharing so recipients see the latest comments."
        alert.addButton(withTitle: "Save and Share")
        alert.addButton(withTitle: "Share Existing File")
        alert.addButton(withTitle: "Cancel")

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            guard document.write(to: url) else {
                showAlert(title: "Save Failed", message: "The PDF could not be written to \(url.path).")
                return
            }
            refreshAnnotations()
        case .alertSecondButtonReturn:
            break
        default:
            return
        }

        presentSharePicker(for: url)
        statusMessage = "Ready to share \(url.lastPathComponent)."
    }

    func addHighlight() {
        addMarkup(style: .highlight, title: "Highlight Comment")
    }

    func addUnderline() {
        addMarkup(style: .underline, title: "Underline Comment")
    }

    func addComment() {
        addMarkup(style: .comment, title: "Comment")
    }

    func addFreeText() {
        guard document != nil else {
            statusMessage = "Open a PDF before adding free text."
            return
        }

        activeEditor = nil
        placementTool = .freeText
        statusMessage = "Click on the page to place free text."
    }

    func placePendingAnnotation(on page: PDFPage, near point: CGPoint) {
        guard let placementTool else { return }

        let insertion: AnnotationInsertion
        let title: String

        switch placementTool {
        case .freeText:
            insertion = AnnotationFactory.freeTextInsertion(
                on: page,
                near: point,
                text: "",
                author: AnnotationFactory.defaultAuthor
            )
            title = "Free Text"
        }

        self.placementTool = nil
        add(insertion)
        refreshAnnotations()
        openEditor(
            title: title,
            annotations: [insertion.annotation],
            pages: [page],
            isNew: true
        )
    }

    func addReply(to item: AnnotationSnapshot) {
        let insertion = AnnotationFactory.replyInsertion(
            to: item.annotation,
            on: item.page,
            comment: "",
            author: AnnotationFactory.defaultAuthor,
            parentID: item.id
        )
        add(insertion)
        refreshAnnotations()
        openEditor(
            title: "Reply",
            annotations: [insertion.annotation],
            pages: [item.page],
            isNew: true
        )
    }

    func edit(_ item: AnnotationSnapshot) {
        openEditor(
            title: item.kind == .freeText ? "Edit Free Text" : "Edit Comment",
            annotations: [item.annotation],
            pages: [item.page],
            isNew: false
        )
    }

    func delete(_ item: AnnotationSnapshot) {
        let targets = annotations.filter { candidate in
            candidate.id == item.id || candidate.parentID == item.id
        }
        let targetIDs = Set(targets.map(\.id))

        for target in targets {
            removeAnnotation(target.annotation, from: target.page)
        }

        if selectedAnnotationID.map(targetIDs.contains) == true {
            selectedAnnotationID = nil
        }
        if hoveredAnnotationID.map(targetIDs.contains) == true {
            hoveredAnnotationID = nil
        }

        activeEditor = nil
        refreshAnnotations()
        statusMessage = targets.count > 1 ? "Comment thread deleted." : "Comment deleted."
    }

    func toggleReviewed(_ item: AnnotationSnapshot) {
        let isReviewed = ReviewState.isReviewed(item.status)
        let nextState = isReviewed ? "Unmarked" : "Marked"
        let date = Date()

        item.annotation.modificationDate = date
        _ = item.annotation.setValue(date, forAnnotationKey: .date)
        _ = item.annotation.setValue(nextState, forAnnotationKey: AnnotationKeys.state)
        _ = item.annotation.setValue("Marked", forAnnotationKey: AnnotationKeys.stateModel)

        if let popup = item.annotation.popup {
            popup.modificationDate = date
        }

        pdfView?.annotationsChanged(on: item.page)
        refreshAnnotations()
        statusMessage = isReviewed ? "Marked as not reviewed." : "Marked as reviewed."
    }

    func saveEditor(
        _ context: AnnotationEditorContext,
        text: String,
        author: String
    ) {
        updateAnnotations(in: context, text: text, author: author)
        refreshAnnotations()
        activeEditor = nil
        statusMessage = "Comment saved."
    }

    func updateEditorDraft(
        _ context: AnnotationEditorContext,
        text: String,
        author: String
    ) {
        guard activeEditor?.id == context.id else { return }
        updateAnnotations(in: context, text: text, author: author)
        refreshAnnotations()
    }

    func deleteAnnotations(in context: AnnotationEditorContext) {
        for (index, annotation) in context.annotations.enumerated() {
            guard index < context.pages.count else { continue }
            removeAnnotation(annotation, from: context.pages[index])
        }

        activeEditor = nil
        selectedAnnotationID = nil
        refreshAnnotations()
        statusMessage = "Annotation deleted."
    }

    func select(_ item: AnnotationSnapshot) {
        clearHoveredAnnotation()
        clearHighlightedAnnotation()
        selectedAnnotationID = item.id
        item.annotation.isHighlighted = true
        pdfView?.go(to: item.bounds.insetBy(dx: -24, dy: -24), on: item.page)
        pdfView?.annotationsChanged(on: item.page)
        statusMessage = "\(item.kind.displayName) on page \(item.pageLabel)."
    }

    func setCommentHover(_ item: AnnotationSnapshot, isHovered: Bool) {
        if isHovered {
            clearHoveredAnnotation(except: item.id)
            hoveredAnnotationID = item.id
            item.annotation.isHighlighted = true
            pdfView?.annotationsChanged(on: item.page)
            return
        }

        guard hoveredAnnotationID == item.id else { return }
        hoveredAnnotationID = nil
        guard selectedAnnotationID != item.id else { return }
        item.annotation.isHighlighted = false
        pdfView?.annotationsChanged(on: item.page)
    }

    func openAnnotationFromPDF(_ annotation: PDFAnnotation, page: PDFPage) {
        let parent = AnnotationFactory.parentAnnotation(for: annotation)
        let targetPage = parent.page ?? page
        let pageIndex = document?.index(for: targetPage) ?? 0
        let annotationIndex = targetPage.annotations.firstIndex(where: { $0 === parent }) ?? 0
        let id = AnnotationKeys.stableID(
            for: parent,
            pageIndex: pageIndex,
            annotationIndex: annotationIndex
        )
        if let item = annotations.first(where: { $0.id == id }) {
            select(item)
            edit(item)
        } else {
            openEditor(
                title: "Edit Comment",
                annotations: [parent],
                pages: [targetPage],
                isNew: false
            )
        }
    }

    func refreshAnnotations() {
        guard let document else {
            annotations = []
            return
        }
        annotations = AnnotationReader.snapshots(in: document)
    }

    func runSearch() {
        guard let document else { return }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            searchResults = []
            pdfView?.highlightedSelections = nil
            statusMessage = "Search cleared."
            return
        }

        let results = document.findString(query, withOptions: [.caseInsensitive, .diacriticInsensitive])
        for result in results {
            result.color = NSColor.findHighlightColor.withAlphaComponent(0.45)
        }
        searchResults = results
        pdfView?.highlightedSelections = results
        currentSearchIndex = 0
        goToSearchResult(at: currentSearchIndex)
        statusMessage = results.isEmpty ? "No matches for \(query)." : "\(results.count) search matches."
    }

    func showSearch() {
        guard document != nil else { return }
        showToolbarSearch = true
        statusMessage = "Search ready."
        DispatchQueue.main.async { [weak self] in
            self?.focusToolbarSearchField()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.focusToolbarSearchField()
        }
    }

    func hideSearch() {
        showToolbarSearch = false
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            searchResults = []
            pdfView?.highlightedSelections = nil
        }
    }

    func nextSearchResult() {
        guard !searchResults.isEmpty else { return }
        currentSearchIndex = (currentSearchIndex + 1) % searchResults.count
        goToSearchResult(at: currentSearchIndex)
    }

    func previousSearchResult() {
        guard !searchResults.isEmpty else { return }
        currentSearchIndex = (currentSearchIndex - 1 + searchResults.count) % searchResults.count
        goToSearchResult(at: currentSearchIndex)
    }

    func zoomIn() {
        pdfView?.autoScales = false
        pdfView?.zoomIn(nil)
    }

    func zoomOut() {
        pdfView?.autoScales = false
        pdfView?.zoomOut(nil)
    }

    func fitWidth() {
        pdfView?.displayMode = .singlePageContinuous
        pdfView?.autoScales = true
        statusMessage = "Fit to width."
    }

    func fitPage() {
        pdfView?.displayMode = .singlePage
        pdfView?.autoScales = true
        statusMessage = "Fit to page."
    }

    func twoPageContinuous() {
        pdfView?.displayMode = .twoUpContinuous
        pdfView?.displayDirection = .vertical
        pdfView?.displaysAsBook = false
        pdfView?.autoScales = true
        statusMessage = "Two pages continuous."
    }

    func goToPageFromField() {
        guard let document,
              let target = Int(pageText.trimmingCharacters(in: .whitespacesAndNewlines)),
              target >= 1,
              target <= document.pageCount,
              let page = document.page(at: target - 1)
        else {
            updateCurrentPageState()
            return
        }

        navigate(to: page, pageIndex: target - 1)
    }

    func goToPreviousPage() {
        guard let document, let currentPage = pdfView?.currentPage else { return }
        let index = document.index(for: currentPage)
        guard index != NSNotFound, index > 0, let page = document.page(at: index - 1) else {
            updateCurrentPageState()
            return
        }

        navigate(to: page, pageIndex: index - 1)
    }

    func goToNextPage() {
        guard let document, let currentPage = pdfView?.currentPage else { return }
        let index = document.index(for: currentPage)
        guard index != NSNotFound,
              index + 1 < document.pageCount,
              let page = document.page(at: index + 1)
        else {
            updateCurrentPageState()
            return
        }

        navigate(to: page, pageIndex: index + 1)
    }

    func toggleFullScreen() {
        NSApp.keyWindow?.toggleFullScreen(nil)
    }

    func minimizeWindow() {
        NSApp.keyWindow?.miniaturize(nil)
    }

    private func addMarkup(style: MarkupAnnotationStyle, title: String) {
        guard let selection = pdfView?.currentSelection, !selection.pages.isEmpty else {
            statusMessage = style == .comment
                ? "Select text before adding a comment."
                : "Select text before adding a markup annotation."
            return
        }

        let insertions = AnnotationFactory.markupInsertions(
            from: selection,
            style: style,
            comment: "",
            author: AnnotationFactory.defaultAuthor
        )
        guard !insertions.isEmpty else {
            statusMessage = "No selectable text was found in the selection."
            return
        }

        for insertion in insertions {
            add(insertion)
        }
        pdfView?.clearSelection()
        refreshAnnotations()
        openEditor(
            title: title,
            annotations: insertions.map(\.annotation),
            pages: insertions.map(\.page),
            isNew: true
        )
    }

    private func add(_ insertion: AnnotationInsertion) {
        insertion.page.addAnnotation(insertion.annotation)
        if let popup = insertion.popup {
            insertion.page.addAnnotation(popup)
        }
        pdfView?.annotationsChanged(on: insertion.page)
    }

    private func updateAnnotations(
        in context: AnnotationEditorContext,
        text: String,
        author: String
    ) {
        let trimmedAuthor = author.trimmingCharacters(in: .whitespacesAndNewlines)
        let authorValue = trimmedAuthor.isEmpty ? AnnotationFactory.defaultAuthor : trimmedAuthor

        for (index, annotation) in context.annotations.enumerated() {
            guard index < context.pages.count else { continue }
            let page = context.pages[index]
            let popup = AnnotationFactory.updateComment(
                for: annotation,
                on: page,
                text: text,
                author: authorValue
            )
            if let popup {
                page.addAnnotation(popup)
            }
            pdfView?.annotationsChanged(on: page)
        }
    }

    private func removeAnnotation(_ annotation: PDFAnnotation, from page: PDFPage) {
        let linkedPopups = page.annotations.filter { candidate in
            guard AnnotationKeys.annotation(candidate, hasSubtype: .popup) else { return false }
            return candidate === annotation.popup || AnnotationFactory.parentAnnotation(for: candidate) === annotation
        }

        for popup in linkedPopups {
            page.removeAnnotation(popup)
        }
        if let popup = annotation.popup, popup.page != nil {
            page.removeAnnotation(popup)
        }

        page.removeAnnotation(annotation)
        pdfView?.annotationsChanged(on: page)
    }

    private func openEditor(
        title: String,
        annotations: [PDFAnnotation],
        pages: [PDFPage],
        isNew: Bool
    ) {
        closeNativePopups(on: pages)
        let first = annotations.first
        activeEditor = AnnotationEditorContext(
            title: title,
            annotations: annotations,
            pages: pages,
            isNewAnnotation: isNew,
            allowsDelete: true,
            initialText: first?.contents ?? "",
            initialAuthor: first?.userName ?? AnnotationFactory.defaultAuthor
        )
    }

    private func closeNativePopups(on pages: [PDFPage]) {
        for page in pages {
            for annotation in page.annotations {
                if AnnotationKeys.annotation(annotation, hasSubtype: .popup) {
                    annotation.isOpen = false
                }
                annotation.popup?.isOpen = false
            }
            pdfView?.annotationsChanged(on: page)
        }
    }

    private func configure(_ view: PDFView) {
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.displaysPageBreaks = true
        view.pageBreakMargins = NSEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)
        view.displayBox = .cropBox
        view.autoScales = true
        view.minScaleFactor = 0.25
        view.maxScaleFactor = 6
        view.interpolationQuality = .high
        view.backgroundColor = NSColor.controlBackgroundColor
        view.acceptsDraggedFiles = true
        view.pageShadowsEnabled = true
    }

    private func write(_ document: PDFDocument, to url: URL) {
        guard document.write(to: url) else {
            showAlert(title: "Save Failed", message: "The PDF could not be written to \(url.path).")
            return
        }
        refreshAnnotations()
        statusMessage = "Saved \(url.lastPathComponent)."
    }

    private func presentSharePicker(for url: URL) {
        guard let contentView = NSApp.keyWindow?.contentView else { return }

        let anchor = NSRect(
            x: contentView.bounds.maxX - 24,
            y: contentView.bounds.maxY - 24,
            width: 1,
            height: 1
        )
        let picker = NSSharingServicePicker(items: [url])
        picker.show(relativeTo: anchor, of: contentView, preferredEdge: .minY)
    }

    private func suggestedAnnotatedFilename() -> String {
        guard let url = documentURL else { return "Annotated.pdf" }
        let base = url.deletingPathExtension().lastPathComponent
        return "\(base)-annotated.pdf"
    }

    private func goToSearchResult(at index: Int) {
        guard searchResults.indices.contains(index), let pdfView else { return }
        let selection = searchResults[index]
        pdfView.setCurrentSelection(selection, animate: true)
        pdfView.go(to: selection)
    }

    private func navigate(to page: PDFPage, pageIndex: Int) {
        guard let pdfView else { return }

        let bounds = page.bounds(for: pdfView.displayBox)
        let topSlice = NSRect(
            x: bounds.minX,
            y: bounds.maxY - 1,
            width: bounds.width,
            height: 1
        )
        pdfView.go(to: topSlice, on: page)
        pdfView.setNeedsDisplay(pdfView.bounds)

        currentPageIndex = pageIndex
        pageText = "\(pageIndex + 1)"
    }

    private func updateCurrentPageState() {
        guard let document, let currentPage = pdfView?.currentPage else { return }
        let index = document.index(for: currentPage)
        guard index != NSNotFound else { return }
        currentPageIndex = index
        pageText = "\(index + 1)"
    }

    private func clearHighlightedAnnotation() {
        guard let selectedAnnotationID,
              let previous = annotations.first(where: { $0.id == selectedAnnotationID })
        else {
            return
        }
        previous.annotation.isHighlighted = false
        pdfView?.annotationsChanged(on: previous.page)
    }

    private func clearHoveredAnnotation(except keptID: String? = nil) {
        guard let hoveredAnnotationID,
              hoveredAnnotationID != keptID,
              hoveredAnnotationID != selectedAnnotationID,
              let previous = annotations.first(where: { $0.id == hoveredAnnotationID })
        else {
            return
        }

        previous.annotation.isHighlighted = false
        pdfView?.annotationsChanged(on: previous.page)
        self.hoveredAnnotationID = nil
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func focusToolbarSearchField() {
        guard let window = NSApp.keyWindow,
              let root = window.contentView?.superview,
              let field = findSearchField(in: root)
        else {
            return
        }

        window.makeFirstResponder(field)
        field.selectText(nil)
    }

    private func findSearchField(in view: NSView) -> NSTextField? {
        if let field = view as? NSTextField,
           field.placeholderString == "Search" {
            return field
        }

        for subview in view.subviews {
            if let field = findSearchField(in: subview) {
                return field
            }
        }

        return nil
    }

    private func applySidebarPreferenceForCurrentDocument() {
        guard let documentURL else {
            applySidebarPreference(.defaultReading)
            return
        }

        let preference = AppDefaults.sidebarPreference(
            for: sidebarPreferenceKey(for: documentURL, bucket: sidebarWidthBucket)
        ) ?? .defaultReading
        applySidebarPreference(preference)
    }

    private func applySidebarPreference(_ preference: SidebarPreference) {
        isApplyingSidebarPreference = true
        showLeftSidebar = preference.showLeftSidebar
        showCommentsSidebar = preference.showCommentsSidebar
        isApplyingSidebarPreference = false
    }

    private func persistSidebarPreferenceIfNeeded() {
        guard !isApplyingSidebarPreference,
              let documentURL
        else {
            return
        }

        let preference = SidebarPreference(
            showLeftSidebar: showLeftSidebar,
            showCommentsSidebar: showCommentsSidebar
        )
        AppDefaults.setSidebarPreference(
            preference,
            for: sidebarPreferenceKey(for: documentURL, bucket: sidebarWidthBucket)
        )
    }

    private func sidebarPreferenceKey(for url: URL, bucket: SidebarWidthBucket) -> String {
        let documentKey = url.isFileURL ? url.standardizedFileURL.path : url.absoluteString
        return "\(documentKey)#\(bucket.rawValue)"
    }
}
