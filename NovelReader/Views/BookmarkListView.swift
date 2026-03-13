import SwiftUI
import SwiftData

struct BookmarkListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Bookmark.createdDate, order: .reverse) private var bookmarks: [Bookmark]
    @Query private var books: [Book]

    private var groupedBookmarks: [(String, [Bookmark])] {
        let dict = Dictionary(grouping: bookmarks) { $0.bookFileName }
        return dict.sorted { $0.key < $1.key }
    }

    var body: some View {
        NavigationStack {
            Group {
                if bookmarks.isEmpty {
                    ContentUnavailableView {
                        Label("暂无书签", systemImage: "bookmark")
                    } description: {
                        Text("阅读时下拉可添加书签")
                    }
                } else {
                    List {
                        ForEach(groupedBookmarks, id: \.0) { bookFileName, items in
                            Section(header: Text(bookDisplayTitle(for: bookFileName))) {
                                ForEach(items) { bookmark in
                                    if let book = findBook(for: bookmark.bookFileName) {
                                        NavigationLink {
                                            ReaderView(
                                                book: book,
                                                volumeFileName: bookmark.volumeFileName,
                                                initialPageIndex: bookmark.pageIndex
                                            )
                                        } label: {
                                            BookmarkRow(bookmark: bookmark)
                                        }
                                    }
                                }
                                .onDelete { offsets in
                                    deleteBookmarks(from: items, at: offsets)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("书签")
        }
    }

    private func bookDisplayTitle(for fileName: String) -> String {
        if let book = findBook(for: fileName) {
            return book.title
        }
        return fileName.replacingOccurrences(of: ".md", with: "")
    }

    private func findBook(for fileName: String) -> Book? {
        books.first { $0.fileName == fileName }
    }

    private func deleteBookmarks(from items: [Bookmark], at offsets: IndexSet) {
        for offset in offsets {
            modelContext.delete(items[offset])
        }
    }
}

private struct BookmarkRow: View {
    let bookmark: Bookmark

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "bookmark.fill")
                    .foregroundStyle(Color.accentColor)
                    .font(.caption)

                Text(bookmark.chapterTitle)
                    .font(.subheadline)
                    .lineLimit(1)
            }

            HStack(spacing: 12) {
                if let vol = bookmark.volumeFileName {
                    Text(vol.replacingOccurrences(of: ".md", with: ""))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Text("第 \(bookmark.pageIndex + 1) 页")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(bookmark.createdDate.formatted(.dateTime.month().day().hour().minute()))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }
}
