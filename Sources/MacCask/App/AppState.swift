import Foundation
import Observation

/// 侧边栏模块
enum SidebarSection: String, CaseIterable, Identifiable, Hashable {
    case overview
    case apps
    case homebrew
    case launchItems
    case leftovers

    var id: String { rawValue }

    /// 标题
    var title: String {
        switch self {
        case .overview: return L10n.tr("概览")
        case .apps: return L10n.tr("应用程序")
        case .homebrew: return "Homebrew"
        case .launchItems: return L10n.tr("启动项")
        case .leftovers: return L10n.tr("残留文件")
        }
    }

    /// 图标
    var symbol: String {
        switch self {
        case .overview: return "chart.pie"
        case .apps: return "square.grid.2x2"
        case .homebrew: return "mug"
        case .launchItems: return "power"
        case .leftovers: return "archivebox"
        }
    }
}

/// 全局状态：持有各模块视图模型与当前选中的模块
@Observable
@MainActor
final class AppState {
    /// 当前模块
    var section: SidebarSection = .overview
    let installedApps = InstalledAppsViewModel()
    let homebrew = HomebrewViewModel()
    let launchItems = LaunchItemsViewModel()
    let leftovers = LeftoversViewModel()
    let overview: OverviewViewModel

    init() {
        overview = OverviewViewModel(apps: installedApps, homebrew: homebrew,
                                     launchItems: launchItems, leftovers: leftovers)
    }

    /// 统一刷新入口随当前模块显示忙碌状态，避免重复触发扫描。
    var isCurrentSectionRefreshing: Bool { isRefreshing(section) }

    /// 按指定模块查询状态，侧栏未选中的模块也能正确显示进度。
    func isRefreshing(_ section: SidebarSection) -> Bool {
        switch section {
        case .overview: return overview.isRefreshing
        case .apps: return installedApps.isScanning
        case .homebrew: return homebrew.isLoading
        case .launchItems: return launchItems.isLoading
        case .leftovers: return leftovers.isScanning
        }
    }

    /// 刷新当前模块
    func refreshCurrentSection() async {
        await refresh(section)
    }

    /// 刷新指定模块，不改变当前页面；概览沿用刷新全部数据的语义。
    func refresh(_ section: SidebarSection) async {
        guard !isRefreshing(section) else { return }
        switch section {
        case .overview: await overview.refresh()
        case .apps: await installedApps.refresh()
        case .homebrew: await homebrew.refresh()
        case .launchItems: await launchItems.refresh()
        case .leftovers: await leftovers.refresh()
        }
    }

    /// 侧边栏徽标数字（0 表示不显示）
    /// - 应用程序：第三方应用数量（与概览页一致，不含系统应用）
    /// - Homebrew：可更新数量
    /// - 启动项：已开启数量
    /// - 残留文件：未忽略的残留数量
    func badge(for section: SidebarSection) -> Int {
        switch section {
        case .overview: return 0
        case .apps: return overview.thirdPartyApps.count
        case .homebrew: return homebrew.outdatedCount
        case .launchItems: return launchItems.enabledCount
        case .leftovers: return leftovers.activeCount
        }
    }
}
