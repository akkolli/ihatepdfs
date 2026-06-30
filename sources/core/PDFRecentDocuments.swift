import Foundation

public struct PDFRecentDocumentProgress {
    public var key: String
    public var pageIndex: Int
    public var openedAt: Date

    public init(key: String, pageIndex: Int, openedAt: Date) {
        self.key = key
        self.pageIndex = pageIndex
        self.openedAt = openedAt
    }
}

public enum PDFRecentDocuments {
    public static func filteredPDFs(
        from urls: [URL],
        currentURL: URL? = nil,
        limit: Int,
        fileExists: (URL) -> Bool = { FileManager.default.fileExists(atPath: $0.path) }
    ) -> [URL] {
        guard limit > 0 else { return [] }

        var result: [URL] = []
        var seen = Set<URL>()
        let current = currentURL.map(normalized)

        for url in urls {
            let normalizedURL = normalized(url)
            guard normalizedURL != current,
                  seen.insert(normalizedURL).inserted,
                  PDFFileSelection.isPDFFileURL(normalizedURL),
                  fileExists(normalizedURL)
            else {
                continue
            }

            result.append(normalizedURL)
            if result.count == limit {
                break
            }
        }

        return result
    }

    public static func documentKey(for url: URL) -> String {
        normalized(url).path
    }

    public static func progress(
        for url: URL,
        in records: [String: PDFRecentDocumentProgress]
    ) -> PDFRecentDocumentProgress? {
        records[documentKey(for: url)]
    }

    public static func updatedProgress(
        _ records: [String: PDFRecentDocumentProgress],
        url: URL,
        pageIndex: Int,
        openedAt: Date
    ) -> [String: PDFRecentDocumentProgress] {
        let key = documentKey(for: url)
        var copy = records
        copy[key] = PDFRecentDocumentProgress(
            key: key,
            pageIndex: max(0, pageIndex),
            openedAt: openedAt
        )
        return copy
    }

    public static func clampedPageIndex(_ pageIndex: Int?, pageCount: Int) -> Int {
        guard pageCount > 0, let pageIndex else { return 0 }
        return min(max(0, pageIndex), pageCount - 1)
    }

    static func normalized(_ url: URL) -> URL {
        url.standardizedFileURL
    }
}
