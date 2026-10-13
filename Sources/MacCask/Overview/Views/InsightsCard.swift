import SwiftUI

/// 优化建议卡片：每条建议可点击跳转到对应模块处理
struct InsightsCard: View {
    let model: OverviewViewModel
    let navigate: (SidebarSection) -> Void

    var body: some View {
        let insights = model.insights
        DashboardCard(title: L10n.tr("建议"), subtitle: insights.isEmpty ? nil : L10n.tr("{0} 条可优化项", "\(insights.count)")) {
            if insights.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill").font(.largeTitle).foregroundStyle(ChartPalette.good)
                    Text(L10n.tr("一切良好")).font(.callout.weight(.medium))
                    Text(L10n.tr("暂时没有需要处理的事项")).font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 180)
            } else {
                VStack(spacing: 4) {
                    ForEach(insights) { insight in
                        InsightRow(insight: insight) { navigate(insight.section) }
                    }
                }
            }
        }
    }
}

/// 单条建议
private struct InsightRow: View {
    let insight: Insight
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: insight.level.symbol)
                    .foregroundStyle(insight.level.color)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text(insight.title).font(.callout.weight(.medium))
                    Text(insight.detail).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(isHovering ? Color.primary.opacity(0.05) : .clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}
