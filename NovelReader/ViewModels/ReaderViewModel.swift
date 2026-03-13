import SwiftUI

@MainActor
@Observable
class ReaderViewModel {
    var chapters: [Chapter] = []
    var currentChapterIndex: Int = 0
    var pages: [String] = []
    var currentPageIndex: Int = 0
    var showSettings = false
    var showChapterList = false

    private var shouldGoToLastPage = false

    var fontSize: CGFloat = 18 {
        didSet { UserDefaults.standard.set(Double(fontSize), forKey: "readerFontSize") }
    }
    var lineSpacing: CGFloat = 8 {
        didSet { UserDefaults.standard.set(Double(lineSpacing), forKey: "readerLineSpacing") }
    }
    var theme: ReaderTheme = .light {
        didSet { UserDefaults.standard.set(theme.rawValue, forKey: "readerTheme") }
    }

    var currentChapter: Chapter? {
        guard chapters.indices.contains(currentChapterIndex) else { return nil }
        return chapters[currentChapterIndex]
    }

    var chapterTitle: String {
        currentChapter?.title ?? ""
    }

    var currentPageContent: AttributedString {
        guard pages.indices.contains(currentPageIndex) else { return AttributedString("") }
        return MarkdownParser.renderMarkdown(pages[currentPageIndex])
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

        currentChapterIndex = min(book.lastReadChapterIndex, max(chapters.count - 1, 0))
        book.totalChapters = chapters.count
    }

    // MARK: - Pagination

    func paginateCurrentChapter(in size: CGSize) {
        guard let chapter = currentChapter else {
            pages = []
            return
        }
        let fullText = "**\(chapter.title)**\n\n\(chapter.content)"
        pages = TextPaginator.paginate(
            fullText,
            fontSize: fontSize,
            lineSpacing: lineSpacing,
            pageSize: size
        )
        if shouldGoToLastPage {
            currentPageIndex = max(0, pages.count - 1)
            shouldGoToLastPage = false
        } else {
            currentPageIndex = 0
        }
    }

    // MARK: - Page Navigation

    func nextPage() {
        if currentPageIndex < pages.count - 1 {
            currentPageIndex += 1
        } else if currentChapterIndex < chapters.count - 1 {
            currentChapterIndex += 1
        }
    }

    func previousPage() {
        if currentPageIndex > 0 {
            currentPageIndex -= 1
        } else if currentChapterIndex > 0 {
            shouldGoToLastPage = true
            currentChapterIndex -= 1
        }
    }

    // MARK: - Chapter Navigation (for chapter list)

    func goToChapter(_ index: Int) {
        guard chapters.indices.contains(index) else { return }
        shouldGoToLastPage = false
        currentChapterIndex = index
        currentPageIndex = 0
    }

    func saveProgress(for book: Book) {
        book.lastReadChapterIndex = currentChapterIndex
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
