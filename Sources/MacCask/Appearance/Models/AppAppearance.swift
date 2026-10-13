import Foundation

/// 外观偏好使用固定标识持久化，未知值回退到系统外观。
enum AppAppearance: String, CaseIterable, Identifiable {
    case system, light, dark
    static let preferenceKey = "appAppearance"
    var id: String { rawValue }

    /// 外观名称随应用语言切换。
    var title: String {
        switch self {
        case .system: return L10n.tr("跟随系统")
        case .light: return L10n.tr("浅色")
        case .dark: return L10n.tr("深色")
        }
    }

    /// 读取当前选择；清除偏好或未知值均恢复跟随系统。
    static func resolve(_ value: String?) -> AppAppearance {
        value.flatMap(AppAppearance.init(rawValue:)) ?? .system
    }
}
