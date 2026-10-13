import Combine
import Sparkle

/// macOS 更新器：仅正式应用包启动更新，裸程序与文档渲染不访问更新源。
@MainActor
final class MacAppUpdater: NSObject, ObservableObject, AppUpdating, @preconcurrency SPUStandardUserDriverDelegate {
    static let shared = MacAppUpdater()
    @Published private(set) var availableVersion: String?
    @Published private(set) var canCheckForUpdates = false
    @Published var automaticallyChecksForUpdates = false {
        didSet {
            if let updater = controller?.updater,
               updater.automaticallyChecksForUpdates != automaticallyChecksForUpdates {
                updater.automaticallyChecksForUpdates = automaticallyChecksForUpdates
            }
        }
    }
    private var controller: SPUStandardUpdaterController?
    private var observations = Set<AnyCancellable>()

    /// 只有具有更新地址和公钥的应用包才初始化更新器，避免开发运行报错。
    private override init() {
        super.init()
        guard Bundle.main.bundleURL.pathExtension == "app",
              Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") is String,
              Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") is String else { return }
        let controller = SPUStandardUpdaterController(startingUpdater: false,
            updaterDelegate: nil, userDriverDelegate: self)
        self.controller = controller
        controller.updater.publisher(for: \.canCheckForUpdates)
            .receive(on: RunLoop.main).sink { [weak self] in self?.canCheckForUpdates = $0 }
            .store(in: &observations)
        controller.updater.publisher(for: \.automaticallyChecksForUpdates)
            .receive(on: RunLoop.main).sink { [weak self] in self?.automaticallyChecksForUpdates = $0 }
            .store(in: &observations)
        controller.startUpdater()
    }

    /// 后台发现新版时由页面提示代替 Sparkle 自动弹窗。
    var supportsGentleScheduledUpdateReminders: Bool { true }

    /// 即使刚启动或系统空闲，也等待用户主动打开更新窗口。
    func standardUserDriverShouldHandleShowingScheduledUpdate(_ update: SUAppcastItem,
                                                              andInImmediateFocus immediateFocus: Bool) -> Bool {
        false
    }

    /// 保留待更新版本供页面显示；手动检查仍使用标准更新窗口。
    func standardUserDriverWillHandleShowingUpdate(_ handleShowingUpdate: Bool,
                                                   forUpdate update: SUAppcastItem, state: SPUUserUpdateState) {
        availableVersion = update.displayVersionString
    }

    /// 取消、跳过或失败结束会话后撤下提示，避免留下无法继续的更新入口。
    func standardUserDriverWillFinishUpdateSession() { availableVersion = nil }

    /// 用户主动检查时使用 Sparkle 标准交互，验证成功后才能安装。
    func checkForUpdates() { controller?.checkForUpdates(nil) }
}
