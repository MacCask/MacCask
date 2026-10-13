import Foundation
import Observation
import XCTest
@testable import MacCask

/// 概览必须跟随共享应用结果，测试全部使用隔离目录及内存数据源。
@MainActor
final class OverviewLinkageTests: XCTestCase {
    /// 创建隔离目录，结束时自动清理。
    private func temporaryDirectory() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try FileManager.default.removeItem(at: root) }
        return root
    }

    /// 构造长期未使用的第三方应用，覆盖排行及活跃度建议。
    private func app(at url: URL) -> InstalledApp {
        InstalledApp(url: url, name: "Example", matchNames: ["Example"], bundleID: "com.example.app",
                     version: nil, isSystem: false, isAppStore: false, caskToken: nil,
                     lastUsed: Date().addingTimeInterval(-800 * 86400))
    }

    /// 只注入共享应用模型，其他模块不执行真实扫描。
    private func overview(_ apps: InstalledAppsViewModel) -> OverviewViewModel {
        OverviewViewModel(apps: apps, homebrew: HomebrewViewModel(),
                          launchItems: LaunchItemsViewModel(), leftovers: LeftoversViewModel())
    }

    /// 包不变、关联数据增长后，首页总占用、排行、活跃度及观察通知全部同步。
    func testRefreshAndReanalysisUpdateOverview() async throws {
        let root = try temporaryDirectory()
        let appURL = root.appendingPathComponent("Example.app")
        let support = root.appendingPathComponent("Application Support")
        let data = support.appendingPathComponent("com.example.app")
        for url in [appURL, data] {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        try Data(repeating: 12, count: 100_000).write(to: appURL.appendingPathComponent("binary"))
        let messages = data.appendingPathComponent("messages")
        try Data(repeating: 42, count: 200_000).write(to: messages)
        let application = app(at: appURL)
        let locations = [LibraryLocation(url: support, category: .applicationSupport, matchesByName: false)]
        let apps = InstalledAppsViewModel(useSizeCache: false, scanApps: { [application] },
            analyzeApp: { await RelatedFilesAnalyzer.analyze($0, locations: locations) })
        let model = overview(apps)
        XCTAssertFalse(model.appSizesReady)
        XCTAssertNil(model.thirdPartyAppBytes)
        await apps.refresh()
        let initial = try XCTUnwrap(model.thirdPartyAppBytes)
        let package = apps.sizes[application.id]
        let modified = FileSizeCalculator.modificationDate(of: appURL)
        XCTAssertEqual(initial, apps.visibleTotalSize)
        XCTAssertEqual(model.topApps().first?.bytes, initial)
        XCTAssertEqual(model.staleBucket?.bytes, initial)

        let changed = expectation(description: "首页观察到关联数据增长")
        withObservationTracking { _ = model.thirdPartyAppBytes } onChange: { changed.fulfill() }
        try Data(repeating: 43, count: 900_000).write(to: messages)
        // 文件通知先标记失效；选中应用走共享分析流程，不刷新首页。
        apps.setApplicationActive(false)
        apps.receiveFileChanges([messages])
        apps.selection = application.id
        await fulfillment(of: [changed], timeout: 5)
        let updated = try XCTUnwrap(model.thirdPartyAppBytes)
        XCTAssertGreaterThan(updated, initial)
        XCTAssertEqual(apps.sizes[application.id], package)
        XCTAssertEqual(FileSizeCalculator.modificationDate(of: appURL), modified)
        XCTAssertEqual(model.topApps().first?.bytes, updated)
        XCTAssertEqual(model.staleBucket?.bytes, updated)
        XCTAssertEqual(apps.visibleTotalSize, updated)
        XCTAssertTrue(model.appSizesComplete)

        try Data(repeating: 44, count: 1_500_000).write(to: messages)
        await apps.refresh()
        XCTAssertGreaterThan(try XCTUnwrap(model.thirdPartyAppBytes), updated)
        XCTAssertEqual(model.topApps().first?.bytes, apps.visibleTotalSize)
        XCTAssertEqual(model.staleBucket?.bytes, apps.visibleTotalSize)
        apps.removeApp(application.id)
        XCTAssertEqual(model.thirdPartyAppBytes, 0)
        XCTAssertTrue(model.topApps().isEmpty)
        XCTAssertTrue(model.activityBuckets.allSatisfy { $0.count == 0 })
        XCTAssertNil(apps.usageFiles[application.id])
    }

    /// 无权限时首页排行及分组保留下限状态，不把部分占用标为完整。
    func testIncompleteMeasurementsRemainIncomplete() async {
        let application = app(at: URL(fileURLWithPath: "/demo/Example.app"))
        let failure = URL(fileURLWithPath: "/demo/Containers/com.example.app")
        let result = RelatedFilesAnalysis(files: [LibraryFile(url: application.url, category: .application,
            sizeBytes: 100)], unreadableURLs: [failure])
        let apps = InstalledAppsViewModel(useSizeCache: false, scanApps: { [application] }, analyzeApp: { _ in result })
        let model = overview(apps)
        await apps.refresh()
        XCTAssertTrue(model.appSizesReady)
        XCTAssertFalse(model.appSizesComplete)
        XCTAssertEqual(model.thirdPartyAppBytes, 100)
        XCTAssertEqual(model.topApps().first?.isComplete, false)
        XCTAssertEqual(model.staleBucket?.isComplete, false)
    }

    /// 共享目录、父子目录及关联缓存均不可重复计入磁盘分段。
    func testDiskCategoriesDeduplicateCacheAndSharedData() {
        let cache = URL(fileURLWithPath: "/demo/Library/Caches")
        let app = LibraryFile(url: URL(fileURLWithPath: "/demo/Example.app"), category: .application, sizeBytes: 100)
        let data = LibraryFile(url: URL(fileURLWithPath: "/demo/Library/Group Containers/shared"),
                               category: .groupContainers, sizeBytes: 300)
        let child = LibraryFile(url: data.url.appendingPathComponent("child"), category: .groupContainers, sizeBytes: 50)
        let ownedCache = LibraryFile(url: cache.appendingPathComponent("com.example.app"), category: .caches, sizeBytes: 200)
        let adjacent = LibraryFile(url: URL(fileURLWithPath: "/demo/Library/CachesOther/data"),
                                   category: .applicationSupport, sizeBytes: 20)
        let leftover = LibraryFile(url: URL(fileURLWithPath: "/demo/Library/Application Support/deleted"),
                                  category: .applicationSupport, sizeBytes: 70)
        let leftoverCache = LibraryFile(url: cache.appendingPathComponent("deleted"), category: .caches, sizeBytes: 30)
        let result = OverviewService.diskCategories(appFiles: [app, data, data, child, ownedCache, adjacent],
            leftoverFiles: [leftover, leftover, leftoverCache, data], cacheBytes: 500, cacheRoot: cache)
        XCTAssertEqual(result.apps, 620)
        XCTAssertEqual(result.caches, 300)
        XCTAssertEqual(result.leftovers, 70)
        XCTAssertEqual(result.apps + (result.caches ?? 0) + result.leftovers, 990)
        let parent = LibraryFile(url: data.url.deletingLastPathComponent(), category: .groupContainers, sizeBytes: 400)
        let nested = OverviewService.diskCategories(appFiles: [data], leftoverFiles: [parent], cacheBytes: nil, cacheRoot: cache)
        XCTAssertEqual(nested.leftovers, 100)
        XCTAssertNil(nested.caches)
    }
}
