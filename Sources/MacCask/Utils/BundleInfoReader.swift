import AppKit

/// 应用包基础信息
struct BundleInfo: Sendable {
    /// 访达中显示的本地化名称
    let name: String
    /// 用于匹配 Library 目录的候选名称（文件名、CFBundleName、可执行文件名，去重）
    let matchNames: [String]
    let bundleID: String?
    let version: String?
    /// 是否通过 App Store 安装
    let isAppStore: Bool
}

/// 应用包信息读取工具
enum BundleInfoReader {
    /// 读取 .app 的 Info.plist 信息
    static func read(_ url: URL) -> BundleInfo {
        let info = NSDictionary(contentsOf: url.appendingPathComponent("Contents/Info.plist")) as? [String: Any] ?? [:]
        let fileName = url.deletingPathExtension().lastPathComponent
        // 访达显示名（已本地化，如 Calculator.app 显示为「计算器」）
        var name = FileManager.default.displayName(atPath: url.path)
        if name.hasSuffix(".app") { name = String(name.dropLast(4)) }
        var matchNames: [String] = []
        for candidate in [fileName, info["CFBundleName"] as? String, info["CFBundleExecutable"] as? String] {
            if let candidate, !candidate.isEmpty, !matchNames.contains(candidate) { matchNames.append(candidate) }
        }
        let short = info["CFBundleShortVersionString"] as? String
        let build = info["CFBundleVersion"] as? String
        let isAppStore = FileManager.default.fileExists(atPath: url.appendingPathComponent("Contents/_MASReceipt").path)
        return BundleInfo(name: name.isEmpty ? fileName : name,
                          matchNames: matchNames,
                          bundleID: info["CFBundleIdentifier"] as? String,
                          version: short ?? build,
                          isAppStore: isAppStore)
    }

    /// 通过 Spotlight 读取应用上次使用时间
    static func lastUsedDate(_ url: URL) -> Date? {
        guard let item = MDItemCreateWithURL(nil, url as CFURL) else { return nil }
        return MDItemCopyAttribute(item, kMDItemLastUsedDate) as? Date
    }

    /// 读取应用图标（带缓存）
    @MainActor static func icon(for path: String) -> NSImage {
        if let cached = iconCache[path] { return cached }
        let image = NSWorkspace.shared.icon(forFile: path)
        iconCache[path] = image
        return image
    }

    @MainActor private static var iconCache: [String: NSImage] = [:]

    /// 从路径中截取所在的 .app 包路径，如 /Applications/A.app/Contents/MacOS/a → /Applications/A.app
    static func enclosingAppPath(of path: String) -> String? {
        guard let range = path.range(of: ".app/") ?? (path.hasSuffix(".app") ? path.range(of: ".app", options: .backwards) : nil) else {
            return nil
        }
        return String(path[path.startIndex..<range.lowerBound]) + ".app"
    }
}
