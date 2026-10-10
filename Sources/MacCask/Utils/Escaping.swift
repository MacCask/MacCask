import Foundation

/// Shell 参数转义工具
enum ShellEscaping {
    /// 用单引号包裹字符串，并转义其中的单引号，可安全拼接到 shell 命令中
    static func quote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}

/// AppleScript 字符串转义工具
enum AppleScriptEscaping {
    /// 生成带双引号的 AppleScript 字符串字面量，转义反斜杠与双引号
    static func quoted(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }
}
