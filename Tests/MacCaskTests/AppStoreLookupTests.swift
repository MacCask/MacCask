import XCTest
@testable import MacCask

/// 商店数据可能与本地版本不同，验证匹配与保守版本判断。
final class AppStoreLookupTests: XCTestCase {
    /// 数字分段必须按数值排序，不能把 1.10 判定为早于 1.9。
    func testVersionComparison() {
        XCTAssertEqual(NumericVersion.compare("1.10", "1.9"), .orderedDescending)
        XCTAssertEqual(NumericVersion.compare("1.2.0", "1.2"), .orderedSame)
        XCTAssertEqual(NumericVersion.compare("1.2", "2.0"), .orderedAscending)
        XCTAssertNil(NumericVersion.compare("1.2 beta", "1.1"))
        XCTAssertNil(NumericVersion.compare("", "1.0"))
    }

    /// 只接受精确 Bundle ID 匹配的 Mac 应用，不误用同名软件或 iOS 结果。
    func testExactMacMatchAndStoreLink() throws {
        let data = Data("""
        {"results":[
          {"trackId":1,"bundleId":"com.example.other","version":"9","kind":"mac-software"},
          {"trackId":2,"bundleId":"com.example.app","version":"9","kind":"software"},
          {"trackId":3,"bundleId":"com.example.app","version":"2.0","kind":"mac-software","minimumOsVersion":"15.0"}
        ]}
        """.utf8)
        let result = try XCTUnwrap(AppStoreLookup.parse(data, bundleID: "com.example.app"))
        XCTAssertEqual(result.version, "2.0")
        XCTAssertEqual(result.storeURL(country: "cn").absoluteString, "macappstore://apps.apple.com/cn/app/id3")
        XCTAssertNil(try AppStoreLookup.parse(data, bundleID: "com.example.missing"))
    }

    /// 空结果与响应损坏分别表示未找到和失败，不应显示已是最新。
    func testMissingAndMalformedResponses() throws {
        XCTAssertNil(try AppStoreLookup.parse(Data("{\"results\":[]}".utf8), bundleID: "example"))
        XCTAssertThrowsError(try AppStoreLookup.parse(Data("not-json".utf8), bundleID: "example"))
    }

    /// Bundle ID 作为参数编码，不能注入额外查询参数。
    func testQueryEncoding() {
        let url = AppStoreLookup.url(bundleID: "com.example.app&country=xx", country: "cn")
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems!
        XCTAssertEqual(items.count, 3)
        XCTAssertEqual(items.first { $0.name == "bundleId" }?.value, "com.example.app&country=xx")
        XCTAssertEqual(items.first { $0.name == "country" }?.value, "cn")
    }
    /// 批量查询无需选择详情，列表和详情共用更新记录，本地升级后标记自动消失。
    @MainActor func testListUpdateStateTracksInstalledVersion() async {
        let store = StoreApp(trackId: 3, bundleId: "com.example.app", version: "1.21.2",
                             minimumOsVersion: "11.0", kind: "mac-software")
        let updates = AppStoreUpdates(fetch: { _, _, _ in store })
        let old = InstalledApp(url: URL(fileURLWithPath: "/Applications/Demo.app"), name: "Demo", matchNames: [],
            bundleID: store.bundleId, version: "1.21.1", isSystem: false, isAppStore: true, caskToken: nil, lastUsed: nil)
        await updates.refresh([old])
        XCTAssertEqual(updates.update(for: old)?.version, "1.21.2")
        let current = InstalledApp(url: old.url, name: old.name, matchNames: [], bundleID: store.bundleId,
            version: "1.21.2", isSystem: false, isAppStore: true, caskToken: nil, lastUsed: nil)
        XCTAssertNil(updates.update(for: current))
        let external = InstalledApp(url: old.url, name: old.name, matchNames: [], bundleID: store.bundleId,
            version: "1.21.1", isSystem: false, isAppStore: false, caskToken: nil, lastUsed: nil)
        XCTAssertNil(updates.update(for: external))
    }

}
