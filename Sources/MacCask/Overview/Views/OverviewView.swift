import SwiftUI

/// 概览页面：磁盘占用、各模块状态、图表与优化建议
struct OverviewView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        let model = state.overview
        ScrollView {
            OverviewDashboard()
                .padding(20)
                .frame(maxWidth: 1280)
                .frame(maxWidth: .infinity)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .navigationTitle("概览")
        .toolbar {
            ToolbarItem {
                Button {
                    Task { await model.refresh() }
                } label: {
                    if model.isRefreshing {
                        ProgressView().controlSize(.small)
                    } else {
                        Label("刷新", systemImage: "arrow.clockwise")
                    }
                }
                .disabled(model.isRefreshing)
                .help("重新扫描所有数据")
            }
        }
        .task { await model.loadIfNeeded() }
    }
}

/// 概览仪表盘内容：磁盘卡片、状态磁贴、图表与建议
struct OverviewDashboard: View {
    @Environment(AppState.self) private var state
    /// 宽度是否足够两张卡片并排（只在跨过阈值时变化，避免频繁重新布局）
    @State private var isWide = true

    var body: some View {
        let model = state.overview
        VStack(alignment: .leading, spacing: 16) {
            DiskUsageCard(model: model, navigate: navigate)
            tiles(model)
            adaptiveRow {
                TopAppsChart(model: model, openApp: openApp)
                AppSourceChart(model: model)
            }
            adaptiveRow {
                ActivityChart(model: model)
                InsightsCard(model: model, navigate: navigate)
            }
        }
        .onGeometryChange(for: Bool.self) { $0.size.width >= 820 } action: { isWide = $0 }
    }

    /// 四个模块的状态磁贴
    private func tiles(_ model: OverviewViewModel) -> some View {
        let apps = model.apps
        let brew = model.homebrew
        let launch = model.launchItems
        let leftovers = model.leftovers
        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 16)], spacing: 16) {
            StatTile(title: "应用程序",
                     value: apps.hasLoaded ? "\(model.thirdPartyApps.count)" : "—",
                     detail: apps.hasLoaded ? "第三方 · 另有 \(apps.apps.count - model.thirdPartyApps.count) 个系统应用" : "扫描中…",
                     symbol: "square.grid.2x2.fill", tint: ChartPalette.blue) { navigate(.apps) }
            StatTile(title: "Homebrew",
                     value: brew.isBrewAvailable ? (brew.hasLoaded ? "\(brew.packages.count)" : "—") : "未安装",
                     detail: brew.hasLoaded ? "\(brew.count(of: .formula)) 个工具 · \(brew.count(of: .cask)) 个应用" : "读取中…",
                     symbol: "mug.fill", tint: ChartPalette.orange,
                     badge: brew.outdatedCount > 0 ? "\(brew.outdatedCount) 个可更新" : nil) { navigate(.homebrew) }
            StatTile(title: "启动项",
                     value: launch.hasLoaded ? "\(launch.enabledCount)" : "—",
                     detail: launch.hasLoaded ? "已开启 · 共 \(launch.items.count) 项，\(model.runningLaunchItems) 项运行中" : "读取中…",
                     symbol: "power", tint: ChartPalette.aqua) { navigate(.launchItems) }
            StatTile(title: "残留文件",
                     value: leftovers.hasLoaded ? ByteFormatter.string(model.leftoverActiveBytes) : "—",
                     detail: leftovers.hasLoaded ? "\(leftovers.activeCount) 项可清理" : "扫描中…",
                     symbol: "archivebox.fill", tint: ChartPalette.yellow) { navigate(.leftovers) }
        }
    }

    /// 自适应行：宽度足够时并排，否则上下排列；用 AnyLayout 切换，保持子视图身份不变
    private func adaptiveRow<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        let layout = isWide ? AnyLayout(HStackLayout(alignment: .top, spacing: 16)) : AnyLayout(VStackLayout(spacing: 16))
        return layout { content() }
    }

    /// 跳转到指定模块
    private func navigate(_ section: SidebarSection) {
        state.section = section
    }

    /// 跳转到应用列表并选中指定应用
    private func openApp(_ app: InstalledApp) {
        state.installedApps.searchText = ""
        if !state.installedApps.filter.matches(app) { state.installedApps.filter = .all }
        state.installedApps.selection = app.id
        state.section = .apps
    }
}
