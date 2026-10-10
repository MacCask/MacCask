import Foundation

/// plist 文件读取工具
enum PlistReader {
    /// 读取 plist 为字典（兼容 XML 与二进制格式）
    static func dictionary(at url: URL) -> [String: Any]? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return (try? PropertyListSerialization.propertyList(from: data, format: nil)) as? [String: Any]
    }
}
