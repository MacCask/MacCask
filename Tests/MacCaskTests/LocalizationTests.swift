import Foundation
import XCTest
@testable import MacCask

/// 验证语言回退、翻译资源及动态数据插值，不修改真实用户偏好。
final class LocalizationTests: XCTestCase {
    /// 首选语言匹配英语及简体中文，其他语言按优先级回退。
    func testSystemLanguageResolution() {
        XCTAssertEqual(AppLanguage.resolve(nil, preferredLanguages: ["zh-Hans-CN", "en-US"]), .simplifiedChinese)
        XCTAssertEqual(AppLanguage.resolve("system", preferredLanguages: ["en-GB", "zh-Hans"]), .english)
        XCTAssertEqual(AppLanguage.resolve(nil, preferredLanguages: ["zh_CN"]), .simplifiedChinese)
        XCTAssertEqual(AppLanguage.resolve(nil, preferredLanguages: ["zh-SG"]), .simplifiedChinese)
        XCTAssertEqual(AppLanguage.resolve(nil, preferredLanguages: ["fr-FR", "zh-Hans"]), .simplifiedChinese)
        XCTAssertEqual(AppLanguage.resolve(nil, preferredLanguages: ["zh-Hant-TW"]), .english)
        XCTAssertEqual(AppLanguage.resolve(nil, preferredLanguages: []), .english)
        XCTAssertEqual(AppLanguage.resolve("invalid", preferredLanguages: ["en"]), .english)
    }

    /// 显式选择覆盖系统语言，偏好标识可稳定保存与恢复。
    func testExplicitLanguagePreference() {
        XCTAssertEqual(AppLanguage.resolve("en", preferredLanguages: ["zh-Hans"]), .english)
        XCTAssertEqual(AppLanguage.resolve("zh-Hans", preferredLanguages: ["en"]), .simplifiedChinese)
        let defaults = UserDefaults(suiteName: "MacCaskTests.Language.\(UUID().uuidString)")!
        defaults.set(AppLanguage.simplifiedChinese.rawValue, forKey: AppLanguage.preferenceKey)
        XCTAssertEqual(AppLanguage.resolve(defaults.string(forKey: AppLanguage.preferenceKey)), .simplifiedChinese)
        defaults.removeObject(forKey: AppLanguage.preferenceKey)
    }

    /// 两种语言均能插入多个动态参数，参数内容不会被递归解释。
    func testTranslationsAndInterpolation() {
        XCTAssertGreaterThan(L10n.english.count, 250)
        XCTAssertEqual(L10n.translate("应用程序", language: .english), "Applications")
        XCTAssertEqual(L10n.translate("应用程序", language: .simplifiedChinese), "应用程序")
        XCTAssertEqual(L10n.translate("已选 {0} 项 · {1}", arguments: ["3", "42 MB"], language: .english), "3 selected · 42 MB")
        XCTAssertEqual(L10n.translate("已选 {0} 项 · {1}", arguments: ["3", "42 MB"], language: .simplifiedChinese), "已选 3 项 · 42 MB")
        XCTAssertEqual(L10n.translate("已选 {0} 项 · {1}", arguments: ["{1}", "42 MB"], language: .english), "{1} selected · 42 MB")
        XCTAssertEqual(L10n.translate("unknown key", language: .english), "unknown key")
    }

    /// 译文必须保留原文全部占位符，不包含未翻译的中文界面文本。
    func testCatalogIntegrity() throws {
        let placeholders = try NSRegularExpression(pattern: #"\{\d+\}"#)
        let chinese = try NSRegularExpression(pattern: #"[\p{Han}]"#)
        for (key, value) in L10n.english {
            let sourceTokens = placeholders.matches(in: key, range: NSRange(key.startIndex..., in: key))
                .map { (key as NSString).substring(with: $0.range) }.sorted()
            let translatedTokens = placeholders.matches(in: value, range: NSRange(value.startIndex..., in: value))
                .map { (value as NSString).substring(with: $0.range) }.sorted()
            XCTAssertEqual(sourceTokens, translatedTokens, key)
            XCTAssertNil(chinese.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)), key)
        }
    }

    /// 语言切换不能改变用于持久化及选择的枚举原始标识。
    func testStableIdentifiers() {
        XCTAssertEqual(AppFilter.thirdParty.rawValue, "第三方")
        XCTAssertEqual(LaunchItemSource.loginItem.rawValue, "登录项")
        XCTAssertEqual(LibraryCategory.caches.rawValue, "缓存")
    }

    /// 日期和零字节文案必须使用应用语言，而不是固定使用系统语言。
    func testLocalizedFormatting() {
        let english = Locale(identifier: "en_US")
        let chinese = Locale(identifier: "zh-Hans_CN")
        XCTAssertEqual(ByteFormatter.string(0, locale: english), "0 bytes")
        XCTAssertTrue(ByteFormatter.string(0, locale: chinese).contains("字节"))
        let date = Date(timeIntervalSince1970: 1_704_196_800)
        XCTAssertTrue(DateText.short(date, locale: english).contains("Jan"))
        XCTAssertTrue(DateText.short(date, locale: chinese).contains("年"))
        let hourAgo = Date().addingTimeInterval(-3600)
        XCTAssertTrue(DateText.relative(hourAgo, locale: english).contains("hour"))
        XCTAssertTrue(DateText.relative(hourAgo, locale: chinese).contains("小时"))
    }
}
