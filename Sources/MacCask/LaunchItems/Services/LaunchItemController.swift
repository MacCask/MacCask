import Foundation

/// 启动项开关控制（launchd 类型）
enum LaunchItemController {
    /// 启用或禁用 launchd 启动项
    /// - 代理：在 gui/<uid> 域中 enable/disable，并立即加载/卸载
    /// - 守护进程：在 system 域中操作，需要管理员权限
    static func setEnabled(_ item: LaunchItem, enabled: Bool) async -> CommandResult {
        guard let plist = item.plistURL else { return .failure("缺少 plist 路径") }
        let domain = item.source == .systemDaemon ? "system" : "gui/\(getuid())"
        let target = "\(domain)/\(item.label)"

        if item.source.requiresAdmin {
            let commands = enabled
                ? "launchctl enable \(ShellEscaping.quote(target)); launchctl bootstrap \(domain) \(ShellEscaping.quote(plist.path)) 2>/dev/null; true"
                : "launchctl disable \(ShellEscaping.quote(target)); launchctl bootout \(ShellEscaping.quote(target)) 2>/dev/null; true"
            return await Platform.current.privilegedRunner.runAsAdministrator(commands)
        }

        let runner = Platform.current.commandRunner
        if enabled {
            let result = await runner.run("/bin/launchctl", arguments: ["enable", target])
            guard result.succeeded else { return result }
            // 已加载时 bootstrap 会报错，忽略
            _ = await runner.run("/bin/launchctl", arguments: ["bootstrap", domain, plist.path])
            return result
        } else {
            let result = await runner.run("/bin/launchctl", arguments: ["disable", target])
            guard result.succeeded else { return result }
            // 未加载时 bootout 会报错，忽略
            _ = await runner.run("/bin/launchctl", arguments: ["bootout", target])
            return result
        }
    }
}
