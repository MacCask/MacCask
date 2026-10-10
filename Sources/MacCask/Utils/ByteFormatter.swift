import Foundation

/// 字节大小格式化工具
enum ByteFormatter {
    /// 将字节数格式化为人类可读文本（如 12.3 MB）
    static func string(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    /// 可选大小格式化，nil 时返回占位文本
    static func string(_ bytes: Int64?, placeholder: String = "计算中…") -> String {
        guard let bytes else { return placeholder }
        return string(bytes)
    }
}

/// 日期格式化工具
enum DateText {
    /// 相对时间描述（如「3 天前」）
    static func relative(_ date: Date?) -> String {
        guard let date else { return "未知" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    /// 短日期（如 2026/10/11）
    static func short(_ date: Date?) -> String {
        guard let date else { return "未知" }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}
