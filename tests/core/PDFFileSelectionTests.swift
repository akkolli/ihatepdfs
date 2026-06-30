import XCTest
@testable import IHatePDFsCore

final class PDFFileSelectionTests: XCTestCase {
    func testPDFFileURLAcceptsPDFExtensionsCaseInsensitively() {
        XCTAssertTrue(PDFFileSelection.isPDFFileURL(URL(fileURLWithPath: "/tmp/article.pdf")))
        XCTAssertTrue(PDFFileSelection.isPDFFileURL(URL(fileURLWithPath: "/tmp/article.PDF")))
    }

    func testPDFFileURLRejectsNonPDFAndRemoteURLs() {
        XCTAssertFalse(PDFFileSelection.isPDFFileURL(URL(fileURLWithPath: "/tmp/notes.txt")))
        XCTAssertFalse(PDFFileSelection.isPDFFileURL(URL(string: "https://example.com/article.pdf")!))
    }

    func testPDFFileURLRejectsDirectoriesNamedLikePDFs() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("pdf")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        XCTAssertFalse(PDFFileSelection.isPDFFileURL(directory))
    }
}
