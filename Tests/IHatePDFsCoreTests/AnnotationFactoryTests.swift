import XCTest
import AppKit
import PDFKit
@testable import IHatePDFsCore

final class AnnotationFactoryTests: XCTestCase {
    func testHighlightSelectionRoundTripsThroughPDFSave() throws {
        let document = try makeSelectableTextDocument()
        let page = try XCTUnwrap(document.page(at: 0))
        let selection = try XCTUnwrap(page.selection(for: NSRange(location: 0, length: 29)))
        let insertions = AnnotationFactory.markupInsertions(
            from: selection,
            style: .highlight,
            comment: "Use this passage in lecture.",
            author: "Professor"
        )

        XCTAssertEqual(insertions.count, 1)

        for insertion in insertions {
            insertion.page.addAnnotation(insertion.annotation)
            if let popup = insertion.popup {
                insertion.page.addAnnotation(popup)
            }
        }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("pdf")
        defer { try? FileManager.default.removeItem(at: outputURL) }

        XCTAssertTrue(document.write(to: outputURL))

        let reopened = try XCTUnwrap(PDFDocument(url: outputURL))
        let reopenedPage = try XCTUnwrap(reopened.page(at: 0))
        XCTAssertEqual(reopenedPage.string, "This is selectable academic text.")
        XCTAssertTrue(
            reopenedPage.annotations.contains {
                AnnotationKeys.annotation($0, hasSubtype: .highlight)
                    && $0.contents == "Use this passage in lecture."
            }
        )
    }

    func testSelectionBoundCommentRoundTripsAsCommentKind() throws {
        let document = try makeSelectableTextDocument()
        let page = try XCTUnwrap(document.page(at: 0))
        let selection = try XCTUnwrap(page.selection(for: NSRange(location: 8, length: 10)))
        let insertion = try XCTUnwrap(
            AnnotationFactory.markupInsertions(
                from: selection,
                style: .comment,
                comment: "Explain this phrase.",
                author: "Professor"
            ).first
        )

        page.addAnnotation(insertion.annotation)
        if let popup = insertion.popup {
            page.addAnnotation(popup)
        }

        let reopenedPage = try saveAndReopen(document).page(at: 0).unwrap()
        let reopenedComment = try XCTUnwrap(reopenedPage.annotations.first {
            AnnotationKeys.annotation($0, hasSubtype: .highlight)
                && $0.contents == "Explain this phrase."
        })

        XCTAssertEqual(AcademicAnnotationKind(annotation: reopenedComment), .comment)
        XCTAssertEqual(
            reopenedComment.value(forAnnotationKey: AnnotationKeys.appKind) as? String,
            AnnotationKeys.appKindComment
        )
    }

    func testSelectionBoundCommentCreatedEmptyGetsPopupWhenTextIsSaved() throws {
        let document = try makeSelectableTextDocument()
        let page = try XCTUnwrap(document.page(at: 0))
        let selection = try XCTUnwrap(page.selection(for: NSRange(location: 8, length: 10)))
        let insertion = try XCTUnwrap(
            AnnotationFactory.markupInsertions(
                from: selection,
                style: .comment,
                comment: "",
                author: "Professor"
            ).first
        )

        XCTAssertNil(insertion.popup)
        page.addAnnotation(insertion.annotation)

        let popup = try XCTUnwrap(AnnotationFactory.updateComment(
            for: insertion.annotation,
            on: page,
            text: "Explain this phrase.",
            author: "Professor"
        ))
        page.addAnnotation(popup)

        let reopenedPage = try saveAndReopen(document).page(at: 0).unwrap()
        let reopenedComment = try XCTUnwrap(reopenedPage.annotations.first {
            AnnotationKeys.annotation($0, hasSubtype: .highlight)
                && $0.contents == "Explain this phrase."
        })

        XCTAssertEqual(AcademicAnnotationKind(annotation: reopenedComment), .comment)
        XCTAssertTrue(reopenedPage.annotations.contains {
            AnnotationKeys.annotation($0, hasSubtype: .popup)
                && $0.contents == "Explain this phrase."
        })
    }

    func testAddingAnnotationPreservesPriorAnnotation() throws {
        let document = try makeSelectableTextDocument()
        let page = try XCTUnwrap(document.page(at: 0))

        let prior = AnnotationFactory.noteInsertion(
            on: page,
            near: CGPoint(x: 420, y: 700),
            comment: "Existing note from another reader.",
            author: "Colleague"
        )
        page.addAnnotation(prior.annotation)
        if let popup = prior.popup {
            page.addAnnotation(popup)
        }

        let selection = try XCTUnwrap(page.selection(for: NSRange(location: 8, length: 10)))
        let highlight = try XCTUnwrap(
            AnnotationFactory.markupInsertions(
                from: selection,
                style: .highlight,
                comment: "New professor comment.",
                author: "Professor"
            ).first
        )
        page.addAnnotation(highlight.annotation)
        if let popup = highlight.popup {
            page.addAnnotation(popup)
        }

        let reopenedPage = try saveAndReopen(document).page(at: 0).unwrap()
        XCTAssertEqual(reopenedPage.string, "This is selectable academic text.")
        XCTAssertTrue(reopenedPage.annotations.contains {
            AnnotationKeys.annotation($0, hasSubtype: .text)
                && $0.contents == "Existing note from another reader."
        })
        XCTAssertTrue(reopenedPage.annotations.contains {
            AnnotationKeys.annotation($0, hasSubtype: .highlight)
                && $0.contents == "New professor comment."
        })
    }

    func testScannedImagePDFCanReceiveStandardTextAnnotation() throws {
        let document = try makeImageOnlyDocument()
        let page = try XCTUnwrap(document.page(at: 0))
        let insertion = AnnotationFactory.noteInsertion(
            on: page,
            near: CGPoint(x: 300, y: 500),
            comment: "Comment on scanned reading.",
            author: "Professor"
        )
        page.addAnnotation(insertion.annotation)
        if let popup = insertion.popup {
            page.addAnnotation(popup)
        }

        let reopenedPage = try saveAndReopen(document).page(at: 0).unwrap()
        XCTAssertNil(reopenedPage.string)
        XCTAssertTrue(reopenedPage.annotations.contains {
            AnnotationKeys.annotation($0, hasSubtype: .text)
                && $0.contents == "Comment on scanned reading."
        })
    }

    func testFiveHundredPagePDFCanBeSavedWithAnnotation() throws {
        let document = PDFDocument()
        for index in 0..<501 {
            document.insert(PDFPage(), at: index)
        }
        XCTAssertEqual(document.pageCount, 501)

        let page = try XCTUnwrap(document.page(at: 500))
        let insertion = AnnotationFactory.noteInsertion(
            on: page,
            near: CGPoint(x: 120, y: 120),
            comment: "End of long reading.",
            author: "Professor"
        )
        page.addAnnotation(insertion.annotation)
        if let popup = insertion.popup {
            page.addAnnotation(popup)
        }

        let reopened = try saveAndReopen(document)
        XCTAssertEqual(reopened.pageCount, 501)
        let reopenedPage = try XCTUnwrap(reopened.page(at: 500))
        XCTAssertTrue(reopenedPage.annotations.contains {
            AnnotationKeys.annotation($0, hasSubtype: .text)
                && $0.contents == "End of long reading."
        })
    }

    func testTextAnnotationUsesStandardKeys() throws {
        let page = PDFPage()
        let insertion = AnnotationFactory.noteInsertion(
            on: page,
            near: CGPoint(x: 100, y: 100),
            comment: "Discuss this claim in class.",
            author: "Professor"
        )

        XCTAssertTrue(AnnotationKeys.annotation(insertion.annotation, hasSubtype: .text))
        XCTAssertEqual(insertion.annotation.contents, "Discuss this claim in class.")
        XCTAssertEqual(insertion.annotation.userName, "Professor")
        XCTAssertNotNil(insertion.annotation.value(forAnnotationKey: .name))
        XCTAssertNotNil(insertion.annotation.value(forAnnotationKey: AnnotationKeys.creationDate))
        XCTAssertEqual(insertion.annotation.value(forAnnotationKey: AnnotationKeys.state) as? String, "Unmarked")
        XCTAssertNotNil(insertion.popup)
        XCTAssertTrue(insertion.popup.map { AnnotationKeys.annotation($0, hasSubtype: .popup) } ?? false)
    }

    func testReplyStoresHiddenTextAnnotationWithBestEffortParentID() throws {
        let page = PDFPage()
        let parent = AnnotationFactory.noteInsertion(
            on: page,
            near: CGPoint(x: 100, y: 100),
            comment: "Parent",
            author: "Professor"
        ).annotation
        let reply = AnnotationFactory.replyInsertion(
            to: parent,
            on: page,
            comment: "Reply",
            author: "Reader",
            parentID: "parent-id"
        )

        XCTAssertTrue(AnnotationKeys.annotation(reply.annotation, hasSubtype: .text))
        XCTAssertEqual(reply.annotation.value(forAnnotationKey: AnnotationKeys.inReplyTo) as? String, "parent-id")
        XCTAssertEqual(reply.annotation.value(forAnnotationKey: AnnotationKeys.replyType) as? String, "R")
        XCTAssertTrue(reply.annotation.shouldDisplay)
        XCTAssertFalse(reply.annotation.shouldPrint)
        XCTAssertGreaterThan(reply.annotation.bounds.minX, page.bounds(for: .cropBox).maxX)
        XCTAssertGreaterThan(reply.annotation.bounds.minY, page.bounds(for: .cropBox).maxY)
        XCTAssertNil(reply.popup)
    }

    func testStringReplyParentIDResolvesToParentStableID() throws {
        let document = PDFDocument()
        let page = PDFPage()
        document.insert(page, at: 0)

        let parent = AnnotationFactory.noteInsertion(
            on: page,
            near: CGPoint(x: 100, y: 100),
            comment: "Parent",
            author: "Professor"
        ).annotation
        page.addAnnotation(parent)

        let parentID = try XCTUnwrap(parent.value(forAnnotationKey: .name) as? String)
        let reply = AnnotationFactory.replyInsertion(
            to: parent,
            on: page,
            comment: "Reply",
            author: "Reader",
            parentID: parentID
        ).annotation
        page.addAnnotation(reply)

        let snapshots = AnnotationReader.snapshots(in: document)
        let parentSnapshot = try XCTUnwrap(snapshots.first { $0.contents == "Parent" })
        let replySnapshot = try XCTUnwrap(snapshots.first { $0.contents == "Reply" })

        XCTAssertEqual(replySnapshot.kind, .reply)
        XCTAssertEqual(replySnapshot.parentID, parentSnapshot.id)
    }

    func testFreeTextCreatesStandardFreeTextAnnotation() throws {
        let page = PDFPage()
        let insertion = AnnotationFactory.freeTextInsertion(
            on: page,
            near: CGPoint(x: 200, y: 200),
            text: "Important definition",
            author: "Professor"
        )

        XCTAssertTrue(AnnotationKeys.annotation(insertion.annotation, hasSubtype: .freeText))
        XCTAssertEqual(insertion.annotation.contents, "Important definition")
        XCTAssertNil(insertion.popup)
    }

    private func makeSelectableTextDocument() throws -> PDFDocument {
        let data = NSMutableData()
        var mediaBox = CGRect(x: 0, y: 0, width: 612, height: 792)
        let consumer = try XCTUnwrap(CGDataConsumer(data: data))
        let context = try XCTUnwrap(CGContext(consumer: consumer, mediaBox: &mediaBox, nil))

        context.beginPDFPage(nil)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        let text = NSAttributedString(
            string: "This is selectable academic text.",
            attributes: [.font: NSFont.systemFont(ofSize: 18)]
        )
        text.draw(at: CGPoint(x: 72, y: 700))
        NSGraphicsContext.restoreGraphicsState()
        context.endPDFPage()
        context.closePDF()

        return try XCTUnwrap(PDFDocument(data: data as Data))
    }

    private func makeImageOnlyDocument() throws -> PDFDocument {
        let image = NSImage(size: CGSize(width: 612, height: 792))
        image.lockFocus()
        NSColor.white.setFill()
        NSRect(x: 0, y: 0, width: 612, height: 792).fill()
        NSColor.darkGray.setStroke()
        let path = NSBezierPath(rect: NSRect(x: 72, y: 580, width: 468, height: 80))
        path.lineWidth = 2
        path.stroke()
        image.unlockFocus()

        let document = PDFDocument()
        document.insert(try XCTUnwrap(PDFPage(image: image)), at: 0)
        return document
    }

    private func saveAndReopen(_ document: PDFDocument) throws -> PDFDocument {
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("pdf")
        XCTAssertTrue(document.write(to: outputURL))
        let reopened = try XCTUnwrap(PDFDocument(url: outputURL))
        try? FileManager.default.removeItem(at: outputURL)
        return reopened
    }
}

private extension Optional {
    func unwrap(
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> Wrapped {
        try XCTUnwrap(self, file: file, line: line)
    }
}
