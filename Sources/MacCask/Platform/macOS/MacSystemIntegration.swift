import AppKit

/// macOS 系统集成实现：访达、系统设置、权限检测、运行中应用
struct MacSystemIntegration: SystemIntegrating {
    /// 在访达中显示并选中文件
    @MainActor func revealInFinder(_ urls: [URL]) {
        NSWorkspace.shared.activateFileViewerSelecting(urls)
    }

    /// 打开「隐私与安全性 → 完全磁盘访问权限」
    @MainActor func openFullDiskAccessSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }

    /// 打开「通用 → 登录项与扩展」
    @MainActor func openLoginItemsSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }

    /// 用默认浏览器打开网址
    @MainActor func openURL(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    /// 通过尝试读取受 TCC 保护的目录判断是否拥有完全磁盘访问权限
    func hasFullDiskAccess() -> Bool {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let probes = [
            home.appendingPathComponent("Library/Safari"),
            home.appendingPathComponent("Library/Mail"),
            URL(fileURLWithPath: "/Library/Application Support/com.apple.TCC")
        ]
        for probe in probes where FileManager.default.fileExists(atPath: probe.path) {
            if (try? FileManager.default.contentsOfDirectory(atPath: probe.path)) != nil {
                return true
            }
        }
        return false
    }

    /// 指定 bundle id 的应用是否正在运行
    @MainActor func isApplicationRunning(bundleID: String) -> Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty
    }

    /// 当前所有正在运行应用的 bundle id
    @MainActor func runningBundleIDs() -> Set<String> {
        Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
    }

    /// 读取启动磁盘容量；可用空间优先使用「重要用途可用容量」（包含可清除空间，与访达一致）
    func startupDiskUsage() -> DiskUsage? {
        let keys: Set<URLResourceKey> = [.volumeLocalizedNameKey, .volumeTotalCapacityKey,
                                         .volumeAvailableCapacityForImportantUsageKey, .volumeAvailableCapacityKey]
        guard let values = try? URL(fileURLWithPath: "/").resourceValues(forKeys: keys),
              let total = values.volumeTotalCapacity else { return nil }
        let available = values.volumeAvailableCapacityForImportantUsage ?? Int64(values.volumeAvailableCapacity ?? 0)
        return DiskUsage(volumeName: values.volumeLocalizedName ?? "Macintosh HD",
                         totalBytes: Int64(total), availableBytes: available)
    }
}
