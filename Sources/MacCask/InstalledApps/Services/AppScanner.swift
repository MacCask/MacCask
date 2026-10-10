import Foundation

/// 应用扫描服务：发现本机安装的 .app
enum AppScanner {
    /// 扫描根目录与是否属于系统目录
    private static var roots: [(url: URL, isSystemRoot: Bool)] {
        [
            (URL(fileURLWithPath: "/Applications"), false),
            (LibraryLocations.home.appendingPathComponent("Applications"), false),
            (URL(fileURLWithPath: "/System/Applications"), true)
        ]
    }

    /// 扫描所有应用（在后台线程执行）
    /// - Parameter caskApps: cask 安装的 app 文件名 → cask token
    static func scan(caskApps: [String: String]) async -> [InstalledApp] {
        await Task.detached(priority: .userInitiated) {
            var seen = Set<String>()
            var apps: [InstalledApp] = []
            for root in roots {
                for url in findApps(in: root.url, depth: 2) where seen.insert(url.path).inserted {
                    apps.append(makeApp(url: url, inSystemRoot: root.isSystemRoot, caskApps: caskApps))
                }
            }
            return apps
        }.value
    }

    /// 递归查找目录中的 .app（不进入 .app 内部），depth 控制子目录层数
    private static func findApps(in dir: URL, depth: Int) -> [URL] {
        guard depth > 0 else { return [] }
        var result: [URL] = []
        for entry in LibraryLocations.entries(of: dir) {
            if entry.pathExtension == "app" {
                result.append(entry)
            } else if (try? entry.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey])).map({ $0.isDirectory == true && $0.isPackage != true }) == true {
                result.append(contentsOf: findApps(in: entry, depth: depth - 1))
            }
        }
        return result
    }

    /// 读取应用信息并判断标签
    private static func makeApp(url: URL, inSystemRoot: Bool, caskApps: [String: String]) -> InstalledApp {
        let info = BundleInfoReader.read(url)
        // 系统应用：位于 /System 下，或苹果自带（com.apple.* 且不是 App Store 下载的，如 Safari）
        let isApple = info.bundleID?.hasPrefix("com.apple.") == true
        let isSystem = inSystemRoot || (isApple && !info.isAppStore)
        return InstalledApp(
            url: url,
            name: info.name,
            matchNames: info.matchNames,
            bundleID: info.bundleID,
            version: info.version,
            isSystem: isSystem,
            isAppStore: info.isAppStore,
            caskToken: isSystem ? nil : caskApps[url.lastPathComponent],
            lastUsed: BundleInfoReader.lastUsedDate(url)
        )
    }

    /// 通过 Spotlight 获取全盘所有应用的 bundle id（包含辅助程序等），用于残留判断
    static func allBundleIDsOnDisk() async -> Set<String> {
        let query = "kMDItemContentType == 'com.apple.application-bundle'"
        let result = await Platform.current.commandRunner.run("/usr/bin/mdfind", arguments: ["-attr", "kMDItemCFBundleIdentifier", query])
        var ids = Set<String>()
        let marker = "kMDItemCFBundleIdentifier = "
        for line in result.output.split(separator: "\n") {
            guard let range = line.range(of: marker) else { continue }
            let id = line[range.upperBound...].trimmingCharacters(in: .whitespaces)
            if !id.isEmpty && id != "(null)" { ids.insert(id) }
        }
        return ids
    }
}
