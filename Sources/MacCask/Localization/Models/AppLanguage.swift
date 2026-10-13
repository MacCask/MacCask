import Foundation

/// 语言偏好与枚举标识独立，切换语言不会改变持久化记录的键。
enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case english = "en"
    case simplifiedChinese = "zh-Hans"

    static let preferenceKey = "appLanguage"
    var id: String { rawValue }

    /// 使用语言自身的名称，让用户在陌生界面中也能找到目标语言。
    var title: String {
        switch self {
        case .system: return L10n.tr("跟随系统")
        case .english: return "English"
        case .simplifiedChinese: return "简体中文"
        }
    }

    /// 按系统首选语言顺序匹配支持的语言，不支持时回退到英语。
    static func systemLanguage(preferredLanguages: [String] = Locale.preferredLanguages) -> AppLanguage {
        for identifier in preferredLanguages {
            let tag = identifier.replacingOccurrences(of: "_", with: "-").lowercased()
            if tag == "en" || tag.hasPrefix("en-") { return .english }
            if tag == "zh" || tag.hasPrefix("zh-hans") || tag == "zh-cn" || tag == "zh-sg" {
                return .simplifiedChinese
            }
        }
        return .english
    }

    /// 解析用户偏好；无设置或无效设置均跟随系统。
    static func resolve(_ preference: String?, preferredLanguages: [String] = Locale.preferredLanguages) -> AppLanguage {
        let language = preference.flatMap(Self.init(rawValue:)) ?? .system
        return language == .system ? systemLanguage(preferredLanguages: preferredLanguages) : language
    }
}
