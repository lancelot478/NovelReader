import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct BookshelfView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Book.addedDate, order: .reverse) private var books: [Book]
    @State private var showFileImporter = false

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        NavigationStack {
            Group {
                if books.isEmpty {
                    ContentUnavailableView {
                        Label("书架空空如也", systemImage: "book.closed")
                    } description: {
                        Text("点击右上角 + 导入 Markdown 文件开始阅读")
                    }
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 20) {
                            ForEach(books) { book in
                                NavigationLink(value: book) {
                                    BookCardView(book: book)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    if !book.isBundled {
                                        Button(role: .destructive) {
                                            deleteBook(book)
                                        } label: {
                                            Label("删除", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("书架")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showFileImporter = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.plainText],
                allowsMultipleSelection: true
            ) { result in
                handleFileImport(result)
            }
            .navigationDestination(for: Book.self) { book in
                if book.fileName.hasSuffix(".md") {
                    ReaderView(book: book)
                } else {
                    VolumeListView(book: book)
                }
            }
            .task {
                importBundledBooks()
            }
        }
    }

    // MARK: - Bundled Book Import

    private func importBundledBooks() {
        guard let booksURL = Bundle.main.url(forResource: "Books", withExtension: nil) else { return }
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: booksURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        let existingNames = Set(books.map(\.fileName))

        for url in contents {
            let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false

            if isDir {
                let folderName = url.lastPathComponent
                guard !existingNames.contains(folderName) else { continue }

                let book = Book(title: folderName, fileName: folderName, isBundled: true)
                book.totalChapters = countChaptersInFolder(url)
                modelContext.insert(book)
            } else if url.pathExtension.lowercased() == "md" {
                let fileName = url.lastPathComponent
                guard !existingNames.contains(fileName) else { continue }

                let title = url.deletingPathExtension().lastPathComponent
                let book = Book(title: title, fileName: fileName, isBundled: true)
                if let content = try? String(contentsOf: url, encoding: .utf8) {
                    book.totalChapters = MarkdownParser.parseChapters(from: content).count
                }
                modelContext.insert(book)
            }
        }
    }

    private func countChaptersInFolder(_ folderURL: URL) -> Int {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        var total = 0
        for file in files where file.pathExtension.lowercased() == "md" {
            if let content = try? String(contentsOf: file, encoding: .utf8) {
                total += MarkdownParser.parseChapters(from: content).count
            }
        }
        return total
    }

    // MARK: - File Import

    private func handleFileImport(_ result: Result<[URL], any Error>) {
        guard case .success(let urls) = result else { return }
        for url in urls {
            importFile(url)
        }
    }

    private func importFile(_ url: URL) {
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }

        guard let documentsURL = FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask
        ).first else { return }

        let fileName = url.lastPathComponent
        let title = url.deletingPathExtension().lastPathComponent
        let destURL = documentsURL.appendingPathComponent(fileName)

        do {
            if FileManager.default.fileExists(atPath: destURL.path) {
                try FileManager.default.removeItem(at: destURL)
            }
            try FileManager.default.copyItem(at: url, to: destURL)

            let book = Book(title: title, fileName: fileName)
            if let content = try? String(contentsOf: destURL, encoding: .utf8) {
                book.totalChapters = MarkdownParser.parseChapters(from: content).count
            }
            modelContext.insert(book)
        } catch {
            print("导入失败: \(error.localizedDescription)")
        }
    }

    private func deleteBook(_ book: Book) {
        if let documentsURL = FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask
        ).first {
            let fileURL = documentsURL.appendingPathComponent(book.fileName)
            try? FileManager.default.removeItem(at: fileURL)
        }
        modelContext.delete(book)
    }
}

private struct BookCardView: View {
    let book: Book

    var body: some View {
        VStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hue: book.colorHue, saturation: 0.35, brightness: 0.9),
                            Color(hue: book.colorHue, saturation: 0.5, brightness: 0.7)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .aspectRatio(3 / 4, contentMode: .fit)
                .overlay {
                    VStack(spacing: 8) {
                        Text(book.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                            .padding(.horizontal, 8)

                        if book.totalChapters > 0 {
                            Text("\(book.totalChapters) 章")
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(0.8))
                        }
                    }
                }
                .shadow(color: .black.opacity(0.15), radius: 4, y: 2)

            Text(book.title)
                .font(.caption)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .foregroundStyle(.primary)
        }
    }
}
