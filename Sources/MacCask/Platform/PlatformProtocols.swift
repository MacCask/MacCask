import Foundation

// MARK: - 平台抽象接口
// 所有与操作系统交互的能力都在这里以协议定义，具体实现放到各平台子目录（如 macOS/）。
// 修改协议时，所有平台实现必须同步修改。

/// 外部命令执行结果
struct CommandResult: Sendable {
    /// 进程退出码
    let exitCode: Int32
    /// 标准输出与标准错误合并后的文本
    let output: String

    /// 是否执行成功（退出码为 0）
    var succeeded: Bool { exitCode == 0 }

    /// 构造一个失败结果，用于命令无法启动等情况
    static func failure(_ message: String) -> CommandResult {
        CommandResult(exitCode: -1, output: message)
    }
}

/// 外部命令执行接口
protocol CommandRunning: Sendable {
    /// 执行命令并等待结束
    /// - Parameters:
    ///   - executable: 可执行文件绝对路径
    ///   - arguments: 参数列表
    ///   - environment: 额外的环境变量（会合并到当前进程环境）
    ///   - onOutput: 实时输出回调（每次收到一段文本时调用，可能在后台线程）
    func run(_ executable: String,
             arguments: [String],
             environment: [String: String],
             onOutput: (@Sendable (String) -> Void)?) async -> CommandResult
}

extension CommandRunning {
    /// 便捷方法：不需要额外环境变量和实时输出时使用
    func run(_ executable: String, arguments: [String]) async -> CommandResult {
        await run(executable, arguments: arguments, environment: [:], onOutput: nil)
    }
}

/// 以管理员权限执行命令的接口
protocol PrivilegedCommandRunning: Sendable {
    /// 以管理员权限执行一段 shell 命令（会弹出系统授权框）
    func runAsAdministrator(_ shellCommand: String) async -> CommandResult
}

/// 文件删除（移到废纸篓）接口
protocol FileTrashing: Sendable {
    /// 将多个文件移到废纸篓；普通权限失败的文件会尝试申请管理员权限
    /// - Returns: 每个失败文件的路径与错误信息
    func moveToTrash(_ urls: [URL]) async -> [URL: String]
}

/// 登录项描述
struct LoginItemInfo: Sendable, Hashable {
    /// 显示名称
    let name: String
    /// 应用路径
    let path: String
}

/// 登录项管理接口
protocol LoginItemManaging: Sendable {
    /// 读取当前用户的全部登录项
    func listLoginItems() async -> Result<[LoginItemInfo], Error>
    /// 添加登录项
    func addLoginItem(path: String) async -> CommandResult
    /// 按名称移除登录项
    func removeLoginItem(name: String) async -> CommandResult
}

/// 磁盘容量信息
struct DiskUsage: Sendable {
    /// 卷名称
    let volumeName: String
    /// 总容量（字节）
    let totalBytes: Int64
    /// 可用容量（字节，包含系统可回收的空间，与访达显示一致）
    let availableBytes: Int64

    /// 已用容量
    var usedBytes: Int64 { max(totalBytes - availableBytes, 0) }
    /// 已用比例（0~1）
    var usedFraction: Double { totalBytes > 0 ? Double(usedBytes) / Double(totalBytes) : 0 }
    /// 计算某个大小占总容量的比例（0~1）
    func fraction(of bytes: Int64) -> Double { totalBytes > 0 ? Double(bytes) / Double(totalBytes) : 0 }
}

/// 系统集成接口（访达、系统设置、权限检测等）
protocol SystemIntegrating: Sendable {
    /// 在访达中显示并选中文件
    @MainActor func revealInFinder(_ urls: [URL])
    /// 打开「完全磁盘访问权限」设置页
    @MainActor func openFullDiskAccessSettings()
    /// 打开「登录项与扩展」设置页
    @MainActor func openLoginItemsSettings()
    /// 打开网址
    @MainActor func openURL(_ url: URL)
    /// 当前进程是否拥有完全磁盘访问权限
    func hasFullDiskAccess() -> Bool
    /// 指定 bundle id 的应用是否正在运行
    @MainActor func isApplicationRunning(bundleID: String) -> Bool
    /// 当前所有正在运行应用的 bundle id
    @MainActor func runningBundleIDs() -> Set<String>
    /// 启动磁盘的容量信息
    func startupDiskUsage() -> DiskUsage?
}

/// 平台服务集合，业务层统一通过 `Platform.current` 获取
struct PlatformServices: Sendable {
    let commandRunner: any CommandRunning
    let privilegedRunner: any PrivilegedCommandRunning
    let trasher: any FileTrashing
    let loginItems: any LoginItemManaging
    let system: any SystemIntegrating
}

/// 平台服务入口
enum Platform {
    /// 当前平台的服务实现
    static let current: PlatformServices = {
        #if os(macOS)
        let runner = MacCommandRunner()
        let privileged = MacPrivilegedCommandRunner(runner: runner)
        return PlatformServices(
            commandRunner: runner,
            privilegedRunner: privileged,
            trasher: MacFileTrasher(privilegedRunner: privileged),
            loginItems: MacLoginItemManager(runner: runner),
            system: MacSystemIntegration()
        )
        #else
        #error("暂不支持当前平台")
        #endif
    }()
}
