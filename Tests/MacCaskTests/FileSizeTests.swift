import Foundation
import XCTest
@testable import MacCask

/// 验证真实文件遍历、错误传播和微信目录匹配，不读取用户聊天内容。
final class FileSizeTests: XCTestCase {
    /// 创建隔离目录并在测试结束后自动清理。
    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try FileManager.default.removeItem(at: url) }
        return url
    }

    /// 包内及隐藏文件应计入，符号链接不应重复计入目标文件。
    func testNestedFilesAndSymlinks() throws {
        let root = try temporaryDirectory()
        let package = root.appendingPathComponent("Nested.app")
        try FileManager.default.createDirectory(at: package, withIntermediateDirectories: true)
        let file = package.appendingPathComponent(".hidden")
        try Data(repeating: 42, count: 100_000).write(to: file)
        let link = root.appendingPathComponent("link")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: package)
        let measured = FileSizeCalculator.measure(of: root)
        XCTAssertTrue(measured.isComplete)
        XCTAssertGreaterThan(measured.bytes, 0)
        XCTAssertEqual(measured.bytes, FileSizeCalculator.measure(of: file).bytes)
        XCTAssertEqual(FileSizeCalculator.measure(of: link).bytes, 0)
    }

    /// 空目录是完整零字节，不存在的文件则必须携带失败状态。
    func testEmptyAndMissingPaths() throws {
        let root = try temporaryDirectory()
        XCTAssertTrue(FileSizeCalculator.measure(of: root).isComplete)
        XCTAssertEqual(FileSizeCalculator.measure(of: root).bytes, 0)
        let missing = root.appendingPathComponent("missing")
        XCTAssertEqual(FileSizeCalculator.measure(of: missing).unreadableURLs, [missing])
    }

    /// 目录权限被拒绝时仍保留可读部分，不能静默返回完整结果。
    func testUnreadableSubdirectory() throws {
        let root = try temporaryDirectory()
        let denied = root.appendingPathComponent("denied")
        try FileManager.default.createDirectory(at: denied, withIntermediateDirectories: true)
        try Data(repeating: 42, count: 100_000).write(to: denied.appendingPathComponent("data"))
        let readable = root.appendingPathComponent("readable")
        try Data(repeating: 43, count: 50_000).write(to: readable)
        try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: denied.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: denied.path) }
        let result = FileSizeCalculator.measure(of: root)
        XCTAssertFalse(result.isComplete)
        XCTAssertTrue(result.unreadableURLs.contains { $0.resolvingSymlinksInPath().path == denied.resolvingSymlinksInPath().path })
        XCTAssertEqual(result.bytes, FileSizeCalculator.measure(of: readable).bytes)
    }

    /// 列表总占用包含包和关联数据，数据变化不能依赖应用包修改时间刷新。
    func testTotalUsageIncludesChangingRelatedData() async throws {
        let root = try temporaryDirectory()
        let appURL = root.appendingPathComponent("Example.app")
        let support = root.appendingPathComponent("Application Support")
        let dataURL = support.appendingPathComponent("com.example.app")
        for url in [appURL, dataURL] {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        try Data(repeating: 12, count: 100_000).write(to: appURL.appendingPathComponent("binary"))
        let dataFile = dataURL.appendingPathComponent("messages")
        try Data(repeating: 42, count: 200_000).write(to: dataFile)
        let app = InstalledApp(url: appURL, name: "Example", matchNames: ["Example"],
            bundleID: "com.example.app", version: nil, isSystem: false,
            isAppStore: false, caskToken: nil, lastUsed: nil)
        let locations = [LibraryLocation(url: support, category: .applicationSupport, matchesByName: true)]
        let modified = FileSizeCalculator.modificationDate(of: appURL)
        let initial = await RelatedFilesAnalyzer.analyze(app, locations: locations)
        let packageSize = FileSizeCalculator.allocatedSize(of: appURL)
        XCTAssertEqual(initial.totalMeasurement.bytes, packageSize + FileSizeCalculator.allocatedSize(of: dataURL))
        XCTAssertTrue(initial.totalMeasurement.isComplete)
        try Data(repeating: 43, count: 900_000).write(to: dataFile)
        let updated = await RelatedFilesAnalyzer.analyze(app, locations: locations)
        XCTAssertEqual(modified, FileSizeCalculator.modificationDate(of: appURL))
        XCTAssertGreaterThan(updated.totalMeasurement.bytes, initial.totalMeasurement.bytes)
        XCTAssertEqual(updated.totalMeasurement.bytes, packageSize + FileSizeCalculator.allocatedSize(of: dataURL))
        try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: dataURL.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: dataURL.path) }
        let partial = await RelatedFilesAnalyzer.analyze(app, locations: locations)
        XCTAssertFalse(partial.totalMeasurement.isComplete)
        XCTAssertEqual(partial.totalMeasurement.bytes, packageSize)
    }

    /// 微信主容器及带 TeamID 的群组容器都应关联，其他腾讯应用不能混入。
    func testWeChatContainersAndScanErrors() async throws {
        let root = try temporaryDirectory()
        let appURL = root.appendingPathComponent("WeChat.app")
        let containers = root.appendingPathComponent("Containers")
        let groups = root.appendingPathComponent("Group Containers")
        let main = containers.appendingPathComponent("com.tencent.xinWeChat")
        let group = groups.appendingPathComponent("5A4RE8SF68.com.tencent.xinWeChat")
        for url in [appURL, main, group, containers.appendingPathComponent("com.tencent.qq")] {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        try Data(repeating: 42, count: 100_000).write(to: group.appendingPathComponent("data"))
        let app = InstalledApp(url: appURL, name: "微信", matchNames: ["WeChat"],
            bundleID: "com.tencent.xinWeChat", version: nil, isSystem: false,
            isAppStore: false, caskToken: nil, lastUsed: nil)
        let locations = [
            LibraryLocation(url: containers, category: .containers, matchesByName: false),
            LibraryLocation(url: groups, category: .groupContainers, matchesByName: false),
            LibraryLocation(url: root.appendingPathComponent("missing"), category: .caches, matchesByName: true)
        ]
        let result = await RelatedFilesAnalyzer.analyze(app, locations: locations)
        XCTAssertTrue(result.isComplete)
        XCTAssertEqual(Set(result.files.map { $0.url.resolvingSymlinksInPath().path }),
                       Set([appURL, main, group].map { $0.resolvingSymlinksInPath().path }))
        XCTAssertGreaterThan(result.files.totalSize, 0)
        try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: group.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: group.path) }
        let partial = await RelatedFilesAnalyzer.analyze(app, locations: locations)
        XCTAssertFalse(partial.isComplete)
        XCTAssertEqual(partial.files.first { $0.url.resolvingSymlinksInPath().path == group.resolvingSymlinksInPath().path }?.isSizeComplete, false)
        try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: containers.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: containers.path) }
        let deniedRoot = await RelatedFilesAnalyzer.analyze(app, locations: locations)
        XCTAssertTrue(deniedRoot.unreadableURLs.contains(containers))
    }
}
