import SwiftUI

struct ChapterListView: View {
    var viewModel: ReaderViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(viewModel.chapters.indices, id: \.self) { index in
                Button {
                    viewModel.goToChapter(index)
                    dismiss()
                } label: {
                    HStack {
                        Text(viewModel.chapters[index].title)
                            .foregroundColor(
                                index == viewModel.currentChapterIndex
                                    ? .accentColor : .primary
                            )
                            .fontWeight(
                                index == viewModel.currentChapterIndex ? .semibold : .regular
                            )

                        Spacer()

                        if index == viewModel.currentChapterIndex {
                            Image(systemName: "book.fill")
                                .font(.caption)
                                .foregroundColor(.accentColor)
                        }
                    }
                }
            }
            .navigationTitle("目录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}
