import Foundation
import Observation

/// 概览模块视图模型：汇总其他模块的数据并计算磁盘占用
@Observable
@MainActor
final class OverviewViewModel {
    /// 启动磁盘容量
    private(set) var disk: DiskUsage?
    /// Homebrew 占用
    private(set) var homebrewBytes: Int64?
    /// 用户缓存占用
    private(set) var cacheBytes: Int64?
    /// 是否正在刷新
    private(set) var isRefreshing = false
    private var hasLoaded = false
    private(set) var diskCategorySnapshot: (apps: Int64, caches: Int64?, leftovers: Int64)?

    /// 以值快照驱动后台分类；悬停、窗口调整等重绘不会再次计算目录归属。
    struct CategoryInput: Hashable, Sendable {
        let appFiles: [LibraryFile]
        let leftoverFiles: [LibraryFile]
        let cacheBytes: Int64?
    }

    var categoryInput: CategoryInput {
        CategoryInput(appFiles: thirdPartyApps.flatMap { apps.usageFiles[$0.id] ?? [] },
                      leftoverFiles: leftovers.groups.filter { !$0.isIgnored }.flatMap(\.files),
                      cacheBytes: cacheBytes)
    }

    /// 合并扫描结果变更后在后台计算，取消的旧快照不得覆盖新值。
    func updateDiskCategories(_ input: CategoryInput) async {
        do { try await Task.sleep(for: .milliseconds(100)) } catch { return }
        let result = await Task.detached(priority: .utility) {
            OverviewService.diskCategories(appFiles: input.appFiles,
                leftoverFiles: input.leftoverFiles, cacheBytes: input.cacheBytes)
        }.value
        guard !Task.isCancelled else { return }
        diskCategorySnapshot = result
    }

    let apps: InstalledAppsViewModel
    let homebrew: HomebrewViewModel
    let launchItems: LaunchItemsViewModel
    let leftovers: LeftoversViewModel

    init(apps: InstalledAppsViewModel, homebrew: HomebrewViewModel,
         launchItems: LaunchItemsViewModel, leftovers: LeftoversViewModel) {
        self.apps = apps
        self.homebrew = homebrew
        self.launchItems = launchItems
        self.leftovers = leftovers
    }

    // MARK: - 加载

    /// 首次进入时加载
    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        hasLoaded = true
        await load(force: false)
    }

    /// 刷新全部数据（强制重新扫描各模块）
    func refresh() async {
        await load(force: true)
    }

    /// 并行加载：磁盘容量立即读取，各模块数据与额外统计并行进行
    private func load(force: Bool) async {
        guard !isRefreshing else { return }
        hasLoaded = true
        isRefreshing = true
        defer { isRefreshing = false }
        disk = await Task.detached(priority: .utility) { Platform.current.system.startupDiskUsage() }.value
        async let brewSize = OverviewService.homebrewDiskSize()
        async let cacheSize = OverviewService.userCacheSize()
        async let appsDone: Void = force ? apps.refresh() : apps.loadIfNeeded()
        async let brewDone: Void = force ? homebrew.refresh() : homebrew.loadIfNeeded()
        async let launchDone: Void = force ? launchItems.refresh() : launchItems.loadIfNeeded()
        async let leftoversDone: Void = force ? leftovers.refresh() : leftovers.loadIfNeeded()
        homebrewBytes = await brewSize
        cacheBytes = await cacheSize
        _ = await (appsDone, brewDone, launchDone, leftoversDone)
        disk = await Task.detached(priority: .utility) { Platform.current.system.startupDiskUsage() }.value
    }

    /// 联动已有应用结果；短暂合并批次变化，不重新扫描应用或生成另一份占用缓存。
    func refreshSupplementaryStatistics() async {
        guard hasLoaded, !isRefreshing, !apps.isScanning else { return }
        do { try await Task.sleep(for: .milliseconds(500)) } catch { return }
        guard !Task.isCancelled else { return }
        disk = await Task.detached(priority: .utility) { Platform.current.system.startupDiskUsage() }.value
        async let brewSize = OverviewService.homebrewDiskSize()
        async let cacheSize = OverviewService.userCacheSize()
        let values = await (brewSize, cacheSize)
        guard !Task.isCancelled else { return }
        homebrewBytes = values.0
        cacheBytes = values.1
        disk = await Task.detached(priority: .utility) { Platform.current.system.startupDiskUsage() }.value
    }

    /// 部分读取的占用在首页也保留“至少”标识。
    var appSizesComplete: Bool {
        appSizesReady && thirdPartyApps.allSatisfy { apps.totalSizes[$0.id]?.isComplete == true }
    }

    // MARK: - 应用统计

    /// 第三方应用（系统应用位于只读系统卷，不计入数据占用）
    var thirdPartyApps: [InstalledApp] { apps.apps.filter { !$0.isSystem } }

    /// 应用大小是否全部计算完成
    var appSizesReady: Bool {
        apps.hasLoaded && thirdPartyApps.allSatisfy { apps.totalSizes[$0.id] != nil }
    }

    /// 第三方应用合计大小（计算完成前为 nil）
    var thirdPartyAppBytes: Int64? {
        appSizesReady ? thirdPartyApps.reduce(0) { $0 + (apps.totalSizes[$1.id]?.bytes ?? 0) } : nil
    }

    /// 占用最大的应用
    func topApps(limit: Int = 8) -> [(app: InstalledApp, bytes: Int64, isComplete: Bool)] {
        thirdPartyApps
            .compactMap { app in apps.totalSizes[app.id].map { (app, $0.bytes, $0.isComplete) } }
            .sorted { $0.1 > $1.1 }
            .prefix(limit)
            .map { (app: $0.0, bytes: $0.1, isComplete: $0.2) }
    }

    /// 应用来源分布；颜色跟随来源（Homebrew 始终为橙色），与磁盘分段条一致
    var sourceSlices: [AppSourceSlice] {
        let all = apps.apps
        let homebrew = all.filter(\.isHomebrew).count
        let appStore = all.filter(\.isAppStore).count
        let system = all.filter(\.isSystem).count
        let other = all.count - homebrew - appStore - system
        return [
            AppSourceSlice(title: L10n.tr("第三方"), count: other, color: ChartPalette.blue),
            AppSourceSlice(title: "Homebrew", count: homebrew, color: ChartPalette.orange),
            AppSourceSlice(title: "App Store", count: appStore, color: ChartPalette.aqua),
            AppSourceSlice(title: L10n.tr("系统"), count: system, color: ChartPalette.neutral)
        ].filter { $0.count > 0 }
    }

    /// 第三方应用的活跃度分组
    var activityBuckets: [ActivityBucket] {
        OverviewService.activityBuckets(apps: thirdPartyApps, sizes: apps.totalSizes)
    }

    // MARK: - 磁盘分段

    /// 磁盘分段：第三方应用 / Homebrew / 用户缓存 / 残留文件 / 其他已用
    var diskSegments: [DiskSegment] {
        guard let disk else { return [] }
        let categorized = diskCategorySnapshot
        let appBytes: Int64? = appSizesReady ? categorized?.apps : nil
        let leftoverBytes: Int64? = leftovers.hasLoaded ? categorized?.leftovers : nil
        let known = [appBytes, homebrewBytes, categorized?.caches, leftoverBytes].compactMap { $0 }.reduce(0, +)
        return [
            DiskSegment(id: "apps", title: L10n.tr("第三方应用"), bytes: appBytes, color: ChartPalette.blue, section: .apps, isComplete: appSizesComplete),
            DiskSegment(id: "brew", title: "Homebrew", bytes: homebrewBytes, color: ChartPalette.orange, section: .homebrew),
            DiskSegment(id: "cache", title: L10n.tr("用户缓存"), bytes: categorized?.caches, color: ChartPalette.aqua),
            DiskSegment(id: "leftovers", title: L10n.tr("残留文件"), bytes: leftoverBytes, color: ChartPalette.yellow, section: .leftovers),
            DiskSegment(id: "other", title: L10n.tr("其他已用"), bytes: max(disk.usedBytes - known, 0), color: ChartPalette.neutral)
        ]
    }

    // MARK: - 其他模块统计

    /// 未忽略残留的合计大小
    var leftoverActiveBytes: Int64 {
        leftovers.groups.filter { !$0.isIgnored }.reduce(0) { $0 + $1.totalSize }
    }

    /// 已开启的启动项中正在运行的数量
    var runningLaunchItems: Int { launchItems.items.filter { $0.isEnabled && $0.isRunning }.count }

    /// 长期（超过一年）未使用的应用分组
    var staleBucket: ActivityBucket? {
        activityBuckets.first { $0.isStale && $0.count > 0 }
    }

    // MARK: - 建议

    /// 根据当前状态生成优化建议，按严重程度排序
    var insights: [Insight] {
        var result: [Insight] = []
        if let disk {
            let free = 1 - disk.usedFraction
            if free < 0.1 {
                result.append(Insight(level: .critical, title: L10n.tr("磁盘空间不足"),
                                      detail: L10n.tr("仅剩 {0}（{1}），建议清理残留与长期未用的应用", "\(ByteFormatter.string(disk.availableBytes))", "\(percent(free))"),
                                      section: .leftovers))
            } else if free < 0.2 {
                result.append(Insight(level: .warning, title: L10n.tr("磁盘空间偏紧"),
                                      detail: L10n.tr("剩余 {0}（{1}）", "\(ByteFormatter.string(disk.availableBytes))", "\(percent(free))"),
                                      section: .leftovers))
            }
        }
        if homebrew.outdatedCount > 0 {
            result.append(Insight(level: .warning, title: L10n.tr("{0} 个 Homebrew 包可更新", "\(homebrew.outdatedCount)"),
                                  detail: L10n.tr("及时更新可获得修复与安全补丁"), section: .homebrew))
        }
        let leftoverCount = leftovers.activeCount
        if leftoverCount > 0 {
            result.append(Insight(level: .info, title: L10n.tr("发现 {0} 项残留文件", "\(leftoverCount)"),
                                  detail: L10n.tr("已卸载应用留下的数据，共 {0} 可清理", "\(ByteFormatter.string(leftoverActiveBytes))"),
                                  section: .leftovers))
        }
        if let stale = staleBucket {
            result.append(Insight(level: .info, title: L10n.tr("{0} 个应用超过一年未使用", "\(stale.count)"),
                                  detail: L10n.tr("共占用 {0}，可考虑卸载", "\(ByteFormatter.measured(stale.bytes, isComplete: stale.isComplete))"), section: .apps))
        }
        let daemons = launchItems.items.filter { $0.source == .systemDaemon && $0.isEnabled }.count
        if daemons > 5 {
            result.append(Insight(level: .info, title: L10n.tr("{0} 个第三方守护进程已开启", "\(daemons)"),
                                  detail: L10n.tr("后台常驻进程过多会影响开机速度与续航"), section: .launchItems))
        }
        let order: [InsightLevel] = [.critical, .warning, .info]
        return result.sorted { order.firstIndex(of: $0.level)! < order.firstIndex(of: $1.level)! }
    }

    /// 百分比文本
    func percent(_ fraction: Double) -> String {
        fraction.formatted(.percent.precision(.fractionLength(fraction < 0.01 && fraction > 0 ? 2 : 1)).locale(L10n.locale))
    }
}
