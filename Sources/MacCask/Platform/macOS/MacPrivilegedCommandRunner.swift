import Foundation

/// macOS 管理员权限命令实现：通过 osascript 的 `with administrator privileges` 弹出系统授权框
struct MacPrivilegedCommandRunner: PrivilegedCommandRunning {
    let runner: any CommandRunning

    /// 以管理员权限执行 shell 命令
    func runAsAdministrator(_ shellCommand: String) async -> CommandResult {
        let script = "do shell script \(AppleScriptEscaping.quoted(shellCommand)) with administrator privileges"
        let result = await runner.run("/usr/bin/osascript", arguments: ["-e", script])
        // 用户取消授权时 osascript 返回 -128 错误
        if !result.succeeded && result.output.contains("-128") {
            return .failure(L10n.tr("已取消授权"))
        }
        return result
    }
}
