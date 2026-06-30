import XCTest
@testable import IHatePDFsCore

final class PDFRecentDocumentsTests: XCTestCase {
    func testFilteredPDFsKeepsExistingPDFsOnly() {
        let pdf = URL(fileURLWithPath: "/Users/test/Documents/reading.pdf")
        let upperPDF = URL(fileURLWithPath: "/Users/test/Documents/report.PDF")
        let text = URL(fileURLWithPath: "/Users/test/Documents/notes.txt")

        let result = PDFRecentDocuments.filteredPDFs(
            from: [pdf, text, upperPDF],
            limit: 10,
            fileExists: { $0 == pdf || $0 == upperPDF }
        )

        XCTAssertEqual(result, [pdf, upperPDF])
    }

    func testFilteredPDFsDeduplicatesExcludesCurrentAndHonorsLimit() {
        let first = URL(fileURLWithPath: "/Users/test/Documents/first.pdf")
        let second = URL(fileURLWithPath: "/Users/test/Documents/second.pdf")
        let third = URL(fileURLWithPath: "/Users/test/Documents/third.pdf")

        let result = PDFRecentDocuments.filteredPDFs(
            from: [first, second, first, third],
            currentURL: second,
            limit: 1,
            fileExists: { _ in true }
        )

        XCTAssertEqual(result, [first])
    }

    func testProgressStoresPageByNormalizedDocumentKey() {
        let url = URL(fileURLWithPath: "/Users/test/Documents/../Documents/reading.pdf")
        let openedAt = Date(timeIntervalSince1970: 42)

        let records = PDFRecentDocuments.updatedProgress(
            [:],
            url: url,
            pageIndex: 8,
            openedAt: openedAt
        )
        let progress = PDFRecentDocuments.progress(for: url, in: records)

        XCTAssertEqual(progress?.pageIndex, 8)
        XCTAssertEqual(progress?.openedAt, openedAt)
        XCTAssertEqual(progress?.key, PDFRecentDocuments.documentKey(for: url))
    }

    func testProgressClampsSavedPageToAvailablePageCount() {
        XCTAssertEqual(PDFRecentDocuments.clampedPageIndex(nil, pageCount: 20), 0)
        XCTAssertEqual(PDFRecentDocuments.clampedPageIndex(-4, pageCount: 20), 0)
        XCTAssertEqual(PDFRecentDocuments.clampedPageIndex(4, pageCount: 20), 4)
        XCTAssertEqual(PDFRecentDocuments.clampedPageIndex(99, pageCount: 20), 19)
        XCTAssertEqual(PDFRecentDocuments.clampedPageIndex(4, pageCount: 0), 0)
    }
}
