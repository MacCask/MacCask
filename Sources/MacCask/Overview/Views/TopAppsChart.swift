import SwiftUI

/// 占用最多的应用：横向条形列表（图标 + 名称 | 条形 | 大小与磁盘占比），点击跳转到应用详情
struct TopAppsChart: View {
    let model: OverviewViewModel
    let openApp: (InstalledApp) -> Void

    var body: some View {
        let items = model.topApps()
        DashboardCard(title: L10n.tr("占用最多的应用"), subtitle: L10n.tr("第三方应用 · 右侧为占整个磁盘的比例")) {
            if items.isEmpty {
                LoadingView(text: L10n.tr("正在计算应用大小…")).frame(height: 240)
            } else {
                // 条形长度相对最大值缩放
                let maxBytes = Double(items.first?.bytes ?? 1)
                VStack(spacing: 4) {
                    ForEach(items, id: \.app.id) { item in
                        TopAppRow(app: item.app, bytes: item.bytes,
                                  ratio: Double(item.bytes) / maxBytes,
                                  diskPercent: model.disk.map { model.percent($0.fraction(of: item.bytes)) } ?? "") {
                            openApp(item.app)
                        }
                    }
                }
            }
        }
    }
}

/// 单行：悬停状态由行自己持有，鼠标移动时只重绘当前行，不影响整张卡片
private struct TopAppRow: View {
    let app: InstalledApp
    let bytes: Int64
    let ratio: Double
    let diskPercent: String
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(nsImage: BundleInfoReader.icon(for: app.id, size: 20))
                    .frame(width: 20, height: 20)
                Text(app.name)
                    .font(.callout)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(width: 120, alignment: .leading)
                // 条形用 scaleEffect 按比例缩放，不需要 GeometryReader
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(ChartPalette.blue)
                    .frame(height: 14)
                    .scaleEffect(x: max(ratio, 0.01), anchor: .leading)
                    .frame(maxWidth: .infinity)
                Text(ByteFormatter.string(bytes))
                    .font(.callout.monospacedDigit())
                    .frame(width: 72, alignment: .trailing)
                Text(diskPercent)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 44, alignment: .trailing)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(isHovering ? Color.primary.opacity(0.06) : .clear,
                        in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .help(L10n.tr("查看「{0}」的详情", "\(app.name)"))
    }
}
