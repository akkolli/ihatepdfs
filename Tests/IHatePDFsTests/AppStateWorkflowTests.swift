import CoreGraphics
import Foundation
import IHatePDFsCore
import PDFKit
import XCTest
@testable import IHatePDFs

@MainActor
final class AppStateWorkflowTests: XCTestCase {
    func testOpeningDocumentStartsInFocusedReadingWorkflow() throws {
        let url = try makeTemporaryPDF()
        defer { try? FileManager.default.removeItem(at: url) }

        let appState = AppState()
        appState.updateWindowWidth(1_280)
        appState.showLeftSidebar = true
        appState.leftSidebarMode = .annotations
        appState.showCommentsSidebar = true
        appState.sidebarMode = .highlights
        appState.commentSearchText = "draft"
        appState.commentFilter = .withComments
        appState.selectedKindFilter = .comment
        appState.selectedAuthorFilter = "Someone"
        appState.selectedStatusFilter = ReviewState.reviewed
        appState.collapsedPageIndexes = [0]

        appState.loadDocument(from: url)

        XCTAssertNotNil(appState.document)
        XCTAssertEqual(appState.documentURL, url)
        XCTAssertFalse(appState.showLeftSidebar)
        XCTAssertEqual(appState.leftSidebarMode, .pages)
        XCTAssertFalse(appState.showCommentsSidebar)
        XCTAssertEqual(appState.sidebarMode, .annotations)
        XCTAssertEqual(appState.commentSearchText, "")
        XCTAssertEqual(appState.commentFilter, .all)
        XCTAssertNil(appState.selectedKindFilter)
        XCTAssertEqual(appState.selectedAuthorFilter, "All Authors")
        XCTAssertEqual(appState.selectedStatusFilter, ReviewState.allStatuses)
        XCTAssertTrue(appState.collapsedPageIndexes.isEmpty)
        XCTAssertFalse(appState.hasUnsavedChanges)
    }

    func testOpeningDocumentCollapsesSidebars() throws {
        let url = try makeTemporaryPDF()
        defer { try? FileManager.default.removeItem(at: url) }

        let appState = AppState()
        appState.updateWindowWidth(1_280)
        appState.showLeftSidebar = true
        appState.leftSidebarMode = .annotations
        appState.showCommentsSidebar = true
        appState.sidebarMode = .highlights

        appState.loadDocument(from: url)

        XCTAssertFalse(appState.showLeftSidebar)
        XCTAssertFalse(appState.showCommentsSidebar)
    }

    func testDroppingPDFWhileDocumentOpenReplacesThroughAppState() async throws {
        let firstURL = try makeTemporaryPDF()
        let secondURL = try makeTemporaryPDF()
        defer {
            try? FileManager.default.removeItem(at: firstURL)
            try? FileManager.default.removeItem(at: secondURL)
        }

        let appState = AppState()
        appState.loadDocument(from: firstURL)
        XCTAssertEqual(appState.documentURL, firstURL)

        let provider = try XCTUnwrap(NSItemProvider(contentsOf: secondURL))
        XCTAssertTrue(appState.openDroppedDocument(from: [provider]))

        try await waitUntil {
            appState.documentURL == secondURL
        }

        XCTAssertEqual(appState.documentURL, secondURL)
        XCTAssertNotNil(appState.document)
        XCTAssertFalse(appState.hasUnsavedChanges)
    }

    func testClosingDocumentReturnsToEmptyWindowWorkflow() throws {
        let url = try makeTemporaryPDF()
        defer { try? FileManager.default.removeItem(at: url) }

        let appState = AppState()
        appState.loadDocument(from: url)
        appState.showLeftSidebar = true
        appState.leftSidebarMode = .annotations
        appState.showCommentsSidebar = true
        appState.sidebarMode = .highlights
        appState.searchText = "draft"
        appState.showToolbarSearch = true
        appState.collapsedPageIndexes = [0]

        appState.closeDocument()

        XCTAssertNil(appState.document)
        XCTAssertNil(appState.documentURL)
        XCTAssertFalse(appState.showLeftSidebar)
        XCTAssertEqual(appState.leftSidebarMode, .pages)
        XCTAssertFalse(appState.showCommentsSidebar)
        XCTAssertEqual(appState.sidebarMode, .annotations)
        XCTAssertEqual(appState.searchText, "")
        XCTAssertFalse(appState.showToolbarSearch)
        XCTAssertTrue(appState.annotations.isEmpty)
        XCTAssertTrue(appState.bookmarks.isEmpty)
        XCTAssertEqual(appState.currentPageIndex, 0)
        XCTAssertEqual(appState.pageText, "1")
        XCTAssertFalse(appState.hasUnsavedWork)
        XCTAssertEqual(appState.statusMessage, "Closed PDF.")
    }

    func testCompactWorkflowShowsOnlyOneSidebarAtATime() {
        let appState = AppState()
        appState.updateWindowWidth(ReaderAdaptiveLayout.minimumWindowWidth)

        appState.toggleRightSidebar(mode: .highlights)
        XCTAssertTrue(appState.showCommentsSidebar)
        XCTAssertEqual(appState.sidebarMode, .highlights)
        XCTAssertFalse(appState.showLeftSidebar)

        appState.togglePageSidebar()
        XCTAssertTrue(appState.showLeftSidebar)
        XCTAssertEqual(appState.leftSidebarMode, .pages)
        XCTAssertFalse(appState.showCommentsSidebar)

        appState.toggleRightSidebar(mode: .highlights)
        XCTAssertTrue(appState.showCommentsSidebar)
        XCTAssertEqual(appState.sidebarMode, .highlights)
        XCTAssertFalse(appState.showLeftSidebar)
    }

    func testPageSidebarToggleClosesLeftSidebarEvenWhenMarksAreSelected() {
        let appState = AppState()
        appState.updateWindowWidth(1_280)
        appState.showLeftSidebar = true
        appState.leftSidebarMode = .annotations

        appState.togglePageSidebar()

        XCTAssertFalse(appState.showLeftSidebar)
        XCTAssertEqual(appState.leftSidebarMode, .annotations)
    }

    func testRightSidebarToolbarToggleClosesAndReopensCurrentMode() {
        let appState = AppState()
        appState.updateWindowWidth(1_280)

        appState.toggleRightSidebar(mode: .highlights)
        XCTAssertTrue(appState.showCommentsSidebar)
        XCTAssertEqual(appState.sidebarMode, .highlights)

        appState.toggleRightSidebarVisibility()
        XCTAssertFalse(appState.showCommentsSidebar)
        XCTAssertEqual(appState.sidebarMode, .highlights)

        appState.toggleRightSidebarVisibility()
        XCTAssertTrue(appState.showCommentsSidebar)
        XCTAssertEqual(appState.sidebarMode, .highlights)
    }

    func testRightSidebarToggleClosesFromDifferentOpenMode() {
        let appState = AppState()
        appState.updateWindowWidth(1_280)

        appState.toggleRightSidebar(mode: .highlights)
        XCTAssertTrue(appState.showCommentsSidebar)
        XCTAssertEqual(appState.sidebarMode, .highlights)

        appState.toggleRightSidebar(mode: .annotations)
        XCTAssertFalse(appState.showCommentsSidebar)
        XCTAssertEqual(appState.sidebarMode, .highlights)

        appState.toggleRightSidebar(mode: .annotations)
        XCTAssertTrue(appState.showCommentsSidebar)
        XCTAssertEqual(appState.sidebarMode, .annotations)
    }

    func testRightSidebarToggleFromHighlightsDoesNotSwitchModeWhenClosing() {
        let appState = AppState()
        appState.updateWindowWidth(1_280)

        appState.toggleRightSidebar(mode: .highlights)
        XCTAssertTrue(appState.showCommentsSidebar)
        XCTAssertEqual(appState.sidebarMode, .highlights)

        appState.toggleRightSidebarVisibility()
        XCTAssertFalse(appState.showCommentsSidebar)
        XCTAssertEqual(appState.sidebarMode, .highlights)

        appState.toggleRightSidebarVisibility()
        XCTAssertTrue(appState.showCommentsSidebar)
        XCTAssertEqual(appState.sidebarMode, .highlights)
    }

    func testRightSidebarToolbarToggleDefaultsToCommentsWhenNoModeWasChosen() {
        let appState = AppState()
        appState.updateWindowWidth(1_280)

        XCTAssertFalse(appState.showCommentsSidebar)
        XCTAssertEqual(appState.sidebarMode, .annotations)

        appState.toggleRightSidebarVisibility()

        XCTAssertTrue(appState.showCommentsSidebar)
        XCTAssertEqual(appState.sidebarMode, .annotations)
    }

    func testRegularWorkflowAllowsNavigationAndReviewSidebarsTogether() {
        let appState = AppState()
        appState.updateWindowWidth(1_000)

        appState.togglePageSidebar()
        appState.toggleRightSidebar(mode: .annotations)

        XCTAssertTrue(appState.showLeftSidebar)
        XCTAssertEqual(appState.leftSidebarMode, .pages)
        XCTAssertTrue(appState.showCommentsSidebar)
        XCTAssertEqual(appState.sidebarMode, .annotations)
    }

    func testSaveAvailabilityTracksReplyDraftAsUnsavedWork() throws {
        let url = try makeTemporaryPDF()
        defer { try? FileManager.default.removeItem(at: url) }

        let appState = AppState()
        appState.loadDocument(from: url)

        XCTAssertFalse(appState.hasUnsavedWork)
        XCTAssertFalse(appState.canSaveDocument)
        XCTAssertEqual(appState.saveHelpText, "No unsaved changes.")

        appState.sidebarReplyDraft = "Need to verify this quote."

        XCTAssertTrue(appState.hasUnsavedWork)
        XCTAssertTrue(appState.hasUnsentSidebarReplyDraft)
        XCTAssertTrue(appState.canSaveDocument)
        XCTAssertEqual(appState.saveHelpText, "Send or cancel the reply draft before saving.")

        appState.hasUnsavedChanges = true
        XCTAssertTrue(appState.canSaveDocument)
        XCTAssertEqual(appState.saveHelpText, "Save PDF")
    }

    private func makeTemporaryPDF() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("pdf")

        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data) else {
            throw TestPDFError.couldNotCreateConsumer
        }

        var mediaBox = CGRect(x: 0, y: 0, width: 612, height: 792)
        guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw TestPDFError.couldNotCreateContext
        }

        context.beginPDFPage(nil)
        context.endPDFPage()
        context.closePDF()

        try data.write(to: url, options: .atomic)
        return url
    }

    private enum TestPDFError: Error {
        case couldNotCreateConsumer
        case couldNotCreateContext
    }

    private func waitUntil(
        timeout: TimeInterval = 2,
        condition: @MainActor @escaping () -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() {
                return
            }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTFail("Timed out waiting for condition.")
    }
}
