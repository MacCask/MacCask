import Foundation

/// 概览统计服务：负责需要额外计算的数据与纯统计逻辑
enum OverviewService {
    /// Homebrew 占用：Cellar（命令行工具）+ Caskroom（图形应用安装包）
    static func homebrewDiskSize() async -> Int64? {
        guard let prefix = await BrewService.shared.prefix() else { return nil }
        let base = URL(fileURLWithPath: prefix)
        return await Task.detached(priority: .utility) {
            FileSizeCalculator.allocatedSize(of: base.appendingPathComponent("Cellar"))
                + FileSizeCalculator.allocatedSize(of: base.appendingPathComponent("Caskroom"))
        }.value
    }

    /// 当前用户缓存目录（~/Library/Caches）占用
    static func userCacheSize() async -> Int64 {
        await FileSizeCalculator.allocatedSizeInBackground(of: LibraryLocations.home.appendingPathComponent("Library/Caches"))
    }

    /// 按上次使用时间把应用分组
    static func activityBuckets(apps: [InstalledApp], sizes: [String: Int64], now: Date = Date()) -> [ActivityBucket] {
        let day: TimeInterval = 86_400
        // 分组上限（天），nil 表示无上限；最后单独统计未知
        let ranges: [(String, Double?, Bool)] = [
            ("7 天内", 7, false), ("30 天内", 30, false), ("半年内", 182, false),
            ("一年内", 365, false), ("超过一年", nil, true)
        ]
        var counts = Array(repeating: 0, count: ranges.count)
        var bytes = Array(repeating: Int64(0), count: ranges.count)
        var unknownCount = 0
        var unknownBytes: Int64 = 0
        for app in apps {
            let size = sizes[app.id] ?? 0
            guard let lastUsed = app.lastUsed else {
                unknownCount += 1; unknownBytes += size
                continue
            }
            let days = now.timeIntervalSince(lastUsed) / day
            let index = ranges.firstIndex { $0.1.map { days <= $0 } ?? true } ?? ranges.count - 1
            counts[index] += 1
            bytes[index] += size
        }
        var buckets = ranges.enumerated().map { i, r in
            ActivityBucket(title: r.0, count: counts[i], bytes: bytes[i], isStale: r.2)
        }
        if unknownCount > 0 {
            buckets.append(ActivityBucket(title: "未知", count: unknownCount, bytes: unknownBytes, isStale: false, isUnknown: true))
        }
        return buckets
    }
}
