import AppKit
import XCTest
@testable import MacCask

/// 覆盖启动统计的执行器隔离、大量路径去重与系统菜单语言切换。
@MainActor
final class ResponsivenessTests: XCTestCase {
    /// 即使由 UI 发起请求，分析器在第一次挂起前的同步工作也必须脱离主线程。
    func testScannerStartsSynchronousWorkOffMainThread() async {
        let app = InstalledApp(url: URL(fileURLWithPath: "/tmp/Example.app"), name: "Example",
            matchNames: ["Example"], bundleID: "com.example.app", version: nil, isSystem: false,
            isAppStore: false, caskToken: nil, lastUsed: nil)
        let scanner = AppUsageScanner { app in
            XCTAssertFalse(Thread.isMainThread)
            return RelatedFilesAnalysis(files: [LibraryFile(url: app.url, category: .application, sizeBytes: 42)])
        }
        let result = await scanner.analysis(for: app)
        XCTAssertEqual(result.totalMeasurement.bytes, 42)
    }

    /// 成千上万个关联目录含重复及父子关系时仍保持正确结果与交互级耗时。
    func testLargePathIndex() {
        let parents = (0..<2_000).map {
            LibraryFile(url: URL(fileURLWithPath: "/tmp/data/app\($0)"), category: .applicationSupport, sizeBytes: 100)
        }
        let children = parents.map {
            LibraryFile(url: $0.url.appendingPathComponent("child"), category: .applicationSupport, sizeBytes: 20)
        }
        let started = Date()
        let unique = (children + parents + parents).uniqueFiles
        let categorized = OverviewService.diskCategories(appFiles: children + parents,
            leftoverFiles: parents, cacheBytes: 500, cacheRoot: URL(fileURLWithPath: "/tmp/cache"))
        let elapsed = Date().timeIntervalSince(started)
        XCTAssertEqual(unique.count, 2_000)
        XCTAssertEqual(categorized.apps, 200_000)
        XCTAssertEqual(categorized.leftovers, 0)
        XCTAssertEqual(categorized.caches, 500)
        // 宽松上限用于防止退回逐对 Foundation URL 标准化的平方复杂度。
        XCTAssertLessThan(elapsed, 2)
        print("Indexed 6,000 paths and categorized 4,000 entries in \(elapsed) seconds")
        XCTAssertFalse(PathHierarchy.ancestors(of: "/tmp/data/app10").contains("/tmp/data/app1"))
    }

    /// 异步分类发布后刷新首页；已取消的旧任务不能覆盖最新快照。
    func testDiskClassificationPublishesLatestSnapshot() async {
        let model = OverviewViewModel(apps: InstalledAppsViewModel(useSizeCache: false),
            homebrew: HomebrewViewModel(), launchItems: LaunchItemsViewModel(), leftovers: LeftoversViewModel())
        let input = OverviewViewModel.CategoryInput(appFiles: [], leftoverFiles: [], cacheBytes: 123)
        await model.updateDiskCategories(input)
        XCTAssertEqual(model.diskCategorySnapshot?.caches, 123)
        let cancelled = Task { await model.updateDiskCategories(.init(appFiles: [], leftoverFiles: [], cacheBytes: 999)) }
        cancelled.cancel()
        await cancelled.value
        XCTAssertEqual(model.diskCategorySnapshot?.caches, 123)
    }

    /// 切换中英文时保留设置图标、快捷键及响应动作，并且始终只有一个设置入口。
    func testNativeMenuSwitchesLanguageWithoutReplacingItems() {
        _ = NSApplication.shared
        let menu = NSMenu()
        let settings = NSMenuItem(title: "Settings…", action: Selector(("showSettingsWindow:")), keyEquivalent: ",")
        settings.keyEquivalentModifierMask = .command
        settings.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)
        let originalImage = settings.image
        menu.addItem(settings)
        let about = NSMenuItem(title: "About MacCask", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        menu.addItem(about)
        let hide = NSMenuItem(title: "Hide MacCask", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        menu.addItem(hide)
        let services = NSMenuItem(title: "Services", action: nil, keyEquivalent: "")
        menu.addItem(services)
        MacMenuLocalization.update(menu, language: .simplifiedChinese)
        XCTAssertEqual(menu.items.map(\.title), ["设置…", "关于 MacCask", "隐藏 MacCask", "服务"])
        MacMenuLocalization.update(menu, language: .english)
        XCTAssertEqual(menu.items.map(\.title), ["Settings…", "About MacCask", "Hide MacCask", "Services"])
        MacMenuLocalization.update(menu, language: .simplifiedChinese)
        XCTAssertEqual(menu.items.count, 4)
        XCTAssertTrue(settings.image === originalImage)
        XCTAssertEqual(settings.keyEquivalent, ",")
        XCTAssertEqual(settings.action, Selector(("showSettingsWindow:")))
        XCTAssertEqual(hide.action, #selector(NSApplication.hide(_:)))
    }
}
