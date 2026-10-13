import SwiftUI

/// 残留筛选与结果数量放在列表头，删除操作独立放在底部。
struct LeftoversListHeader: View {
    @Bindable var model: LeftoversViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.tr("残留文件")).font(.title2.weight(.semibold))
            Text(L10n.tr("{0} 项残留 · 共 {1}", "\(model.visibleGroups.count)", "\(ByteFormatter.string(model.visibleTotalSize))"))
                .font(.caption).foregroundStyle(.secondary)
            HStack(alignment: .top, spacing: 10) {
                Menu(L10n.tr("筛选")) {
                    Toggle(L10n.tr("显示低可信度项"), isOn: $model.showLowConfidence)
                    Toggle(L10n.tr("显示已忽略项"), isOn: $model.showIgnored)
                }
                .menuStyle(.borderlessButton).fixedSize()
                Text([model.showLowConfidence ? L10n.tr("含低可信度项") : L10n.tr("隐藏低可信度项"),
                      model.showIgnored ? L10n.tr("含已忽略项") : L10n.tr("隐藏已忽略项")].joined(separator: " · "))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16).background(.bar)
        .overlay(alignment: .bottom) { Divider() }
    }
}

/// 删除按钮与实际选中数量、大小共同展示，交由调用方弹出原有确认对话框。
struct LeftoversSelectionBar: View {
    let model: LeftoversViewModel
    let trash: () -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 20) {
                summary
                Spacer(minLength: 16)
                trashButton
            }
            VStack(alignment: .leading, spacing: 8) {
                summary
                HStack { Spacer(); trashButton }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16).background(.bar)
        .overlay(alignment: .top) { Divider() }
    }

    /// 选中快照的数量与大小始终和删除操作相邻。
    private var summary: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.tr("已选 {0} 项 · {1}", "\(model.selectedGroups.count)",
                         "\(ByteFormatter.string(model.selectedGroups.reduce(0) { $0 + $1.totalSize }))"))
                .font(.callout.weight(.medium))
            Text(L10n.tr("文件可从废纸篓恢复"))
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    /// 仅在选中有效残留项时显示删除按钮，执行中禁止重复触发。
    @ViewBuilder
    private var trashButton: some View {
        if !model.selectedGroups.isEmpty {
            Button(L10n.tr("移到废纸篓…"), role: .destructive, action: trash)
                .buttonStyle(.borderedProminent).tint(.red)
                .disabled(model.isTrashing)
        }
    }
}
