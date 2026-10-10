import XCTest
@testable import MacCask

/// 核心解析与匹配逻辑测试
final class MacCaskTests: XCTestCase {
    /// 从各类文件名中提取标识符
    func testIdentifierExtraction() {
        XCTAssertEqual(IdentifierMatcher.identifier(fromEntryName: "com.foo.Bar.plist"), "com.foo.Bar")
        XCTAssertEqual(IdentifierMatcher.identifier(fromEntryName: "com.foo.Bar.savedState"), "com.foo.Bar")
        XCTAssertEqual(IdentifierMatcher.identifier(fromEntryName: "com.foo.Bar.1A2B3C4D-1111-2222-3333-444455556666.plist"), "com.foo.Bar")
        XCTAssertEqual(IdentifierMatcher.identifier(fromEntryName: "group.com.foo.shared"), "com.foo.shared")
        XCTAssertEqual(IdentifierMatcher.identifier(fromEntryName: "5A4RE8SF68.com.tencent.xinWeChat"), "com.tencent.xinWeChat")
    }

    /// 反向域名与系统标识符判断
    func testReverseDNSAndSystem() {
        XCTAssertTrue(IdentifierMatcher.isReverseDNS("com.foo.bar"))
        XCTAssertFalse(IdentifierMatcher.isReverseDNS("Google"))
        XCTAssertFalse(IdentifierMatcher.isReverseDNS("homebrew.mxcl.redis"))
        XCTAssertTrue(IdentifierMatcher.isSystemIdentifier("com.apple.Safari"))
    }

    /// 应用关联文件匹配
    func testEntryBelongsToApp() {
        XCTAssertTrue(IdentifierMatcher.entry("com.foo.App.plist", belongsTo: "com.foo.App", appNames: ["App"], allowNameMatch: false))
        XCTAssertTrue(IdentifierMatcher.entry("com.foo.App.helper", belongsTo: "com.foo.App", appNames: ["App"], allowNameMatch: false))
        XCTAssertFalse(IdentifierMatcher.entry("com.foo.AppX", belongsTo: "com.foo.App", appNames: ["App"], allowNameMatch: false))
        XCTAssertTrue(IdentifierMatcher.entry("Visual Studio Code", belongsTo: "com.microsoft.VSCode", appNames: ["Visual Studio Code", "Code"], allowNameMatch: true))
        XCTAssertFalse(IdentifierMatcher.entry("Visual Studio Code", belongsTo: "com.microsoft.VSCode", appNames: ["Visual Studio Code", "Code"], allowNameMatch: false))
    }

    /// 已安装索引：相等、互为前缀、厂商判断
    func testInstalledIndex() {
        let index = InstalledIdentifierIndex(bundleIDs: ["com.foo.App", "com.bar.Tool.helper"])
        XCTAssertTrue(index.isInstalled("com.foo.app"))
        XCTAssertTrue(index.isInstalled("com.foo.App.ShipIt"))
        XCTAssertTrue(index.isInstalled("com.bar.Tool"))
        XCTAssertFalse(index.isInstalled("com.foo.Other"))
        XCTAssertTrue(index.hasVendor(of: "com.foo.Other"))
        XCTAssertFalse(index.hasVendor(of: "com.baz.Other"))
    }

    /// launchctl 输出解析
    func testLaunchctlParsing() {
        let disabled = """
        disabled services = {
            "com.foo.agent" => disabled
            "com.bar.agent" => enabled
        }
        """
        let overrides = LaunchItemScanner.parseOverrides(disabled)
        XCTAssertEqual(overrides["com.foo.agent"], true)
        XCTAssertEqual(overrides["com.bar.agent"], false)

        let list = "PID\tStatus\tLabel\n-\t0\tcom.idle\n768\t0\tcom.running\n"
        XCTAssertEqual(LaunchItemScanner.parseRunning(list), ["com.running": 768])
    }

    /// brew JSON 解析（包含 app artifact 的 target 写法）
    func testBrewParsing() throws {
        let json = """
        {"formulae":[{"name":"aom","desc":"d","versions":{"stable":"3.15.1"},"outdated":true,"pinned":false,
          "installed":[{"version":"3.5.0_1","installed_on_request":false},{"version":"3.13.2","installed_on_request":false,"time":1774605206}]}],
         "casks":[{"token":"foo","name":["Foo App"],"version":"2.0","installed":"1.0","outdated":true,
          "artifacts":[{"app":["Foo.app"]},{"app":["Bar.app",{"target":"Baz.app"}]},{"zap":[]}]}]}
        """
        let packages = try BrewJSONParser.parse(Data(json.utf8))
        XCTAssertEqual(packages.count, 2)
        let formula = try XCTUnwrap(packages.first { $0.kind == .formula })
        XCTAssertEqual(formula.installedVersion, "3.13.2")
        XCTAssertEqual(formula.latestVersion, "3.15.1")
        XCTAssertEqual(formula.keptVersionCount, 2)
        XCTAssertFalse(formula.installedOnRequest)
        let cask = try XCTUnwrap(packages.first { $0.kind == .cask })
        XCTAssertEqual(cask.displayName, "Foo App")
        XCTAssertEqual(cask.appNames, ["Foo.app", "Baz.app"])
    }

    /// 转义工具
    func testEscaping() {
        XCTAssertEqual(ShellEscaping.quote("a'b"), "'a'\\''b'")
        XCTAssertEqual(AppleScriptEscaping.quoted("a\"b\\c"), "\"a\\\"b\\\\c\"")
    }
}
