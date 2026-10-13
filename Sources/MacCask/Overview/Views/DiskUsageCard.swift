import SwiftUI

/// 磁盘占用主卡片：已用百分比 + 分段占用条 + 图例
struct DiskUsageCard: View {
    let model: OverviewViewModel
    let navigate: (SidebarSection) -> Void
    /// 悬停中的分段
    @State private var hoveredID: String?

    var body: some View {
        DashboardCard(title: L10n.tr("磁盘占用"), subtitle: model.disk?.volumeName) {
            if let disk = model.disk {
                headline(disk)
            }
        } content: {
            if let disk = model.disk {
                // 分段数据每次刷新只计算一次，供分段条与图例共用
                let segments = model.diskSegments
                VStack(alignment: .leading, spacing: 18) {
                    usageBar(disk, segments: segments)
                    legend(disk, segments: segments)
                }
            } else {
                Text(L10n.tr("无法读取磁盘信息")).foregroundStyle(.secondary)
            }
        }
    }

    /// 右上角：已用百分比大数字
    private func headline(_ disk: DiskUsage) -> some View {
        let free = 1 - disk.usedFraction
        return HStack(alignment: .firstTextBaseline, spacing: 10) {
            if free < 0.2 {
                TagBadge(text: free < 0.1 ? L10n.tr("空间不足") : L10n.tr("空间偏紧"),
                         style: .warning, symbol: "exclamationmark.triangle.fill")
            }
            VStack(alignment: .trailing, spacing: 2) {
                Text(model.percent(disk.usedFraction))
                    .font(.system(size: 34, weight: .semibold, design: .rounded).monospacedDigit())
                Text(L10n.tr("已用 {0} / 共 {1}", "\(ByteFormatter.string(disk.usedBytes))", "\(ByteFormatter.string(disk.totalBytes))"))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// 分段条：各分段按占总容量比例排列，末尾为可用空间轨道；分段间留 2pt 间隙
    private func usageBar(_ disk: DiskUsage, segments allSegments: [DiskSegment]) -> some View {
        GeometryReader { geo in
            let segments = allSegments.filter { ($0.bytes ?? 0) > 0 }
            let gap: CGFloat = 2
            let usable = geo.size.width - gap * CGFloat(segments.count)
            HStack(spacing: gap) {
                ForEach(segments) { segment in
                    // 极小的分段至少保留 3pt，保证可见、可悬停
                    let width = max(usable * disk.fraction(of: segment.bytes ?? 0), 3)
                    Rectangle()
                        .fill(segment.color)
                        .frame(width: width)
                        .opacity(hoveredID == nil || hoveredID == segment.id ? 1 : 0.35)
                        .onHover { hoveredID = $0 ? segment.id : nil }
                        .help(L10n.tr("{0}：{1}（占磁盘 {2}）", "\(segment.title)", "\(ByteFormatter.string(segment.bytes ?? 0))", "\(model.percent(disk.fraction(of: segment.bytes ?? 0)))"))
                }
                Rectangle().fill(ChartPalette.track)
                    .opacity(hoveredID == nil || hoveredID == "free" ? 1 : 0.5)
                    .onHover { hoveredID = $0 ? "free" : nil }
                    .help(L10n.tr("可用：{0}", "\(ByteFormatter.string(disk.availableBytes))"))
            }
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            .animation(.easeOut(duration: 0.15), value: hoveredID)
        }
        .frame(height: 18)
    }

    /// 图例：两列网格，显示大小与占磁盘比例，可点击跳转
    private func legend(_ disk: DiskUsage, segments: [DiskSegment]) -> some View {
        let columns = [GridItem(.flexible(), spacing: 28), GridItem(.flexible(), spacing: 28)]
        return LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
            ForEach(segments) { segment in
                legendRow(segment, disk: disk)
            }
            LegendItem(color: ChartPalette.track, title: L10n.tr("可用"), value: ByteFormatter.string(disk.availableBytes),
                       secondary: model.percent(1 - disk.usedFraction),
                       isDimmed: hoveredID != nil && hoveredID != "free")
                .onHover { hoveredID = $0 ? "free" : nil }
        }
    }

    /// 单条图例：有对应模块时可点击
    @ViewBuilder
    private func legendRow(_ segment: DiskSegment, disk: DiskUsage) -> some View {
        let item = LegendItem(color: segment.color, title: segment.title,
                              value: segment.bytes.map(ByteFormatter.string) ?? L10n.tr("计算中…"),
                              secondary: segment.bytes.map { model.percent(disk.fraction(of: $0)) },
                              isDimmed: hoveredID != nil && hoveredID != segment.id)
            .contentShape(Rectangle())
            .onHover { hoveredID = $0 ? segment.id : nil }
        if let section = segment.section {
            Button { navigate(section) } label: { item }
                .buttonStyle(.plain)
                .help(L10n.tr("前往{0}", "\(section.title)"))
        } else {
            item
        }
    }
}
