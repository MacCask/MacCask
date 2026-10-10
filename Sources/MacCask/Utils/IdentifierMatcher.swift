import Foundation

/// 标识符解析与匹配工具：从 Library 文件名中提取 bundle id，并与已安装应用比对
enum IdentifierMatcher {
    /// 需要剥离的文件后缀
    private static let strippedSuffixes = [".plist", ".savedState", ".binarycookies", ".lockfile"]

    /// 系统标识符前缀，这些条目不会被当作残留
    static let systemPrefixes = [
        "com.apple.", "group.com.apple.", "systemgroup.com.apple.", "org.cups.", "com.openssh.", "org.openbsd.",
        // 开发工具链与第三方 SDK 的共享缓存，不属于某个具体应用
        "org.swift.", "com.crashlytics.", "com.plausiblelabs.", "org.sparkle-project.", "io.sentry."
    ]

    /// 从文件/目录名中提取标识符
    /// - 去掉 .plist / .savedState 等后缀
    /// - 去掉 ByHost 偏好设置末尾的硬件 UUID
    /// - 去掉群组容器的 `group.` 前缀或 10 位 TeamID 前缀
    static func identifier(fromEntryName name: String) -> String {
        var result = name
        for suffix in strippedSuffixes where result.hasSuffix(suffix) {
            result = String(result.dropLast(suffix.count))
        }
        var parts = result.split(separator: ".").map(String.init)
        // ByHost：com.vendor.app.XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX
        if let last = parts.last, parts.count > 2, looksLikeUUID(last) {
            parts.removeLast()
        }
        // 群组容器前缀
        if parts.count > 2, parts[0] == "group" {
            parts.removeFirst()
        } else if parts.count > 2, looksLikeTeamID(parts[0]) {
            parts.removeFirst()
        }
        return parts.joined(separator: ".")
    }

    /// 是否为反向域名格式（至少三段，如 com.vendor.app）
    static func isReverseDNS(_ identifier: String) -> Bool {
        let parts = identifier.split(separator: ".")
        guard parts.count >= 3 else { return false }
        let tlds: Set<String> = ["com", "org", "net", "io", "cn", "de", "jp", "co", "me", "app", "dev", "uk", "fr", "ru", "us", "info", "tv", "cc", "ai", "xyz"]
        return tlds.contains(parts[0].lowercased())
    }

    /// 是否为系统标识符
    static func isSystemIdentifier(_ identifier: String) -> Bool {
        let lower = identifier.lowercased()
        return systemPrefixes.contains { lower.hasPrefix($0) }
    }

    /// 两个标识符是否属于同一应用：相等，或一方是另一方的「.」前缀（如 com.foo.app 与 com.foo.app.helper）
    static func isRelated(_ a: String, _ b: String) -> Bool {
        let x = a.lowercased(), y = b.lowercased()
        return x == y || x.hasPrefix(y + ".") || y.hasPrefix(x + ".")
    }

    /// 厂商前缀（前两段），如 com.google.Chrome → com.google
    static func vendor(of identifier: String) -> String {
        identifier.lowercased().split(separator: ".").prefix(2).joined(separator: ".")
    }

    /// 判断 Library 中的条目是否属于某个应用
    /// - Parameters:
    ///   - entryName: 文件或目录名
    ///   - bundleID: 应用 bundle id
    ///   - appNames: 应用的候选名称（文件名、CFBundleName 等）
    ///   - allowNameMatch: 是否允许按名称匹配
    static func entry(_ entryName: String, belongsTo bundleID: String?, appNames: [String], allowNameMatch: Bool) -> Bool {
        let id = identifier(fromEntryName: entryName)
        if let bundleID, !bundleID.isEmpty, isRelated(id, bundleID) {
            return true
        }
        // 名称匹配需要完全相等，且名称至少 3 个字符，避免过短名称误报
        guard allowNameMatch else { return false }
        return appNames.contains { $0.count >= 3 && entryName.caseInsensitiveCompare($0) == .orderedSame }
    }

    /// 是否像 UUID（8-4-4-4-12 格式）
    private static func looksLikeUUID(_ s: String) -> Bool {
        s.count == 36 && s.filter { $0 == "-" }.count == 4
    }

    /// 是否像苹果开发者 TeamID（10 位大写字母或数字）
    private static func looksLikeTeamID(_ s: String) -> Bool {
        s.count == 10 && s.allSatisfy { $0.isUppercase || $0.isNumber }
    }
}
