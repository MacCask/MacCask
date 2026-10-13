import SwiftUI

/// 残留文件详情列：多选时仍展示当前聚焦项，批量操作在列表底部。
struct LeftoverDetailView: View {
    let model: LeftoversViewModel

    var body: some View {
        if let group = model.detailGroup {
            VStack(spacing: 0) {
                groupDetail(group).frame(maxWidth: .infinity, maxHeight: .infinity)
                actions(group)
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

                HStack(spacing: 16) {
                    PlainStatView(title: L10n.tr("占用空间"), value: ByteFormatter.string(group.totalSize), symbol: "internaldrive")
                    Divider().frame(height: 48)
                    PlainStatView(title: L10n.tr("文件位置"), value: L10n.tr("{0} 处", "\(group.files.count)"), symbol: "folder")
                    Divider().frame(height: 48)
                    PlainStatView(title: L10n.tr("可信度"), value: group.confidence == .high ? L10n.tr("高") : L10n.tr("低"), symbol: "checkmark.shield")
                }
                .padding(.vertical, 12)
                Divider()

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
    /// 查看和忽略仅针对当前展示的分组，批量删除保留在列表的选择操作栏。
    private func actions(_ group: LeftoverGroup) -> some View {
        HStack {
            Button(L10n.tr("在访达中显示")) { Platform.current.system.revealInFinder(group.files.map(\.url)) }
            Spacer()
            Button(group.isIgnored ? L10n.tr("取消忽略") : L10n.tr("忽略")) {
                if group.isIgnored { model.unignore([group.id]) } else { model.ignore([group.id]) }
            }
            .disabled(model.isTrashing)
        }
        .padding(12).background(.bar)
    }

}
