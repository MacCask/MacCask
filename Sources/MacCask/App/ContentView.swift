import SwiftUI

/// 主窗口：侧边栏 → 列表 → 详情 三栏布局
struct ContentView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        Group {
            if state.section == .overview {
                // 概览是整页仪表盘，使用两栏布局
                NavigationSplitView {
                    sidebar
                } detail: {
                    OverviewView()
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
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 260)
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

/// 侧边栏
struct SidebarView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var state = state
        List(selection: Binding(get: { state.section }, set: { if let value = $0 { state.section = value } })) {
            Label(SidebarSection.overview.title, systemImage: SidebarSection.overview.symbol)
                .tag(SidebarSection.overview)
            Section("管理") {
                ForEach(SidebarSection.allCases.filter { $0 != .overview }) { section in
                    Label(section.title, systemImage: section.symbol)
                        .badge(state.badge(for: section))
                        .tag(section)
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Label("文件均移到废纸篓，可恢复", systemImage: "arrow.uturn.backward.circle")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
