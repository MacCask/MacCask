import Foundation

/// 关联文件及扫描失败路径；扫描根目录失败也必须展示，不能作为空目录忽略。
struct RelatedFilesAnalysis: Sendable {
    var files: [LibraryFile] = []
    var unreadableURLs: Set<URL> = []
    var isComplete: Bool { unreadableURLs.isEmpty }

    /// 应用包已包含在 files 中，总占用直接汇总，不能再次加上包大小。
    var totalMeasurement: FileSizeMeasurement {
        FileSizeMeasurement(bytes: files.totalSize, unreadableURLs: unreadableURLs.union(
            files.filter { !$0.isSizeComplete }.map(\.url)))
    }
}

/// 关联文件分析：找出应用在各 Library 目录中留下的文件。
enum RelatedFilesAnalyzer {
    /// 在后台分析应用关联文件，支持注入扫描位置用于隔离测试。
    static func analyze(_ app: InstalledApp, locations: [LibraryLocation] = LibraryLocations.all()) async -> RelatedFilesAnalysis {
        await Task.detached(priority: .userInitiated) {
            var result = RelatedFilesAnalysis()
            append(app.url, category: .application, to: &result)
            for location in locations {
                do {
                    let entries = try FileManager.default.contentsOfDirectory(
                        at: location.url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
                    for entry in entries {
                        guard IdentifierMatcher.entry(entry.lastPathComponent, belongsTo: app.bundleID,
                            appNames: app.matchNames, allowNameMatch: location.matchesByName) else { continue }
                        append(entry, category: location.category, to: &result)
                    }
                } catch {
                    // 尚未创建的 Library 目录不属于失败；权限拒绝等错误必须保留。
                    let failure = error as NSError
                    if failure.domain != NSCocoaErrorDomain || failure.code != NSFileReadNoSuchFileError {
                        result.unreadableURLs.insert(location.url)
                    }
                }
            }
            return result
        }.value
    }

    /// 汇总大小与读取状态，保留无法读取的关联目录供用户定位。
    private static func append(_ url: URL, category: LibraryCategory, to result: inout RelatedFilesAnalysis) {
        let measurement = FileSizeCalculator.measure(of: url)
        result.files.append(LibraryFile(url: url, category: category, sizeBytes: measurement.bytes,
                                       isSizeComplete: measurement.isComplete))
        result.unreadableURLs.formUnion(measurement.unreadableURLs)
    }
}
