import AppKit
import Foundation
import PDFKit

public enum AcademicAnnotationKind: String, CaseIterable, Identifiable {
    case comment
    case highlight
    case underline
    case note
    case freeText
    case reply
    case other

    public var id: String { rawValue }

    public init(annotation: PDFAnnotation) {
        if annotation.value(forAnnotationKey: AnnotationKeys.appKind) as? String == AnnotationKeys.appKindComment {
            self = .comment
            return
        }

        if AnnotationKeys.isReply(annotation) {
            self = .reply
            return
        }

        if AnnotationKeys.annotation(annotation, hasSubtype: .highlight) {
            self = .highlight
        } else if AnnotationKeys.annotation(annotation, hasSubtype: .underline) {
            self = .underline
        } else if AnnotationKeys.annotation(annotation, hasSubtype: .text) {
            self = .note
        } else if AnnotationKeys.annotation(annotation, hasSubtype: .freeText) {
            self = .freeText
        } else {
            self = .other
        }
    }

    public var displayName: String {
        switch self {
        case .comment: return "Comment"
        case .highlight: return "Highlight"
        case .underline: return "Underline"
        case .note: return "Note"
        case .freeText: return "Free Text"
        case .reply: return "Reply"
        case .other: return "Other"
        }
    }

    public var symbolName: String {
        switch self {
        case .comment: return "text.bubble"
        case .highlight: return "highlighter"
        case .underline: return "underline"
        case .note: return "note.text"
        case .freeText: return "textformat"
        case .reply: return "arrowshape.turn.up.left"
        case .other: return "ellipsis"
        }
    }
}

public struct AnnotationSnapshot: Identifiable, Equatable {
    public let id: String
    public let pageIndex: Int
    public let pageLabel: String
    public let annotationIndex: Int
    public let kind: AcademicAnnotationKind
    public let author: String
    public let createdAt: Date?
    public let modifiedAt: Date?
    public let status: String
    public let contents: String
    public let bounds: CGRect
    public let annotation: PDFAnnotation
    public let page: PDFPage
    public let parentID: String?

    public init(
        id: String,
        pageIndex: Int,
        pageLabel: String,
        annotationIndex: Int,
        kind: AcademicAnnotationKind,
        author: String,
        createdAt: Date?,
        modifiedAt: Date?,
        status: String,
        contents: String,
        bounds: CGRect,
        annotation: PDFAnnotation,
        page: PDFPage,
        parentID: String?
    ) {
        self.id = id
        self.pageIndex = pageIndex
        self.pageLabel = pageLabel
        self.annotationIndex = annotationIndex
        self.kind = kind
        self.author = author
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.status = status
        self.contents = contents
        self.bounds = bounds
        self.annotation = annotation
        self.page = page
        self.parentID = parentID
    }

    public var firstLine: String {
        let trimmed = contents.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed
            .split(whereSeparator: \.isNewline)
            .first
            .map(String.init)
        else {
            return "No comment"
        }
        return first
    }

    public var hasComment: Bool {
        !contents.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public var isReply: Bool {
        parentID != nil
    }

    public static func == (lhs: AnnotationSnapshot, rhs: AnnotationSnapshot) -> Bool {
        lhs.id == rhs.id
            && lhs.pageIndex == rhs.pageIndex
            && lhs.pageLabel == rhs.pageLabel
            && lhs.annotationIndex == rhs.annotationIndex
            && lhs.kind == rhs.kind
            && lhs.author == rhs.author
            && lhs.createdAt == rhs.createdAt
            && lhs.modifiedAt == rhs.modifiedAt
            && lhs.status == rhs.status
            && lhs.contents == rhs.contents
            && lhs.bounds == rhs.bounds
            && lhs.parentID == rhs.parentID
    }
}

public enum AnnotationKeys {
    public static let inReplyTo = PDFAnnotationKey(rawValue: "IRT")
    public static let replyType = PDFAnnotationKey(rawValue: "RT")
    public static let creationDate = PDFAnnotationKey(rawValue: "CreationDate")
    public static let state = PDFAnnotationKey(rawValue: "State")
    public static let stateModel = PDFAnnotationKey(rawValue: "StateModel")
    public static let appKind = PDFAnnotationKey(rawValue: "IHatePDFsKind")
    public static let appKindComment = "Comment"

    public static func stableID(
        for annotation: PDFAnnotation,
        pageIndex: Int,
        annotationIndex: Int
    ) -> String {
        if let name = annotation.value(forAnnotationKey: .name) as? String, !name.isEmpty {
            return name
        }

        let type = annotation.type ?? "Unknown"
        let rect = annotation.bounds
        return [
            "page-\(pageIndex + 1)",
            "annotation-\(annotationIndex)",
            type,
            String(format: "%.2f-%.2f-%.2f-%.2f", rect.minX, rect.minY, rect.width, rect.height)
        ].joined(separator: "-")
    }

    public static func parentID(
        for annotation: PDFAnnotation,
        document: PDFDocument?
    ) -> String? {
        if let parentID = annotation.value(forAnnotationKey: inReplyTo) as? String,
           !parentID.isEmpty {
            return parentID
        }

        guard let parent = annotation.value(forAnnotationKey: inReplyTo) as? PDFAnnotation else {
            return nil
        }

        guard let page = parent.page,
              let document,
              document.index(for: page) != NSNotFound
        else {
            return parent.value(forAnnotationKey: .name) as? String
        }

        let pageIndex = document.index(for: page)
        let annotationIndex = page.annotations.firstIndex(where: { $0 === parent }) ?? 0
        return stableID(for: parent, pageIndex: pageIndex, annotationIndex: annotationIndex)
    }

    public static func isReply(_ annotation: PDFAnnotation) -> Bool {
        annotation.value(forAnnotationKey: inReplyTo) is PDFAnnotation
            || annotation.value(forAnnotationKey: inReplyTo) is String
    }

    public static func annotation(_ annotation: PDFAnnotation, hasSubtype subtype: PDFAnnotationSubtype) -> Bool {
        guard let type = annotation.type else { return false }
        let raw = subtype.rawValue
        let normalized = raw.hasPrefix("/") ? String(raw.dropFirst()) : raw
        return type == raw || type == normalized
    }

    public static func pdfDateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "'D:'yyyyMMddHHmmss'Z00''00'''"
        return formatter.string(from: date)
    }

    public static func dateValue(for key: PDFAnnotationKey, in annotation: PDFAnnotation) -> Date? {
        if let date = annotation.value(forAnnotationKey: key) as? Date {
            return date
        }

        guard let value = annotation.value(forAnnotationKey: key) as? String else {
            return nil
        }

        return parsePDFDate(value)
    }

    private static func parsePDFDate(_ value: String) -> Date? {
        let normalized = value
            .replacingOccurrences(of: "Z00'00'", with: "Z")
            .replacingOccurrences(of: "Z00\\'00\\'", with: "Z")
        let formats = [
            "'D:'yyyyMMddHHmmss'Z'",
            "'D:'yyyyMMddHHmmss",
            "yyyy-MM-dd'T'HH:mm:ssZ"
        ]

        for format in formats {
            let formatter = DateFormatter()
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = format
            if let date = formatter.date(from: normalized) {
                return date
            }
        }

        return nil
    }
}

public enum AnnotationReader {
    public static func snapshots(in document: PDFDocument) -> [AnnotationSnapshot] {
        var result: [AnnotationSnapshot] = []

        for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex) else { continue }

            for (annotationIndex, annotation) in page.annotations.enumerated() {
                guard !AnnotationKeys.annotation(annotation, hasSubtype: .popup) else { continue }

                let kind = AcademicAnnotationKind(annotation: annotation)
                guard kind != .other || annotation.contents?.isEmpty == false else { continue }

                let id = AnnotationKeys.stableID(
                    for: annotation,
                    pageIndex: pageIndex,
                    annotationIndex: annotationIndex
                )
                let pageLabel = page.label ?? "\(pageIndex + 1)"
                let author = annotation.userName
                    ?? annotation.value(forAnnotationKey: .textLabel) as? String
                    ?? "Unknown"
                let createdAt = AnnotationKeys.dateValue(for: AnnotationKeys.creationDate, in: annotation)
                    ?? annotation.modificationDate
                let status = annotation.value(forAnnotationKey: AnnotationKeys.state) as? String
                    ?? "Unmarked"
                let parentID = AnnotationKeys.parentID(for: annotation, document: document)

                result.append(
                    AnnotationSnapshot(
                        id: id,
                        pageIndex: pageIndex,
                        pageLabel: pageLabel,
                        annotationIndex: annotationIndex,
                        kind: kind,
                        author: author,
                        createdAt: createdAt,
                        modifiedAt: annotation.modificationDate,
                        status: status,
                        contents: annotation.contents ?? "",
                        bounds: annotation.bounds,
                        annotation: annotation,
                        page: page,
                        parentID: parentID
                    )
                )
            }
        }

        return result.sorted { left, right in
            if left.pageIndex != right.pageIndex {
                return left.pageIndex < right.pageIndex
            }
            if left.bounds.maxY != right.bounds.maxY {
                return left.bounds.maxY > right.bounds.maxY
            }
            return left.bounds.minX < right.bounds.minX
        }
    }
}
