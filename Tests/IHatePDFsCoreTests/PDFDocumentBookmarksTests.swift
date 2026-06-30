import XCTest
@testable import IHatePDFsCore

final class PDFDocumentBookmarksTests: XCTestCase {
    func testUpsertReplacesExistingBookmark() {
        let first = PDFDocumentBookmark(id: "first", pageIndex: 4, pageLabel: "5", title: "Old")
        let second = PDFDocumentBookmark(id: "second", pageIndex: 1, pageLabel: "2", title: "Second")
        let replacement = PDFDocumentBookmark(id: "replacement", pageIndex: 4, pageLabel: "5", title: "New")

        let result = PDFDocumentBookmarks.upsert(replacement, in: [first, second])

        XCTAssertEqual(result.map(\.id), ["replacement"])
        XCTAssertEqual(result.first?.title, "New")
    }

    func testRemovingBookmarkCollapsesDirtyMultipleBookmarkData() {
        let first = PDFDocumentBookmark(id: "first", pageIndex: 0, pageLabel: "1", title: "First")
        let second = PDFDocumentBookmark(id: "second", pageIndex: 1, pageLabel: "2", title: "Second")

        let result = PDFDocumentBookmarks.removing(id: "first", from: [first, second])

        XCTAssertEqual(result.map(\.id), ["second"])
    }

    func testClampedDropsInvalidBookmarksAndKeepsOneBookmark() {
        let older = PDFDocumentBookmark(
            id: "older",
            pageIndex: 0,
            pageLabel: "1",
            title: "Older",
            createdAt: Date(timeIntervalSince1970: 100)
        )
        let newer = PDFDocumentBookmark(
            id: "newer",
            pageIndex: 1,
            pageLabel: "2",
            title: "Newer",
            createdAt: Date(timeIntervalSince1970: 200)
        )
        let invalid = PDFDocumentBookmark(
            id: "invalid",
            pageIndex: 4,
            pageLabel: "5",
            title: "Invalid",
            createdAt: Date(timeIntervalSince1970: 300)
        )

        let result = PDFDocumentBookmarks.clamped([invalid, older, newer], pageCount: 2)

        XCTAssertEqual(result.map(\.id), ["newer"])
    }
}
