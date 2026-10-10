import Charts
import SwiftUI

/// 应用来源分布：环形图 + 图例，悬停时中心显示该来源的数量
struct AppSourceChart: View {
    let model: OverviewViewModel
    @State private var selectedCount: Int?

    var body: some View {
        let slices = model.sourceSlices
        let total = slices.reduce(0) { $0 + $1.count }
        DashboardCard(title: "应用来源", subtitle: "共 \(total) 个应用") {
            if slices.isEmpty {
                LoadingView(text: "正在扫描应用…").frame(height: 200)
            } else {
                HStack(spacing: 24) {
                    donut(slices, total: total)
                    VStack(spacing: 10) {
                        ForEach(slices) { slice in
                            LegendItem(color: slice.color, title: slice.title, value: "\(slice.count)",
                                       secondary: percent(slice.count, total),
                                       isDimmed: hovered(slices) != nil && hovered(slices)?.id != slice.id)
                        }
                    }
                    .frame(maxWidth: 220)
                }
            }
        }
    }

    /// 环形图
    private func donut(_ slices: [AppSourceSlice], total: Int) -> some View {
        let active = hovered(slices)
        return Chart(slices) { slice in
            SectorMark(angle: .value("数量", slice.count), innerRadius: .ratio(0.64), angularInset: 1.5)
                .cornerRadius(3)
                .foregroundStyle(slice.color)
                .opacity(active == nil || active?.id == slice.id ? 1 : 0.35)
        }
        .chartAngleSelection(value: $selectedCount)
        .chartBackground { _ in
            VStack(spacing: 0) {
                Text("\(active?.count ?? total)")
                    .font(.system(size: 26, weight: .semibold, design: .rounded).monospacedDigit())
                Text(active?.title ?? "全部应用").font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(width: 170, height: 170)
    }

    /// 根据角度选择值换算出悬停的分块（chartAngleSelection 返回的是累计数量）
    private func hovered(_ slices: [AppSourceSlice]) -> AppSourceSlice? {
        guard let selectedCount else { return nil }
        var cumulative = 0
        for slice in slices {
            cumulative += slice.count
            if selectedCount <= cumulative { return slice }
        }
        return nil
    }

    /// 百分比文本
    private func percent(_ part: Int, _ total: Int) -> String {
        total > 0 ? (Double(part) / Double(total)).formatted(.percent.precision(.fractionLength(0))) : "0%"
    }
}
