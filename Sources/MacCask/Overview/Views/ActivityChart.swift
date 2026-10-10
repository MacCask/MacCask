import Charts
import SwiftUI

/// 应用使用活跃度：按上次使用时间分组的柱状图，悬停显示该组占用
struct ActivityChart: View {
    let model: OverviewViewModel
    @State private var selectedTitle: String?

    var body: some View {
        let buckets = model.activityBuckets
        DashboardCard(title: "使用活跃度", subtitle: "第三方应用按上次使用时间分组") {
            if let stale = model.staleBucket, model.appSizesReady {
                VStack(alignment: .trailing, spacing: 0) {
                    Text(ByteFormatter.string(stale.bytes))
                        .font(.title3.weight(.semibold).monospacedDigit())
                    Text("超过一年未使用").font(.caption).foregroundStyle(.secondary)
                }
            }
        } content: {
            if buckets.allSatisfy({ $0.count == 0 }) {
                LoadingView(text: "正在扫描应用…").frame(height: 200)
            } else {
                chart(buckets)
            }
        }
    }

    /// 柱状图主体：单一系列使用分类色 1，「未知」组使用中性色
    private func chart(_ buckets: [ActivityBucket]) -> some View {
        Chart(buckets) { bucket in
            BarMark(x: .value("时间", bucket.title), y: .value("应用数", bucket.count), width: .ratio(0.55))
                // 「未知」不是时间区间，用中性色与真实分组区分
                .foregroundStyle(bucket.isUnknown ? ChartPalette.neutral : ChartPalette.blue)
                .cornerRadius(4)
                .opacity(selectedTitle == nil || selectedTitle == bucket.title ? 1 : 0.35)
                .annotation(position: .top, spacing: 4) {
                    Text("\(bucket.count)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            if let selectedTitle, selectedTitle == bucket.title {
                RuleMark(x: .value("时间", bucket.title))
                    .foregroundStyle(.clear)
                    .annotation(position: .top, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                        tooltip(bucket)
                    }
            }
        }
        .chartXSelection(value: $selectedTitle)
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine().foregroundStyle(Color.primary.opacity(0.06))
                AxisValueLabel()
            }
        }
        .chartXAxis {
            AxisMarks { _ in AxisValueLabel().font(.caption) }
        }
        .frame(height: 210)
    }

    /// 悬停提示：数量与合计大小
    private func tooltip(_ bucket: ActivityBucket) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(bucket.title).font(.caption.weight(.semibold))
            Text("\(bucket.count) 个应用 · \(ByteFormatter.string(bucket.bytes))")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 4, y: 1)
    }
}
