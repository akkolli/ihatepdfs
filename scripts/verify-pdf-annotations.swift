import CoreGraphics
import Foundation

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
    case missingPopup(page: Int, index: Int, subtype: String)
    case missingPopupParent(page: Int, index: Int)
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
        case .missingPopup(let page, let index, let subtype):
            return "\(subtype) annotation \(index) on page \(page) is missing a /Popup dictionary"
        case .missingPopupParent(let page, let index):
            return "Popup annotation \(index) on page \(page) is missing a /Parent dictionary"
        case .missingExpectedSubtype(let subtype):
            return "Expected at least one /\(subtype) annotation"
        }
    }
}

let inputPath = CommandLine.arguments.dropFirst().first ?? "dist/annotation-verification.pdf"
let inputURL = URL(fileURLWithPath: inputPath)

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
            try requirePopup(in: annotation, page: pageNumber, index: annotationIndex, subtype: "Highlight")
            if hasString(in: annotation, key: "IHatePDFsKind") {
                try requireString(in: annotation, key: "IHatePDFsKind", page: pageNumber, index: annotationIndex)
                summary.selectedTextComments += 1
            } else {
                summary.highlights += 1
            }
        case "Underline":
            summary.underlines += 1
            try requireMarkupKeys(in: annotation, page: pageNumber, index: annotationIndex)
            try requirePopup(in: annotation, page: pageNumber, index: annotationIndex, subtype: "Underline")
        case "Text":
            try requireTextKeys(in: annotation, page: pageNumber, index: annotationIndex)

            if hasString(in: annotation, key: "IRT") || hasString(in: annotation, key: "RT") {
                summary.replies += 1
                try requireString(in: annotation, key: "IRT", page: pageNumber, index: annotationIndex)
                try requireString(in: annotation, key: "RT", page: pageNumber, index: annotationIndex)
            } else {
                try requirePopup(in: annotation, page: pageNumber, index: annotationIndex, subtype: "Text")
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
            guard CGPDFDictionaryGetDictionary(annotation, "Parent", &parentDictionary) else {
                throw VerificationError.missingPopupParent(page: pageNumber, index: annotationIndex)
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
guard summary.popups >= 4 else {
    throw VerificationError.missingExpectedSubtype("Popup")
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

func requirePopup(
    in dictionary: CGPDFDictionaryRef,
    page: Int,
    index: Int,
    subtype: String
) throws {
    var popupDictionary: CGPDFDictionaryRef?
    guard CGPDFDictionaryGetDictionary(dictionary, "Popup", &popupDictionary),
          let popupDictionary
    else {
        throw VerificationError.missingPopup(page: page, index: index, subtype: subtype)
    }

    let popupSubtype = try nameValue(in: popupDictionary, key: "Subtype", page: page, index: index)
    guard popupSubtype == "Popup" else {
        throw VerificationError.missingPopup(page: page, index: index, subtype: subtype)
    }
}
