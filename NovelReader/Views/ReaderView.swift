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
    var initialPageIndex: Int? = nil
    @State private var viewModel = ReaderViewModel()
    @State private var showOverlay = false
    @State private var contentSize: CGSize = .zero
    @State private var dragOffset: CGFloat = 0
    @State private var pullDownOffset: CGFloat = 0
    @State private var isDraggingVertical: Bool? = nil
    @State private var isAnimating = false
    @State private var isCurrentPageBookmarked = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private let pullDownThreshold: CGFloat = 120

    var body: some View {
        GeometryReader { geometry in
            let pageSize = CGSize(
                width: geometry.size.width - 40,
                height: geometry.size.height - 60
            )
            let viewWidth = geometry.size.width

            ZStack {
                viewModel.theme.backgroundColor.ignoresSafeArea()

                if viewModel.chapters.isEmpty {
                    ContentUnavailableView(
                        "无法加载",
                        systemImage: "exclamationmark.triangle",
                        description: Text("文件内容为空或无法读取")
                    )
                } else if viewModel.renderedPages.isEmpty {
                    ProgressView()
                } else {
                    ZStack(alignment: .top) {
                        bookmarkIndicator
                            .offset(y: -60 + pullDownOffset)

                        slidingPages(viewWidth: viewWidth)
                            .offset(y: pullDownOffset)
                    }
                }

                if showOverlay, !viewModel.chapters.isEmpty {
                    overlayContent
                }
            }
            .onAppear {
                contentSize = pageSize
                viewModel.bookFileName = book.fileName
                viewModel.volumeFileName = volumeFileName
                viewModel.loadBook(book, volumeFileName: volumeFileName)
                viewModel.paginateAll(in: pageSize)
                if let target = initialPageIndex,
                   viewModel.renderedPages.indices.contains(target) {
                    viewModel.currentPageIndex = target
                }
                refreshBookmarkState()
            }
            .onChange(of: geometry.size) { _, newSize in
                let newPageSize = CGSize(width: newSize.width - 40, height: newSize.height - 60)
                guard newPageSize != contentSize else { return }
                contentSize = newPageSize
                viewModel.repaginate(in: newPageSize)
            }
            .onChange(of: viewModel.fontSize) {
                viewModel.repaginate(in: contentSize)
            }
            .onChange(of: viewModel.lineSpacing) {
                viewModel.repaginate(in: contentSize)
            }
            .onChange(of: viewModel.currentPageIndex) {
                refreshBookmarkState()
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

    // MARK: - Bookmark Indicator

    private var bookmarkIndicator: some View {
        let triggered = pullDownOffset >= pullDownThreshold
        let label: String
        if isCurrentPageBookmarked {
            label = triggered ? "松开取消书签" : "下拉取消书签"
        } else {
            label = triggered ? "松开添加书签" : "下拉添加书签"
        }

        return HStack(spacing: 8) {
            Image(systemName: isCurrentPageBookmarked ? "bookmark.fill" : "bookmark")
                .font(.title3)
            Text(label)
                .font(.subheadline)
        }
        .foregroundStyle(triggered ? .white : .white.opacity(0.7))
        .frame(maxWidth: .infinity)
        .frame(height: 60)
        .background(
            (isCurrentPageBookmarked
                ? Color.red.opacity(triggered ? 0.85 : 0.6)
                : Color.accentColor.opacity(triggered ? 0.85 : 0.6)
            )
        )
    }

    private func refreshBookmarkState() {
        isCurrentPageBookmarked = viewModel.isBookmarked(in: modelContext)
    }

    // MARK: - Sliding Pages

    private func slidingPages(viewWidth: CGFloat) -> some View {
        ZStack {
            if dragOffset > 0, viewModel.currentPageIndex > 0 {
                pageView(for: viewModel.currentPageIndex - 1)
                    .offset(x: dragOffset - viewWidth)
            }

            pageView(for: viewModel.currentPageIndex)
                .offset(x: dragOffset)

            if dragOffset < 0, viewModel.currentPageIndex < viewModel.totalPages - 1 {
                pageView(for: viewModel.currentPageIndex + 1)
                    .offset(x: dragOffset + viewWidth)
            }
        }
        .clipped()
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 15)
                .onChanged { value in
                    guard !isAnimating else { return }
                    let dx = value.translation.width
                    let dy = value.translation.height

                    if isDraggingVertical == nil {
                        isDraggingVertical = dy > 0 && abs(dy) > abs(dx) * 1.5
                    }

                    if isDraggingVertical == true {
                        pullDownOffset = max(0, min(dy, pullDownThreshold + 30))
                    } else {
                        let atStart = viewModel.currentPageIndex == 0 && dx > 0
                        let atEnd = viewModel.currentPageIndex >= viewModel.totalPages - 1 && dx < 0
                        dragOffset = (atStart || atEnd) ? dx * 0.15 : dx
                    }
                }
                .onEnded { value in
                    guard !isAnimating else { return }
                    defer { isDraggingVertical = nil }

                    if isDraggingVertical == true {
                        if pullDownOffset >= pullDownThreshold {
                            viewModel.toggleBookmark(in: modelContext)
                            refreshBookmarkState()
                        }
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                            pullDownOffset = 0
                        }
                    } else {
                        handleDragEnded(value, viewWidth: viewWidth)
                    }
                }
        )
        .simultaneousGesture(
            SpatialTapGesture()
                .onEnded { value in
                    guard !isAnimating else { return }
                    handleTap(at: value.location, viewWidth: viewWidth)
                }
        )
    }

    private func pageView(for index: Int) -> some View {
        viewModel.theme.backgroundColor
            .overlay(alignment: .topLeading) {
                if viewModel.renderedPages.indices.contains(index) {
                    Text(viewModel.renderedPages[index])
                        .font(.system(size: viewModel.fontSize))
                        .foregroundStyle(viewModel.theme.textColor)
                        .lineSpacing(viewModel.lineSpacing)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 30)
                }
            }
    }

    // MARK: - Gesture Handling

    private func handleDragEnded(_ value: DragGesture.Value, viewWidth: CGFloat) {
        let threshold = viewWidth * 0.35
        let velocity = value.velocity.width

        let shouldGoNext = (dragOffset < -threshold || velocity < -800)
            && viewModel.currentPageIndex < viewModel.totalPages - 1
        let shouldGoPrev = (dragOffset > threshold || velocity > 800)
            && viewModel.currentPageIndex > 0

        if shouldGoNext {
            animatePageTurn(to: -viewWidth) { viewModel.nextPage() }
        } else if shouldGoPrev {
            animatePageTurn(to: viewWidth) { viewModel.previousPage() }
        } else {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                dragOffset = 0
            }
        }
    }

    private func handleTap(at location: CGPoint, viewWidth: CGFloat) {
        if showOverlay {
            withAnimation(.easeInOut(duration: 0.2)) { showOverlay = false }
            return
        }

        let zone = location.x / viewWidth
        if zone < 0.3 {
            guard viewModel.currentPageIndex > 0 else { return }
            animatePageTurn(to: viewWidth) { viewModel.previousPage() }
        } else if zone > 0.7 {
            guard viewModel.currentPageIndex < viewModel.totalPages - 1 else { return }
            animatePageTurn(to: -viewWidth) { viewModel.nextPage() }
        } else {
            withAnimation(.easeInOut(duration: 0.2)) { showOverlay = true }
        }
    }

    private func animatePageTurn(to targetOffset: CGFloat, then action: @escaping () -> Void) {
        isAnimating = true
        withAnimation(.easeOut(duration: 0.25)) {
            dragOffset = targetOffset
        } completion: {
            action()
            dragOffset = 0
            isAnimating = false
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
                Text("\(viewModel.currentPageIndex + 1) / \(viewModel.totalPages)")
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

                if viewModel.totalPages > 1 {
                    Slider(
                        value: Binding(
                            get: { Double(viewModel.currentPageIndex) },
                            set: { viewModel.currentPageIndex = Int($0) }
                        ),
                        in: 0...Double(max(1, viewModel.totalPages - 1)),
                        step: 1
                    )
                    .tint(.white)
                }

                Text("\(viewModel.totalPages)")
                    .font(.caption)
                    .monospacedDigit()
            }

            HStack(spacing: 40) {
                Button {
                    guard viewModel.currentPageIndex > 0 else { return }
                    animatePageTurn(to: UIScreen.main.bounds.width) { viewModel.previousPage() }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("上一页").font(.caption2)
                    }
                }
                .disabled(viewModel.currentPageIndex == 0)

                Button {
                    viewModel.showSettings = true
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "textformat.size")
                        Text("设置").font(.caption2)
                    }
                }

                Button {
                    guard viewModel.currentPageIndex < viewModel.totalPages - 1 else { return }
                    animatePageTurn(to: -UIScreen.main.bounds.width) { viewModel.nextPage() }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "chevron.right")
                        Text("下一页").font(.caption2)
                    }
                }
                .disabled(viewModel.currentPageIndex >= viewModel.totalPages - 1)
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
