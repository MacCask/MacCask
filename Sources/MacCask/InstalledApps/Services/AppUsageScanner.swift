import Foundation

/// 每个应用只有一份结果及一个在途任务；失效期间保留最近的完整扫描快照。
@MainActor
final class AppUsageScanner {
    private struct Running {
        let token: UUID
        let revision: Int
        let task: Task<RelatedFilesAnalysis, Never>
    }
    private let analyzer: @Sendable (InstalledApp) async -> RelatedFilesAnalysis
    private var results: [String: RelatedFilesAnalysis] = [:]
    private var running: [String: Running] = [:]
    private var revisions: [String: Int] = [:]
    private var scannedAt: [String: Date] = [:]
    private var slotWaiters: [CheckedContinuation<Void, Never>] = []
    private(set) var dirty: Set<String> = []

    /// 注入实际分析服务，测试可使用隔离数据源。
    init(analyzer: @escaping @Sendable (InstalledApp) async -> RelatedFilesAnalysis) {
        self.analyzer = analyzer
    }

    /// 读取最近结果，不触发文件遍历。
    func cached(_ id: String) -> RelatedFilesAnalysis? { results[id] }

    /// 查询实际共享任务状态，多个等待者不能过早清除更新提示。
    func isRunning(_ id: String) -> Bool { running[id] != nil }

    /// 合并同一批失效标记；扫描期间的新事件仍需在下一轮处理。
    func invalidate(_ ids: Set<String>) {
        for id in ids {
            revisions[id, default: 0] += 1
            dirty.insert(id)
        }
    }

    /// 激活时补充核验超过指定间隔的结果，以覆盖监听失败或遗漏。
    func expire(olderThan interval: TimeInterval, now: Date = Date()) {
        invalidate(Set(scannedAt.filter { now.timeIntervalSince($0.value) >= interval }.map(\.key)))
    }

    /// 优先复用结果，在途分析共享；强制刷新等待早于失效标记的任务后只补扫一次。
    func analysis(for app: InstalledApp) async -> RelatedFilesAnalysis {
        let requestedRevision = revisions[app.id, default: 0]
        while true {
            if !dirty.contains(app.id), let cached = results[app.id] { return cached }
            let work: Running
            if let existing = running[app.id] {
                work = existing
            } else {
                // 列表与详情共用全局四路上限，而非各自创建一组并发扫描。
                if running.count >= 4 {
                    await withCheckedContinuation { slotWaiters.append($0) }
                    continue
                }
                let analyze = analyzer
                work = Running(token: UUID(), revision: revisions[app.id, default: 0],
                               task: Task.detached(priority: .utility) { await analyze(app) })
                running[app.id] = work
            }
            let result = await work.task.value
            if running[app.id]?.token == work.token {
                running[app.id] = nil
                releaseWaiters()
                // 移除或取消的任务不允许写回；扫描中产生的新变化保留失效标记。
                if !work.task.isCancelled {
                    results[app.id] = result
                    scannedAt[app.id] = Date()
                    if revisions[app.id, default: 0] == work.revision { dirty.remove(app.id) }
                }
            }
            if work.task.isCancelled || work.revision >= requestedRevision { return result }
        }
    }

    /// 移除应用时停止其扫描并删除结果，不影响其他共享任务。
    func remove(_ id: String) {
        running.removeValue(forKey: id)?.task.cancel()
        releaseWaiters()
        results[id] = nil
        scannedAt[id] = nil
        dirty.remove(id)
        revisions[id, default: 0] += 1
    }

    /// 唤醒排队请求，由主线程再次检查共享任务及剩余名额。
    private func releaseWaiters() {
        let waiting = slotWaiters
        slotWaiters = []
        for waiter in waiting { waiter.resume() }
    }
}
