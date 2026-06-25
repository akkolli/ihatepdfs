import XCTest
import PDFKit
@testable import IHatePDFsCore

final class AnnotationHitTestingTests: XCTestCase {
    func testTextMarkupHitTestingUsesQuadPointsInsteadOfUnionBounds() {
        let annotation = PDFAnnotation(
            bounds: CGRect(x: 10, y: 20, width: 100, height: 60),
            forType: .highlight,
            withProperties: nil
        )
        annotation.quadrilateralPoints = [
            NSValue(point: CGPoint(x: 0, y: 55)),
            NSValue(point: CGPoint(x: 100, y: 55)),
            NSValue(point: CGPoint(x: 0, y: 45)),
            NSValue(point: CGPoint(x: 100, y: 45)),
            NSValue(point: CGPoint(x: 0, y: 15)),
            NSValue(point: CGPoint(x: 100, y: 15)),
            NSValue(point: CGPoint(x: 0, y: 5)),
            NSValue(point: CGPoint(x: 100, y: 5))
        ]

        XCTAssertTrue(AnnotationHitTesting.containsTextMarkupPoint(CGPoint(x: 50, y: 70), in: annotation))
        XCTAssertTrue(AnnotationHitTesting.containsTextMarkupPoint(CGPoint(x: 50, y: 30), in: annotation))
        XCTAssertFalse(AnnotationHitTesting.containsTextMarkupPoint(CGPoint(x: 50, y: 50), in: annotation))
    }

    func testTextMarkupHitTestingFallsBackToBoundsWithoutQuadPoints() {
        let annotation = PDFAnnotation(
            bounds: CGRect(x: 10, y: 20, width: 100, height: 20),
            forType: .underline,
            withProperties: nil
        )

        XCTAssertTrue(AnnotationHitTesting.containsTextMarkupPoint(CGPoint(x: 50, y: 30), in: annotation))
        XCTAssertFalse(AnnotationHitTesting.containsTextMarkupPoint(CGPoint(x: 50, y: 60), in: annotation))
    }
}
