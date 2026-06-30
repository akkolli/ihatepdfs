import Foundation
import UniformTypeIdentifiers

public enum PDFFileSelection {
    public static func isPDFFileURL(_ url: URL) -> Bool {
        guard url.isFileURL else { return false }

        let resourceValues = try? url.resourceValues(forKeys: [.contentTypeKey, .isDirectoryKey])
        if resourceValues?.isDirectory == true {
            return false
        }

        if let contentType = resourceValues?.contentType {
            return contentType.conforms(to: .pdf)
        }

        return url.pathExtension.localizedCaseInsensitiveCompare("pdf") == .orderedSame
    }
}
