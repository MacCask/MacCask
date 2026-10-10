import Foundation

/// 已安装应用标识符索引，用于快速判断某标识符是否仍有应用在使用
struct InstalledIdentifierIndex: Sendable {
    /// 已安装 bundle id（小写）
    private let ids: Set<String>
    /// 已安装 bundle id 的所有「.」前缀（至少三段，小写）
    private let prefixes: Set<String>
    /// 已安装应用的厂商前缀（前两段，小写）
    private let vendors: Set<String>

    /// 由 bundle id 集合构建索引
    init(bundleIDs: Set<String>) {
        let lower = Set(bundleIDs.map { $0.lowercased() })
        var prefixes = Set<String>()
        for id in lower {
            let parts = id.split(separator: ".")
            guard parts.count >= 3 else { continue }
            for n in 3...parts.count {
                prefixes.insert(parts.prefix(n).joined(separator: "."))
            }
        }
        ids = lower
        self.prefixes = prefixes
        vendors = Set(lower.map(IdentifierMatcher.vendor(of:)))
    }

    /// 标识符是否属于已安装应用（相等或互为「.」前缀）
    func isInstalled(_ identifier: String) -> Bool {
        let lower = identifier.lowercased()
        // 已安装 id 以候选为前缀（或相等）
        if prefixes.contains(lower) { return true }
        // 候选以已安装 id 为前缀，如 com.foo.app.helper 属于 com.foo.app
        let parts = lower.split(separator: ".")
        guard parts.count > 2 else { return false }
        for n in 2..<parts.count where ids.contains(parts.prefix(n).joined(separator: ".")) {
            return true
        }
        return false
    }

    /// 同厂商是否仍有已安装应用
    func hasVendor(of identifier: String) -> Bool {
        vendors.contains(IdentifierMatcher.vendor(of: identifier))
    }
}

/// 残留文件扫描服务
enum LeftoverScanner {
    /// 收集所有「已安装」的标识符：应用目录扫描 + Spotlight 全盘 + 运行中的应用 + 有效的 launchd 项 + 本应用
    @MainActor
    static func collectInstalledIDs() async -> Set<String> {
        async let spotlight = AppScanner.allBundleIDsOnDisk()
        async let apps = AppScanner.scan(caskApps: [:])
        async let launchd = LaunchItemScanner.scanLaunchdItems()
        var ids = Platform.current.system.runningBundleIDs()
        ids.formUnion(await spotlight)
        ids.formUnion(await apps.compactMap(\.bundleID))
        // 执行程序仍然存在的 launchd 项不是残留（其 plist 与特权助手通常以 Label 命名）
        ids.formUnion(await launchd.filter { $0.program.map(FileManager.default.fileExists(atPath:)) == true }.map(\.label))
        if let own = Bundle.main.bundleIdentifier { ids.insert(own) }
        return ids
    }

    /// 扫描 Library 目录中的残留文件（后台执行）
    static func scan(index: InstalledIdentifierIndex) async -> [LeftoverGroup] {
        await Task.detached(priority: .userInitiated) {
            var groups: [String: LeftoverGroup] = [:]
            var order: [String] = []
            for location in LibraryLocations.all() {
                for entry in LibraryLocations.entries(of: location.url) {
                    let identifier = IdentifierMatcher.identifier(fromEntryName: entry.lastPathComponent)
                    // 只处理反向域名格式、非系统、且没有对应已安装应用的条目
                    guard IdentifierMatcher.isReverseDNS(identifier),
                          !IdentifierMatcher.isSystemIdentifier(identifier),
                          !index.isInstalled(identifier) else { continue }
                    let file = LibraryFile(url: entry, category: location.category,
                                           sizeBytes: FileSizeCalculator.allocatedSize(of: entry))
                    let key = identifier.lowercased()
                    if groups[key] == nil {
                        order.append(key)
                        groups[key] = LeftoverGroup(identifier: identifier, files: [],
                                                    confidence: index.hasVendor(of: identifier) ? .low : .high,
                                                    isIgnored: false)
                    }
                    groups[key]?.files.append(file)
                }
            }
            return order.compactMap { groups[$0] }
        }.value
    }
}
