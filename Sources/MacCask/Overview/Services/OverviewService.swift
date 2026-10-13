import Foundation

/// 概览统计服务：负责需要额外计算的数据与纯统计逻辑
enum OverviewService {
    /// Homebrew 占用：Cellar（命令行工具）+ Caskroom（图形应用安装包）
    static func homebrewDiskSize() async -> Int64? {
        guard let prefix = await BrewService.shared.prefix() else { return nil }
        let base = URL(fileURLWithPath: prefix)
        let worker = Task.detached(priority: .utility) {
            FileSizeCalculator.allocatedSize(of: base.appendingPathComponent("Cellar"))
                + FileSizeCalculator.allocatedSize(of: base.appendingPathComponent("Caskroom"))
        }
        return await withTaskCancellationHandler { await worker.value } onCancel: { worker.cancel() }
    }

    /// 当前用户缓存目录（~/Library/Caches）占用
    static func userCacheSize() async -> Int64 {
        await FileSizeCalculator.allocatedSizeInBackground(of: LibraryLocations.home.appendingPathComponent("Library/Caches"))
    }

    /// 磁盘分类使用唯一文件：应用关联缓存归应用，残余用户缓存单独统计，残留排除重叠。
    static func diskCategories(appFiles: [LibraryFile], leftoverFiles: [LibraryFile],
                               cacheBytes: Int64?, cacheRoot: URL = LibraryLocations.home.appendingPathComponent("Library/Caches"))
        -> (apps: Int64, caches: Int64?, leftovers: Int64) {
        let owned = appFiles.uniqueFiles
        let root = cacheRoot.standardizedFileURL.path
        var ownedPaths = Set<String>()
        var subtreeBytes: [String: Int64] = [:]
        var ownedCaches: Int64 = 0
        for file in owned {
            let path = file.url.standardizedFileURL.path
            ownedPaths.insert(path)
            let ancestors = PathHierarchy.ancestors(of: path)
            if ancestors.contains(root) { ownedCaches += file.sizeBytes }
            for ancestor in ancestors { subtreeBytes[ancestor, default: 0] += file.sizeBytes }
        }
        let remainingLeftovers = leftoverFiles.uniqueFiles.reduce(Int64(0)) { total, file in
            let path = file.url.standardizedFileURL.path
            let ancestors = PathHierarchy.ancestors(of: path)
            guard !ancestors.contains(root), !ancestors.contains(where: { ownedPaths.contains($0) }) else { return total }
            // 父级残留只扣除已归属子项；索引查询避免每次绘制进行平方级路径比较。
            return total + max(file.sizeBytes - (subtreeBytes[path] ?? 0), 0)
        }
        return (owned.totalSize, cacheBytes.map { max($0 - ownedCaches, 0) }, remainingLeftovers)
    }

    /// 按上次使用时间把应用分组
    static func activityBuckets(apps: [InstalledApp], sizes: [String: FileSizeMeasurement], now: Date = Date()) -> [ActivityBucket] {
        let day: TimeInterval = 86_400
        // 分组上限（天），nil 表示无上限；最后单独统计未知
        let ranges: [(String, Double?, Bool)] = [
            (L10n.tr("7 天内"), 7, false), (L10n.tr("30 天内"), 30, false), (L10n.tr("半年内"), 182, false),
            (L10n.tr("一年内"), 365, false), (L10n.tr("超过一年"), nil, true)
        ]
        var counts = Array(repeating: 0, count: ranges.count)
        var bytes = Array(repeating: Int64(0), count: ranges.count)
        var complete = Array(repeating: true, count: ranges.count)
        var unknownComplete = true
        var unknownCount = 0
        var unknownBytes: Int64 = 0
        for app in apps {
            let size = sizes[app.id]?.bytes ?? 0
            let isComplete = sizes[app.id]?.isComplete == true
            guard let lastUsed = app.lastUsed else {
                unknownCount += 1; unknownBytes += size
                unknownComplete = unknownComplete && isComplete
                continue
            }
            let days = now.timeIntervalSince(lastUsed) / day
            let index = ranges.firstIndex { $0.1.map { days <= $0 } ?? true } ?? ranges.count - 1
            counts[index] += 1
            bytes[index] += size
            complete[index] = complete[index] && isComplete
        }
        var buckets = ranges.enumerated().map { i, r in
            ActivityBucket(title: r.0, count: counts[i], bytes: bytes[i], isStale: r.2, isComplete: complete[i])
        }
        if unknownCount > 0 {
            buckets.append(ActivityBucket(title: L10n.tr("未知"), count: unknownCount, bytes: unknownBytes, isStale: false, isUnknown: true, isComplete: unknownComplete))
        }
        return buckets
    }
}
