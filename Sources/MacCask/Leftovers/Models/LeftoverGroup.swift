import Foundation

/// 残留可信度
enum LeftoverConfidence: Sendable {
    /// 同厂商没有任何应用仍在安装，基本可以确定是残留
    case high
    /// 同厂商仍有应用在安装，可能是共享数据，删除前请确认
    case low
}

/// 一组残留文件（同一标识符在不同目录中的条目）
struct LeftoverGroup: Identifiable, Hashable, Sendable {
    /// 以小写标识符作为唯一标识
    var id: String { identifier.lowercased() }
    /// 标识符（通常为 bundle id）
    let identifier: String
    /// 该标识符对应的所有文件
    var files: [LibraryFile]
    /// 可信度
    let confidence: LeftoverConfidence
    /// 是否已被用户忽略
    var isIgnored: Bool

    /// 合计大小
    var totalSize: Int64 { files.totalSize }

    /// 显示名称：取标识符最后一段，如 com.vendor.MyApp → MyApp
    var displayName: String {
        identifier.split(separator: ".").last.map(String.init) ?? identifier
    }

    /// 涉及的目录分类（去重）
    var categories: [LibraryCategory] {
        var seen = Set<LibraryCategory>()
        return files.map(\.category).filter { seen.insert($0).inserted }
    }
}
