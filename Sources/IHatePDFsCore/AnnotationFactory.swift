import AppKit
import Foundation
import PDFKit

public enum AcademicAnnotationPalette {
    public static let comment = NSColor(
        calibratedRed: 0.88,
        green: 0.72,
        blue: 0.46,
        alpha: 0.10
    )
    public static let highlight = NSColor(
        calibratedRed: 0.88,
        green: 0.72,
        blue: 0.46,
        alpha: 0.24
    )
    public static let underline = NSColor(
        calibratedRed: 0.48,
        green: 0.53,
        blue: 0.62,
        alpha: 0.56
    )
    public static let note = NSColor(
        calibratedRed: 0.64,
        green: 0.59,
        blue: 0.49,
        alpha: 0.9
    )
    public static let reply = NSColor(
        calibratedRed: 0.52,
        green: 0.58,
        blue: 0.60,
        alpha: 0.88
    )
    public static let freeTextFill = NSColor(
        calibratedRed: 0.91,
        green: 0.86,
        blue: 0.75,
        alpha: 0.32
    )
    public static let freeTextInk = NSColor(
        calibratedWhite: 0.22,
        alpha: 1
    )
}

public enum MarkupAnnotationStyle {
    case comment
    case highlight
    case underline

    var subtype: PDFAnnotationSubtype {
        switch self {
        case .comment: return .highlight
        case .highlight: return .highlight
        case .underline: return .underline
        }
    }

    var color: NSColor {
        switch self {
        case .comment: return AcademicAnnotationPalette.comment
        case .highlight: return AcademicAnnotationPalette.highlight
        case .underline: return AcademicAnnotationPalette.underline
        }
    }

    var markupType: PDFMarkupType {
        switch self {
        case .comment: return .highlight
        case .highlight: return .highlight
        case .underline: return .underline
        }
    }
}

public struct AnnotationInsertion {
    public let page: PDFPage
    public let annotation: PDFAnnotation
    public let popup: PDFAnnotation?

    public init(page: PDFPage, annotation: PDFAnnotation, popup: PDFAnnotation?) {
        self.page = page
        self.annotation = annotation
        self.popup = popup
    }
}

public enum AnnotationFactory {
    public static let defaultAuthor = NSFullUserName().isEmpty ? NSUserName() : NSFullUserName()

    public static func markupInsertions(
        from selection: PDFSelection,
        style: MarkupAnnotationStyle,
        comment: String,
        author: String,
        date: Date = Date()
    ) -> [AnnotationInsertion] {
        let lineSelections = selection.selectionsByLine()
        var groups: [(page: PDFPage, rects: [CGRect])] = []

        for lineSelection in lineSelections {
            for page in lineSelection.pages {
                let rect = lineSelection.bounds(for: page).insetBy(dx: -1.5, dy: -1.0)
                guard !rect.isNull, rect.width > 0, rect.height > 0 else { continue }

                if let index = groups.firstIndex(where: { $0.page === page }) {
                    groups[index].rects.append(rect)
                } else {
                    groups.append((page: page, rects: [rect]))
                }
            }
        }

        return groups.compactMap { group in
            guard let firstRect = group.rects.first else { return nil }
            let unionRect = group.rects.dropFirst().reduce(firstRect) { partial, rect in
                partial.union(rect)
            }
            let annotation = PDFAnnotation(bounds: unionRect, forType: style.subtype, withProperties: nil)
            annotation.markupType = style.markupType
            annotation.color = style.color
            annotation.quadrilateralPoints = group.rects.flatMap { rect in
                quadPoints(for: rect, relativeTo: unionRect)
            }
            standardize(annotation, comment: comment, author: author, date: date)
            if style == .comment {
                _ = annotation.setValue(AnnotationKeys.appKindComment, forAnnotationKey: AnnotationKeys.appKind)
            }
            let popup = makePopupIfNeeded(for: annotation, on: group.page, open: false)
            return AnnotationInsertion(page: group.page, annotation: annotation, popup: popup)
        }
    }

    public static func noteInsertion(
        on page: PDFPage,
        near point: CGPoint,
        comment: String,
        author: String,
        date: Date = Date()
    ) -> AnnotationInsertion {
        let bounds = clampedRect(
            desired: CGRect(x: point.x, y: point.y, width: 28, height: 28),
            on: page,
            fallbackSize: CGSize(width: 28, height: 28)
        )
        let annotation = PDFAnnotation(bounds: bounds, forType: .text, withProperties: nil)
        annotation.color = AcademicAnnotationPalette.note
        annotation.iconType = .note
        standardize(annotation, comment: comment, author: author, date: date)
        let popup = makePopupIfNeeded(for: annotation, on: page, open: false)
        return AnnotationInsertion(page: page, annotation: annotation, popup: popup)
    }

    public static func freeTextInsertion(
        on page: PDFPage,
        near point: CGPoint,
        text: String,
        author: String,
        date: Date = Date()
    ) -> AnnotationInsertion {
        let bounds = clampedRect(
            desired: CGRect(x: point.x - 120, y: point.y - 40, width: 240, height: 80),
            on: page,
            fallbackSize: CGSize(width: 240, height: 80)
        )
        let annotation = PDFAnnotation(bounds: bounds, forType: .freeText, withProperties: nil)
        annotation.font = NSFont.systemFont(ofSize: 13)
        annotation.fontColor = AcademicAnnotationPalette.freeTextInk
        annotation.alignment = .left
        annotation.color = AcademicAnnotationPalette.freeTextFill

        let border = PDFBorder()
        border.lineWidth = 0.75
        annotation.border = border

        standardize(annotation, comment: text, author: author, date: date)
        return AnnotationInsertion(page: page, annotation: annotation, popup: nil)
    }

    public static func replyInsertion(
        to parent: PDFAnnotation,
        on page: PDFPage,
        comment: String,
        author: String,
        parentID: String? = nil,
        date: Date = Date()
    ) -> AnnotationInsertion {
        let parentBounds = parent.bounds
        let targetPoint = CGPoint(
            x: parentBounds.maxX + 16,
            y: max(parentBounds.minY, parentBounds.midY - 12)
        )
        let bounds = clampedRect(
            desired: CGRect(origin: targetPoint, size: CGSize(width: 24, height: 24)),
            on: page,
            fallbackSize: CGSize(width: 24, height: 24)
        )
        let annotation = PDFAnnotation(bounds: bounds, forType: .text, withProperties: nil)
        annotation.color = AcademicAnnotationPalette.reply
        annotation.iconType = .comment
        standardize(annotation, comment: comment, author: author, date: date)
        let parentIdentifier = parentID
            ?? parent.value(forAnnotationKey: .name) as? String
            ?? UUID().uuidString
        _ = annotation.setValue(parentIdentifier, forAnnotationKey: AnnotationKeys.inReplyTo)
        _ = annotation.setValue("R", forAnnotationKey: AnnotationKeys.replyType)
        hideReplyMarker(annotation, on: page)
        return AnnotationInsertion(page: page, annotation: annotation, popup: nil)
    }

    public static func updateComment(
        for annotation: PDFAnnotation,
        on page: PDFPage,
        text: String,
        author: String,
        date: Date = Date()
    ) -> PDFAnnotation? {
        annotation.contents = text
        annotation.userName = author
        annotation.modificationDate = date
        _ = annotation.setValue(author, forAnnotationKey: .textLabel)
        _ = annotation.setValue(date, forAnnotationKey: .date)
        if annotation.value(forAnnotationKey: AnnotationKeys.creationDate) == nil {
            _ = annotation.setValue(
                AnnotationKeys.pdfDateString(from: date),
                forAnnotationKey: AnnotationKeys.creationDate
            )
        }

        if AnnotationKeys.annotation(annotation, hasSubtype: .freeText) {
            return nil
        }

        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if let popup = annotation.popup {
                page.removeAnnotation(popup)
                annotation.popup = nil
            }
            return nil
        }

        if AnnotationKeys.isReply(annotation) {
            hideReplyMarker(annotation, on: page)
            return nil
        }

        if let popup = annotation.popup {
            popup.contents = text
            popup.userName = author
            popup.modificationDate = date
            popup.isOpen = false
            return nil
        }

        return makePopupIfNeeded(for: annotation, on: page, open: false)
    }

    public static func standardize(
        _ annotation: PDFAnnotation,
        comment: String,
        author: String,
        date: Date
    ) {
        annotation.contents = comment
        annotation.userName = author
        annotation.modificationDate = date
        annotation.shouldDisplay = true
        annotation.shouldPrint = true
        _ = annotation.setValue(UUID().uuidString, forAnnotationKey: .name)
        _ = annotation.setValue(author, forAnnotationKey: .textLabel)
        _ = annotation.setValue(date, forAnnotationKey: .date)
        _ = annotation.setValue(
            AnnotationKeys.pdfDateString(from: date),
            forAnnotationKey: AnnotationKeys.creationDate
        )
        _ = annotation.setValue("Unmarked", forAnnotationKey: AnnotationKeys.state)
        _ = annotation.setValue("Marked", forAnnotationKey: AnnotationKeys.stateModel)
    }

    public static func makePopupIfNeeded(
        for annotation: PDFAnnotation,
        on page: PDFPage,
        open: Bool
    ) -> PDFAnnotation? {
        guard !AnnotationKeys.annotation(annotation, hasSubtype: .popup) else { return nil }
        guard !AnnotationKeys.annotation(annotation, hasSubtype: .freeText) else { return nil }
        guard let contents = annotation.contents,
              !contents.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return nil
        }

        if let popup = annotation.popup {
            popup.contents = contents
            popup.userName = annotation.userName
            popup.modificationDate = annotation.modificationDate
            popup.isOpen = open
            popup.shouldDisplay = true
            popup.shouldPrint = true
            return popup.page == nil ? popup : nil
        }

        let popupBounds = popupRect(for: annotation.bounds, on: page)
        let popup = PDFAnnotation(bounds: popupBounds, forType: .popup, withProperties: nil)
        popup.contents = contents
        popup.userName = annotation.userName
        popup.modificationDate = annotation.modificationDate
        popup.isOpen = open
        popup.shouldDisplay = true
        popup.shouldPrint = true
        annotation.popup = popup
        return popup
    }

    public static func hideReplyMarker(_ annotation: PDFAnnotation, on page: PDFPage) {
        guard AnnotationKeys.isReply(annotation) else { return }

        let pageBounds = page.bounds(for: .cropBox)
        annotation.bounds = CGRect(
            x: pageBounds.maxX + 32,
            y: pageBounds.maxY + 32,
            width: 1,
            height: 1
        )
        annotation.shouldDisplay = true
        annotation.shouldPrint = false

        if let popup = annotation.popup {
            page.removeAnnotation(popup)
            annotation.popup = nil
        }
    }

    public static func parentAnnotation(for annotation: PDFAnnotation) -> PDFAnnotation {
        if AnnotationKeys.annotation(annotation, hasSubtype: .popup),
           let parent = annotation.value(forAnnotationKey: .parent) as? PDFAnnotation {
            return parent
        }
        return annotation
    }

    private static func quadPoints(for rect: CGRect, relativeTo bounds: CGRect) -> [NSValue] {
        let minX = rect.minX - bounds.minX
        let maxX = rect.maxX - bounds.minX
        let minY = rect.minY - bounds.minY
        let maxY = rect.maxY - bounds.minY

        return [
            NSValue(point: CGPoint(x: minX, y: maxY)),
            NSValue(point: CGPoint(x: maxX, y: maxY)),
            NSValue(point: CGPoint(x: minX, y: minY)),
            NSValue(point: CGPoint(x: maxX, y: minY))
        ]
    }

    private static func popupRect(for annotationBounds: CGRect, on page: PDFPage) -> CGRect {
        let pageBounds = page.bounds(for: .cropBox)
        let desired = CGRect(
            x: annotationBounds.maxX + 10,
            y: max(annotationBounds.minY - 96, pageBounds.minY + 12),
            width: 240,
            height: 120
        )
        return clampedRect(
            desired: desired,
            on: page,
            fallbackSize: CGSize(width: 240, height: 120)
        )
    }

    private static func clampedRect(
        desired: CGRect,
        on page: PDFPage,
        fallbackSize: CGSize
    ) -> CGRect {
        let pageBounds = page.bounds(for: .cropBox).insetBy(dx: 12, dy: 12)
        let width = min(desired.width > 0 ? desired.width : fallbackSize.width, pageBounds.width)
        let height = min(desired.height > 0 ? desired.height : fallbackSize.height, pageBounds.height)
        let x = min(max(desired.minX, pageBounds.minX), pageBounds.maxX - width)
        let y = min(max(desired.minY, pageBounds.minY), pageBounds.maxY - height)
        return CGRect(x: x, y: y, width: width, height: height)
    }
}
