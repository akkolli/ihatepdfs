import Foundation

public struct PDFDocumentBookmark {
    public var id: String
    public var pageIndex: Int
    public var pageLabel: String
    public var title: String
    public var createdAt: Date

    public init(
        id: String = UUID().uuidString,
        pageIndex: Int,
        pageLabel: String,
        title: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.pageIndex = pageIndex
        self.pageLabel = pageLabel
        self.title = title
        self.createdAt = createdAt
    }
}

public enum PDFDocumentBookmarks {
    public static func sorted(_ bookmarks: [PDFDocumentBookmark]) -> [PDFDocumentBookmark] {
        preferredBookmark(in: bookmarks).map { [$0] } ?? []
    }

    public static func upsert(
        _ bookmark: PDFDocumentBookmark,
        in _: [PDFDocumentBookmark]
    ) -> [PDFDocumentBookmark] {
        [bookmark]
    }

    public static func removing(id: String, from bookmarks: [PDFDocumentBookmark]) -> [PDFDocumentBookmark] {
        sorted(bookmarks.filter { $0.id != id })
    }

    public static func bookmark(on pageIndex: Int, in bookmarks: [PDFDocumentBookmark]) -> PDFDocumentBookmark? {
        sorted(bookmarks).first { $0.pageIndex == pageIndex }
    }

    public static func clamped(
        _ bookmarks: [PDFDocumentBookmark],
        pageCount: Int
    ) -> [PDFDocumentBookmark] {
        guard pageCount > 0 else { return [] }
        return sorted(bookmarks.filter { (0..<pageCount).contains($0.pageIndex) })
    }

    private static func preferredBookmark(in bookmarks: [PDFDocumentBookmark]) -> PDFDocumentBookmark? {
        bookmarks.max {
            if $0.createdAt != $1.createdAt {
                return $0.createdAt < $1.createdAt
            }
            return $0.pageIndex < $1.pageIndex
        }
    }
}
