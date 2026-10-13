/// 更新入口的平台接口，界面无需直接依赖 Sparkle。
@MainActor
protocol AppUpdating: AnyObject {
    var availableVersion: String? { get }
    var canCheckForUpdates: Bool { get }
    var automaticallyChecksForUpdates: Bool { get set }
    func checkForUpdates()
}

