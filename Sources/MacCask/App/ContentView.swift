import SwiftUI

/// 主窗口：侧边栏 → 列表 → 详情 三栏布局
struct ContentView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        Group {
            if state.section == .overview || state.section == .leftovers {
                // 整页工作区使用两栏导航，残留内部共享跨列表与详情的操作栏。
                NavigationSplitView {
                    sidebar
                } detail: {
                    if state.section == .overview {
                        OverviewView()
                    } else {
                        LeftoversWorkspaceView(model: state.leftovers)
                    }
                }
            } else {
                NavigationSplitView {
                    sidebar
                } content: {
                    contentColumn
                        .navigationSplitViewColumnWidth(min: 340, ideal: 400, max: 560)
                } detail: {
                    detailColumn
                }
            }
        }
        .task {
            // 启动后在后台预加载 Homebrew，让侧边栏尽早显示可更新数量
            await state.homebrew.loadIfNeeded()
        }
    }

    /// 侧边栏列
    private var sidebar: some View {
        SidebarView()
            .navigationSplitViewColumnWidth(min: 220, ideal: 230, max: 300)
    }

    /// 内容列：当前模块的列表
    @ViewBuilder
    private var contentColumn: some View {
        switch state.section {
        case .overview: EmptyView()
        case .apps: InstalledAppsListView(model: state.installedApps)
        case .homebrew: HomebrewListView(model: state.homebrew)
        case .launchItems: LaunchItemsListView(model: state.launchItems)
        case .leftovers: LeftoversListView(model: state.leftovers)
        }
    }

    /// 详情列：当前模块的选中项详情
    @ViewBuilder
    private var detailColumn: some View {
        switch state.section {
        case .overview: EmptyView()
        case .apps: AppDetailView(model: state.installedApps)
        case .homebrew: HomebrewDetailView(model: state.homebrew)
        case .launchItems: LaunchItemDetailView(model: state.launchItems)
        case .leftovers: LeftoverDetailView(model: state.leftovers)
        }
    }
}
