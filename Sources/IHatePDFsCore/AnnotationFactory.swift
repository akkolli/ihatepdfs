import AppKit
import Foundation
import PDFKit

public enum AcademicAnnotationPalette {
    public static let comment = NSColor(
        calibratedRed: 0.98,
        green: 0.64,
        blue: 0.16,
        alpha: 0.30
    )
    public static let highlight = NSColor(
        calibratedRed: 1.0,
        green: 0.78,
        blue: 0.0,
        alpha: 0.52
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

    func color(
        highlightColor: NSColor = AcademicAnnotationPalette.highlight,
        commentColor: NSColor = AcademicAnnotationPalette.comment
    ) -> NSColor {
        switch self {
        case .comment: return commentColor
        case .highlight: return highlightColor
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
        highlightColor: NSColor = AcademicAnnotationPalette.highlight,
        commentColor: NSColor = AcademicAnnotationPalette.comment,
        date: Date = Date()
    ) -> [AnnotationInsertion] {
        let lineSelections = selection.selectionsByLine()
        var groups: [(page: PDFPage, rects: [CGRect], text: [String])] = []

        for lineSelection in lineSelections {
            let lineText = lineSelection.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            for page in lineSelection.pages {
                let rect = lineSelection.bounds(for: page).insetBy(dx: -1.5, dy: -1.0)
                guard !rect.isNull, rect.width > 0, rect.height > 0 else { continue }

                if let index = groups.firstIndex(where: { $0.page === page }) {
                    groups[index].rects.append(rect)
                    if !lineText.isEmpty {
                        groups[index].text.append(lineText)
                    }
                } else {
                    groups.append((page: page, rects: [rect], text: lineText.isEmpty ? [] : [lineText]))
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
            annotation.color = style.color(highlightColor: highlightColor, commentColor: commentColor)
            annotation.quadrilateralPoints = group.rects.flatMap { rect in
                quadPoints(for: rect, relativeTo: unionRect)
            }
            standardize(annotation, comment: comment, author: author, date: date)
            if style == .highlight {
                let highlightText = group.text.joined(separator: " ")
                if !highlightText.isEmpty {
                    _ = annotation.setValue(highlightText, forAnnotationKey: AnnotationKeys.appHighlightText)
                }
            }
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
        annotation.shouldDisplay = false
        annotation.shouldPrint = false
        return AnnotationInsertion(page: page, annotation: annotation, popup: nil)
    }

    public static func updateComment(
        for annotation: PDFAnnotation,
        on page: PDFPage,
        text: String,
        author: String,
        date: Date = Date()
    ) -> PDFAnnotation? {
        AnnotationKeys.setCommentText(text, for: annotation)
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
        AnnotationKeys.setCommentText(comment, for: annotation)
        annotation.contents = comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? nil
            : comment
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
        let contents = AnnotationKeys.commentText(for: annotation)
        guard !contents.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        if let popup = annotation.popup {
            popup.contents = contents
            popup.userName = annotation.userName
            popup.modificationDate = annotation.modificationDate
            popup.isOpen = open
            popup.bounds = popupRect(for: annotation.bounds, on: page)
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

    @discardableResult
    public static func normalizePopupPlacement(
        for annotation: PDFAnnotation,
        on page: PDFPage
    ) -> Bool {
        guard let popup = annotation.popup else { return false }

        let bounds = popupRect(for: annotation.bounds, on: page)
        guard popup.bounds != bounds else { return false }
        popup.bounds = bounds
        return true
    }

    @discardableResult
    public static func setPopupMarkerVisibility(
        for annotation: PDFAnnotation,
        on page: PDFPage,
        isVisible: Bool
    ) -> Bool {
        guard let popup = annotation.popup else { return false }

        let oldBounds = popup.bounds
        let oldShouldDisplay = popup.shouldDisplay
        let oldShouldPrint = popup.shouldPrint
        let oldIsOpen = popup.isOpen

        popup.bounds = popupRect(for: annotation.bounds, on: page)
        popup.shouldDisplay = isVisible
        popup.shouldPrint = isVisible
        popup.isOpen = false

        return oldBounds != popup.bounds
            || oldShouldDisplay != popup.shouldDisplay
            || oldShouldPrint != popup.shouldPrint
            || oldIsOpen != popup.isOpen
    }

    @discardableResult
    public static func restoreCommentTextForExport(_ annotation: PDFAnnotation) -> Bool {
        let contents = AnnotationKeys.commentText(for: annotation)
        return restoreCommentText(contents, forExportIn: annotation)
    }

    @discardableResult
    public static func prepareForPreviewCompatibleExport(
        _ annotation: PDFAnnotation,
        on page: PDFPage
    ) -> Bool {
        let contents = AnnotationKeys.commentText(for: annotation)
        var didChange = restoreCommentText(contents, forExportIn: annotation)

        guard !AnnotationKeys.annotation(annotation, hasSubtype: .freeText) else {
            return didChange
        }

        if let popup = annotation.popup {
            if popup.page != nil {
                page.removeAnnotation(popup)
            }
            annotation.popup = nil
            didChange = true
        }

        let linkedPopups = page.annotations.filter { candidate in
            guard AnnotationKeys.annotation(candidate, hasSubtype: .popup) else { return false }
            return parentAnnotation(for: candidate) === annotation
        }

        for popup in linkedPopups {
            page.removeAnnotation(popup)
            didChange = true
        }

        if restoreCommentText(contents, forExportIn: annotation) {
            didChange = true
        }

        return didChange
    }

    @discardableResult
    private static func restoreCommentText(
        _ contents: String,
        forExportIn annotation: PDFAnnotation
    ) -> Bool {
        let exportedContents = contents.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? nil
            : contents
        let oldContents = annotation.contents

        annotation.contents = exportedContents
        if !contents.isEmpty {
            AnnotationKeys.setCommentText(contents, for: annotation)
        }

        return oldContents != annotation.contents
    }

    @discardableResult
    public static func detachPopupForViewer(
        from annotation: PDFAnnotation,
        on page: PDFPage
    ) -> Bool {
        let contents = AnnotationKeys.commentText(for: annotation)
        let userName = annotation.userName
        let modificationDate = annotation.modificationDate
        let creationDate = annotation.value(forAnnotationKey: AnnotationKeys.creationDate)
        let textLabel = annotation.value(forAnnotationKey: .textLabel)
        let date = annotation.value(forAnnotationKey: .date)
        let shouldSuppressNativeContents = !AnnotationKeys.isReply(annotation)
            && !AnnotationKeys.annotation(annotation, hasSubtype: .freeText)
        let oldContents = annotation.contents
        var didChange = false

        if !contents.isEmpty || annotation.value(forAnnotationKey: AnnotationKeys.appCommentText) == nil {
            AnnotationKeys.setCommentText(contents, for: annotation)
        }

        if let popup = annotation.popup {
            popup.isOpen = false
            popup.shouldDisplay = false
            popup.shouldPrint = false
            if popup.page != nil {
                page.removeAnnotation(popup)
            }
            annotation.popup = nil
            didChange = true
        }

        annotation.contents = shouldSuppressNativeContents ? nil : contents
        annotation.userName = userName
        annotation.modificationDate = modificationDate
        if let creationDate {
            _ = annotation.setValue(creationDate, forAnnotationKey: AnnotationKeys.creationDate)
        }
        if let textLabel {
            _ = annotation.setValue(textLabel, forAnnotationKey: .textLabel)
        }
        if let date {
            _ = annotation.setValue(date, forAnnotationKey: .date)
        }

        return didChange || oldContents != annotation.contents
    }

    public static func hideReplyMarker(_ annotation: PDFAnnotation, on page: PDFPage) {
        guard AnnotationKeys.isReply(annotation) else { return }

        let contents = AnnotationKeys.commentText(for: annotation)
        let userName = annotation.userName
        let modificationDate = annotation.modificationDate

        if let popup = annotation.popup {
            page.removeAnnotation(popup)
            annotation.popup = nil
        }

        let pageBounds = page.bounds(for: .cropBox)
        annotation.bounds = CGRect(
            x: pageBounds.maxX + 32,
            y: pageBounds.maxY + 32,
            width: 24,
            height: 24
        )
        annotation.shouldDisplay = false
        annotation.shouldPrint = false
        AnnotationKeys.setCommentText(contents, for: annotation)
        annotation.contents = contents
        annotation.userName = userName
        annotation.modificationDate = modificationDate
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
        let indicatorInset: CGFloat = 28
        let verticalInset: CGFloat = 12
        let y = min(
            max(annotationBounds.maxY - indicatorInset, pageBounds.minY + verticalInset),
            pageBounds.maxY - indicatorInset - verticalInset
        )

        return CGRect(
            x: pageBounds.maxX - indicatorInset,
            y: y,
            width: 240,
            height: 120
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
