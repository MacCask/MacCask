import Foundation

/// 公共商店目录信息，不读取 Apple 账户或购买记录。
struct StoreApp: Decodable, Sendable {
    let trackId: Int64
    let bundleId: String
    let version: String
    let minimumOsVersion: String?
    let kind: String

    /// 使用已校验的商店 ID 构造系统 App Store 链接，不信任远程返回的任意网址。
    func storeURL(country: String) -> URL {
        URL(string: "macappstore://apps.apple.com/\(country)/app/id\(trackId)")!
    }

    /// 商店要求高于当前系统时显示要求，避免将不可安装版本描述为可直接更新。
    var requiresNewerSystem: Bool {
        guard let minimumOsVersion else { return false }
        let os = ProcessInfo.processInfo.operatingSystemVersion
        return NumericVersion.compare(minimumOsVersion, "\(os.majorVersion).\(os.minorVersion).\(os.patchVersion)") == .orderedDescending
    }
}
