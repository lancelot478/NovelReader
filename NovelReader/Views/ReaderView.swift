import SwiftUI

private struct DisableSwipeBack: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        DispatchQueue.main.async {
            uiViewController.navigationController?.interactivePopGestureRecognizer?.isEnabled = false
        }
    }

    static func dismantleUIViewControllerRepresentable(_ uiViewController: UIViewController, coordinator: ()) {
        uiViewController.navigationController?.interactivePopGestureRecognizer?.isEnabled = true
    }
}

struct ReaderView: View {
    let book: Book
    var volumeFileName: String? = nil
    @State private var viewModel = ReaderViewModel()
    @State private var showOverlay = false
    @State private var contentSize: CGSize = .zero
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        GeometryReader { geometry in
            let pageSize = CGSize(
                width: geometry.size.width - 40,
                height: geometry.size.height - 60
            )

            ZStack {
                viewModel.theme.backgroundColor.ignoresSafeArea()

                if viewModel.chapters.isEmpty {
                    ContentUnavailableView(
                        "无法加载",
                        systemImage: "exclamationmark.triangle",
                        description: Text("文件内容为空或无法读取")
                    )
                } else if viewModel.pages.isEmpty {
                    ProgressView()
                } else {
                    pageContent(viewWidth: geometry.size.width)
                }

                if showOverlay, !viewModel.chapters.isEmpty {
                    overlayContent
                }
            }
            .onAppear {
                contentSize = pageSize
                viewModel.loadBook(book, volumeFileName: volumeFileName)
                viewModel.paginateCurrentChapter(in: pageSize)
            }
            .onChange(of: geometry.size) { _, newSize in
                let newPageSize = CGSize(width: newSize.width - 40, height: newSize.height - 60)
                guard newPageSize != contentSize else { return }
                contentSize = newPageSize
                viewModel.paginateCurrentChapter(in: newPageSize)
            }
            .onChange(of: viewModel.currentChapterIndex) {
                viewModel.paginateCurrentChapter(in: contentSize)
            }
            .onChange(of: viewModel.fontSize) {
                viewModel.paginateCurrentChapter(in: contentSize)
            }
            .onChange(of: viewModel.lineSpacing) {
                viewModel.paginateCurrentChapter(in: contentSize)
            }
        }
        .background(DisableSwipeBack())
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onDisappear { viewModel.saveProgress(for: book) }
        .sheet(isPresented: $viewModel.showSettings) {
            ReaderSettingsView(viewModel: viewModel)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $viewModel.showChapterList) {
            ChapterListView(viewModel: viewModel)
        }
    }

    // MARK: - Page Content

    private func pageContent(viewWidth: CGFloat) -> some View {
        Text(viewModel.currentPageContent)
            .font(.system(size: viewModel.fontSize))
            .foregroundStyle(viewModel.theme.textColor)
            .lineSpacing(viewModel.lineSpacing)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.horizontal, 20)
            .padding(.vertical, 30)
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
            viewModel.previousPage()
        } else if zone > 0.7 {
            viewModel.nextPage()
        } else {
            withAnimation(.easeInOut(duration: 0.2)) { showOverlay = true }
        }
    }

    private func handleSwipe(_ translation: CGSize) {
        guard abs(translation.width) > abs(translation.height) * 1.5 else { return }
        if translation.width < -80 {
            viewModel.nextPage()
        } else if translation.width > 80 {
            viewModel.previousPage()
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
            VStack(spacing: 2) {
                Text(viewModel.chapterTitle)
                    .font(.subheadline)
                    .lineLimit(1)
                Text("\(viewModel.currentPageIndex + 1) / \(viewModel.pages.count)")
                    .font(.caption2)
                    .opacity(0.8)
            }
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
                Text("\(viewModel.currentPageIndex + 1)")
                    .font(.caption)
                    .monospacedDigit()

                if viewModel.pages.count > 1 {
                    Slider(
                        value: Binding(
                            get: { Double(viewModel.currentPageIndex) },
                            set: { viewModel.currentPageIndex = Int($0) }
                        ),
                        in: 0...Double(max(1, viewModel.pages.count - 1)),
                        step: 1
                    )
                    .tint(.white)
                }

                Text("\(viewModel.pages.count)")
                    .font(.caption)
                    .monospacedDigit()
            }

            HStack(spacing: 40) {
                Button {
                    viewModel.previousPage()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("上一页").font(.caption2)
                    }
                }
                .disabled(viewModel.currentPageIndex == 0 && viewModel.currentChapterIndex == 0)

                Button {
                    viewModel.showSettings = true
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "textformat.size")
                        Text("设置").font(.caption2)
                    }
                }

                Button {
                    viewModel.nextPage()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "chevron.right")
                        Text("下一页").font(.caption2)
                    }
                }
                .disabled(
                    viewModel.currentPageIndex >= viewModel.pages.count - 1
                    && viewModel.currentChapterIndex >= viewModel.chapters.count - 1
                )
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
