import SwiftUI

/// Library 文件行：可选的勾选框 + 分类图标 + 路径 + 大小
struct LibraryFileRow: View {
    let file: LibraryFile
    /// 勾选状态绑定，为 nil 时不显示勾选框
    var isChecked: Binding<Bool>? = nil

    var body: some View {
        HStack(spacing: 10) {
            if let isChecked {
                Toggle("", isOn: isChecked)
                    .toggleStyle(.checkbox)
                    .labelsHidden()
            }
            Image(systemName: file.category.symbol)
                .foregroundStyle(.secondary)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(file.url.lastPathComponent)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    TagBadge(text: file.category.title)
                    if file.isSystemLevel {
                        TagBadge(text: L10n.tr("需管理员"), style: .warning, symbol: "lock.fill")
                    }
                }
                Text(file.displayPath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            Text(ByteFormatter.measured(file.sizeBytes, isComplete: file.isSizeComplete))
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .contextMenu { FileContextMenu(urls: [file.url]) }
    }
}
