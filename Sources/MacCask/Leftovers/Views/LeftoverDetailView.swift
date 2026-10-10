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
                Label("已选择 \(selected.count) 项", systemImage: "square.stack.3d.up")
            } description: {
                Text("合计 \(ByteFormatter.string(selected.reduce(0) { $0 + $1.totalSize }))，共 \(selected.reduce(0) { $0 + $1.files.count }) 个文件")
            }
        } else {
            ContentUnavailableView("选择残留项", systemImage: "archivebox",
                                   description: Text("按住 ⌘ 或 ⇧ 可多选，右键可忽略或删除"))
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
                    StatCard(title: "占用空间", value: ByteFormatter.string(group.totalSize), symbol: "internaldrive", tint: .orange)
                    StatCard(title: "文件位置", value: "\(group.files.count) 处", symbol: "folder")
                    StatCard(title: "可信度", value: group.confidence == .high ? "高" : "低", symbol: "checkmark.shield",
                             tint: group.confidence == .high ? .green : .yellow)
                }

                if group.confidence == .low {
                    Label("同一开发商（\(IdentifierMatcher.vendor(of: group.identifier))）仍有应用安装，这些文件可能被共享使用，删除前请确认。",
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
