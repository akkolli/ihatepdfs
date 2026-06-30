import AppKit
import PDFKit
import XCTest
@testable import IHatePDFsCore

final class PerformanceBudgetTests: XCTestCase {
    func testLargeDocumentFullAnnotationSnapshotPerformance() {
        let document = makeLargeAnnotatedDocument(pageCount: 500, annotationEvery: 10)

        measure {
            let snapshots = AnnotationReader.snapshots(in: document)
            XCTAssertEqual(snapshots.count, 50)
        }
    }

    func testLargeDocumentPageScopedAnnotationRefreshPerformance() throws {
        let document = makeLargeAnnotatedDocument(pageCount: 500, annotationEvery: 10)
        let targetPage = try XCTUnwrap(document.page(at: 250))

        measure {
            let snapshots = AnnotationReader.snapshots(in: document, pages: [targetPage])
            XCTAssertEqual(snapshots.count, 1)
            XCTAssertEqual(snapshots.first?.pageIndex, 250)
        }
    }

    private func makeLargeAnnotatedDocument(pageCount: Int, annotationEvery stride: Int) -> PDFDocument {
        let document = PDFDocument()

        for pageIndex in 0..<pageCount {
            let page = PDFPage()
            document.insert(page, at: pageIndex)

            guard pageIndex.isMultiple(of: stride) else { continue }
            let insertion = AnnotationFactory.noteInsertion(
                on: page,
                near: CGPoint(x: 120, y: 160),
                comment: "Note on page \(pageIndex + 1)",
                author: "Professor"
            )
            page.addAnnotation(insertion.annotation)
        }

        return document
    }
}
