import SwiftUI

/// 占用最多的应用：横向条形列表（图标 + 名称 | 条形 | 大小与磁盘占比），悬停高亮，点击跳转到应用详情
struct TopAppsChart: View {
    let model: OverviewViewModel
    let openApp: (InstalledApp) -> Void
    @State private var hoveredID: String?

    var body: some View {
        let items = model.topApps()
        DashboardCard(title: "占用最多的应用", subtitle: "第三方应用 · 右侧为占整个磁盘的比例") {
            if items.isEmpty {
                LoadingView(text: "正在计算应用大小…").frame(height: 240)
            } else {
                // 条形长度相对最大值缩放
                let maxBytes = Double(items.first?.bytes ?? 1)
                VStack(spacing: 4) {
                    ForEach(items, id: \.app.id) { item in
                        row(item, ratio: Double(item.bytes) / maxBytes)
                    }
                }
            }
        }
    }

    /// 单行
    private func row(_ item: (app: InstalledApp, bytes: Int64), ratio: Double) -> some View {
        let dimmed = hoveredID != nil && hoveredID != item.app.id
        return Button { openApp(item.app) } label: {
            HStack(spacing: 10) {
                Image(nsImage: BundleInfoReader.icon(for: item.app.id))
                    .resizable()
                    .frame(width: 20, height: 20)
                Text(item.app.name)
                    .font(.callout)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(width: 120, alignment: .leading)
                GeometryReader { geo in
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(ChartPalette.blue)
                        .frame(width: max(geo.size.width * ratio, 4), height: 14)
                        .frame(maxHeight: .infinity)
                }
                .frame(height: 20)
                Text(ByteFormatter.string(item.bytes))
                    .font(.callout.monospacedDigit())
                    .frame(width: 72, alignment: .trailing)
                Text(model.disk.map { model.percent($0.fraction(of: item.bytes)) } ?? "")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 44, alignment: .trailing)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(hoveredID == item.app.id ? Color.primary.opacity(0.05) : .clear,
                        in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .opacity(dimmed ? 0.45 : 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hoveredID = $0 ? item.app.id : nil }
        .animation(.easeOut(duration: 0.12), value: hoveredID)
        .help("查看「\(item.app.name)」的详情")
    }
}
