import Foundation

/// 保留成功读取的字节数和失败路径，避免将部分结果当作完整占用。
struct FileSizeMeasurement: Sendable {
    var bytes: Int64 = 0
    var unreadableURLs: Set<URL> = []
    var isComplete: Bool { unreadableURLs.isEmpty }
}

/// 文件/目录磁盘占用计算工具。
enum FileSizeCalculator {
    private static let fileKeys: Set<URLResourceKey> = [
        .isDirectoryKey, .isSymbolicLinkKey, .isRegularFileKey,
        .totalFileAllocatedSizeKey, .fileAllocatedSizeKey
    ]

    /// 计算已读取部分的大小；需要判断完整性时使用 measure。
    static func allocatedSize(of url: URL) -> Int64 {
        measure(of: url).bytes
    }

    /// 递归计算实际磁盘占用，不跟随符号链接，并记录读取失败的路径。
    static func measure(of url: URL) -> FileSizeMeasurement {
        var result = FileSizeMeasurement()
        do {
            let values = try url.resourceValues(forKeys: fileKeys)
            if values.isSymbolicLink == true { return result }
            if values.isDirectory != true {
                if let size = values.totalFileAllocatedSize ?? values.fileAllocatedSize {
                    result.bytes = Int64(size)
                } else {
                    result.unreadableURLs.insert(url)
                }
                return result
            }
        } catch {
            result.unreadableURLs.insert(url)
            return result
        }
        // 包内文件和隐藏文件也计入；遇到权限错误继续扫描其他可读目录。
        guard let enumerator = FileManager.default.enumerator(
            at: url, includingPropertiesForKeys: Array(fileKeys), options: [],
            errorHandler: { failedURL, _ in
                result.unreadableURLs.insert(failedURL)
                return true
            }
        ) else {
            result.unreadableURLs.insert(url)
            return result
        }
        for case let fileURL as URL in enumerator {
            do {
                let values = try fileURL.resourceValues(forKeys: fileKeys)
                guard values.isSymbolicLink != true, values.isRegularFile == true else { continue }
                if let size = values.totalFileAllocatedSize ?? values.fileAllocatedSize {
                    result.bytes += Int64(size)
                } else {
                    result.unreadableURLs.insert(fileURL)
                }
            } catch {
                result.unreadableURLs.insert(fileURL)
            }
        }
        return result
    }

    /// 在后台线程计算大小，避免阻塞主线程。
    static func allocatedSizeInBackground(of url: URL) async -> Int64 {
        await Task.detached(priority: .utility) { allocatedSize(of: url) }.value
    }

    /// 读取文件修改时间。
    static func modificationDate(of url: URL) -> Date? {
        try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }
}
