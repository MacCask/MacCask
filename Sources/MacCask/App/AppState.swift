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

    /// 刷新当前模块
    func refreshCurrentSection() async {
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
