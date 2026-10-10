import Foundation

/// Library 中可能存放应用数据的目录分类
enum LibraryCategory: String, CaseIterable, Sendable {
    case applicationSupport = "应用支持"
    case caches = "缓存"
    case preferences = "偏好设置"
    case containers = "沙盒容器"
    case groupContainers = "群组容器"
    case savedState = "窗口状态"
    case logs = "日志"
    case httpStorages = "网络存储"
    case webKit = "WebKit 数据"
    case cookies = "Cookies"
    case launchAgents = "启动代理"
    case launchDaemons = "守护进程"
    case privilegedHelpers = "特权助手"
    case application = "应用程序"

    /// 分类对应的 SF Symbol 图标
    var symbol: String {
        switch self {
        case .applicationSupport: return "folder"
        case .caches: return "internaldrive"
        case .preferences: return "slider.horizontal.3"
        case .containers, .groupContainers: return "shippingbox"
        case .savedState: return "macwindow"
        case .logs: return "doc.text"
        case .httpStorages, .webKit, .cookies: return "network"
        case .launchAgents, .launchDaemons: return "power"
        case .privilegedHelpers: return "lock.shield"
        case .application: return "app"
        }
    }
}

/// 一个需要扫描的 Library 目录
struct LibraryLocation: Sendable {
    /// 目录路径
    let url: URL
    /// 目录分类
    let category: LibraryCategory
    /// 是否允许按应用名称（而不仅是 bundle id）匹配，名称匹配只在误报较低的目录开启
    let matchesByName: Bool
}

/// Library 目录定义，关联文件分析与残留扫描共用
enum LibraryLocations {
    /// 当前用户主目录
    static var home: URL { FileManager.default.homeDirectoryForCurrentUser }

    /// 所有需要扫描的目录（用户级 + 系统级）
    static func all() -> [LibraryLocation] {
        let user = home.appendingPathComponent("Library")
        let system = URL(fileURLWithPath: "/Library")
        return [
            LibraryLocation(url: user.appendingPathComponent("Application Support"), category: .applicationSupport, matchesByName: true),
            LibraryLocation(url: user.appendingPathComponent("Caches"), category: .caches, matchesByName: true),
            LibraryLocation(url: user.appendingPathComponent("Preferences"), category: .preferences, matchesByName: false),
            LibraryLocation(url: user.appendingPathComponent("Preferences/ByHost"), category: .preferences, matchesByName: false),
            LibraryLocation(url: user.appendingPathComponent("Containers"), category: .containers, matchesByName: false),
            LibraryLocation(url: user.appendingPathComponent("Group Containers"), category: .groupContainers, matchesByName: false),
            LibraryLocation(url: user.appendingPathComponent("Saved Application State"), category: .savedState, matchesByName: false),
            LibraryLocation(url: user.appendingPathComponent("Logs"), category: .logs, matchesByName: true),
            LibraryLocation(url: user.appendingPathComponent("HTTPStorages"), category: .httpStorages, matchesByName: false),
            LibraryLocation(url: user.appendingPathComponent("WebKit"), category: .webKit, matchesByName: false),
            LibraryLocation(url: user.appendingPathComponent("Cookies"), category: .cookies, matchesByName: false),
            LibraryLocation(url: user.appendingPathComponent("LaunchAgents"), category: .launchAgents, matchesByName: false),
            LibraryLocation(url: system.appendingPathComponent("Application Support"), category: .applicationSupport, matchesByName: true),
            LibraryLocation(url: system.appendingPathComponent("Caches"), category: .caches, matchesByName: false),
            LibraryLocation(url: system.appendingPathComponent("Preferences"), category: .preferences, matchesByName: false),
            LibraryLocation(url: system.appendingPathComponent("Logs"), category: .logs, matchesByName: true),
            LibraryLocation(url: system.appendingPathComponent("LaunchAgents"), category: .launchAgents, matchesByName: false),
            LibraryLocation(url: system.appendingPathComponent("LaunchDaemons"), category: .launchDaemons, matchesByName: false),
            LibraryLocation(url: system.appendingPathComponent("PrivilegedHelperTools"), category: .privilegedHelpers, matchesByName: false)
        ]
    }

    /// 列出目录下的直接子项（跳过隐藏文件），无权限时返回空
    static func entries(of url: URL) -> [URL] {
        (try? FileManager.default.contentsOfDirectory(
            at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]
        )) ?? []
    }
}
