import Foundation

/// 所有模块共用的翻译和插值工具；中文原文作为稳定的资源键。
enum L10n {
    /// 当前生效语言，后台错误提示与主窗口使用相同的用户偏好。
    static var language: AppLanguage {
        AppLanguage.resolve(UserDefaults.standard.string(forKey: AppLanguage.preferenceKey))
    }

    /// 日期、数字和系统控件使用所选语言，同时保留当前地区。
    static var locale: Locale {
        let region = Locale.current.region?.identifier ?? "US"
        return Locale(identifier: "\(language.rawValue)_\(region)")
    }

    /// 读取随应用打包的翻译表，不依赖工程目录或联网服务。
    static let english: [String: String] = {
        guard let url = AppResources.url(forResource: "English", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let translations = try? JSONDecoder().decode([String: String].self, from: data) else { return [:] }
        return translations
    }()

    /// 翻译界面文本，将插值逐项传入，避免用户数据被当作翻译键。
    static func tr(_ key: String, _ arguments: String...) -> String {
        translate(key, arguments: arguments, language: language)
    }

    /// 单次扫描模板并替换占位符，参数内的占位符样式不会被再次替换。
    static func translate(_ key: String, arguments: [String] = [], language: AppLanguage) -> String {
        let template = language == .english ? (english[key] ?? key) : key
        var result = ""
        var cursor = template.startIndex
        while cursor < template.endIndex {
            if template[cursor] == "{", let end = template[cursor...].firstIndex(of: "}"),
               let index = Int(template[template.index(after: cursor)..<end]), arguments.indices.contains(index) {
                result += arguments[index]
                cursor = template.index(after: end)
            } else {
                result.append(template[cursor])
                cursor = template.index(after: cursor)
            }
        }
        return result
    }
}
