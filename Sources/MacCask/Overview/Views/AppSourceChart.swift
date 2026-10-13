import Charts
import SwiftUI

/// 应用来源分布：环形图 + 图例，悬停时中心显示该来源的数量
struct AppSourceChart: View {
    let model: OverviewViewModel
    /// 悬停中的来源（只在跨越分块时变化）
    @State private var hoveredTitle: String?

    var body: some View {
        let slices = model.sourceSlices
        let total = slices.reduce(0) { $0 + $1.count }
        let active = slices.first { $0.title == hoveredTitle }
        DashboardCard(title: L10n.tr("应用来源"), subtitle: L10n.tr("共 {0} 个应用", "\(total)")) {
            if slices.isEmpty {
                LoadingView(text: L10n.tr("正在扫描应用…")).frame(height: 200)
            } else {
                HStack(spacing: 24) {
                    donut(slices, total: total, active: active)
                    VStack(spacing: 10) {
                        ForEach(slices) { slice in
                            LegendItem(color: slice.color, title: slice.title, value: "\(slice.count)",
                                       secondary: percent(slice.count, total),
                                       isDimmed: active != nil && active?.id != slice.id)
                                .contentShape(Rectangle())
                                .onHover { hoveredTitle = $0 ? slice.title : nil }
                        }
                    }
                    .frame(maxWidth: 220)
                }
                .animation(.easeOut(duration: 0.15), value: hoveredTitle)
            }
        }
    }

    /// 环形图
    private func donut(_ slices: [AppSourceSlice], total: Int, active: AppSourceSlice?) -> some View {
        Chart(slices) { slice in
            SectorMark(angle: .value(L10n.tr("数量"), slice.count), innerRadius: .ratio(0.64), angularInset: 1.5)
                .cornerRadius(3)
                .foregroundStyle(slice.color)
                .opacity(active == nil || active?.id == slice.id ? 1 : 0.35)
        }
        // chartAngleSelection 的值随鼠标逐像素变化；用自定义绑定换算成分块，只有分块变化时才更新状态，避免整张卡片频繁重绘
        .chartAngleSelection(value: Binding<Int?>(
            get: { nil },
            set: { value in
                let title = value.flatMap { slice(at: $0, in: slices)?.title }
                if title != hoveredTitle { hoveredTitle = title }
            }
        ))
        .chartBackground { _ in
            VStack(spacing: 0) {
                Text("\(active?.count ?? total)")
                    .font(.system(size: 26, weight: .semibold, design: .rounded).monospacedDigit())
                    .contentTransition(.numericText())
                Text(active?.title ?? L10n.tr("全部应用")).font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(width: 170, height: 170)
    }

    /// 由累计数值找到对应分块（chartAngleSelection 返回的是从起点开始的累计数量）
    private func slice(at cumulativeValue: Int, in slices: [AppSourceSlice]) -> AppSourceSlice? {
        var cumulative = 0
        for slice in slices {
            cumulative += slice.count
            if cumulativeValue <= cumulative { return slice }
        }
        return nil
    }

    /// 百分比文本
    private func percent(_ part: Int, _ total: Int) -> String {
        total > 0 ? (Double(part) / Double(total)).formatted(.percent.precision(.fractionLength(0)).locale(L10n.locale)) : "0%"
    }
}
