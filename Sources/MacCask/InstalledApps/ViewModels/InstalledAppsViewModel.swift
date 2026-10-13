import Foundation
import Observation

/// 已安装应用模块视图模型
@Observable
@MainActor
final class InstalledAppsViewModel {
    /// 扫描到的全部应用
    private(set) var apps: [InstalledApp] = []
    /// 是否正在扫描
    private(set) var isScanning = false
    /// 正在更新的应用保留旧数值，并由列表展示轻量进度标识。
    private(set) var updatingAppIDs: Set<String> = []
    /// 是否已加载过
    private(set) var hasLoaded = false
    /// 应用包大小（路径 → 字节）
    private(set) var sizes: [String: Int64] = [:]
    /// 列表总占用：应用包和关联数据；尚未完成扫描的应用没有条目。
    private(set) var totalSizes: [String: FileSizeMeasurement] = [:]
    /// 与总占用同批更新的文件明细，供首页去重及缓存分类。
    private(set) var usageFiles: [String: [LibraryFile]] = [:]
    /// 占用结果发生变化时通知概览重新读取磁盘统计。
    private(set) var usageRevision = 0
    /// 搜索关键字
    var searchText = ""
    /// 分类筛选
    var filter: AppFilter = .thirdParty
    /// 排序方式
    var sortOrder: AppSortOrder = .name
    /// 当前选中应用
    var selection: InstalledApp.ID? {
        didSet { if selection != oldValue { analyzeSelection() } }
    }

    /// 选中应用的关联文件
    private(set) var relatedFiles: [LibraryFile] = []
    /// 未能读取的路径，含扫描根目录和关联文件的子目录。
    private(set) var unreadableURLs: [URL] = []
    var isAnalysisComplete: Bool { unreadableURLs.isEmpty }
    /// 是否正在分析关联文件
    private(set) var isAnalyzing = false
    /// 卸载时勾选的文件路径
    var checkedFiles: Set<String> = []
    /// 当前命令会话（Homebrew 卸载时显示日志）
    var activeSession: CommandSession?
    /// 提示信息
    var alertMessage: String?

    private let cacheRepository: SizeCacheRepository?
    private let scanApps: () async -> [InstalledApp]
    private let usageScanner: AppUsageScanner
    private let fileMonitor: (any FileChangeMonitoring)?
    private var watching = false
    private var needsDiscovery = false
    private var discoveryRevision = 0
    private var isApplicationActive = true
    private var automaticUpdateTask: Task<Void, Never>?
    private var isUpdatingChangedApps = false
    private var lastAutomaticUpdate = Date.distantPast
    private var analyzeTask: Task<Void, Never>?

    /// 默认使用实际扫描服务，隔离测试可替换数据源并关闭持久缓存。
    init(useSizeCache: Bool = true, fileMonitor: (any FileChangeMonitoring)? = nil,
         scanApps: @escaping () async -> [InstalledApp] = {
             let casks = await BrewService.shared.caskAppMap()
             return await AppScanner.scan(caskApps: casks)
         },
         analyzeApp: @escaping @Sendable (InstalledApp) async -> RelatedFilesAnalysis = {
             await RelatedFilesAnalyzer.analyze($0)
         }) {
        cacheRepository = useSizeCache ? SizeCacheRepository() : nil
        self.scanApps = scanApps
        usageScanner = AppUsageScanner(analyzer: analyzeApp)
        self.fileMonitor = fileMonitor ?? (useSizeCache ? Platform.current.makeFileMonitor() : nil)
    }

    /// 当前选中应用
    var selectedApp: InstalledApp? {
        guard let selection else { return nil }
        return apps.first { $0.id == selection }
    }

    /// 筛选、搜索、排序后的应用列表
    var visibleApps: [InstalledApp] {
        let keyword = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        let filtered = apps.filter { app in
            filter.matches(app) && (keyword.isEmpty
                || app.name.lowercased().contains(keyword)
                || (app.bundleID?.lowercased().contains(keyword) ?? false))
        }
        switch sortOrder {
        case .name:
            return filtered.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        case .size:
            return filtered.sorted { (totalSizes[$0.id]?.bytes ?? -1) > (totalSizes[$1.id]?.bytes ?? -1) }
        case .lastUsed:
            return filtered.sorted { ($0.lastUsed ?? .distantPast) > ($1.lastUsed ?? .distantPast) }
        }
    }

    /// 某个筛选分类下的数量
    func count(for filter: AppFilter) -> Int {
        apps.filter(filter.matches).count
    }

    /// 当前列表中应用的总大小
    var visibleTotalSize: Int64 {
        visibleApps.reduce(0) { $0 + (totalSizes[$1.id]?.bytes ?? 0) }
    }

    /// 列表合计也保留读取失败和扫描尚未结束的状态。
    var visibleTotalSizeText: String {
        let visible = visibleApps
        guard visible.isEmpty || visible.contains(where: { totalSizes[$0.id] != nil }) else {
            return L10n.tr("计算中…")
        }
        let complete = visible.allSatisfy { totalSizes[$0.id]?.isComplete == true }
        if !complete && visibleTotalSize == 0 && visible.contains(where: { totalSizes[$0.id] == nil }) {
            return L10n.tr("计算中…")
        }
        return ByteFormatter.measured(visibleTotalSize, isComplete: complete)
    }

    /// 关联文件合计（不含应用包本身）
    var relatedDataSize: Int64 {
        relatedFiles.filter { $0.category != .application }.totalSize
    }

    /// 勾选文件的合计大小
    var checkedSize: Int64 {
        relatedFiles.filter { checkedFiles.contains($0.id) }.totalSize
    }

    /// 已加载时仅安排失效结果更新，页面切换不清空已有结果。
    func loadIfNeeded() async {
        if hasLoaded { scheduleUpdates(); return }
        await refresh()
    }

    /// 主动刷新强制失效全部应用；期间保留旧占用及详情，不重复启动详情分析。
    func refresh() async {
        guard !isScanning else { return }
        isScanning = true
        analyzeTask?.cancel()
        defer {
            isScanning = false
            usageRevision += 1
            scheduleUpdates()
        }
        startWatching()
        await discoverApps()
        usageScanner.invalidate(Set(apps.map(\.id)))
        startWatching()
        await computeSizes(apps)
        reanalyze()
    }

    /// 发现新增或已移除应用，只删除不存在的记录，保留其他应用快照。
    private func discoverApps() async {
        let revision = discoveryRevision
        let discovered = await scanApps()
        let ids = Set(discovered.map(\.id))
        for app in apps where !ids.contains(app.id) { removeApp(app.id) }
        apps = discovered
        hasLoaded = true
        // 扫描安装目录期间发生的新变化不能被本轮完成通知吞掉。
        if discoveryRevision == revision { needsDiscovery = false }
    }

    /// 以四路并发请求共享扫描器；已有结果直接复用，同一应用的在途任务会合并。
    private func computeSizes(_ targets: [InstalledApp]) async {
        let cached = cacheRepository?.cachedEntries(for: targets.map(\.id)) ?? [:]
        let modifiedDates = await Task.detached(priority: .utility) {
            Dictionary(uniqueKeysWithValues: targets.map { ($0.id, FileSizeCalculator.modificationDate(of: $0.url)) })
        }.value
        for app in targets where sizes[app.id] == nil {
            let modified = modifiedDates[app.id] ?? nil
            if let entry = cached[app.id], let modified, entry.modifiedAt == modified {
                sizes[app.id] = entry.sizeBytes
            }
        }
        let batchSize = 4
        for start in stride(from: 0, to: targets.count, by: batchSize) {
            let batch = Array(targets[start..<min(start + batchSize, targets.count)])
            await withTaskGroup(of: (InstalledApp, RelatedFilesAnalysis).self) { group in
                let scanner = usageScanner
                for app in batch where scanner.cached(app.id) == nil || scanner.dirty.contains(app.id) {
                    updatingAppIDs.insert(app.id)
                    if selection == app.id { isAnalyzing = true }
                }
                for app in batch { group.addTask { (app, await scanner.analysis(for: app)) } }
                for await (app, _) in group {
                    if !usageScanner.isRunning(app.id) { updatingAppIDs.remove(app.id) }
                    guard apps.contains(where: { $0.id == app.id }), let snapshot = usageScanner.cached(app.id) else { continue }
                    applyAnalysis(snapshot, for: app.id)
                    if let bundle = snapshot.files.first(where: { $0.category == .application }),
                       bundle.isSizeComplete, let modified = modifiedDates[app.id] ?? nil {
                        cacheRepository?.upsert(path: app.id, modifiedAt: modified, sizeBytes: bundle.sizeBytes)
                    }
                }
            }
        }
        cacheRepository?.save()
    }

    /// 通知只标记失效：同时支持已知路径变化及尚未记录的新关联目录。
    func receiveFileChanges(_ paths: [URL], rescanAll: Bool = false) {
        let ownDatabase = LibraryLocations.home.appendingPathComponent("Library/Application Support/MacCask")
        let paths = paths.filter { !$0.isWithin(ownDatabase) }
        guard rescanAll || !paths.isEmpty else { return }
        usageScanner.invalidate(AppFileChangeRouter.affectedApps(paths: paths, apps: apps,
            files: usageFiles, locations: LibraryLocations.all(), rescanAll: rescanAll))
        let roots = applicationRoots
        if rescanAll || paths.contains(where: { path in roots.contains { path.isWithin($0) || $0.isWithin(path) } }) {
            needsDiscovery = true
            discoveryRevision += 1
        }
        if rescanAll { watching = false }
        scheduleUpdates()
    }

    /// 前台恢复时核验过期结果；后台只接收失效标记，不持续重新计算大小。
    func setApplicationActive(_ active: Bool) {
        isApplicationActive = active
        if active {
            // 仅重新发现应用信息，已有且未失效的占用仍直接复用。
            if hasLoaded { needsDiscovery = true; discoveryRevision += 1 }
            // 健康监听仅每日兜底核验；启动失败时缩短到五分钟，避免频繁全量重算。
            usageScanner.expire(olderThan: watching ? 86_400 : 300)
            scheduleUpdates()
        } else if !isUpdatingChangedApps {
            automaticUpdateTask?.cancel()
            automaticUpdateTask = nil
        }
    }

    /// 应用安装根目录与扫描服务保持一致。
    private var applicationRoots: [URL] {
        [URL(fileURLWithPath: "/Applications"), LibraryLocations.home.appendingPathComponent("Applications"),
         URL(fileURLWithPath: "/System/Applications")]
    }

    /// 缺失目录监听其 Library 父目录，便于发现首次创建的数据目录。
    private func startWatching() {
        guard !watching, let fileMonitor else { return }
        let candidates = applicationRoots + LibraryLocations.all().map(\.url)
        let paths = candidates.compactMap { url -> URL? in
            if FileManager.default.fileExists(atPath: url.path) { return url }
            let parent = url.deletingLastPathComponent()
            return parent.lastPathComponent == "Library" ? parent : nil
        }
        watching = fileMonitor.start(paths: paths) { [weak self] paths, rescanAll in
            Task { @MainActor [weak self] in self?.receiveFileChanges(paths, rescanAll: rescanAll) }
        }
    }

    /// 合并短时间事件，自动扫描轮次至少间隔三十秒，持续写入不能造成扫描风暴。
    private func scheduleUpdates() {
        guard hasLoaded, isApplicationActive, !isScanning, automaticUpdateTask == nil,
              needsDiscovery || !usageScanner.dirty.isEmpty else { return }
        let delay = max(3, 30 - Date().timeIntervalSince(lastAutomaticUpdate))
        automaticUpdateTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(delay)) } catch { return }
            guard let self, self.isApplicationActive else { return }
            if !self.isScanning {
                self.isUpdatingChangedApps = true
                self.lastAutomaticUpdate = Date()
                if self.needsDiscovery { await self.discoverApps() }
                self.startWatching()
                let targets = self.apps.filter { self.usageScanner.cached($0.id) == nil || self.usageScanner.dirty.contains($0.id) }
                await self.computeSizes(targets)
                self.isUpdatingChangedApps = false
            }
            self.automaticUpdateTask = nil
            self.scheduleUpdates()
        }
    }

    /// 原子更新共享占用及明细，所有页面均读取这份结果。
    private func applyAnalysis(_ result: RelatedFilesAnalysis, for id: String) {
        totalSizes[id] = result.totalMeasurement
        usageFiles[id] = result.files
        if let bundle = result.files.first(where: { $0.category == .application }) { sizes[id] = bundle.sizeBytes }
        if selection == id { showAnalysis(result, preserveChecks: !relatedFiles.isEmpty) }
        usageRevision += 1
    }

    /// 卸载后同步移除全部占用状态，避免首页继续展示已删除应用。
    func removeApp(_ id: String) {
        usageScanner.remove(id)
        updatingAppIDs.remove(id)
        apps.removeAll { $0.id == id }
        sizes[id] = nil
        totalSizes[id] = nil
        usageFiles[id] = nil
        if selection == id { selection = nil }
        usageRevision += 1
    }

    /// 切换选中项先展示共享明细；只有未扫描或已失效时才请求分析。
    private func analyzeSelection() {
        analyzeTask?.cancel()
        guard let app = selectedApp else {
            relatedFiles = []; unreadableURLs = []; checkedFiles = []; isAnalyzing = false
            return
        }
        if let cached = usageScanner.cached(app.id) {
            showAnalysis(cached, preserveChecks: false)
            if !usageScanner.dirty.contains(app.id) { return }
        } else {
            relatedFiles = []; unreadableURLs = []; checkedFiles = []
        }
        isAnalyzing = true
        updatingAppIDs.insert(app.id)
        analyzeTask = Task {
            _ = await usageScanner.analysis(for: app)
            if !usageScanner.isRunning(app.id) { updatingAppIDs.remove(app.id) }
            // 页面等待任务取消不等于共享扫描取消，仍需发布结果供列表与首页使用。
            guard apps.contains(where: { $0.id == app.id }), let result = usageScanner.cached(app.id) else { return }
            applyAnalysis(result, for: app.id)
            scheduleUpdates()
        }
    }

    /// 详情更新不清空已有数值或用户勾选；新选中应用默认全部勾选。
    private func showAnalysis(_ result: RelatedFilesAnalysis, preserveChecks: Bool) {
        relatedFiles = result.files
        unreadableURLs = result.unreadableURLs.sorted { $0.path < $1.path }
        let ids = Set(result.files.map(\.id))
        checkedFiles = preserveChecks ? checkedFiles.intersection(ids) : ids
        isAnalyzing = selection.map { usageScanner.isRunning($0) } ?? false
    }

    /// 刷新当前选中详情，优先复用共享结果；强制失效由刷新或文件事件负责。
    func reanalyze() {
        analyzeSelection()
    }

    /// 卸载选中应用（删除勾选的文件）
    func uninstallSelected() {
        guard let app = selectedApp, !app.isSystem else { return }
        if let bundleID = app.bundleID, Platform.current.system.isApplicationRunning(bundleID: bundleID) {
            alertMessage = L10n.tr("「{0}」正在运行，请先退出后再卸载。", "\(app.name)")
            return
        }
        let files = relatedFiles.filter { checkedFiles.contains($0.id) }
        guard !files.isEmpty else { return }

        // Homebrew 安装的应用显示命令日志
        let session = app.isHomebrew ? CommandSession(title: L10n.tr("卸载 {0}", "\(app.name)")) : nil
        activeSession = session
        Task {
            let outcome = await AppUninstaller.uninstall(app, files: files, output: session?.outputHandler() ?? { @Sendable _ in })
            session?.finish(succeeded: outcome.succeeded)
            if session == nil, !outcome.succeeded {
                let failed = outcome.failures.keys.map(\.path).sorted().joined(separator: "\n")
                alertMessage = outcome.errorMessage ?? L10n.tr("以下文件未能移到废纸篓：\n{0}", "\(failed)")
            }
            // 应用包已删除则从列表移除，否则重新分析剩余文件
            if !FileManager.default.fileExists(atPath: app.url.path) {
                removeApp(app.id)
            } else {
                usageScanner.invalidate([app.id])
                reanalyze()
            }
        }
    }
}
