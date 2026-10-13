import Foundation

/// 字节大小格式化工具
enum ByteFormatter {
    /// 将字节数格式化为人类可读文本（如 12.3 MB）
    static func string(_ bytes: Int64) -> String {
        string(bytes, locale: L10n.locale)
    }

    /// 显式区域版本供测试使用，保留原有单参数接口供 map 等高阶函数调用。
    static func string(_ bytes: Int64, locale: Locale) -> String {
        bytes.formatted(.byteCount(style: .file, spellsOutZero: false).locale(locale))
    }

    /// 可选大小格式化，nil 时返回占位文本
    static func string(_ bytes: Int64?, placeholder: String = L10n.tr("计算中…")) -> String {
        guard let bytes else { return placeholder }
        return string(bytes)
    }
}

/// 日期格式化工具
enum DateText {
    /// 相对时间描述（如「3 天前」）
    static func relative(_ date: Date?, locale: Locale = L10n.locale) -> String {
        guard let date else { return L10n.tr("未知") }
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = locale
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    /// 短日期（如 2026/10/11）
    static func short(_ date: Date?, locale: Locale = L10n.locale) -> String {
        guard let date else { return L10n.tr("未知") }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
