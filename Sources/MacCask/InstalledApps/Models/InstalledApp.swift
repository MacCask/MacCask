import Foundation

/// 已安装的应用
struct InstalledApp: Identifiable, Hashable, Sendable {
    /// 以路径作为唯一标识
    var id: String { url.path }
    /// 应用包路径
    let url: URL
    /// 显示名称
    let name: String
    /// 用于匹配关联文件的候选名称
    let matchNames: [String]
    /// Bundle ID
    let bundleID: String?
    /// 版本号
    let version: String?
    /// 是否为系统应用（禁止卸载）
    let isSystem: Bool
    /// 是否通过 App Store 安装
    let isAppStore: Bool
    /// 对应的 Homebrew cask token（非 Homebrew 安装为 nil）
    let caskToken: String?
    /// 上次使用时间
    let lastUsed: Date?

    /// 是否通过 Homebrew 安装
    var isHomebrew: Bool { caskToken != nil }
    /// 应用包文件名（如 Safari.app）
    var fileName: String { url.lastPathComponent }
}

/// 应用列表分类筛选
enum AppFilter: String, CaseIterable, Identifiable {
    case all = "全部"
    case thirdParty = "第三方"
    case system = "系统"
    case appStore = "App Store"
    case homebrew = "Homebrew"

    var id: String { rawValue }
    /// 展示文本随语言变化，原始值继续作为稳定标识。
    var title: String { L10n.tr(rawValue) }

    /// 导航与列表标题使用完整名称，避免孤立的分类词缺少上下文。
    var navigationTitle: String {
        switch self {
        case .all: return L10n.tr("全部应用")
        case .thirdParty: return L10n.tr("第三方应用")
        case .system: return L10n.tr("系统应用")
        case .appStore: return "App Store"
        case .homebrew: return L10n.tr("Homebrew 安装")
        }
    }

    /// 判断应用是否符合筛选条件
    func matches(_ app: InstalledApp) -> Bool {
        switch self {
        case .all: return true
        case .thirdParty: return !app.isSystem
        case .system: return app.isSystem
        case .appStore: return app.isAppStore
        case .homebrew: return app.isHomebrew
        }
    }
}

/// 应用列表排序方式
enum AppSortOrder: String, CaseIterable, Identifiable {
    case name = "名称"
    case size = "大小"
    case lastUsed = "上次使用"

    var id: String { rawValue }
    /// 展示排序名称，避免语言切换改变选中值。
    var title: String { L10n.tr(rawValue) }
}
