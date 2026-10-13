import SwiftUI

/// 残留文件详情列：单选显示文件明细，多选显示汇总
struct LeftoverDetailView: View {
    let model: LeftoversViewModel

    var body: some View {
        let selected = model.selectedGroups
        if selected.count == 1, let group = selected.first {
            groupDetail(group)
        } else if selected.count > 1 {
            ContentUnavailableView {
                Label(L10n.tr("已选择 {0} 项", "\(selected.count)"), systemImage: "square.stack.3d.up")
            } description: {
                Text(L10n.tr("合计 {0}，共 {1} 个文件", "\(ByteFormatter.string(selected.reduce(0) { $0 + $1.totalSize }))", "\(selected.reduce(0) { $0 + $1.files.count })"))
            }
        } else {
            ContentUnavailableView(L10n.tr("选择残留项"), systemImage: "archivebox",
                                   description: Text(L10n.tr("按住 ⌘ 或 ⇧ 可多选，右键可忽略或删除")))
        }
    }

    /// 单个分组详情
    private func groupDetail(_ group: LeftoverGroup) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 16) {
                    Image(systemName: "archivebox.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(Color.orange.gradient, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    VStack(alignment: .leading, spacing: 6) {
                        Text(group.displayName).font(.title2.weight(.semibold))
                        Text(group.identifier).font(.callout.monospaced()).foregroundStyle(.secondary).textSelection(.enabled)
                    }
                    Spacer()
                }

                HStack(spacing: 12) {
                    StatCard(title: L10n.tr("占用空间"), value: ByteFormatter.string(group.totalSize), symbol: "internaldrive", tint: .orange)
                    StatCard(title: L10n.tr("文件位置"), value: L10n.tr("{0} 处", "\(group.files.count)"), symbol: "folder")
                    StatCard(title: L10n.tr("可信度"), value: group.confidence == .high ? L10n.tr("高") : L10n.tr("低"), symbol: "checkmark.shield",
                             tint: group.confidence == .high ? .green : .yellow)
                }

                if group.confidence == .low {
                    Label(L10n.tr("同一开发商（{0}）仍有应用安装，这些文件可能被共享使用，删除前请确认。", "\(IdentifierMatcher.vendor(of: group.identifier))"),
                          systemImage: "exclamationmark.triangle")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 0) {
                    ForEach(group.files) { file in
                        LibraryFileRow(file: file)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                        if file.id != group.files.last?.id { Divider().padding(.leading, 12) }
                    }
                }
                .background(.background.secondary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .padding(24)
        }
    }
}
