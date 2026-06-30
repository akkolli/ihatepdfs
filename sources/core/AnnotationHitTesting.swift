import Foundation
import PDFKit

public enum AnnotationHitTesting {
    public static func containsTextMarkupPoint(
        _ point: CGPoint,
        in annotation: PDFAnnotation,
        tolerance: CGFloat = 3
    ) -> Bool {
        guard AnnotationKeys.annotation(annotation, hasSubtype: .highlight)
                || AnnotationKeys.annotation(annotation, hasSubtype: .underline)
        else {
            return annotation.bounds.insetBy(dx: -tolerance, dy: -tolerance).contains(point)
        }

        let quadPoints = annotation.quadrilateralPoints ?? []
        guard !quadPoints.isEmpty else {
            return annotation.bounds.insetBy(dx: -tolerance, dy: -tolerance).contains(point)
        }

        var index = 0
        while index + 3 < quadPoints.count {
            let points = quadPoints[index..<(index + 4)].map { value in
                let relativePoint = value.pointValue
                return CGPoint(
                    x: annotation.bounds.minX + relativePoint.x,
                    y: annotation.bounds.minY + relativePoint.y
                )
            }
            if boundingRect(for: points).insetBy(dx: -tolerance, dy: -tolerance).contains(point) {
                return true
            }
            index += 4
        }

        return false
    }

    private static func boundingRect(for points: [CGPoint]) -> CGRect {
        guard let first = points.first else { return .null }

        return points.dropFirst().reduce(CGRect(origin: first, size: .zero)) { rect, point in
            rect.union(CGRect(origin: point, size: .zero))
        }
    }
}
