import SwiftUI

struct VolumeItem: Identifiable, Hashable {
    let id: String
    let displayName: String
    let chapterCount: Int
    let colorHue: Double
}

struct VolumeListView: View {
    let book: Book
    @State private var volumes: [VolumeItem] = []

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        Group {
            if volumes.isEmpty {
                ContentUnavailableView(
                    "暂无内容",
                    systemImage: "doc.text",
                    description: Text("该书籍文件夹下没有找到 Markdown 文件")
                )
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 20) {
                        ForEach(volumes) { volume in
                            NavigationLink {
                                ReaderView(book: book, volumeFileName: volume.id)
                            } label: {
                                VolumeCardView(volume: volume)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle(book.title)
        .task { loadVolumes() }
    }

    private func loadVolumes() {
        let baseURL: URL?
        if book.isBundled {
            baseURL = Bundle.main.url(forResource: "Books", withExtension: nil)
        } else {
            baseURL = FileManager.default.urls(
                for: .documentDirectory, in: .userDomainMask
            ).first
        }
        guard let base = baseURL else { return }

        let folderURL = base.appendingPathComponent(book.fileName)
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return }

        volumes = contents
            .filter { $0.pathExtension.lowercased() == "md" }
            .sorted { MarkdownParser.fileSortKey($0.lastPathComponent) < MarkdownParser.fileSortKey($1.lastPathComponent) }
            .map { url in
                let fileName = url.lastPathComponent
                let displayName = url.deletingPathExtension().lastPathComponent
                var chapterCount = 0
                if let content = try? String(contentsOf: url, encoding: .utf8) {
                    chapterCount = MarkdownParser.parseChapters(from: content).count
                }
                return VolumeItem(
                    id: fileName,
                    displayName: displayName,
                    chapterCount: chapterCount,
                    colorHue: book.colorHue
                )
            }
    }
}

private struct VolumeCardView: View {
    let volume: VolumeItem

    var body: some View {
        VStack(alignment: .center, spacing: 8) {
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hue: volume.colorHue, saturation: 0.3, brightness: 0.92),
                            Color(hue: volume.colorHue, saturation: 0.45, brightness: 0.72)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .aspectRatio(3 / 4, contentMode: .fit)
                .overlay {
                    VStack(spacing: 6) {
                        Image(systemName: "doc.text")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.7))

                        Text(volume.displayName)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                            .minimumScaleFactor(0.8)
                            .padding(.horizontal, 6)

                        if volume.chapterCount > 0 {
                            Text("\(volume.chapterCount) 章")
                                .font(.system(size: 10))
                                .foregroundStyle(.white.opacity(0.75))
                        }
                    }
                }
                .shadow(color: .black.opacity(0.12), radius: 3, y: 2)

            Text(volume.displayName)
                .font(.caption)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .foregroundStyle(.primary)
                .frame(height: 32, alignment: .top)
        }
    }
}
