import Foundation

/// 启动项来源
enum LaunchItemSource: String, CaseIterable, Identifiable, Sendable {
    case loginItem = "登录项"
    case userAgent = "用户代理"
    case globalAgent = "全局代理"
    case systemDaemon = "系统守护进程"

    var id: String { rawValue }

    /// 来源说明
    var subtitle: String {
        switch self {
        case .loginItem: return "登录时自动打开的应用"
        case .userAgent: return "~/Library/LaunchAgents，仅对当前用户生效"
        case .globalAgent: return "/Library/LaunchAgents，对所有用户生效"
        case .systemDaemon: return "/Library/LaunchDaemons，以 root 身份在后台运行"
        }
    }

    /// 来源图标
    var symbol: String {
        switch self {
        case .loginItem: return "person.crop.circle"
        case .userAgent: return "person.badge.clock"
        case .globalAgent: return "person.2.badge.gearshape"
        case .systemDaemon: return "gearshape.2"
        }
    }

    /// 开关是否需要管理员权限
    var requiresAdmin: Bool { self == .systemDaemon }
}

/// 一个启动项
struct LaunchItem: Identifiable, Hashable, Sendable {
    /// 唯一标识：来源 + label
    var id: String { "\(source.rawValue):\(label)" }
    /// launchd Label；登录项为应用名称
    let label: String
    /// 来源
    let source: LaunchItemSource
    /// plist 文件路径（登录项为 nil）
    let plistURL: URL?
    /// 执行程序路径（登录项为应用路径）
    let program: String?
    /// 启动参数
    let arguments: [String]
    /// 是否加载时立即运行
    let runAtLoad: Bool
    /// 是否保持常驻
    let keepAlive: Bool
    /// 是否启用
    var isEnabled: Bool
    /// 正在运行的进程号
    let pid: Int?
    /// 关联的 .app 路径（用于显示图标与名称）
    let appPath: String?
    /// 显示名称
    let displayName: String

    /// 是否正在运行
    var isRunning: Bool { pid != nil }
}
