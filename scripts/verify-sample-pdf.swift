import AppKit
import Foundation
import PDFKit

let outputURL = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "dist/annotation-verification.pdf")
try FileManager.default.createDirectory(
    at: outputURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
)

let page = PDFPage()
let document = PDFDocument()
document.insert(page, at: 0)

let verificationDate = Date(timeIntervalSince1970: 1_797_000_000)

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

print("Verified standard PDF annotations in \(outputURL.path)")

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
