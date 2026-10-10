import Foundation

/// 文件/目录磁盘占用计算工具
enum FileSizeCalculator {
    private static let fileKeys: [URLResourceKey] = [
        .isRegularFileKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey
    ]

    /// 计算文件或目录实际占用的磁盘大小（字节）；不跟随符号链接，无法读取的部分忽略
    static func allocatedSize(of url: URL) -> Int64 {
        guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey]) else {
            return 0
        }
        // 符号链接本身几乎不占空间
        if values.isSymbolicLink == true { return 0 }
        if values.isDirectory != true {
            return Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
        }
        // 目录：递归累加所有普通文件（包括 .app 等包内部）
        guard let enumerator = FileManager.default.enumerator(
            at: url, includingPropertiesForKeys: fileKeys, options: [], errorHandler: { _, _ in true }
        ) else { return 0 }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let v = try? fileURL.resourceValues(forKeys: Set(fileKeys)), v.isRegularFile == true else { continue }
            total += Int64(v.totalFileAllocatedSize ?? v.fileAllocatedSize ?? 0)
        }
        return total
    }

    /// 在后台线程计算大小，避免阻塞主线程
    static func allocatedSizeInBackground(of url: URL) async -> Int64 {
        await Task.detached(priority: .utility) { allocatedSize(of: url) }.value
    }

    /// 读取文件修改时间
    static func modificationDate(of url: URL) -> Date? {
        try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }
}
