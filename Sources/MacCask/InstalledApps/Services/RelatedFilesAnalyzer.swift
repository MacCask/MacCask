import Foundation

/// 关联文件分析：找出应用在各 Library 目录中留下的文件
enum RelatedFilesAnalyzer {
    /// 分析应用的关联文件（包含应用包本身），在后台线程执行
    static func analyze(_ app: InstalledApp) async -> [LibraryFile] {
        await Task.detached(priority: .userInitiated) {
            var files: [LibraryFile] = [
                LibraryFile(url: app.url, category: .application, sizeBytes: FileSizeCalculator.allocatedSize(of: app.url))
            ]
            for location in LibraryLocations.all() {
                for entry in LibraryLocations.entries(of: location.url) {
                    guard IdentifierMatcher.entry(entry.lastPathComponent, belongsTo: app.bundleID,
                                                  appNames: app.matchNames, allowNameMatch: location.matchesByName) else { continue }
                    files.append(LibraryFile(url: entry, category: location.category,
                                             sizeBytes: FileSizeCalculator.allocatedSize(of: entry)))
                }
            }
            return files
        }.value
    }
}
