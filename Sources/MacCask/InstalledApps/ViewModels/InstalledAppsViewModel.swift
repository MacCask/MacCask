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
    /// 是否已加载过
    private(set) var hasLoaded = false
    /// 应用包大小（路径 → 字节）
    private(set) var sizes: [String: Int64] = [:]
    /// 列表总占用：应用包和关联数据；尚未完成扫描的应用没有条目。
    private(set) var totalSizes: [String: FileSizeMeasurement] = [:]
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

    private let cacheRepository = SizeCacheRepository()
    private var analyzeTask: Task<Void, Never>?

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

    /// 首次进入时加载
    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        await refresh()
    }

    /// 重新扫描应用并计算大小
    func refresh() async {
        guard !isScanning else { return }
        isScanning = true
        defer { isScanning = false }
        totalSizes = [:]
        let caskApps = await BrewService.shared.caskAppMap()
        apps = await AppScanner.scan(caskApps: caskApps)
        hasLoaded = true
        if let selection, !apps.contains(where: { $0.id == selection }) {
            self.selection = nil
        }
        reanalyze()
        await computeSizes()
    }

    /// 先恢复包大小供详情和概览展示，再以四路并发重新统计每个应用的完整占用。
    private func computeSizes() async {
        let cached = cacheRepository.cachedEntries(for: apps.map(\.id))
        sizes = [:]
        for app in apps {
            let modified = FileSizeCalculator.modificationDate(of: app.url)
            if let entry = cached[app.id], let modified, entry.modifiedAt == modified {
                sizes[app.id] = entry.sizeBytes
            }
        }
        // 关联数据可独立于应用包变化，每次刷新都重新读取，不能用包修改时间判断有效性。
        let snapshot = apps
        let batchSize = 4
        for start in stride(from: 0, to: snapshot.count, by: batchSize) {
            let batch = Array(snapshot[start..<min(start + batchSize, snapshot.count)])
            await withTaskGroup(of: (InstalledApp, RelatedFilesAnalysis, Date?).self) { group in
                for app in batch {
                    group.addTask {
                        let modified = FileSizeCalculator.modificationDate(of: app.url)
                        return (app, await RelatedFilesAnalyzer.analyze(app), modified)
                    }
                }
                for await (app, result, modified) in group {
                    guard apps.contains(where: { $0.id == app.id }) else { continue }
                    // 详情页若已完成更新，保留它较近的结果，避免后台批次覆盖。
                    if totalSizes[app.id] == nil { totalSizes[app.id] = result.totalMeasurement }
                    if let bundle = result.files.first(where: { $0.category == .application }) {
                        sizes[app.id] = bundle.sizeBytes
                        if bundle.isSizeComplete, let modified {
                            cacheRepository.upsert(path: app.id, modifiedAt: modified, sizeBytes: bundle.sizeBytes)
                        }
                    }
                }
            }
        }
        cacheRepository.save()
    }

    /// 分析选中应用的关联文件
    private func analyzeSelection() {
        analyzeTask?.cancel()
        relatedFiles = []
        unreadableURLs = []
        checkedFiles = []
        isAnalyzing = false
        guard let app = selectedApp else { return }
        isAnalyzing = true
        analyzeTask = Task {
            let result = await RelatedFilesAnalyzer.analyze(app)
            guard !Task.isCancelled, selection == app.id else { return }
            totalSizes[app.id] = result.totalMeasurement
            if let bundle = result.files.first(where: { $0.category == .application }) {
                sizes[app.id] = bundle.sizeBytes
            }
            relatedFiles = result.files
            unreadableURLs = result.unreadableURLs.sorted { $0.path < $1.path }
            // 默认全部勾选
            checkedFiles = Set(result.files.map(\.id))
            isAnalyzing = false
        }
    }

    /// 重新分析当前选中应用
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
                apps.removeAll { $0.id == app.id }
                sizes[app.id] = nil
                totalSizes[app.id] = nil
                selection = nil
            } else {
                reanalyze()
            }
        }
    }
}
