import Foundation

/// Library 中的一个文件/目录条目（关联文件分析与残留扫描共用）
struct LibraryFile: Identifiable, Hashable, Sendable {
    /// 以路径作为唯一标识
    var id: String { url.path }
    /// 文件路径
    let url: URL
    /// 所属分类
    let category: LibraryCategory
    /// 占用大小（字节）
    let sizeBytes: Int64

    /// 是否位于系统级目录（删除需要管理员权限）
    var isSystemLevel: Bool { !url.path.hasPrefix(LibraryLocations.home.path) }

    /// 显示用路径：把主目录替换为 ~
    var displayPath: String {
        let home = LibraryLocations.home.path
        return url.path.hasPrefix(home) ? "~" + url.path.dropFirst(home.count) : url.path
    }
}

extension Array where Element == LibraryFile {
    /// 合计大小
    var totalSize: Int64 { reduce(0) { $0 + $1.sizeBytes } }
}
