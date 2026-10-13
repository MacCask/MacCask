import Foundation
import Observation
import XCTest
@testable import MacCask

/// 记录实际分析调用，模拟耗时扫描并允许测试在扫描期间发出变化。
private actor CountingUsageAnalyzer {
    private var calls = 0
    private var bytes: Int64 = 100
    private var active = 0
    private var peak = 0
    /// 获取实际并发峰值。
    func maximumConcurrency() -> Int { peak }
    /// 获取当前调用次数。
    func count() -> Int { calls }
    /// 修改下一次分析返回的容量。
    func setBytes(_ value: Int64) { bytes = value }
    /// 返回开始时的快照，留出并发请求及失效通知的时间窗口。
    func analyze(_ app: InstalledApp) async -> RelatedFilesAnalysis {
        calls += 1
        active += 1
        peak = max(peak, active)
        defer { active -= 1 }
        let captured = bytes
        try? await Task.sleep(for: .milliseconds(100))
        return RelatedFilesAnalysis(files: [LibraryFile(url: app.url, category: .application, sizeBytes: captured)])
    }
}

/// 模拟安装目录扫描期间新增应用，返回扫描开始时的快照。
private actor ChangingAppDiscovery {
    private var applications: [InstalledApp]
    private var calls = 0
    /// 设置初始应用集合。
    init(_ applications: [InstalledApp]) { self.applications = applications }
    /// 修改下一轮扫描的应用集合。
    func replace(_ applications: [InstalledApp]) { self.applications = applications }
    /// 查看扫描是否启动。
    func count() -> Int { calls }
    /// 模拟异步扫描，不读取真实安装目录。
    func scan() async -> [InstalledApp] {
        calls += 1
        let snapshot = applications
        try? await Task.sleep(for: .milliseconds(100))
        return snapshot
    }
}

/// 模拟系统事件源，验证通知经平台接口进入业务调度流程。
@MainActor
private final class TestFileChangeMonitor: FileChangeMonitoring {
    private var handler: (@Sendable ([URL], Bool) -> Void)?
    /// 保存回调，不订阅真实用户目录。
    @discardableResult
    func start(paths: [URL], onChange: @escaping @Sendable ([URL], Bool) -> Void) -> Bool {
        handler = onChange
        return true
    }
    /// 清理回调。
    func stop() { handler = nil }
    /// 注入一次目录变化。
    func emit(_ paths: [URL]) { handler?(paths, false) }
}

/// 扫描去重、失效以及页面复用规则的回归测试。
@MainActor
final class AppUsageScannerTests: XCTestCase {
    /// 生成不会访问真实应用目录的模型。
    private func app(_ name: String = "Example") -> InstalledApp {
        InstalledApp(url: URL(fileURLWithPath: "/demo/\(name).app"), name: name, matchNames: [name],
            bundleID: "com.example.\(name.lowercased())", version: nil, isSystem: false,
            isAppStore: false, caskToken: nil, lastUsed: nil)
    }

    /// 等待分析开始，不依赖任务被系统调度的具体顺序。
    private func waitForStart(_ counter: CountingUsageAnalyzer, count: Int) async {
        for _ in 0..<1000 {
            if await counter.count() >= count { return }
            try? await Task.sleep(for: .milliseconds(1))
        }
        XCTFail("分析任务没有启动")
    }

    /// 同一个应用的并发请求合并，后续查看直接复用。
    func testConcurrentRequestsShareOneScan() async {
        let counter = CountingUsageAnalyzer()
        let scanner = AppUsageScanner { await counter.analyze($0) }
        let application = app()
        async let first = scanner.analysis(for: application)
        async let second = scanner.analysis(for: application)
        let values = await (first, second)
        XCTAssertEqual(values.0.totalMeasurement.bytes, values.1.totalMeasurement.bytes)
        _ = await scanner.analysis(for: application)
        let calls = await counter.count()
        XCTAssertEqual(calls, 1)
    }

    /// 扫描期间的新事件不能被完成通知吞掉，下一轮请求只补扫一次。
    func testInvalidationDuringScanIsPreserved() async {
        let counter = CountingUsageAnalyzer()
        let scanner = AppUsageScanner { await counter.analyze($0) }
        let application = app()
        async let first = scanner.analysis(for: application)
        await waitForStart(counter, count: 1)
        await counter.setBytes(200)
        scanner.invalidate([application.id])
        async let newer = scanner.analysis(for: application)
        let values = await (first, newer)
        XCTAssertEqual(values.0.totalMeasurement.bytes, 100)
        XCTAssertEqual(values.1.totalMeasurement.bytes, 200)
        XCTAssertEqual(scanner.cached(application.id)?.totalMeasurement.bytes, 200)
        XCTAssertFalse(scanner.dirty.contains(application.id))
        let calls = await counter.count()
        XCTAssertEqual(calls, 2)
    }

    /// 不同页面发出的多应用请求也受同一个四路并发上限约束。
    func testGlobalConcurrencyLimitAndExpiry() async {
        let counter = CountingUsageAnalyzer()
        let scanner = AppUsageScanner { await counter.analyze($0) }
        let applications = (0..<7).map { app("Example\($0)") }
        await withTaskGroup(of: Void.self) { group in
            for application in applications { group.addTask { _ = await scanner.analysis(for: application) } }
        }
        let peak = await counter.maximumConcurrency()
        XCTAssertEqual(peak, 4)
        scanner.expire(olderThan: 300, now: Date().addingTimeInterval(400))
        XCTAssertEqual(scanner.dirty, Set(applications.map(\.id)))
        scanner.remove(applications[0].id)
        XCTAssertNil(scanner.cached(applications[0].id))
        XCTAssertFalse(scanner.dirty.contains(applications[0].id))
    }

    /// 多次进入列表、A/B/A 选中切换不扫描；主动刷新期间旧数值仍可展示。
    func testViewModelReusesResultsAndRetainsValuesDuringRefresh() async {
        let counter = CountingUsageAnalyzer()
        let applications = [app(), app("Other")]
        let model = InstalledAppsViewModel(useSizeCache: false, scanApps: { applications },
            analyzeApp: { await counter.analyze($0) })
        await model.refresh()
        model.selection = applications[0].id
        XCTAssertFalse(model.isAnalyzing)
        XCTAssertEqual(model.relatedFiles.totalSize, 100)
        model.selection = applications[1].id
        model.selection = applications[0].id
        await model.loadIfNeeded()
        let initialCalls = await counter.count()
        XCTAssertEqual(initialCalls, 2)
        await counter.setBytes(500)
        async let refreshed: Void = model.refresh()
        await waitForStart(counter, count: 3)
        XCTAssertTrue(model.isScanning)
        XCTAssertEqual(model.totalSizes[applications[0].id]?.bytes, 100)
        XCTAssertEqual(model.relatedFiles.totalSize, 100)
        await refreshed
        XCTAssertEqual(model.totalSizes[applications[0].id]?.bytes, 500)
        XCTAssertEqual(model.relatedFiles.totalSize, 500)
        let finalCalls = await counter.count()
        XCTAssertEqual(finalCalls, 4)
        model.setApplicationActive(false)
        model.receiveFileChanges([applications[0].url.appendingPathComponent("Contents/binary")])
        try? await Task.sleep(for: .milliseconds(20))
        let backgroundCalls = await counter.count()
        XCTAssertEqual(backgroundCalls, finalCalls)
    }

    /// 离开详情只取消页面等待，共享扫描完成后仍更新列表及首页结果。
    func testLeavingDetailDoesNotDiscardSharedResult() async {
        let counter = CountingUsageAnalyzer()
        let applications = [app(), app("Other")]
        let model = InstalledAppsViewModel(useSizeCache: false, scanApps: { applications },
            analyzeApp: { await counter.analyze($0) })
        await model.refresh()
        model.setApplicationActive(false)
        await counter.setBytes(500)
        model.receiveFileChanges([applications[0].url.appendingPathComponent("Contents/binary")])
        let updated = expectation(description: "离开详情后共享结果仍更新")
        withObservationTracking { _ = model.totalSizes[applications[0].id] } onChange: { updated.fulfill() }
        model.selection = applications[0].id
        await waitForStart(counter, count: 3)
        model.selection = applications[1].id
        await fulfillment(of: [updated], timeout: 2)
        XCTAssertEqual(model.totalSizes[applications[0].id]?.bytes, 500)
        XCTAssertEqual(model.relatedFiles.totalSize, 100)
        XCTAssertEqual(model.selection, applications[1].id)
    }

    /// 后台事件仅失效，回到前台后合并通知并自动更新共享统计。
    func testBackgroundEventsUpdateWhenReturningToForeground() async {
        let counter = CountingUsageAnalyzer()
        let monitor = TestFileChangeMonitor()
        let application = app()
        let model = InstalledAppsViewModel(useSizeCache: false, fileMonitor: monitor,
            scanApps: { [application] }, analyzeApp: { await counter.analyze($0) })
        await model.refresh()
        model.setApplicationActive(false)
        await counter.setBytes(500)
        monitor.emit([application.url.appendingPathComponent("Contents/binary")])
        try? await Task.sleep(for: .milliseconds(20))
        let callsBefore = await counter.count()
        XCTAssertEqual(callsBefore, 1)
        let updated = expectation(description: "前台自动更新占用")
        withObservationTracking { _ = model.totalSizes[application.id] } onChange: { updated.fulfill() }
        model.setApplicationActive(true)
        await fulfillment(of: [updated], timeout: 6)
        XCTAssertEqual(model.totalSizes[application.id]?.bytes, 500)
        let callsAfter = await counter.count()
        XCTAssertEqual(callsAfter, 2)
        model.setApplicationActive(false)
        monitor.stop()
    }

    /// 安装发现期间发生的新通知不能丢失，下一轮应发现并计算新增应用。
    func testApplicationAddedDuringDiscoveryIsNotLost() async {
        let counter = CountingUsageAnalyzer()
        let applications = [app(), app("New")]
        let discovery = ChangingAppDiscovery([applications[0]])
        let model = InstalledAppsViewModel(useSizeCache: false, scanApps: { await discovery.scan() },
            analyzeApp: { await counter.analyze($0) })
        async let initial: Void = model.refresh()
        for _ in 0..<1000 {
            if await discovery.count() > 0 { break }
            try? await Task.sleep(for: .milliseconds(1))
        }
        await discovery.replace(applications)
        model.receiveFileChanges([URL(fileURLWithPath: "/Applications/New.app")])
        await initial
        XCTAssertEqual(model.apps.count, 1)
        let added = expectation(description: "下一轮发现新增应用")
        withObservationTracking { _ = model.totalSizes[applications[1].id] } onChange: { added.fulfill() }
        await fulfillment(of: [added], timeout: 6)
        XCTAssertEqual(model.apps.count, 2)
        XCTAssertEqual(model.totalSizes[applications[1].id]?.bytes, 100)
        model.setApplicationActive(false)
    }

    /// 新关联路径可匹配到应用；无关目录不触发，父目录合并通知保守失效。
    func testRoutingNewRelatedDirectory() {
        let applications = [app(), app("Other")]
        let root = URL(fileURLWithPath: "/demo/Library/Application Support")
        let locations = [LibraryLocation(url: root, category: .applicationSupport, matchesByName: true)]
        let changed = root.appendingPathComponent("com.example.example/messages")
        XCTAssertEqual(AppFileChangeRouter.affectedApps(paths: [changed], apps: applications,
            files: [:], locations: locations, rescanAll: false), [applications[0].id])
        XCTAssertTrue(AppFileChangeRouter.affectedApps(paths: [root.appendingPathComponent("unrelated")],
            apps: applications, files: [:], locations: locations, rescanAll: false).isEmpty)
        XCTAssertEqual(AppFileChangeRouter.affectedApps(paths: [root], apps: applications,
            files: [:], locations: locations, rescanAll: false), Set(applications.map(\.id)))
    }

    /// 实际启动 FSEvents 并接收隔离目录变化，同时验证路径别名归一及资源释放。
    func testActualFSEventsNotification() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let monitor = MacFileChangeMonitor(latency: 0.1)
        let received = expectation(description: "收到隔离目录变化")
        received.assertForOverFulfill = false
        let started = monitor.start(paths: [root]) { paths, _ in
            if paths.contains(where: { $0.isWithin(root) || root.isWithin($0) }) { received.fulfill() }
        }
        XCTAssertTrue(started)
        let file = root.appendingPathComponent("new-file")
        try Data(repeating: 42, count: 4096).write(to: file)
        try FileManager.default.removeItem(at: file)
        await fulfillment(of: [received], timeout: 10)
        monitor.stop()
    }
}
