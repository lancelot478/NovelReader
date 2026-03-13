import SwiftUI

struct ReaderSettingsView: View {
    @Bindable var viewModel: ReaderViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("字体大小") {
                    HStack {
                        Text("A").font(.system(size: 14))
                        Slider(value: $viewModel.fontSize, in: 14...28, step: 1)
                        Text("A").font(.system(size: 24))
                    }
                    Text("当前: \(Int(viewModel.fontSize))pt")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("行间距") {
                    HStack {
                        Image(systemName: "text.alignleft").font(.caption)
                        Slider(value: $viewModel.lineSpacing, in: 2...20, step: 1)
                        Image(systemName: "text.alignleft").font(.title3)
                    }
                }

                Section("主题") {
                    HStack(spacing: 20) {
                        ForEach(ReaderTheme.allCases, id: \.self) { theme in
                            VStack(spacing: 6) {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(theme.backgroundColor)
                                    .frame(width: 52, height: 52)
                                    .overlay {
                                        Text("文").foregroundStyle(theme.textColor)
                                    }
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(
                                                viewModel.theme == theme
                                                    ? Color.accentColor
                                                    : Color.gray.opacity(0.3),
                                                lineWidth: viewModel.theme == theme ? 2.5 : 1
                                            )
                                    }

                                Text(theme.rawValue)
                                    .font(.caption)
                                    .foregroundStyle(
                                        viewModel.theme == theme ? .primary : .secondary
                                    )
                            }
                            .onTapGesture { viewModel.theme = theme }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("阅读设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}
