import Foundation

/// 登录项读取失败错误
struct LoginItemError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

/// macOS 登录项实现：通过 AppleScript 调用 System Events
struct MacLoginItemManager: LoginItemManaging {
    let runner: any CommandRunning

    /// 读取全部登录项，每行格式为「名称\t路径」
    func listLoginItems() async -> Result<[LoginItemInfo], Error> {
        let script = """
        set out to ""
        tell application "System Events"
            repeat with li in login items
                set out to out & (name of li) & tab & (path of li) & linefeed
            end repeat
        end tell
        return out
        """
        let result = await runner.run("/usr/bin/osascript", arguments: ["-e", script])
        guard result.succeeded else {
            return .failure(LoginItemError(message: L10n.tr("无法读取登录项（可能需要在「隐私与安全性 → 自动化」中允许 MacCask 控制“系统事件”）")))
        }
        let items = result.output
            .split(separator: "\n")
            .compactMap { line -> LoginItemInfo? in
                let parts = line.split(separator: "\t", maxSplits: 1).map(String.init)
                guard parts.count == 2 else { return nil }
                return LoginItemInfo(name: parts[0], path: parts[1])
            }
        return .success(items)
    }

    /// 添加登录项
    func addLoginItem(path: String) async -> CommandResult {
        let script = "tell application \"System Events\" to make login item at end with properties {path:\(AppleScriptEscaping.quoted(path)), hidden:false}"
        return await runner.run("/usr/bin/osascript", arguments: ["-e", script])
    }

    /// 按名称移除登录项
    func removeLoginItem(name: String) async -> CommandResult {
        let script = "tell application \"System Events\" to delete login item \(AppleScriptEscaping.quoted(name))"
        return await runner.run("/usr/bin/osascript", arguments: ["-e", script])
    }
}
