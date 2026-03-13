import SwiftUI
import SwiftData

@MainActor
@Observable
class ReaderViewModel {
    var chapters: [Chapter] = []
    var renderedPages: [AttributedString] = []
    var currentPageIndex: Int = 0
    var showSettings = false
    var showChapterList = false

    /// Maps each page index to its chapter index
    private(set) var pageToChapter: [Int] = []
    /// Maps each chapter index to its first page index
    private(set) var chapterFirstPage: [Int] = []

    var totalPages: Int { renderedPages.count }

    var fontSize: CGFloat = 18 {
        didSet { UserDefaults.standard.set(Double(fontSize), forKey: "readerFontSize") }
    }
    var lineSpacing: CGFloat = 8 {
        didSet { UserDefaults.standard.set(Double(lineSpacing), forKey: "readerLineSpacing") }
    }
    var theme: ReaderTheme = .light {
        didSet { UserDefaults.standard.set(theme.rawValue, forKey: "readerTheme") }
    }

    var currentChapterIndex: Int {
        guard pageToChapter.indices.contains(currentPageIndex) else { return 0 }
        return pageToChapter[currentPageIndex]
    }

    var chapterTitle: String {
        let idx = currentChapterIndex
        guard chapters.indices.contains(idx) else { return "" }
        return chapters[idx].title
    }

    var currentPageContent: AttributedString {
        guard renderedPages.indices.contains(currentPageIndex) else { return AttributedString("") }
        return renderedPages[currentPageIndex]
    }

    init() {
        let savedFontSize = UserDefaults.standard.double(forKey: "readerFontSize")
        if savedFontSize > 0 { fontSize = CGFloat(savedFontSize) }

        let savedLineSpacing = UserDefaults.standard.double(forKey: "readerLineSpacing")
        if savedLineSpacing > 0 { lineSpacing = CGFloat(savedLineSpacing) }

        if let savedTheme = UserDefaults.standard.string(forKey: "readerTheme"),
           let restored = ReaderTheme(rawValue: savedTheme) {
            theme = restored
        }
    }

    // MARK: - Loading

    func loadBook(_ book: Book, volumeFileName: String? = nil) {
        let baseURL: URL?
        if book.isBundled {
            baseURL = Bundle.main.url(forResource: "Books", withExtension: nil)
        } else {
            baseURL = FileManager.default.urls(
                for: .documentDirectory, in: .userDomainMask
            ).first
        }
        guard let base = baseURL else { return }

        let bookPath = base.appendingPathComponent(book.fileName)

        if let volumeFileName {
            let fileURL = bookPath.appendingPathComponent(volumeFileName)
            guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else { return }
            chapters = MarkdownParser.parseChapters(from: content)
        } else if book.fileName.hasSuffix(".md") {
            guard let content = try? String(contentsOf: bookPath, encoding: .utf8) else { return }
            chapters = MarkdownParser.parseChapters(from: content)
        } else {
            chapters = loadChaptersFromFolder(bookPath)
        }

        book.totalChapters = chapters.count
        savedChapterIndex = min(book.lastReadChapterIndex, max(chapters.count - 1, 0))
    }

    /// Stored to restore position after pagination
    private var savedChapterIndex: Int = 0

    // MARK: - Pagination

    func paginateAll(in size: CGSize) {
        guard !chapters.isEmpty, size.width > 0, size.height > 0 else {
            renderedPages = []
            pageToChapter = []
            chapterFirstPage = []
            return
        }

        var allRendered: [AttributedString] = []
        var allPageToChapter: [Int] = []
        var allChapterFirstPage: [Int] = []

        for (chapterIdx, chapter) in chapters.enumerated() {
            allChapterFirstPage.append(allRendered.count)

            let fullText = "**\(chapter.title)**\n\n\(chapter.content)"
            let rawPages = TextPaginator.paginate(
                fullText,
                fontSize: fontSize,
                lineSpacing: lineSpacing,
                pageSize: size
            )

            for raw in rawPages {
                allRendered.append(MarkdownParser.renderMarkdown(raw))
                allPageToChapter.append(chapterIdx)
            }
        }

        renderedPages = allRendered
        pageToChapter = allPageToChapter
        chapterFirstPage = allChapterFirstPage

        if chapterFirstPage.indices.contains(savedChapterIndex) {
            currentPageIndex = chapterFirstPage[savedChapterIndex]
        } else {
            currentPageIndex = 0
        }
        savedChapterIndex = 0
    }

    func repaginate(in size: CGSize) {
        let oldChapterIdx = currentChapterIndex
        savedChapterIndex = oldChapterIdx
        paginateAll(in: size)
    }

    // MARK: - Page Navigation

    func nextPage() {
        guard currentPageIndex < renderedPages.count - 1 else { return }
        currentPageIndex += 1
    }

    func previousPage() {
        guard currentPageIndex > 0 else { return }
        currentPageIndex -= 1
    }

    // MARK: - Chapter Navigation (for chapter list)

    func goToChapter(_ index: Int) {
        guard chapterFirstPage.indices.contains(index) else { return }
        currentPageIndex = chapterFirstPage[index]
    }

    func saveProgress(for book: Book) {
        book.lastReadChapterIndex = currentChapterIndex
    }

    // MARK: - Bookmarks

    var bookFileName: String = ""
    var volumeFileName: String?

    func isBookmarked(in context: ModelContext) -> Bool {
        let pageIdx = currentPageIndex
        let bookFile = bookFileName
        let volFile = volumeFileName
        let predicate = #Predicate<Bookmark> {
            $0.bookFileName == bookFile && $0.volumeFileName == volFile && $0.pageIndex == pageIdx
        }
        let descriptor = FetchDescriptor<Bookmark>(predicate: predicate)
        return (try? context.fetchCount(descriptor)) ?? 0 > 0
    }

    func toggleBookmark(in context: ModelContext) {
        let pageIdx = currentPageIndex
        let bookFile = bookFileName
        let volFile = volumeFileName
        let predicate = #Predicate<Bookmark> {
            $0.bookFileName == bookFile && $0.volumeFileName == volFile && $0.pageIndex == pageIdx
        }
        let descriptor = FetchDescriptor<Bookmark>(predicate: predicate)

        if let existing = try? context.fetch(descriptor), !existing.isEmpty {
            for item in existing { context.delete(item) }
        } else {
            let bookmark = Bookmark(
                bookFileName: bookFileName,
                volumeFileName: volumeFileName,
                pageIndex: pageIdx,
                chapterTitle: chapterTitle
            )
            context.insert(bookmark)
        }
    }

    // MARK: - Folder Loading

    private func loadChaptersFromFolder(_ folderURL: URL) -> [Chapter] {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return [] }

        let mdFiles = contents
            .filter { $0.pathExtension.lowercased() == "md" }
            .sorted { MarkdownParser.fileSortKey($0.lastPathComponent) < MarkdownParser.fileSortKey($1.lastPathComponent) }

        var allChapters: [Chapter] = []
        for file in mdFiles {
            guard let content = try? String(contentsOf: file, encoding: .utf8) else { continue }
            allChapters.append(contentsOf: MarkdownParser.parseChapters(from: content))
        }
        return allChapters
    }
}

enum ReaderTheme: String, CaseIterable {
    case light = "浅色"
    case sepia = "护眼"
    case dark = "深色"

    var backgroundColor: Color {
        switch self {
        case .light: return .white
        case .sepia: return Color(red: 0.96, green: 0.93, blue: 0.87)
        case .dark: return Color(red: 0.12, green: 0.12, blue: 0.14)
        }
    }

    var textColor: Color {
        switch self {
        case .light: return Color(white: 0.1)
        case .sepia: return Color(red: 0.35, green: 0.28, blue: 0.22)
        case .dark: return Color(red: 0.82, green: 0.82, blue: 0.84)
        }
    }
}
