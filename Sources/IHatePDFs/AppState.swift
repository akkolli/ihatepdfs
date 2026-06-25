import AppKit
import Foundation
import IHatePDFsCore
import PDFKit
import SwiftUI
import UniformTypeIdentifiers

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
    let hadUnsavedChangesBeforeCreation: Bool
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
            clearSelectedAnnotationIfHiddenBySidebarState()
        }
    }
    @Published var showCommentsSidebar = false {
        didSet {
            persistSidebarPreferenceIfNeeded()
            if !showCommentsSidebar {
                clearHoveredAnnotation()
            }
            clearSelectedAnnotationIfHiddenBySidebarState()
        }
    }
    @Published var sidebarMode: SidebarMode = .pages {
        didSet { clearSelectedAnnotationIfHiddenBySidebarState() }
    }
    @Published var searchText = "" {
        didSet { clearSearchResultsForEditedQuery() }
    }
    @Published var showToolbarSearch = false
    @Published var searchResults: [PDFSelection] = []
    @Published var hasTextSelection = false
    @Published var currentSearchIndex = 0
    @Published var pageText = "1"
    @Published var currentPageIndex = 0
    @Published var commentSearchText = "" {
        didSet { clearCommentReviewHighlightsHiddenBySidebarVisibility() }
    }
    @Published var commentFilter: CommentFilter = .all {
        didSet { clearCommentReviewHighlightsHiddenBySidebarVisibility() }
    }
    @Published var selectedKindFilter: AcademicAnnotationKind? {
        didSet { clearCommentReviewHighlightsHiddenBySidebarVisibility() }
    }
    @Published var selectedAuthorFilter = "All Authors" {
        didSet { clearCommentReviewHighlightsHiddenBySidebarVisibility() }
    }
    @Published var selectedStatusFilter = ReviewState.allStatuses {
        didSet { clearCommentReviewHighlightsHiddenBySidebarVisibility() }
    }
    @Published var collapsedPageIndexes: Set<Int> = [] {
        didSet { clearCommentReviewHighlightsHiddenBySidebarVisibility() }
    }
    @Published var sidebarReplyParentID: String?
    @Published var sidebarReplyTargetID: String?
    @Published var sidebarReplyDraft = ""
    @Published var sidebarReplyAuthor = AnnotationFactory.defaultAuthor
    @Published var hasUnsavedChanges = false
    @Published var statusMessage = "Open a PDF to begin."

    private var pageObserver: NSObjectProtocol?
    private var selectionObserver: NSObjectProtocol?
    private var sidebarWidthBucket: SidebarWidthBucket = .regular
    private var isApplyingSidebarPreference = false
    private var hoveredAnnotationID: String?
    private var activeSearchQuery: String?

    var displayTitle: String {
        documentURL?.lastPathComponent ?? "I Hate PDFs"
    }

    var pageCount: Int {
        document?.pageCount ?? 0
    }

    var canGoToPreviousPage: Bool {
        document != nil && currentPageIndex > 0
    }

    var canGoToNextPage: Bool {
        document != nil && currentPageIndex + 1 < pageCount
    }

    var hasUnsavedWork: Bool {
        hasUnsavedChanges || hasSidebarReplyDraft
    }

    var hasUnsentSidebarReplyDraft: Bool {
        hasSidebarReplyDraft
    }

    var canSaveDocument: Bool {
        document != nil && hasUnsavedChanges
    }

    var saveHelpText: String {
        guard document != nil else { return "Open a PDF before saving." }
        if hasUnsavedChanges { return "Save PDF" }
        if hasSidebarReplyDraft { return "Send or cancel the reply draft before saving." }
        return "No Unsaved Changes"
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
        let query = commentSearchText.trimmingCharacters(in: .whitespacesAndNewlines)

        return annotations.filter { item in
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
        let filtered = filteredAnnotations
        let matchingTopLevelIDs = Set(filtered.filter { !$0.isReply }.map(\.id))
        let matchingReplyParentIDs = Set(filtered.compactMap { item in
            item.isReply ? item.parentID : nil
        })

        return annotations.filter { item in
            !item.isReply
                && (matchingTopLevelIDs.contains(item.id) || matchingReplyParentIDs.contains(item.id))
        }
    }

    var repliesByParent: [String: [AnnotationSnapshot]] {
        Dictionary(
            grouping: filteredAnnotations.filter { $0.isReply && $0.hasComment },
            by: \.parentID!
        )
    }

    var sidebarReplyTarget: AnnotationSnapshot? {
        guard let sidebarReplyTargetID else { return nil }
        return annotations.first { $0.id == sidebarReplyTargetID }
    }

    func clearCommentFilters() {
        commentSearchText = ""
        commentFilter = .all
        selectedKindFilter = nil
        selectedAuthorFilter = "All Authors"
        selectedStatusFilter = ReviewState.allStatuses
        statusMessage = "Comment filters cleared."
    }

    private func resetCommentReviewState() {
        commentSearchText = ""
        commentFilter = .all
        selectedKindFilter = nil
        selectedAuthorFilter = "All Authors"
        selectedStatusFilter = ReviewState.allStatuses
        collapsedPageIndexes = []
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
                guard let self else { return }
                self.updateTextSelectionState()
                guard self.placementTool == nil, self.hasTextSelection else { return }
                self.statusMessage = "Selection ready for annotation."
            }
        }
        updateTextSelectionState()
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

    @discardableResult
    func openDroppedDocument(from providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first(where: {
            $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
        }) else {
            statusMessage = "Drop a PDF file to open it."
            return false
        }

        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { [weak self] item, error in
            let url = Self.fileURL(fromDroppedItem: item)

            Task { @MainActor in
                guard let self else { return }

                if error != nil {
                    self.statusMessage = "The dropped file could not be opened."
                    return
                }

                guard let url else {
                    self.statusMessage = "Drop a PDF file to open it."
                    return
                }

                guard PDFFileSelection.isPDFFileURL(url) else {
                    self.showAlert(title: "Unsupported File", message: "Drop a PDF file to open it.")
                    return
                }

                self.loadDocument(from: url)
            }
        }

        return true
    }

    nonisolated private static func fileURL(fromDroppedItem item: NSSecureCoding?) -> URL? {
        if let url = item as? URL, url.isFileURL {
            return url
        }

        if let url = item as? NSURL {
            let bridgedURL = url as URL
            return bridgedURL.isFileURL ? bridgedURL : nil
        }

        if let data = item as? Data,
           let url = URL(dataRepresentation: data, relativeTo: nil),
           url.isFileURL {
            return url
        }

        if let string = item as? String,
           let url = URL(string: string),
           url.isFileURL {
            return url
        }

        return nil
    }

    func loadDocument(from url: URL, checkingUnsavedChanges: Bool = true) {
        if checkingUnsavedChanges {
            guard confirmDiscardOrSaveUnsavedChanges(actionName: "opening another PDF") else { return }
        }

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
        clearSearchState()
        resetCommentReviewState()
        selectedAnnotationID = nil
        activeEditor = nil
        placementTool = nil
        hasTextSelection = false
        hasUnsavedChanges = false
        clearSidebarReplyDraft()
        refreshAnnotations()
        statusMessage = "Opened \(url.lastPathComponent)."
    }

    func closeDocument() {
        guard confirmDiscardOrSaveUnsavedChanges(actionName: "closing this PDF") else { return }

        persistSidebarPreferenceIfNeeded()
        document = nil
        documentURL = nil
        annotations = []
        selectedAnnotationID = nil
        activeEditor = nil
        placementTool = nil
        hasTextSelection = false
        hasUnsavedChanges = false
        clearSidebarReplyDraft()
        clearSearchState()
        resetCommentReviewState()
        pageText = "1"
        currentPageIndex = 0
        pdfView?.document = nil
        applySidebarPreference(.defaultReading)
        statusMessage = "Open a PDF to begin."
    }

    func confirmDocumentWindowClose() -> Bool {
        guard confirmDiscardOrSaveUnsavedChanges(actionName: "closing this window") else {
            return false
        }

        persistSidebarPreferenceIfNeeded()
        return true
    }

    func confirmApplicationQuit() -> Bool {
        guard confirmDiscardOrSaveUnsavedChanges(actionName: "quitting the app") else {
            return false
        }

        persistSidebarPreferenceIfNeeded()
        return true
    }

    func saveDocument() {
        _ = saveDocument(confirmOverwrite: true, confirmReplyDraft: true)
    }

    @discardableResult
    private func saveDocument(confirmOverwrite: Bool, confirmReplyDraft: Bool) -> Bool {
        guard let document else { return false }
        let discardedEmptyEditor = discardEmptyActiveEditorBeforeWritingIfNeeded()

        if confirmReplyDraft {
            guard confirmSaveWithoutSidebarReplyDraft() else { return false }
        }

        if let url = documentURL {
            guard hasUnsavedChanges else {
                if !discardedEmptyEditor {
                    statusMessage = "No unsaved changes."
                }
                return true
            }

            if confirmOverwrite {
                let alert = NSAlert()
                alert.alertStyle = .warning
                alert.messageText = "Overwrite Original PDF?"
                alert.informativeText = "Annotations will be written directly into \(url.lastPathComponent). Use Save As to create a separate annotated copy."
                alert.addButton(withTitle: "Save")
                alert.addButton(withTitle: "Cancel")
                guard alert.runModal() == .alertFirstButtonReturn else { return false }
            }

            return write(document, to: url)
        } else {
            return saveDocumentAs(confirmReplyDraft: confirmReplyDraft)
        }
    }

    @discardableResult
    func saveDocumentAs() -> Bool {
        saveDocumentAs(confirmReplyDraft: true)
    }

    @discardableResult
    private func saveDocumentAs(confirmReplyDraft: Bool) -> Bool {
        guard let document else { return false }
        _ = discardEmptyActiveEditorBeforeWritingIfNeeded()

        if confirmReplyDraft {
            guard confirmSaveWithoutSidebarReplyDraft() else { return false }
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.canCreateDirectories = true
        panel.title = "Save Annotated PDF"
        panel.nameFieldStringValue = suggestedAnnotatedFilename()

        guard panel.runModal() == .OK, let url = panel.url else { return false }
        guard write(document, to: url) else { return false }
        documentURL = url
        persistSidebarPreferenceIfNeeded()
        return true
    }

    func shareDocument() {
        guard let document else { return }
        guard confirmShareWithoutSidebarReplyDraft() else { return }
        _ = discardEmptyActiveEditorBeforeWritingIfNeeded()

        var shareURL = documentURL

        if shareURL == nil {
            guard saveDocumentAs(confirmReplyDraft: false), let url = documentURL else { return }
            shareURL = url
        }

        guard let url = shareURL else { return }

        guard hasUnsavedChanges else {
            presentSharePicker(for: url)
            statusMessage = "Ready to share \(url.lastPathComponent)."
            return
        }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Save Before Sharing?"
        alert.informativeText = "This PDF has unsaved annotations. Save them to \(url.lastPathComponent) before sharing, or share the last saved version without the latest changes."
        alert.addButton(withTitle: "Save and Share")
        alert.addButton(withTitle: "Share Last Saved Version")
        alert.addButton(withTitle: "Cancel")

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            guard write(document, to: url) else { return }
        case .alertSecondButtonReturn:
            statusMessage = "Sharing last saved version; unsaved annotations remain open."
            break
        default:
            return
        }

        presentSharePicker(for: url)
        statusMessage = "Ready to share \(url.lastPathComponent)."
    }

    func addHighlight() {
        addMarkup(style: .highlight, title: "Highlight", opensEditor: false)
    }

    func addUnderline() {
        addMarkup(style: .underline, title: "Underline Comment", opensEditor: true)
    }

    func addComment() {
        addMarkup(style: .comment, title: "Comment", opensEditor: true)
    }

    func addFreeText() {
        guard document != nil else {
            statusMessage = "Open a PDF before adding free text."
            return
        }

        activeEditor = nil
        placementTool = .freeText
        pdfView?.window?.makeFirstResponder(pdfView)
        statusMessage = "Click on the page to place free text."
    }

    func cancelPlacementTool() {
        guard placementTool != nil else { return }

        placementTool = nil
        statusMessage = "Free text placement canceled."
    }

    func placePendingAnnotation(on page: PDFPage, near point: CGPoint) {
        guard let placementTool else { return }

        let insertion: AnnotationInsertion
        let title: String
        let hadUnsavedChangesBeforeCreation = hasUnsavedChanges

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
        refreshAnnotations(on: [page])
        openEditor(
            title: title,
            annotations: [insertion.annotation],
            pages: [page],
            isNew: true,
            hadUnsavedChangesBeforeCreation: hadUnsavedChangesBeforeCreation
        )
    }

    func addReply(to item: AnnotationSnapshot) {
        beginSidebarReply(to: item)
    }

    func beginSidebarReply(
        to target: AnnotationSnapshot,
        inThread threadRoot: AnnotationSnapshot? = nil
    ) {
        guard let root = threadRoot ?? rootComment(for: target) else {
            statusMessage = "Original comment no longer exists."
            return
        }

        if hasSidebarReplyDraft {
            guard sidebarReplyParentID == root.id,
                  sidebarReplyTargetID == target.id
            else {
                showCommentsSidebar = true
                statusMessage = "Finish or cancel the current reply before starting another."
                return
            }

            showCommentsSidebar = true
            select(target, statusMessage: "Reply draft is already open.")
            return
        }

        activeEditor = nil
        showCommentsSidebar = true
        sidebarReplyParentID = root.id
        sidebarReplyTargetID = target.id
        sidebarReplyDraft = ""
        sidebarReplyAuthor = AnnotationFactory.defaultAuthor
        select(target, statusMessage: "Replying to \(target.author).")
    }

    func cancelSidebarReply() {
        clearSidebarReplyDraft()
        statusMessage = "Reply canceled."
    }

    func commitSidebarReply() {
        let trimmedText = sidebarReplyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            statusMessage = "Type a reply before saving."
            return
        }

        guard let sidebarReplyParentID,
              let parent = annotations.first(where: { $0.id == sidebarReplyParentID })
        else {
            clearSidebarReplyDraft()
            statusMessage = "Original comment no longer exists."
            return
        }

        let author = sidebarReplyAuthor.trimmingCharacters(in: .whitespacesAndNewlines)
        let insertion = AnnotationFactory.replyInsertion(
            to: parent.annotation,
            on: parent.page,
            comment: trimmedText,
            author: author.isEmpty ? AnnotationFactory.defaultAuthor : author,
            parentID: parent.id
        )
        add(insertion)
        clearSidebarReplyDraft()
        refreshAnnotations(on: [parent.page])

        if let reply = annotations.first(where: { $0.annotation === insertion.annotation }) {
            selectedAnnotationID = reply.id
        }
        statusMessage = "Reply added."
    }

    func replyFromEditor(
        _ context: AnnotationEditorContext,
        text: String,
        author: String
    ) {
        updateAnnotations(in: context, text: text, author: author)
        refreshAnnotations(on: context.pages)

        guard let annotation = context.primaryAnnotation,
              let item = snapshot(for: annotation)
        else {
            activeEditor = nil
            showCommentsSidebar = true
            statusMessage = "Comment saved."
            return
        }

        activeEditor = nil
        beginSidebarReply(to: item)
    }

    func edit(_ item: AnnotationSnapshot) {
        select(item, statusMessage: "Editing \(item.kind.displayName.lowercased()) on page \(item.pageLabel).")
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
        let targetPages = targets.map(\.page)

        guard confirmDiscardSidebarReplyDraftIfNeeded(
            deleting: targetIDs,
            actionName: targets.count > 1 ? "deleting this comment thread" : "deleting this comment"
        ) else {
            return
        }

        for target in targets {
            removeAnnotation(target.annotation, from: target.page)
        }

        if selectedAnnotationID.map(targetIDs.contains) == true {
            selectedAnnotationID = nil
        }
        if hoveredAnnotationID.map(targetIDs.contains) == true {
            hoveredAnnotationID = nil
        }
        clearSidebarReplyDraftIfNeeded(deleting: targetIDs)

        activeEditor = nil
        refreshAnnotations(on: targetPages)
        statusMessage = targets.count > 1 ? "Comment thread deleted." : "Comment deleted."
    }

    func toggleReviewed(_ item: AnnotationSnapshot) {
        select(item, statusMessage: "\(item.kind.displayName) on page \(item.pageLabel).")
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

        hasUnsavedChanges = true
        pdfView?.annotationsChanged(on: item.page)
        refreshAnnotations(on: [item.page])
        statusMessage = isReviewed ? "Marked as not reviewed." : "Marked as reviewed."
    }

    func saveEditor(
        _ context: AnnotationEditorContext,
        text: String,
        author: String
    ) {
        if shouldDiscardEmptyNewAnnotation(context, text: text) {
            let discardedMessage = context.annotations.contains {
                AcademicAnnotationKind(annotation: $0) == .freeText
            } ? "Empty free text discarded." : "Empty comment discarded."
            deleteAnnotations(in: context)
            statusMessage = discardedMessage
            return
        }

        updateAnnotations(in: context, text: text, author: author)
        refreshAnnotations(on: context.pages)
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
        refreshAnnotations(on: context.pages)
    }

    func deleteAnnotations(in context: AnnotationEditorContext) {
        let contextAnnotations = Set(context.annotations.map(ObjectIdentifier.init))
        let contextSnapshots = annotations.filter { snapshot in
            contextAnnotations.contains(ObjectIdentifier(snapshot.annotation))
        }
        let contextIDs = Set(contextSnapshots.map(\.id))
        let targets = contextIDs.isEmpty
            ? contextSnapshots
            : annotations.filter { candidate in
                contextIDs.contains(candidate.id)
                    || candidate.parentID.map(contextIDs.contains) == true
            }
        let targetIDs = Set(targets.map(\.id))
        let targetPages = targets.map(\.page)

        guard confirmDiscardSidebarReplyDraftIfNeeded(
            deleting: targetIDs,
            actionName: targets.count > 1 ? "deleting this comment thread" : "deleting this annotation"
        ) else {
            return
        }

        if targets.isEmpty {
            for (index, annotation) in context.annotations.enumerated() {
                guard index < context.pages.count else { continue }
                removeAnnotation(annotation, from: context.pages[index])
            }
        } else {
            for target in targets {
                removeAnnotation(target.annotation, from: target.page)
            }
        }

        activeEditor = nil
        if targetIDs.isEmpty || selectedAnnotationID.map(targetIDs.contains) == true {
            selectedAnnotationID = nil
        }
        if hoveredAnnotationID.map(targetIDs.contains) == true {
            hoveredAnnotationID = nil
        }
        clearSidebarReplyDraftIfNeeded(deleting: targetIDs)
        refreshAnnotations(on: targetPages.isEmpty ? context.pages : targetPages)
        if context.isNewAnnotation {
            hasUnsavedChanges = context.hadUnsavedChangesBeforeCreation
        }
        statusMessage = targets.count > 1 ? "Comment thread deleted." : "Annotation deleted."
    }

    func select(_ item: AnnotationSnapshot) {
        select(item, statusMessage: "\(item.kind.displayName) on page \(item.pageLabel).")
    }

    private func select(_ item: AnnotationSnapshot, statusMessage message: String) {
        clearHoveredAnnotation()
        clearHighlightedAnnotation()
        let visibleTarget = visibleAnnotationTarget(for: item)

        selectedAnnotationID = item.id
        visibleTarget.annotation.isHighlighted = true
        pdfView?.go(to: visibleTarget.bounds.insetBy(dx: -24, dy: -24), on: visibleTarget.page)
        pdfView?.annotationsChanged(on: visibleTarget.page)
        statusMessage = message
    }

    func setCommentHover(_ item: AnnotationSnapshot, isHovered: Bool) {
        let visibleTarget = visibleAnnotationTarget(for: item)

        if isHovered {
            clearHoveredAnnotation(except: item.id)
            hoveredAnnotationID = item.id
            visibleTarget.annotation.isHighlighted = true
            pdfView?.annotationsChanged(on: visibleTarget.page)
            return
        }

        guard hoveredAnnotationID == item.id else { return }
        hoveredAnnotationID = nil
        guard !isSelectedVisibleTarget(visibleTarget) else { return }
        visibleTarget.annotation.isHighlighted = false
        pdfView?.annotationsChanged(on: visibleTarget.page)
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

    func refreshAnnotations(on pages: [PDFPage]? = nil) {
        guard let document else {
            annotations = []
            clearSidebarReplyDraft()
            return
        }

        if let pages {
            let trackedPages = uniquePages(pages, in: document)
            guard !trackedPages.isEmpty else {
                pruneSidebarReplyDraftIfNeeded()
                return
            }

            for trackedPage in trackedPages {
                hideReplyMarkers(on: trackedPage.page)
                normalizePopupMarkers(on: trackedPage.page)
                hidePopupMarkersInViewer(on: trackedPage.page)
            }

            let updatedIndexes = Set(trackedPages.map(\.index))
            let updatedPages = trackedPages.map(\.page)
            let updatedSnapshots = AnnotationReader.snapshots(in: document, pages: updatedPages)
            annotations = AnnotationReader.sorted(
                annotations.filter { !updatedIndexes.contains($0.pageIndex) } + updatedSnapshots
            )
            pruneSidebarReplyDraftIfNeeded()
            return
        }

        hideReplyMarkers(in: document)
        normalizePopupMarkers(in: document)
        hidePopupMarkersInViewer(in: document)
        annotations = AnnotationReader.snapshots(in: document)
        pruneSidebarReplyDraftIfNeeded()
    }

    func runSearch() {
        guard let document else { return }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            clearSearchResults()
            statusMessage = "Search cleared."
            return
        }

        let results = document.findString(query, withOptions: [.caseInsensitive, .diacriticInsensitive])
        for result in results {
            result.color = NSColor.findHighlightColor.withAlphaComponent(0.45)
        }
        searchResults = results
        currentSearchIndex = 0
        activeSearchQuery = query
        guard !results.isEmpty else {
            pdfView?.highlightedSelections = nil
            statusMessage = "No matches for \(query)."
            return
        }

        pdfView?.highlightedSelections = results
        goToSearchResult(at: currentSearchIndex)
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
        clearSearchState()
        statusMessage = "Search closed."
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
        guard let document else { return }

        let pageCount = document.pageCount
        let trimmedPageText = pageText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let target = Int(trimmedPageText) else {
            updateCurrentPageState()
            statusMessage = "Enter a page number from 1 to \(pageCount)."
            return
        }

        guard target >= 1, target <= pageCount else {
            updateCurrentPageState()
            statusMessage = "Page must be between 1 and \(pageCount)."
            return
        }

        guard let page = document.page(at: target - 1) else {
            updateCurrentPageState()
            statusMessage = "Page \(target) is unavailable."
            return
        }

        navigate(to: page, pageIndex: target - 1)
    }

    func goToPreviousPage() {
        guard let document, let currentPage = pdfView?.currentPage else { return }
        let index = document.index(for: currentPage)
        guard index != NSNotFound, index > 0, let page = document.page(at: index - 1) else {
            updateCurrentPageState()
            statusMessage = "Already on the first page."
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
            statusMessage = "Already on the last page."
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

    private func addMarkup(
        style: MarkupAnnotationStyle,
        title: String,
        opensEditor: Bool
    ) {
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
            author: AnnotationFactory.defaultAuthor,
            highlightColor: AppSettings.highlightColor,
            commentColor: AppSettings.commentColor
        )
        guard !insertions.isEmpty else {
            statusMessage = "No selectable text was found in the selection."
            return
        }

        let hadUnsavedChangesBeforeCreation = hasUnsavedChanges
        for insertion in insertions {
            add(insertion)
        }
        pdfView?.clearSelection()
        updateTextSelectionState()
        refreshAnnotations(on: insertions.map(\.page))
        guard opensEditor else {
            statusMessage = "Highlighted selection."
            return
        }

        openEditor(
            title: title,
            annotations: insertions.map(\.annotation),
            pages: insertions.map(\.page),
            isNew: true,
            hadUnsavedChangesBeforeCreation: hadUnsavedChangesBeforeCreation
        )
    }

    private func add(_ insertion: AnnotationInsertion) {
        insertion.page.addAnnotation(insertion.annotation)
        if AnnotationKeys.isReply(insertion.annotation) {
            AnnotationFactory.hideReplyMarker(insertion.annotation, on: insertion.page)
        }
        detachPopupMarkerFromViewer(for: insertion.annotation, on: insertion.page)
        hasUnsavedChanges = true
        pdfView?.annotationsChanged(on: insertion.page)
    }

    private func updateTextSelectionState() {
        guard let selection = pdfView?.currentSelection,
              !selection.pages.isEmpty,
              selection.string?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        else {
            hasTextSelection = false
            return
        }

        hasTextSelection = true
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
            _ = AnnotationFactory.updateComment(
                for: annotation,
                on: page,
                text: text,
                author: authorValue
            )
            detachPopupMarkerFromViewer(for: annotation, on: page)
            hasUnsavedChanges = true
            pdfView?.annotationsChanged(on: page)
        }
    }

    private func shouldDiscardEmptyNewAnnotation(
        _ context: AnnotationEditorContext,
        text: String
    ) -> Bool {
        guard context.isNewAnnotation,
              !context.annotations.isEmpty,
              text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return false
        }

        return context.annotations.allSatisfy { annotation in
            let kind = AcademicAnnotationKind(annotation: annotation)
            return kind == .comment || kind == .freeText
        }
    }

    @discardableResult
    private func discardEmptyActiveEditorBeforeWritingIfNeeded() -> Bool {
        guard let context = activeEditor else { return false }

        let text = context.annotations
            .map(AnnotationKeys.commentText(for:))
            .joined(separator: "\n")
        guard shouldDiscardEmptyNewAnnotation(context, text: text) else { return false }

        deleteAnnotations(in: context)
        statusMessage = context.annotations.contains {
            AcademicAnnotationKind(annotation: $0) == .freeText
        } ? "Empty free text discarded." : "Empty comment discarded."
        return true
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
        hasUnsavedChanges = true
        pdfView?.annotationsChanged(on: page)
    }

    private func openEditor(
        title: String,
        annotations: [PDFAnnotation],
        pages: [PDFPage],
        isNew: Bool,
        hadUnsavedChangesBeforeCreation: Bool = false
    ) {
        closeNativePopups(on: pages)
        let first = annotations.first
        activeEditor = AnnotationEditorContext(
            title: title,
            annotations: annotations,
            pages: pages,
            isNewAnnotation: isNew,
            hadUnsavedChangesBeforeCreation: hadUnsavedChangesBeforeCreation,
            allowsDelete: true,
            initialText: first.map(AnnotationKeys.commentText(for:)) ?? "",
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

    private func rootComment(for target: AnnotationSnapshot) -> AnnotationSnapshot? {
        guard let parentID = target.parentID else { return target }
        return annotations.first { $0.id == parentID }
    }

    private func snapshot(for annotation: PDFAnnotation) -> AnnotationSnapshot? {
        annotations.first { $0.annotation === annotation }
    }

    private func visibleAnnotationTarget(for item: AnnotationSnapshot) -> AnnotationSnapshot {
        guard let parentID = item.parentID,
              let parent = annotations.first(where: { $0.id == parentID })
        else {
            return item
        }

        return parent
    }

    private func isSelectedVisibleTarget(_ candidate: AnnotationSnapshot) -> Bool {
        guard let selectedAnnotationID,
              let selected = annotations.first(where: { $0.id == selectedAnnotationID })
        else {
            return false
        }

        return visibleAnnotationTarget(for: selected).id == candidate.id
    }

    private func clearCommentReviewHighlightsHiddenBySidebarVisibility() {
        clearHoveredAnnotation()
        clearSelectedAnnotationIfHiddenBySidebarState()
    }

    private func clearSelectedAnnotationIfHiddenBySidebarState() {
        guard let selectedAnnotationID else { return }
        guard !visibleSidebarAnnotationIDs().contains(selectedAnnotationID) else { return }

        clearHighlightedAnnotation()
        self.selectedAnnotationID = nil
    }

    private func visibleSidebarAnnotationIDs() -> Set<String> {
        var visibleIDs = Set<String>()

        if showLeftSidebar, sidebarMode == .annotations {
            visibleIDs.formUnion(annotations.map(\.id))
        }

        guard showCommentsSidebar else {
            return visibleIDs
        }

        let visibleTopLevel = topLevelComments.filter { item in
            guard pageCount > 1,
                  !isFilteringCommentReview
            else {
                return true
            }

            return !collapsedPageIndexes.contains(item.pageIndex)
        }
        visibleIDs.formUnion(
            visibleTopLevel.map(\.id)
                + visibleTopLevel.flatMap { repliesByParent[$0.id] ?? [] }.map(\.id)
        )

        return visibleIDs
    }

    private var isFilteringCommentReview: Bool {
        !commentSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || commentFilter != .all
            || selectedKindFilter != nil
            || selectedAuthorFilter != "All Authors"
            || selectedStatusFilter != ReviewState.allStatuses
    }

    private func clearSidebarReplyDraft() {
        sidebarReplyParentID = nil
        sidebarReplyTargetID = nil
        sidebarReplyDraft = ""
        sidebarReplyAuthor = AnnotationFactory.defaultAuthor
    }

    private var hasSidebarReplyDraft: Bool {
        !sidebarReplyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func clearSidebarReplyDraftIfNeeded(deleting targetIDs: Set<String>) {
        guard sidebarReplyDraftWouldBeDiscarded(deleting: targetIDs) else { return }
        clearSidebarReplyDraft()
    }

    private func sidebarReplyDraftWouldBeDiscarded(deleting targetIDs: Set<String>) -> Bool {
        guard hasSidebarReplyDraft else { return false }
        return sidebarReplyParentID.map(targetIDs.contains) == true
            || sidebarReplyTargetID.map(targetIDs.contains) == true
    }

    private func pruneSidebarReplyDraftIfNeeded() {
        guard sidebarReplyParentID != nil || sidebarReplyTargetID != nil else { return }

        let ids = Set(annotations.map(\.id))
        guard let parentID = sidebarReplyParentID,
              ids.contains(parentID)
        else {
            clearSidebarReplyDraft()
            return
        }

        if sidebarReplyTargetID.map(ids.contains) != true {
            sidebarReplyTargetID = parentID
        }
    }

    private func uniquePages(_ pages: [PDFPage], in document: PDFDocument) -> [(page: PDFPage, index: Int)] {
        var seenIndexes = Set<Int>()

        return pages.compactMap { page in
            let index = document.index(for: page)
            guard index != NSNotFound, seenIndexes.insert(index).inserted else {
                return nil
            }
            return (page: page, index: index)
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

    @discardableResult
    private func write(_ document: PDFDocument, to url: URL) -> Bool {
        prepareAnnotationsForExport(in: document)
        guard document.write(to: url) else {
            hidePopupMarkersInViewer(in: document)
            showAlert(title: "Save Failed", message: "The PDF could not be written to \(url.path).")
            return false
        }
        refreshAnnotations()
        hasUnsavedChanges = false
        statusMessage = "Saved \(url.lastPathComponent)."
        return true
    }

    private func confirmDiscardOrSaveUnsavedChanges(actionName: String) -> Bool {
        guard confirmDiscardOrSaveAnnotationChanges(actionName: actionName) else {
            return false
        }

        return confirmDiscardSidebarReplyDraft(actionName: actionName)
    }

    private func confirmDiscardOrSaveAnnotationChanges(actionName: String) -> Bool {
        guard hasUnsavedChanges else { return true }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Save Changes?"
        if let fileName = documentURL?.lastPathComponent {
            alert.informativeText = "This PDF has unsaved annotations. Saving writes them directly into \(fileName). Save before \(actionName), discard the changes, or cancel."
        } else {
            alert.informativeText = "This PDF has unsaved annotations. Save an annotated copy before \(actionName), discard the changes, or cancel."
        }
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Discard Changes")
        alert.addButton(withTitle: "Cancel")

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            return saveDocument(confirmOverwrite: false, confirmReplyDraft: false)
        case .alertSecondButtonReturn:
            return true
        default:
            return false
        }
    }

    private func confirmDiscardSidebarReplyDraft(actionName: String) -> Bool {
        guard hasSidebarReplyDraft else { return true }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Discard Reply Draft?"
        alert.informativeText = "You have an unsent reply draft. Send it, cancel it, or discard it before \(actionName)."
        alert.addButton(withTitle: "Discard Reply Draft")
        alert.addButton(withTitle: "Cancel")

        return alert.runModal() == .alertFirstButtonReturn
    }

    private func confirmSaveWithoutSidebarReplyDraft() -> Bool {
        guard hasSidebarReplyDraft else { return true }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Save Without Reply Draft?"
        alert.informativeText = "Your sidebar reply draft has not been added to the PDF yet. Send it before saving if it should be included, or save without that draft."
        alert.addButton(withTitle: "Save Without Draft")
        alert.addButton(withTitle: "Cancel")

        return alert.runModal() == .alertFirstButtonReturn
    }

    private func confirmDiscardSidebarReplyDraftIfNeeded(
        deleting targetIDs: Set<String>,
        actionName: String
    ) -> Bool {
        guard sidebarReplyDraftWouldBeDiscarded(deleting: targetIDs) else { return true }
        return confirmDiscardSidebarReplyDraft(actionName: actionName)
    }

    private func confirmShareWithoutSidebarReplyDraft() -> Bool {
        guard hasSidebarReplyDraft else { return true }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Share Without Reply Draft?"
        alert.informativeText = "Your sidebar reply draft has not been added to the PDF yet. Send it before sharing, or share without that draft."
        alert.addButton(withTitle: "Share Without Draft")
        alert.addButton(withTitle: "Cancel")

        return alert.runModal() == .alertFirstButtonReturn
    }

    private func presentSharePicker(for url: URL) {
        guard let contentView = pdfView?.window?.contentView ?? NSApp.keyWindow?.contentView else { return }

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
        statusMessage = "Search match \(index + 1) of \(searchResults.count)."
    }

    private func clearSearchState() {
        activeSearchQuery = nil
        searchText = ""
        showToolbarSearch = false
        clearSearchResults()
    }

    private func clearSearchResults() {
        activeSearchQuery = nil
        searchResults = []
        currentSearchIndex = 0
        pdfView?.highlightedSelections = nil
    }

    private func clearSearchResultsForEditedQuery() {
        guard let activeSearchQuery,
              searchText.trimmingCharacters(in: .whitespacesAndNewlines) != activeSearchQuery
        else {
            return
        }

        clearSearchResults()
    }

    private func hideReplyMarkers(in document: PDFDocument) {
        for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex) else { continue }
            hideReplyMarkers(on: page)
        }
    }

    @discardableResult
    private func hideReplyMarkers(on page: PDFPage) -> Bool {
        var didChange = false

        for annotation in page.annotations where AnnotationKeys.isReply(annotation) {
            AnnotationFactory.hideReplyMarker(annotation, on: page)
            didChange = true
        }

        if didChange {
            pdfView?.annotationsChanged(on: page)
        }

        return didChange
    }

    private func normalizePopupMarkers(in document: PDFDocument) {
        for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex) else { continue }
            normalizePopupMarkers(on: page)
        }
    }

    @discardableResult
    private func normalizePopupMarkers(on page: PDFPage) -> Bool {
        var didChange = false

        for annotation in page.annotations where !AnnotationKeys.annotation(annotation, hasSubtype: .popup) {
            if AnnotationFactory.normalizePopupPlacement(for: annotation, on: page) {
                didChange = true
            }
        }

        if didChange {
            pdfView?.annotationsChanged(on: page)
        }

        return didChange
    }

    private func prepareAnnotationsForExport(in document: PDFDocument) {
        var changedPages = Set<PDFPage>()

        for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex) else { continue }
            for annotation in page.annotations where !AnnotationKeys.annotation(annotation, hasSubtype: .popup) {
                if AnnotationFactory.prepareForPreviewCompatibleExport(annotation, on: page) {
                    changedPages.insert(page)
                }
            }
        }

        for page in changedPages {
            pdfView?.annotationsChanged(on: page)
        }
    }

    private func hidePopupMarkersInViewer(in document: PDFDocument) {
        for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex) else { continue }
            hidePopupMarkersInViewer(on: page)
        }
    }

    @discardableResult
    private func hidePopupMarkersInViewer(on page: PDFPage) -> Bool {
        var didChange = false
        var popupsToRemove: [PDFAnnotation] = []

        for annotation in page.annotations {
            if AnnotationKeys.annotation(annotation, hasSubtype: .popup) {
                annotation.isOpen = false
                annotation.shouldDisplay = false
                annotation.shouldPrint = false
                popupsToRemove.append(annotation)
                continue
            }

            if detachPopupMarkerFromViewer(for: annotation, on: page) {
                didChange = true
            }
        }

        for popup in popupsToRemove {
            page.removeAnnotation(popup)
        }

        didChange = didChange || !popupsToRemove.isEmpty
        if didChange {
            pdfView?.annotationsChanged(on: page)
        }

        return didChange
    }

    @discardableResult
    private func detachPopupMarkerFromViewer(for annotation: PDFAnnotation, on page: PDFPage) -> Bool {
        AnnotationFactory.detachPopupForViewer(from: annotation, on: page)
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
        statusMessage = "Page \(pageIndex + 1) of \(pageCount)."
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

        let visibleTarget = visibleAnnotationTarget(for: previous)
        visibleTarget.annotation.isHighlighted = false
        pdfView?.annotationsChanged(on: visibleTarget.page)
    }

    private func clearHoveredAnnotation(except keptID: String? = nil) {
        guard let hoveredAnnotationID,
              hoveredAnnotationID != keptID
        else { return }

        defer {
            self.hoveredAnnotationID = nil
        }

        guard let previous = annotations.first(where: { $0.id == hoveredAnnotationID })
        else { return }

        let visibleTarget = visibleAnnotationTarget(for: previous)
        guard !isSelectedVisibleTarget(visibleTarget) else { return }

        visibleTarget.annotation.isHighlighted = false
        pdfView?.annotationsChanged(on: visibleTarget.page)
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
