import AppKit
import Foundation
import IHatePDFsCore
import PDFKit
import SwiftUI
import UniformTypeIdentifiers

enum SidebarMode: String, CaseIterable {
    case pages
    case annotations
    case highlights
}

enum LeftSidebarMode: String, CaseIterable, Codable {
    case pages
    case annotations
}

enum CommentFilter: String, CaseIterable {
    case all
    case withComments
    case withoutComments

    var title: String {
        switch self {
        case .all: return "All"
        case .withComments: return "With Comments"
        case .withoutComments: return "No Comment"
        }
    }
}

enum HighlightSortMode: String, CaseIterable {
    case color
    case page

    var title: String {
        switch self {
        case .color: return "Color"
        case .page: return "Page"
        }
    }

    var systemImage: String {
        switch self {
        case .color: return "paintpalette"
        case .page: return "doc.text"
        }
    }
}

enum AnnotationPlacementTool: Equatable {
    case freeText

    var cancellationMessage: String {
        switch self {
        case .freeText:
            return "Free text placement canceled."
        }
    }
}

private struct AnnotationUndoRecord {
    let annotation: PDFAnnotation
    let page: PDFPage
    let index: Int?
    let popups: [PDFAnnotation]
}

private enum AppDefaults {
    static let documentPageProgress = "IHatePDFs.documentPageProgress.v1"
    static let documentBookmarks = "IHatePDFs.documentBookmarks.v1"

    static func pageProgress(for url: URL) -> PDFRecentDocumentProgress? {
        PDFRecentDocuments.progress(for: url, in: pageProgressRecords())
    }

    static func setPageProgress(url: URL, pageIndex: Int) {
        guard let progress = PDFRecentDocuments.updatedProgress(
            pageProgressRecords(),
            url: url,
            pageIndex: pageIndex,
            openedAt: Date()
        )[PDFRecentDocuments.documentKey(for: url)] else { return }

        var records = UserDefaults.standard.dictionary(forKey: documentPageProgress) ?? [:]
        records[progress.key] = [
            "pageIndex": progress.pageIndex,
            "openedAt": progress.openedAt.timeIntervalSince1970
        ]
        UserDefaults.standard.set(records, forKey: documentPageProgress)
    }

    private static func pageProgressRecords() -> [String: PDFRecentDocumentProgress] {
        let raw = UserDefaults.standard.dictionary(forKey: documentPageProgress) ?? [:]
        var records: [String: PDFRecentDocumentProgress] = [:]
        for (key, value) in raw {
            guard let dictionary = value as? [String: Any],
                  let pageIndex = dictionary["pageIndex"] as? Int,
                  let openedAt = dictionary["openedAt"] as? TimeInterval
            else {
                continue
            }
            records[key] = PDFRecentDocumentProgress(
                key: key,
                pageIndex: pageIndex,
                openedAt: Date(timeIntervalSince1970: openedAt)
            )
        }
        return records
    }

    static func bookmarks(for url: URL) -> [PDFDocumentBookmark] {
        bookmarkRecords()[PDFRecentDocuments.documentKey(for: url)] ?? []
    }

    static func setBookmarks(_ bookmarks: [PDFDocumentBookmark], for url: URL) {
        var records = UserDefaults.standard.dictionary(forKey: documentBookmarks) ?? [:]
        records[PDFRecentDocuments.documentKey(for: url)] = bookmarks.map { bookmark in
            [
                "id": bookmark.id,
                "pageIndex": bookmark.pageIndex,
                "pageLabel": bookmark.pageLabel,
                "title": bookmark.title,
                "createdAt": bookmark.createdAt.timeIntervalSince1970
            ] as [String: Any]
        }
        UserDefaults.standard.set(records, forKey: documentBookmarks)
    }

    private static func bookmarkRecords() -> [String: [PDFDocumentBookmark]] {
        let raw = UserDefaults.standard.dictionary(forKey: documentBookmarks) ?? [:]
        var records: [String: [PDFDocumentBookmark]] = [:]
        for (key, value) in raw {
            guard let dictionaries = value as? [[String: Any]] else { continue }
            records[key] = dictionaries.compactMap { dictionary in
                guard let id = dictionary["id"] as? String,
                      let pageIndex = dictionary["pageIndex"] as? Int,
                      let pageLabel = dictionary["pageLabel"] as? String,
                      let title = dictionary["title"] as? String,
                      let createdAt = dictionary["createdAt"] as? TimeInterval
                else {
                    return nil
                }
                return PDFDocumentBookmark(
                    id: id,
                    pageIndex: pageIndex,
                    pageLabel: pageLabel,
                    title: title,
                    createdAt: Date(timeIntervalSince1970: createdAt)
                )
            }
        }
        return records
    }
}

private enum PDFReadingLayout {
    static let pageBreakMargins = NSEdgeInsets(top: 10, left: 11, bottom: 10, right: 11)
    static let minimumScaleFactor: CGFloat = 0.25
    static let maximumReadingScaleFactor: CGFloat = 4
}

struct AnnotationEditorContext: Identifiable {
    let id = UUID()
    let title: String
    let annotations: [PDFAnnotation]
    let pages: [PDFPage]
    let isNewAnnotation: Bool
    let hadUnsavedChangesBeforeCreation: Bool
    let allowsDelete: Bool
    let allowsReply: Bool
    let initialText: String
    let initialAuthor: String

    var primaryAnnotation: PDFAnnotation? { annotations.first }
    var primaryPage: PDFPage? { pages.first }
}

struct HighlightedTextGroup {
    let id: String
    let title: String
    let color: Color
    let items: [AnnotationSnapshot]
}

struct RecentDocumentItem: Identifiable, Equatable {
    let url: URL
    let pageIndex: Int?
    let openedAt: Date?

    var id: URL { url }

    var title: String {
        url.deletingPathExtension().lastPathComponent
    }

    var folderName: String {
        let parent = url.deletingLastPathComponent()
        let name = parent.lastPathComponent
        return name.isEmpty ? parent.path : name
    }

    var pageText: String? {
        pageIndex.map { "Page \($0 + 1)" }
    }
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
            clearSelectedAnnotationIfHiddenBySidebarState()
        }
    }
    @Published var leftSidebarMode: LeftSidebarMode = .pages {
        didSet {
            clearSelectedAnnotationIfHiddenBySidebarState()
        }
    }
    @Published var showCommentsSidebar = false {
        didSet {
            if showCommentsSidebar, sidebarMode == .pages {
                sidebarMode = .annotations
            }
            if !showCommentsSidebar {
                clearHoveredAnnotation()
            }
            clearSelectedAnnotationIfHiddenBySidebarState()
        }
    }
    @Published var sidebarMode: SidebarMode = .annotations {
        didSet { clearSelectedAnnotationIfHiddenBySidebarState() }
    }
    @Published var searchText = "" {
        didSet { clearSearchResultsForEditedQuery() }
    }
    @Published var showToolbarSearch = false
    @Published var searchResults: [PDFSelection] = []
    @Published private(set) var toolbarSearchFocusRequest = 0
    @Published var hasTextSelection = false
    @Published var isHighlighterModeActive = false
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
    @Published var highlightSortMode: HighlightSortMode = .color
    @Published var collapsedPageIndexes: Set<Int> = [] {
        didSet { clearCommentReviewHighlightsHiddenBySidebarVisibility() }
    }
    @Published var sidebarReplyParentID: String?
    @Published var sidebarReplyTargetID: String?
    @Published var sidebarReplyDraft = ""
    @Published var sidebarReplyAuthor = AnnotationFactory.defaultAuthor
    @Published var bookmarks: [PDFDocumentBookmark] = []
    @Published var recentDocumentURLs: [URL] = []
    @Published private(set) var readerSizeClass: ReaderAdaptiveLayout.SizeClass = .regular
    @Published var hasUnsavedChanges = false
    @Published var statusMessage = "Open a PDF to begin."

    private var pageObserver: NSObjectProtocol?
    private var selectionObserver: NSObjectProtocol?
    private var hoveredAnnotationID: String?
    private var activeSearchQuery: String?
    private var pendingInitialPageIndex: Int?
    weak var hostingWindow: NSWindow?

    override init() {
        super.init()
        refreshRecentDocuments()
    }

    deinit {
        MainActor.assumeIsolated {
            removePDFViewObservers()
        }
    }

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

    var isCommentsReviewVisible: Bool {
        showCommentsSidebar && sidebarMode == .annotations
    }

    var isCompactWindow: Bool {
        readerSizeClass == .compact
    }

    var canShowSelectionActions: Bool {
        document != nil
            && hasTextSelection
            && placementTool == nil
            && activeEditor == nil
            && !isHighlighterModeActive
    }

    var canCancelActiveMode: Bool {
        placementTool != nil || isHighlighterModeActive
    }

    var canClearSearchQuery: Bool {
        !searchText.isEmpty || !searchResults.isEmpty
    }

    var canDeleteSelectedAnnotation: Bool {
        activeEditor == nil
            && selectedAnnotationID != nil
            && annotations.contains { $0.id == selectedAnnotationID }
    }

    var canUndoAnnotationChange: Bool {
        annotationUndoManager?.canUndo == true
    }

    var canRedoAnnotationChange: Bool {
        annotationUndoManager?.canRedo == true
    }

    var searchSummaryText: String? {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return nil }

        if searchResults.isEmpty {
            return activeSearchQuery == query ? "No match" : nil
        }

        let displayIndex = min(max(currentSearchIndex, 0), searchResults.count - 1) + 1
        return "\(displayIndex)/\(searchResults.count)"
    }

    var canSaveDocument: Bool {
        document != nil && hasUnsavedWork
    }

    var activePlacementName: String? {
        switch placementTool {
        case .freeText:
            return "Free Text"
        case nil:
            return nil
        }
    }

    var saveHelpText: String {
        guard document != nil else { return "Open a PDF before saving." }
        if hasUnsavedChanges { return "Save PDF" }
        if hasSidebarReplyDraft { return "Send or cancel the reply draft before saving." }
        return "No unsaved changes."
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

    private var annotationUndoManager: UndoManager? {
        pdfView?.undoManager ?? hostingWindow?.undoManager
    }

    var currentPageBookmark: PDFDocumentBookmark? {
        PDFDocumentBookmarks.bookmark(on: currentPageIndex, in: bookmarks)
    }

    var savedBookmark: PDFDocumentBookmark? {
        bookmarks.first
    }

    var bookmarkActionTitle: String {
        if currentPageBookmark != nil {
            return "Remove Bookmark"
        }
        if savedBookmark != nil {
            return "Move Bookmark"
        }
        return "Add Bookmark"
    }

    var bookmarkActionHelpText: String {
        if currentPageBookmark != nil {
            return "Remove Bookmark"
        }
        if savedBookmark != nil {
            return "Move Bookmark to Current Page"
        }
        return "Bookmark Current Page"
    }

    var highlightedTextGroups: [HighlightedTextGroup] {
        let grouped = Dictionary(grouping: highlightedTextItems) { highlightColorKey(for: $0) }

        return grouped
            .map { key, items in
                HighlightedTextGroup(
                    id: key,
                    title: highlightColorTitle(for: key),
                    color: Color(nsColor: AppSettings.displayColor(forHighlightColor: highlightColor(for: key))),
                    items: AnnotationReader.sorted(items)
                )
            }
            .sorted { left, right in
                if left.title != right.title {
                    return left.title < right.title
                }
                return left.id < right.id
            }
    }

    var highlightedTextItems: [AnnotationSnapshot] {
        AnnotationReader.sorted(annotations.filter { $0.kind == .highlight })
    }

    var recentDocuments: [RecentDocumentItem] {
        recentDocumentURLs.map { url in
            let progress = AppDefaults.pageProgress(for: url)
            return RecentDocumentItem(
                url: url,
                pageIndex: progress?.pageIndex,
                openedAt: progress?.openedAt
            )
        }
    }

    var filteredAnnotations: [AnnotationSnapshot] {
        let query = commentSearchText.trimmingCharacters(in: .whitespacesAndNewlines)

        return annotations.filter { item in
            guard isCommentReviewItem(item) else { return false }

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

        removePDFViewObservers()
        pdfView = view
        configure(view)
        view.document = document
        if let pendingInitialPageIndex, let document {
            goToInitialPage(pendingInitialPageIndex, in: document)
            fitOpenedDocumentToScreen()
            animateDocumentViewIn()
        }

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
                guard !self.isHighlighterModeActive else { return }
                guard self.placementTool == nil, self.hasTextSelection else { return }
                self.statusMessage = "Selection ready for annotation."
            }
        }
        updateTextSelectionState()
    }

    private func removePDFViewObservers() {
        if let pageObserver {
            NotificationCenter.default.removeObserver(pageObserver)
            self.pageObserver = nil
        }

        if let selectionObserver {
            NotificationCenter.default.removeObserver(selectionObserver)
            self.selectionObserver = nil
        }
    }

    func updateWindowWidth(_ width: CGFloat) {
        guard width.isFinite, width > 0 else { return }

        let sizeClass = ReaderAdaptiveLayout.SizeClass(width: width)
        guard sizeClass != readerSizeClass else { return }

        readerSizeClass = sizeClass
        enforceCompactSidebarRules()
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

    func loadDocument(
        from url: URL,
        checkingUnsavedChanges: Bool = true
    ) {
        if checkingUnsavedChanges {
            guard confirmDiscardOrSaveUnsavedChanges(actionName: "opening another PDF") else { return }
        }

        guard let pdf = PDFDocument(url: url) else {
            showAlert(title: "Unable to Open PDF", message: "The selected file could not be opened as a PDF.")
            return
        }

        resetToFocusedReadingLayout()
        document = pdf
        documentURL = url
        NSDocumentController.shared.noteNewRecentDocumentURL(url)
        refreshRecentDocuments()
        refreshBookmarks(for: url, pageCount: pdf.pageCount)
        let restoredPageIndex = PDFRecentDocuments.clampedPageIndex(
            AppDefaults.pageProgress(for: url)?.pageIndex,
            pageCount: pdf.pageCount
        )
        prepareDocumentViewForOpenAnimation()
        pdfView?.document = pdf
        goToInitialPage(restoredPageIndex, in: pdf)
        fitOpenedDocumentToScreen()
        clearSearchState()
        resetCommentReviewState()
        selectedAnnotationID = nil
        activeEditor = nil
        placementTool = nil
        isHighlighterModeActive = false
        hasTextSelection = false
        hasUnsavedChanges = false
        clearSidebarReplyDraft()
        refreshAnnotations()
        animateDocumentViewIn()
        statusMessage = "Opened \(url.lastPathComponent)."
    }

    func refreshRecentDocuments() {
        recentDocumentURLs = PDFRecentDocuments.filteredPDFs(
            from: NSDocumentController.shared.recentDocumentURLs,
            currentURL: documentURL,
            limit: 10
        )
    }

    func openRecentDocument(_ url: URL) {
        guard PDFFileSelection.isPDFFileURL(url) else {
            showAlert(title: "Unsupported File", message: "Choose a PDF file.")
            refreshRecentDocuments()
            return
        }

        guard FileManager.default.fileExists(atPath: url.path) else {
            showAlert(title: "File Not Found", message: "\(url.lastPathComponent) is no longer available.")
            refreshRecentDocuments()
            return
        }

        loadDocument(from: url)
    }

    func clearRecentDocuments() {
        NSDocumentController.shared.clearRecentDocuments(nil)
        refreshRecentDocuments()
        statusMessage = "Recent PDFs cleared."
    }

    func addBookmark() {
        guard let document, let documentURL else {
            statusMessage = "Open a PDF before adding a bookmark."
            return
        }

        let isMovingExistingBookmark = savedBookmark != nil
        let pageLabel = document.page(at: currentPageIndex)?.label ?? "\(currentPageIndex + 1)"
        let bookmark = PDFDocumentBookmark(
            pageIndex: currentPageIndex,
            pageLabel: pageLabel,
            title: "Page \(pageLabel)"
        )
        bookmarks = PDFDocumentBookmarks.upsert(bookmark, in: bookmarks)
        AppDefaults.setBookmarks(bookmarks, for: documentURL)
        statusMessage = isMovingExistingBookmark
            ? "Moved bookmark to page \(pageLabel)."
            : "Bookmarked page \(pageLabel)."
    }

    func removeBookmark(_ bookmark: PDFDocumentBookmark) {
        guard let documentURL else { return }
        bookmarks = PDFDocumentBookmarks.removing(id: bookmark.id, from: bookmarks)
        AppDefaults.setBookmarks(bookmarks, for: documentURL)
        statusMessage = "Bookmark removed."
    }

    func toggleBookmarkForCurrentPage() {
        if let bookmark = currentPageBookmark {
            removeBookmark(bookmark)
        } else {
            addBookmark()
        }
    }

    func togglePageSidebar() {
        if showLeftSidebar {
            showLeftSidebar = false
            return
        }

        if isCompactWindow {
            showCommentsSidebar = false
        }
        leftSidebarMode = .pages
        showLeftSidebar = true
    }

    func toggleAnnotationSidebar() {
        if showLeftSidebar && leftSidebarMode == .annotations {
            showLeftSidebar = false
            return
        }

        if isCompactWindow {
            showCommentsSidebar = false
        }
        leftSidebarMode = .annotations
        showLeftSidebar = true
    }

    func toggleLeftSidebar(mode: SidebarMode) {
        guard mode != .pages else {
            togglePageSidebar()
            return
        }

        toggleRightSidebar(mode: mode)
    }

    func toggleRightSidebar(mode: SidebarMode = .annotations) {
        let targetMode = mode == .pages ? .annotations : mode
        if showCommentsSidebar {
            hideRightSidebar()
            return
        }

        if isCompactWindow {
            showLeftSidebar = false
        }
        sidebarMode = targetMode
        showCommentsSidebar = true
    }

    func toggleRightSidebarVisibility() {
        if showCommentsSidebar {
            hideRightSidebar()
            return
        }

        showRightSidebar(mode: sidebarMode)
    }

    func toggleCommentsReview() {
        toggleRightSidebarVisibility()
    }

    func hideRightSidebar() {
        showCommentsSidebar = false
        if !ReaderAdaptiveLayout(sizeClass: readerSizeClass).allowsDualSidebars {
            showLeftSidebar = false
        }
    }

    func showRightSidebar(mode: SidebarMode = .annotations) {
        if isCompactWindow {
            showLeftSidebar = false
        }
        sidebarMode = mode == .pages ? .annotations : mode
        showCommentsSidebar = true
    }

    func selectHighlightColor(_ color: NSColor, applyToSelection: Bool) {
        AppSettings.highlightColor = color
        isHighlighterModeActive = true
        if applyToSelection {
            addHighlight()
        } else {
            statusMessage = "Highlighter on. Select text to highlight."
        }
    }

    func goToBookmark(_ bookmark: PDFDocumentBookmark) {
        guard let document,
              let page = document.page(at: bookmark.pageIndex)
        else {
            statusMessage = "Bookmark page is unavailable."
            return
        }

        navigate(to: page, pageIndex: bookmark.pageIndex)
        statusMessage = "Bookmark: \(bookmark.title)."
    }

    func goToSavedBookmark() {
        guard let bookmark = savedBookmark else {
            statusMessage = "No bookmarks."
            return
        }
        goToBookmark(bookmark)
    }

    func confirmDocumentWindowClose() -> Bool {
        guard confirmDiscardOrSaveUnsavedChanges(actionName: "closing this window") else {
            return false
        }

        persistCurrentPageProgress()
        return true
    }

    func confirmApplicationQuit() -> Bool {
        guard confirmDiscardOrSaveUnsavedChanges(actionName: "quitting the app") else {
            return false
        }

        persistCurrentPageProgress()
        return true
    }

    func closeDocument() {
        guard document != nil else {
            statusMessage = "No PDF is open."
            return
        }

        guard confirmDiscardOrSaveUnsavedChanges(actionName: "closing this PDF") else {
            return
        }

        persistCurrentPageProgress()
        clearOpenDocumentState()
        refreshRecentDocuments()
        statusMessage = "Closed PDF."
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

    func addHighlightFromHighlighterMode() {
        addMarkup(style: .highlight, title: "Highlight", opensEditor: false)
    }

    func toggleHighlighterMode() {
        guard document != nil else {
            statusMessage = "Open a PDF before highlighting."
            return
        }

        isHighlighterModeActive.toggle()
        guard isHighlighterModeActive else {
            statusMessage = "Highlighter off."
            return
        }

        if hasTextSelection {
            addHighlightFromHighlighterMode()
        } else {
            pdfView?.window?.makeFirstResponder(pdfView)
            statusMessage = "Highlighter on. Select text to highlight."
        }
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
        guard let placementTool else { return }

        self.placementTool = nil
        statusMessage = placementTool.cancellationMessage
    }

    @discardableResult
    func cancelActiveMode() -> Bool {
        var messages: [String] = []

        if let placementTool {
            self.placementTool = nil
            messages.append(placementTool.cancellationMessage)
        }

        if isHighlighterModeActive {
            isHighlighterModeActive = false
            messages.append("Highlighter off.")
        }

        guard !messages.isEmpty else { return false }
        statusMessage = messages.joined(separator: " ")
        return true
    }

    func placePendingAnnotation(on page: PDFPage, near point: CGPoint) {
        guard let placementTool else { return }

        let insertion: AnnotationInsertion
        let hadUnsavedChangesBeforeCreation = hasUnsavedChanges

        switch placementTool {
        case .freeText:
            insertion = AnnotationFactory.freeTextInsertion(
                on: page,
                near: point,
                text: "",
                author: AnnotationFactory.defaultAuthor
            )
        }

        self.placementTool = nil
        let record = add(insertion)
        registerUndoToRemoveAnnotations([record], actionName: "Add Free Text")
        refreshAnnotations(on: [page])
        openEditor(
            title: "Free Text",
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
                showRightSidebar()
                statusMessage = "Finish or cancel the current reply before starting another."
                return
            }

            showRightSidebar()
            select(target, statusMessage: "Reply draft is already open.")
            return
        }

        activeEditor = nil
        showRightSidebar()
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
        let record = add(insertion)
        registerUndoToRemoveAnnotations([record], actionName: "Add Reply")
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
            showRightSidebar()
            statusMessage = "Comment saved."
            return
        }

        activeEditor = nil
        beginSidebarReply(to: item)
    }

    func edit(_ item: AnnotationSnapshot) {
        let editorTitle = item.kind == .freeText ? "Edit Free Text" : "Edit Comment"
        select(item, statusMessage: "Editing \(item.kind.displayName.lowercased()) on page \(item.pageLabel).")
        openEditor(
            title: editorTitle,
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
        let actionName = deleteActionName(for: item, targetCount: targets.count)

        guard confirmDiscardSidebarReplyDraftIfNeeded(
            deleting: targetIDs,
            actionName: deletingActionPhrase(for: item, targetCount: targets.count)
        ) else {
            return
        }

        let records = annotationUndoRecords(for: targets)
        for target in targets {
            removeAnnotation(target.annotation, from: target.page)
        }
        registerUndoToRestoreAnnotations(records, actionName: actionName)

        if selectedAnnotationID.map(targetIDs.contains) == true {
            selectedAnnotationID = nil
        }
        if hoveredAnnotationID.map(targetIDs.contains) == true {
            hoveredAnnotationID = nil
        }
        clearSidebarReplyDraftIfNeeded(deleting: targetIDs)

        activeEditor = nil
        refreshAnnotations(on: targetPages)
        statusMessage = deleteStatusMessage(for: item, targetCount: targets.count)
    }

    func deleteSelectedAnnotation() {
        guard activeEditor == nil else { return }
        guard let selectedAnnotationID,
              let item = annotations.first(where: { $0.id == selectedAnnotationID })
        else {
            statusMessage = "Select an annotation before deleting."
            return
        }

        delete(item)
    }

    func undoAnnotationChange() {
        annotationUndoManager?.undo()
    }

    func redoAnnotationChange() {
        annotationUndoManager?.redo()
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
        let representative = targets.first ?? contextSnapshots.first
        let actionName = representative.map {
            deleteActionName(for: $0, targetCount: targets.isEmpty ? context.annotations.count : targets.count)
        } ?? "Delete Annotation"

        guard confirmDiscardSidebarReplyDraftIfNeeded(
            deleting: targetIDs,
            actionName: representative.map {
                deletingActionPhrase(for: $0, targetCount: targets.isEmpty ? context.annotations.count : targets.count)
            } ?? "deleting this annotation"
        ) else {
            return
        }

        let records = targets.isEmpty
            ? annotationUndoRecords(for: context.annotations, pages: context.pages)
            : annotationUndoRecords(for: targets)

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
        registerUndoToRestoreAnnotations(records, actionName: actionName)

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
        statusMessage = representative.map {
            deleteStatusMessage(for: $0, targetCount: targets.isEmpty ? context.annotations.count : targets.count)
        } ?? "Annotation deleted."
    }

    func select(_ item: AnnotationSnapshot) {
        select(item, statusMessage: "\(item.kind.displayName) on page \(item.pageLabel).")
    }

    func selectHighlightedText(_ item: AnnotationSnapshot) {
        select(item, statusMessage: "Highlight on page \(item.pageLabel).")
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

    private func refreshBookmarks(for url: URL, pageCount: Int) {
        bookmarks = PDFDocumentBookmarks.clamped(
            AppDefaults.bookmarks(for: url),
            pageCount: pageCount
        )
        AppDefaults.setBookmarks(bookmarks, for: url)
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
            pdfView?.clearSelection()
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
        requestSearchFieldFocus()
    }

    private func requestSearchFieldFocus() {
        guard showToolbarSearch else { return }
        toolbarSearchFocusRequest += 1
    }

    func hideSearch() {
        clearSearchState()
        statusMessage = "Search closed."
    }

    func clearSearchQuery() {
        searchText = ""
        clearSearchResults()
        statusMessage = "Search cleared."
        requestSearchFieldFocus()
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
        guard let pdfView else { return }
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.displaysAsBook = false
        pdfView.autoScales = true
        pdfView.layoutDocumentView()
        statusMessage = "Fit to width."
    }

    func fitPage() {
        guard let pdfView else { return }
        pdfView.displayMode = .singlePage
        pdfView.displaysAsBook = false
        pdfView.autoScales = true
        pdfView.layoutDocumentView()
        statusMessage = "Fit to page."
    }

    func twoPageContinuous() {
        guard let pdfView else { return }
        pdfView.displayMode = .twoUpContinuous
        pdfView.displayDirection = .vertical
        pdfView.displaysAsBook = false
        pdfView.autoScales = true
        pdfView.layoutDocumentView()
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
        var records: [AnnotationUndoRecord] = []
        for insertion in insertions {
            records.append(add(insertion))
        }
        registerUndoToRemoveAnnotations(records, actionName: addActionName(for: style))
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
        switch style {
        case .highlight:
            statusMessage = "Highlighted selection."
        case .comment:
            statusMessage = "Adding comment to selection."
        case .underline:
            statusMessage = "Adding underline comment."
        }
    }

    @discardableResult
    private func add(_ insertion: AnnotationInsertion) -> AnnotationUndoRecord {
        insertion.page.addAnnotation(insertion.annotation)
        if AnnotationKeys.isReply(insertion.annotation) {
            AnnotationFactory.hideReplyMarker(insertion.annotation, on: insertion.page)
        }
        detachPopupMarkerFromViewer(for: insertion.annotation, on: insertion.page)
        hasUnsavedChanges = true
        pdfView?.annotationsChanged(on: insertion.page)
        return annotationUndoRecord(for: insertion.annotation, on: insertion.page)
    }

    private func registerUndoToRemoveAnnotations(
        _ records: [AnnotationUndoRecord],
        actionName: String
    ) {
        guard !records.isEmpty, let undoManager = annotationUndoManager else { return }

        undoManager.registerUndo(withTarget: self) { target in
            target.removeAnnotationsForUndo(records, actionName: actionName)
        }
        undoManager.setActionName(actionName)
    }

    private func registerUndoToRestoreAnnotations(
        _ records: [AnnotationUndoRecord],
        actionName: String
    ) {
        guard !records.isEmpty, let undoManager = annotationUndoManager else { return }

        undoManager.registerUndo(withTarget: self) { target in
            target.restoreAnnotationsForUndo(records, actionName: actionName)
        }
        undoManager.setActionName(actionName)
    }

    private func removeAnnotationsForUndo(
        _ records: [AnnotationUndoRecord],
        actionName: String
    ) {
        registerUndoToRestoreAnnotations(records, actionName: actionName)
        clearStateForRemovedAnnotations(records.map(\.annotation))
        for record in records {
            removeAnnotation(record.annotation, from: record.page)
        }
        activeEditor = nil
        refreshAnnotations(on: records.map(\.page))
        statusMessage = "Annotation change undone."
    }

    private func restoreAnnotationsForUndo(
        _ records: [AnnotationUndoRecord],
        actionName: String
    ) {
        registerUndoToRemoveAnnotations(records, actionName: actionName)
        for record in sortedUndoRecordsForRestore(records) {
            restoreAnnotation(record)
        }
        activeEditor = nil
        refreshAnnotations(on: records.map(\.page))
        statusMessage = "Annotation change restored."
    }

    private func annotationUndoRecords(for targets: [AnnotationSnapshot]) -> [AnnotationUndoRecord] {
        uniqueUndoRecords(targets.map { annotationUndoRecord(for: $0.annotation, on: $0.page) })
    }

    private func annotationUndoRecords(
        for annotations: [PDFAnnotation],
        pages: [PDFPage]
    ) -> [AnnotationUndoRecord] {
        let records = annotations.enumerated().compactMap { index, annotation -> AnnotationUndoRecord? in
            guard index < pages.count else { return nil }
            return annotationUndoRecord(for: annotation, on: pages[index])
        }
        return uniqueUndoRecords(records)
    }

    private func annotationUndoRecord(
        for annotation: PDFAnnotation,
        on page: PDFPage
    ) -> AnnotationUndoRecord {
        AnnotationUndoRecord(
            annotation: annotation,
            page: page,
            index: page.annotations.firstIndex { $0 === annotation },
            popups: linkedPopups(for: annotation, on: page)
        )
    }

    private func uniqueUndoRecords(_ records: [AnnotationUndoRecord]) -> [AnnotationUndoRecord] {
        var seen = Set<ObjectIdentifier>()
        var result: [AnnotationUndoRecord] = []
        for record in records {
            let id = ObjectIdentifier(record.annotation)
            guard seen.insert(id).inserted else { continue }
            result.append(record)
        }
        return result
    }

    private func sortedUndoRecordsForRestore(_ records: [AnnotationUndoRecord]) -> [AnnotationUndoRecord] {
        records.sorted { left, right in
            switch (left.index, right.index) {
            case let (leftIndex?, rightIndex?):
                return leftIndex < rightIndex
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            case (nil, nil):
                return false
            }
        }
    }

    private func restoreAnnotation(_ record: AnnotationUndoRecord) {
        if record.annotation.page !== record.page {
            record.page.addAnnotation(record.annotation)
        }

        for popup in record.popups where popup.page == nil {
            record.page.addAnnotation(popup)
        }

        moveAnnotation(record.annotation, on: record.page, to: record.index)
        detachPopupMarkerFromViewer(for: record.annotation, on: record.page)
        hasUnsavedChanges = true
        pdfView?.annotationsChanged(on: record.page)
    }

    private func moveAnnotation(_ annotation: PDFAnnotation, on page: PDFPage, to index: Int?) {
        guard let index,
              index >= 0,
              index < page.annotations.count - 1
        else {
            return
        }

        let tail = page.annotations.dropFirst(index).filter { $0 !== annotation }
        for annotation in tail {
            page.removeAnnotation(annotation)
        }
        for annotation in tail {
            page.addAnnotation(annotation)
        }
    }

    private func clearStateForRemovedAnnotations(_ removedAnnotations: [PDFAnnotation]) {
        let removed = Set(removedAnnotations.map(ObjectIdentifier.init))
        let removedIDs = Set(annotations.compactMap { snapshot in
            removed.contains(ObjectIdentifier(snapshot.annotation)) ? snapshot.id : nil
        })

        if selectedAnnotationID.map(removedIDs.contains) == true {
            selectedAnnotationID = nil
        }
        if hoveredAnnotationID.map(removedIDs.contains) == true {
            hoveredAnnotationID = nil
        }
        clearSidebarReplyDraftIfNeeded(deleting: removedIDs)
    }

    private func addActionName(for style: MarkupAnnotationStyle) -> String {
        switch style {
        case .highlight:
            return "Add Highlight"
        case .comment:
            return "Add Comment"
        case .underline:
            return "Add Underline Comment"
        }
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

    private func replaceAnnotation(
        _ annotation: PDFAnnotation,
        with replacement: PDFAnnotation,
        on page: PDFPage
    ) {
        let insertionIndex = page.annotations.firstIndex { $0 === annotation }
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
        page.addAnnotation(replacement)
        if let insertionIndex,
           insertionIndex < page.annotations.count - 1 {
            let tail = page.annotations.dropFirst(insertionIndex).filter { $0 !== replacement }
            for annotation in tail {
                page.removeAnnotation(annotation)
            }
            for annotation in tail {
                page.addAnnotation(annotation)
            }
        }
        detachPopupMarkerFromViewer(for: replacement, on: page)
        hasUnsavedChanges = true
        pdfView?.annotationsChanged(on: page)
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

    private func deleteActionName(for item: AnnotationSnapshot, targetCount: Int) -> String {
        "Delete \(deleteNounTitle(for: item, targetCount: targetCount))"
    }

    private func deletingActionPhrase(for item: AnnotationSnapshot, targetCount: Int) -> String {
        "deleting this \(deleteNounSentence(for: item, targetCount: targetCount))"
    }

    private func deleteStatusMessage(for item: AnnotationSnapshot, targetCount: Int) -> String {
        "\(deleteNounTitle(for: item, targetCount: targetCount)) deleted."
    }

    private func deleteNounTitle(for item: AnnotationSnapshot, targetCount: Int) -> String {
        if targetCount > 1 {
            return "Comment Thread"
        }

        switch item.kind {
        case .comment:
            return "Comment"
        case .highlight:
            return "Highlight"
        case .underline:
            return "Underline Comment"
        case .note:
            return "Note"
        case .freeText:
            return "Free Text"
        case .reply:
            return "Reply"
        case .other:
            return "Annotation"
        }
    }

    private func deleteNounSentence(for item: AnnotationSnapshot, targetCount: Int) -> String {
        deleteNounTitle(for: item, targetCount: targetCount).lowercased()
    }

    private func removeAnnotation(_ annotation: PDFAnnotation, from page: PDFPage) {
        for popup in linkedPopups(for: annotation, on: page) {
            page.removeAnnotation(popup)
        }

        page.removeAnnotation(annotation)
        hasUnsavedChanges = true
        pdfView?.annotationsChanged(on: page)
    }

    private func linkedPopups(for annotation: PDFAnnotation, on page: PDFPage) -> [PDFAnnotation] {
        var seen = Set<ObjectIdentifier>()
        var popups = page.annotations.filter { candidate in
            guard AnnotationKeys.annotation(candidate, hasSubtype: .popup) else { return false }
            return candidate === annotation.popup || AnnotationFactory.parentAnnotation(for: candidate) === annotation
        }

        if let popup = annotation.popup {
            popups.append(popup)
        }

        return popups.filter { popup in
            seen.insert(ObjectIdentifier(popup)).inserted
        }
    }

    private func openEditor(
        title: String,
        annotations: [PDFAnnotation],
        pages: [PDFPage],
        isNew: Bool,
        hadUnsavedChangesBeforeCreation: Bool = false,
        allowsReply: Bool = true
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
            allowsReply: allowsReply,
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

    private func isCommentReviewItem(_ item: AnnotationSnapshot) -> Bool {
        if item.kind == .highlight, !item.hasComment {
            return false
        }
        return item.isReply ? item.hasComment : true
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

        if showLeftSidebar, leftSidebarMode == .annotations {
            visibleIDs.formUnion(annotations.map(\.id))
        }

        guard showCommentsSidebar else {
            return visibleIDs
        }

        switch sidebarMode {
        case .highlights:
            visibleIDs.formUnion(annotations.filter { $0.kind == .highlight }.map(\.id))
            return visibleIDs
        case .pages:
            return visibleIDs
        case .annotations:
            break
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

    private func highlightColorKey(for item: AnnotationSnapshot) -> String {
        AnnotationColorPreference.storageString(
            for: item.annotation.color,
            fallback: AppSettings.defaultHighlightColorStorageValue
        )
    }

    private func highlightColor(for key: String) -> NSColor {
        AnnotationColorPreference.color(
            from: key,
            fallback: AcademicAnnotationPalette.highlight,
            minimumAlpha: 0.38
        )
    }

    private func highlightColorTitle(for key: String) -> String {
        let selected = highlightColor(for: key)
        let selectedStorage = AppSettings.storageString(forHighlightColor: selected)
        for swatch in AppSettings.highlightSwatches {
            if AppSettings.storageString(forHighlightColor: swatch.color) == selectedStorage {
                return swatch.name
            }
        }
        return "Custom"
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
        view.pageBreakMargins = PDFReadingLayout.pageBreakMargins
        view.displayBox = .cropBox
        view.autoScales = true
        view.minScaleFactor = PDFReadingLayout.minimumScaleFactor
        view.maxScaleFactor = PDFReadingLayout.maximumReadingScaleFactor
        view.interpolationQuality = .high
        view.backgroundColor = NSColor.underPageBackgroundColor
        view.acceptsDraggedFiles = false
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
        pdfView?.clearSelection()
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
        persistCurrentPageProgress()
        statusMessage = "Page \(pageIndex + 1) of \(pageCount)."
    }

    private func goToInitialPage(_ pageIndex: Int, in document: PDFDocument) {
        let targetIndex = PDFRecentDocuments.clampedPageIndex(pageIndex, pageCount: document.pageCount)
        guard let page = document.page(at: targetIndex), let pdfView else {
            pendingInitialPageIndex = targetIndex
            currentPageIndex = targetIndex
            pageText = "\(targetIndex + 1)"
            return
        }

        pendingInitialPageIndex = nil
        let bounds = page.bounds(for: pdfView.displayBox)
        let topSlice = NSRect(x: bounds.minX, y: bounds.maxY - 1, width: bounds.width, height: 1)
        pdfView.go(to: topSlice, on: page)
        pdfView.setNeedsDisplay(pdfView.bounds)
        currentPageIndex = targetIndex
        pageText = "\(targetIndex + 1)"
        persistCurrentPageProgress()
    }

    private func updateCurrentPageState() {
        guard let document, let currentPage = pdfView?.currentPage else { return }
        let index = document.index(for: currentPage)
        guard index != NSNotFound else { return }
        currentPageIndex = index
        pageText = "\(index + 1)"
        persistCurrentPageProgress()
    }

    private func persistCurrentPageProgress() {
        guard let documentURL, document != nil else { return }
        AppDefaults.setPageProgress(url: documentURL, pageIndex: currentPageIndex)
    }

    private func fitOpenedDocumentToScreen() {
        applyOpenFitToView()
        DispatchQueue.main.async { [weak self] in
            self?.applyOpenFitToView()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) { [weak self] in
            self?.applyOpenFitToView()
        }
    }

    private func applyOpenFitToView() {
        guard let pdfView, pdfView.document != nil else { return }
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.displaysAsBook = false
        pdfView.autoScales = true
        pdfView.layoutDocumentView()
    }

    private func prepareDocumentViewForOpenAnimation() {
        guard let pdfView else { return }
        pdfView.wantsLayer = true
        pdfView.alphaValue = 0
    }

    private func animateDocumentViewIn() {
        guard let pdfView else { return }
        pdfView.wantsLayer = true
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            pdfView.animator().alphaValue = 1
        }
    }

    private func animateDocumentViewOut(completion: @escaping () -> Void) {
        guard let pdfView else {
            completion()
            return
        }

        pdfView.wantsLayer = true
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            pdfView.animator().alphaValue = 0
        } completionHandler: {
            pdfView.alphaValue = 1
            completion()
        }
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

    private func resetToFocusedReadingLayout() {
        leftSidebarMode = .pages
        sidebarMode = .annotations
        showLeftSidebar = false
        showCommentsSidebar = false
        enforceCompactSidebarRules()
    }

    private func clearOpenDocumentState() {
        selectedAnnotationID = nil
        activeEditor = nil
        placementTool = nil
        pendingInitialPageIndex = nil
        isHighlighterModeActive = false
        hasTextSelection = false

        clearSearchState()
        resetCommentReviewState()
        clearSidebarReplyDraft()
        resetToFocusedReadingLayout()

        pdfView?.document = nil
        document = nil
        documentURL = nil
        annotations = []
        bookmarks = []
        hasUnsavedChanges = false
        currentPageIndex = 0
        pageText = "1"
    }

    private func enforceCompactSidebarRules() {
        guard !ReaderAdaptiveLayout(sizeClass: readerSizeClass).allowsDualSidebars else { return }
        if showLeftSidebar && showCommentsSidebar {
            showLeftSidebar = false
        }
    }
}
