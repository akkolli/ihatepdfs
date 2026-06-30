import AppKit
import CoreGraphics
import Foundation
import PDFKit

let defaultInputPath = "dist/annotation-verification.pdf"
let arguments = Array(CommandLine.arguments.dropFirst())
let inputURL = URL(fileURLWithPath: arguments.first ?? defaultInputPath)
let verificationDate = Date(timeIntervalSince1970: 1_797_000_000)

if arguments.isEmpty {
    try generateVerificationPDF(at: inputURL)
}

struct AnnotationSummary {
    var highlights = 0
    var selectedTextComments = 0
    var underlines = 0
    var textNotes = 0
    var replies = 0
    var freeText = 0
    var popups = 0
}

enum VerificationError: Error, CustomStringConvertible {
    case unreadablePDF(String)
    case missingPageAnnotations(Int)
    case missingDictionary(page: Int, index: Int)
    case missingName(page: Int, index: Int, key: String)
    case missingString(page: Int, index: Int, key: String)
    case missingArray(page: Int, index: Int, key: String)
    case missingPopupParent(page: Int, index: Int)
    case unexpectedMarkupPopup(page: Int, index: Int, subtype: String)
    case unexpectedPopupLink(page: Int, index: Int, subtype: String)
    case missingExpectedSubtype(String)

    var description: String {
        switch self {
        case .unreadablePDF(let path):
            return "Unable to read PDF at \(path)"
        case .missingPageAnnotations(let page):
            return "Page \(page) has no /Annots array"
        case .missingDictionary(let page, let index):
            return "Annotation \(index) on page \(page) is not a dictionary"
        case .missingName(let page, let index, let key):
            return "Annotation \(index) on page \(page) is missing name key /\(key)"
        case .missingString(let page, let index, let key):
            return "Annotation \(index) on page \(page) is missing string key /\(key)"
        case .missingArray(let page, let index, let key):
            return "Annotation \(index) on page \(page) is missing array key /\(key)"
        case .missingPopupParent(let page, let index):
            return "Popup annotation \(index) on page \(page) is missing a /Parent dictionary"
        case .unexpectedMarkupPopup(let page, let index, let subtype):
            return "Popup annotation \(index) on page \(page) points at a /\(subtype) markup annotation; markup comments should export through /Contents"
        case .unexpectedPopupLink(let page, let index, let subtype):
            return "\(subtype) annotation \(index) on page \(page) should store comments in /Contents, not a /Popup link"
        case .missingExpectedSubtype(let subtype):
            return "Expected at least one /\(subtype) annotation"
        }
    }
}

guard let document = CGPDFDocument(inputURL as CFURL) else {
    throw VerificationError.unreadablePDF(inputURL.path)
}

var summary = AnnotationSummary()

for pageNumber in 1...document.numberOfPages {
    guard let page = document.page(at: pageNumber),
          let pageDictionary = page.dictionary
    else {
        continue
    }

    var annotationsArray: CGPDFArrayRef?
    guard CGPDFDictionaryGetArray(pageDictionary, "Annots", &annotationsArray),
          let annotationsArray
    else {
        continue
    }

    for annotationIndex in 0..<CGPDFArrayGetCount(annotationsArray) {
        let annotation = try annotationDictionary(
            in: annotationsArray,
            at: annotationIndex,
            page: pageNumber
        )
        let subtype = try nameValue(
            in: annotation,
            key: "Subtype",
            page: pageNumber,
            index: annotationIndex
        )

        switch subtype {
        case "Highlight":
            try requireMarkupKeys(in: annotation, page: pageNumber, index: annotationIndex)
            try rejectPopupLink(in: annotation, subtype: subtype, page: pageNumber, index: annotationIndex)
            if hasString(in: annotation, key: "IHatePDFsKind") {
                try requireString(in: annotation, key: "IHatePDFsKind", page: pageNumber, index: annotationIndex)
                summary.selectedTextComments += 1
            } else {
                summary.highlights += 1
            }
        case "Underline":
            summary.underlines += 1
            try requireMarkupKeys(in: annotation, page: pageNumber, index: annotationIndex)
            try rejectPopupLink(in: annotation, subtype: subtype, page: pageNumber, index: annotationIndex)
        case "Text":
            try requireTextKeys(in: annotation, page: pageNumber, index: annotationIndex)

            if hasString(in: annotation, key: "IRT") || hasString(in: annotation, key: "RT") {
                summary.replies += 1
                try requireString(in: annotation, key: "IRT", page: pageNumber, index: annotationIndex)
                try requireString(in: annotation, key: "RT", page: pageNumber, index: annotationIndex)
            } else {
                summary.textNotes += 1
            }
        case "FreeText":
            summary.freeText += 1
            try requireString(in: annotation, key: "Contents", page: pageNumber, index: annotationIndex)
            try requireString(in: annotation, key: "T", page: pageNumber, index: annotationIndex)
            try requireString(in: annotation, key: "M", page: pageNumber, index: annotationIndex)
            try requireString(in: annotation, key: "DA", page: pageNumber, index: annotationIndex)
            try requireArray(in: annotation, key: "C", page: pageNumber, index: annotationIndex)
            try requireArray(in: annotation, key: "Rect", page: pageNumber, index: annotationIndex)
        case "Popup":
            summary.popups += 1
            var parentDictionary: CGPDFDictionaryRef?
            guard CGPDFDictionaryGetDictionary(annotation, "Parent", &parentDictionary),
                  let parentDictionary
            else {
                throw VerificationError.missingPopupParent(page: pageNumber, index: annotationIndex)
            }
            let parentSubtype = try nameValue(
                in: parentDictionary,
                key: "Subtype",
                page: pageNumber,
                index: annotationIndex
            )
            if parentSubtype == "Highlight" || parentSubtype == "Underline" {
                throw VerificationError.unexpectedMarkupPopup(
                    page: pageNumber,
                    index: annotationIndex,
                    subtype: parentSubtype
                )
            }
        default:
            continue
        }
    }
}

guard summary.highlights > 0 else {
    throw VerificationError.missingExpectedSubtype("Highlight")
}
guard summary.selectedTextComments > 0 else {
    throw VerificationError.missingExpectedSubtype("selected-text Comment")
}
guard summary.underlines > 0 else {
    throw VerificationError.missingExpectedSubtype("Underline")
}
guard summary.textNotes > 0 else {
    throw VerificationError.missingExpectedSubtype("Text")
}
guard summary.replies > 0 else {
    throw VerificationError.missingExpectedSubtype("Text reply")
}
guard summary.freeText > 0 else {
    throw VerificationError.missingExpectedSubtype("FreeText")
}
print("Verified raw PDF annotation dictionaries in \(inputURL.path): \(summary.highlights) highlight, \(summary.selectedTextComments) selected-text comment, \(summary.underlines) underline, \(summary.textNotes) text note, \(summary.replies) reply, \(summary.freeText) free-text, \(summary.popups) popups.")

func annotationDictionary(
    in array: CGPDFArrayRef,
    at index: Int,
    page: Int
) throws -> CGPDFDictionaryRef {
    var object: CGPDFObjectRef?
    guard CGPDFArrayGetObject(array, index, &object),
          let object
    else {
        throw VerificationError.missingDictionary(page: page, index: index)
    }

    var dictionary: CGPDFDictionaryRef?
    guard CGPDFObjectGetValue(object, .dictionary, &dictionary),
          let dictionary
    else {
        throw VerificationError.missingDictionary(page: page, index: index)
    }

    return dictionary
}

func nameValue(
    in dictionary: CGPDFDictionaryRef,
    key: String,
    page: Int,
    index: Int
) throws -> String {
    var name: UnsafePointer<Int8>?
    guard CGPDFDictionaryGetName(dictionary, key, &name),
          let name
    else {
        throw VerificationError.missingName(page: page, index: index, key: key)
    }

    return String(cString: name)
}

func requireString(
    in dictionary: CGPDFDictionaryRef,
    key: String,
    page: Int,
    index: Int
) throws {
    var value: CGPDFStringRef?
    guard CGPDFDictionaryGetString(dictionary, key, &value),
          value != nil
    else {
        throw VerificationError.missingString(page: page, index: index, key: key)
    }
}

func requireName(
    in dictionary: CGPDFDictionaryRef,
    key: String,
    page: Int,
    index: Int
) throws {
    var value: UnsafePointer<Int8>?
    guard CGPDFDictionaryGetName(dictionary, key, &value),
          value != nil
    else {
        throw VerificationError.missingName(page: page, index: index, key: key)
    }
}

func hasString(
    in dictionary: CGPDFDictionaryRef,
    key: String
) -> Bool {
    var value: CGPDFStringRef?
    return CGPDFDictionaryGetString(dictionary, key, &value) && value != nil
}

func requireArray(
    in dictionary: CGPDFDictionaryRef,
    key: String,
    page: Int,
    index: Int
) throws {
    var value: CGPDFArrayRef?
    guard CGPDFDictionaryGetArray(dictionary, key, &value),
          value != nil
    else {
        throw VerificationError.missingArray(page: page, index: index, key: key)
    }
}

func requireMarkupKeys(
    in dictionary: CGPDFDictionaryRef,
    page: Int,
    index: Int
) throws {
    try requireString(in: dictionary, key: "Contents", page: page, index: index)
    try requireArray(in: dictionary, key: "QuadPoints", page: page, index: index)
    try requireArray(in: dictionary, key: "C", page: page, index: index)
    try requireString(in: dictionary, key: "T", page: page, index: index)
    try requireString(in: dictionary, key: "M", page: page, index: index)
}

func rejectPopupLink(
    in dictionary: CGPDFDictionaryRef,
    subtype: String,
    page: Int,
    index: Int
) throws {
    var popupDictionary: CGPDFDictionaryRef?
    guard CGPDFDictionaryGetDictionary(dictionary, "Popup", &popupDictionary) else {
        return
    }

    throw VerificationError.unexpectedPopupLink(page: page, index: index, subtype: subtype)
}

func requireTextKeys(
    in dictionary: CGPDFDictionaryRef,
    page: Int,
    index: Int
) throws {
    try requireString(in: dictionary, key: "Contents", page: page, index: index)
    try requireName(in: dictionary, key: "Name", page: page, index: index)
    try requireArray(in: dictionary, key: "C", page: page, index: index)
    try requireString(in: dictionary, key: "T", page: page, index: index)
    try requireString(in: dictionary, key: "M", page: page, index: index)
}

func generateVerificationPDF(at outputURL: URL) throws {
    try FileManager.default.createDirectory(
        at: outputURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )

    let page = PDFPage()
    let document = PDFDocument()
    document.insert(page, at: 0)

    let highlight = PDFAnnotation(
        bounds: CGRect(x: 72, y: 620, width: 260, height: 24),
        forType: .highlight,
        withProperties: nil
    )
    highlight.markupType = .highlight
    highlight.color = NSColor(calibratedRed: 0.88, green: 0.72, blue: 0.46, alpha: 0.24)
    highlight.quadrilateralPoints = quadPoints(width: 260, height: 24)
    standardize(
        highlight,
        name: "verify-highlight",
        contents: "This is a standards-compliant PDF highlight comment.",
        author: "Professor"
    )
    page.addAnnotation(highlight)

    let selectedTextComment = PDFAnnotation(
        bounds: CGRect(x: 72, y: 594, width: 260, height: 22),
        forType: .highlight,
        withProperties: nil
    )
    selectedTextComment.markupType = .highlight
    selectedTextComment.color = NSColor(calibratedRed: 0.88, green: 0.72, blue: 0.46, alpha: 0.10)
    selectedTextComment.quadrilateralPoints = quadPoints(width: 260, height: 22)
    standardize(
        selectedTextComment,
        name: "verify-selected-text-comment",
        contents: "This selected-text comment is saved as standard parent annotation contents.",
        author: "Professor"
    )
    _ = selectedTextComment.setValue("Comment", forAnnotationKey: PDFAnnotationKey(rawValue: "IHatePDFsKind"))
    page.addAnnotation(selectedTextComment)

    let underline = PDFAnnotation(
        bounds: CGRect(x: 72, y: 570, width: 260, height: 24),
        forType: .underline,
        withProperties: nil
    )
    underline.markupType = .underline
    underline.color = NSColor(calibratedRed: 0.48, green: 0.53, blue: 0.62, alpha: 0.56)
    underline.quadrilateralPoints = quadPoints(width: 260, height: 24)
    standardize(
        underline,
        name: "verify-underline",
        contents: "This underline comment should remain openable.",
        author: "Professor"
    )
    page.addAnnotation(underline)

    let textNote = PDFAnnotation(
        bounds: CGRect(x: 360, y: 620, width: 28, height: 28),
        forType: .text,
        withProperties: nil
    )
    textNote.iconType = .note
    textNote.color = NSColor(calibratedRed: 0.64, green: 0.59, blue: 0.49, alpha: 0.90)
    standardize(
        textNote,
        name: "verify-text-note",
        contents: "This standard PDF text annotation remains visible in common PDF readers.",
        author: "Professor"
    )
    page.addAnnotation(textNote)

    let reply = PDFAnnotation(
        bounds: CGRect(x: 402, y: 586, width: 24, height: 24),
        forType: .text,
        withProperties: nil
    )
    reply.iconType = .comment
    reply.color = NSColor(calibratedRed: 0.52, green: 0.58, blue: 0.60, alpha: 0.88)
    standardize(
        reply,
        name: "verify-reply",
        contents: "This reply is saved as PDF reply data without drawing an extra page icon.",
        author: "Reader"
    )
    _ = reply.setValue("verify-text-note", forAnnotationKey: PDFAnnotationKey(rawValue: "IRT"))
    _ = reply.setValue("R", forAnnotationKey: PDFAnnotationKey(rawValue: "RT"))
    reply.shouldDisplay = false
    reply.shouldPrint = false
    page.addAnnotation(reply)

    let freeText = PDFAnnotation(
        bounds: CGRect(x: 72, y: 500, width: 260, height: 50),
        forType: .freeText,
        withProperties: nil
    )
    freeText.font = NSFont.systemFont(ofSize: 13)
    freeText.fontColor = NSColor(calibratedWhite: 0.22, alpha: 1)
    freeText.color = NSColor(calibratedRed: 0.91, green: 0.86, blue: 0.75, alpha: 0.32)
    freeText.alignment = .left
    let border = PDFBorder()
    border.lineWidth = 0.75
    freeText.border = border
    standardize(
        freeText,
        name: "verify-free-text",
        contents: "Free text remains visible on the PDF page.",
        author: "Professor"
    )
    page.addAnnotation(freeText)

    guard document.write(to: outputURL) else {
        fatalError("Unable to write \(outputURL.path)")
    }

    let reopened = PDFDocument(url: outputURL)!
    let annotations = reopened.page(at: 0)!.annotations
    precondition(annotations.contains { matches($0, .highlight) && $0.contents?.contains("highlight") == true })
    precondition(annotations.contains { matches($0, .highlight) && $0.contents?.contains("selected-text comment") == true })
    precondition(annotations.contains { matches($0, .underline) && $0.contents?.contains("underline") == true })
    precondition(annotations.contains { matches($0, .text) && $0.contents?.contains("text annotation") == true })
    precondition(annotations.contains { matches($0, .text) && $0.contents?.contains("reply") == true && !$0.shouldDisplay && !$0.shouldPrint })
    precondition(annotations.contains { matches($0, .freeText) && $0.contents?.contains("Free text") == true })
}

func standardize(
    _ annotation: PDFAnnotation,
    name: String,
    contents: String,
    author: String
) {
    annotation.contents = contents
    annotation.userName = author
    annotation.modificationDate = verificationDate
    annotation.shouldDisplay = true
    annotation.shouldPrint = true
    _ = annotation.setValue(name, forAnnotationKey: .name)
    _ = annotation.setValue(author, forAnnotationKey: .textLabel)
    _ = annotation.setValue(verificationDate, forAnnotationKey: .date)
    _ = annotation.setValue("D:20261215132000Z00'00'", forAnnotationKey: PDFAnnotationKey(rawValue: "CreationDate"))
    _ = annotation.setValue("Unmarked", forAnnotationKey: PDFAnnotationKey(rawValue: "State"))
}

func quadPoints(width: CGFloat, height: CGFloat) -> [NSValue] {
    [
        NSValue(point: CGPoint(x: 0, y: height)),
        NSValue(point: CGPoint(x: width, y: height)),
        NSValue(point: CGPoint(x: 0, y: 0)),
        NSValue(point: CGPoint(x: width, y: 0))
    ]
}

func matches(_ annotation: PDFAnnotation, _ subtype: PDFAnnotationSubtype) -> Bool {
    guard let type = annotation.type else { return false }
    let raw = subtype.rawValue
    let normalized = raw.hasPrefix("/") ? String(raw.dropFirst()) : raw
    return type == raw || type == normalized
}
