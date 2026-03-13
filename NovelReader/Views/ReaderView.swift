import SwiftUI

struct ReaderView: View {
    let book: Book
    var volumeFileName: String? = nil
    @State private var viewModel = ReaderViewModel()
    @State private var showOverlay = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                viewModel.theme.backgroundColor.ignoresSafeArea()

                if viewModel.chapters.isEmpty {
                    ContentUnavailableView(
                        "无法加载",
                        systemImage: "exclamationmark.triangle",
                        description: Text("文件内容为空或无法读取")
                    )
                } else {
                    readerContent(viewWidth: geometry.size.width)
                }

                if showOverlay, !viewModel.chapters.isEmpty {
                    overlayContent
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { viewModel.loadBook(book, volumeFileName: volumeFileName) }
        .onDisappear { viewModel.saveProgress(for: book) }
        .sheet(isPresented: $viewModel.showSettings) {
            ReaderSettingsView(viewModel: viewModel)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $viewModel.showChapterList) {
            ChapterListView(viewModel: viewModel)
        }
    }

    // MARK: - Reading Content

    private func readerContent(viewWidth: CGFloat) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading) {
                    if let chapter = viewModel.currentChapter {
                        Text(chapter.title)
                            .font(.system(size: viewModel.fontSize + 6, weight: .bold))
                            .foregroundStyle(viewModel.theme.textColor)
                            .padding(.bottom, 20)
                            .id("chapterTop")

                        Text(viewModel.renderedContent)
                            .font(.system(size: viewModel.fontSize))
                            .foregroundStyle(viewModel.theme.textColor)
                            .lineSpacing(viewModel.lineSpacing)
                            .textSelection(.enabled)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onChange(of: viewModel.currentChapterIndex) {
                withAnimation {
                    proxy.scrollTo("chapterTop", anchor: .top)
                }
            }
        }
        .contentShape(Rectangle())
        .gesture(
            SpatialTapGesture()
                .onEnded { value in
                    handleTap(at: value.location, viewWidth: viewWidth)
                }
        )
        .simultaneousGesture(
            DragGesture(minimumDistance: 80)
                .onEnded { value in
                    handleSwipe(value.translation)
                }
        )
    }

    // MARK: - Gesture Handling

    private func handleTap(at location: CGPoint, viewWidth: CGFloat) {
        if showOverlay {
            withAnimation(.easeInOut(duration: 0.2)) { showOverlay = false }
            return
        }

        let zone = location.x / viewWidth
        if zone < 0.3 {
            viewModel.previousChapter()
        } else if zone > 0.7 {
            viewModel.nextChapter()
        } else {
            withAnimation(.easeInOut(duration: 0.2)) { showOverlay = true }
        }
    }

    private func handleSwipe(_ translation: CGSize) {
        guard abs(translation.width) > abs(translation.height) * 1.5 else { return }
        if translation.width < -80 {
            viewModel.nextChapter()
        } else if translation.width > 80 {
            viewModel.previousChapter()
        }
    }

    // MARK: - Overlay

    private var overlayContent: some View {
        VStack(spacing: 0) {
            topBar
            Spacer()
            bottomBar
        }
        .transition(.opacity)
    }

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.title3.weight(.semibold))
            }
            Spacer()
            Text(viewModel.chapterTitle)
                .font(.subheadline)
                .lineLimit(1)
            Spacer()
            Button { viewModel.showChapterList = true } label: {
                Image(systemName: "list.bullet")
                    .font(.title3)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.black.opacity(0.65))
    }

    private var bottomBar: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                Text("\(viewModel.currentChapterIndex + 1)")
                    .font(.caption)
                    .monospacedDigit()

                if viewModel.chapters.count > 1 {
                    Slider(
                        value: Binding(
                            get: { Double(viewModel.currentChapterIndex) },
                            set: { viewModel.goToChapter(Int($0)) }
                        ),
                        in: 0...Double(viewModel.chapters.count - 1),
                        step: 1
                    )
                    .tint(.white)
                }

                Text("\(viewModel.chapters.count)")
                    .font(.caption)
                    .monospacedDigit()
            }

            HStack(spacing: 40) {
                Button {
                    viewModel.previousChapter()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("上一章").font(.caption2)
                    }
                }
                .disabled(viewModel.currentChapterIndex == 0)

                Button {
                    viewModel.showSettings = true
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "textformat.size")
                        Text("设置").font(.caption2)
                    }
                }

                Button {
                    viewModel.nextChapter()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "chevron.right")
                        Text("下一章").font(.caption2)
                    }
                }
                .disabled(viewModel.currentChapterIndex >= viewModel.chapters.count - 1)
            }
            .font(.title3)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .padding(.bottom, 8)
        .background(.black.opacity(0.65))
    }
}
