import Foundation

/// 卸载结果
struct UninstallOutcome: Sendable {
    /// 删除失败的文件及原因
    let failures: [URL: String]
    /// 整体错误信息（如 brew 卸载失败）
    let errorMessage: String?

    /// 是否完全成功
    var succeeded: Bool { failures.isEmpty && errorMessage == nil }
}

/// 应用卸载服务
enum AppUninstaller {
    /// 卸载应用：Homebrew 安装的先执行 brew uninstall，其余文件移到废纸篓
    /// - Parameters:
    ///   - app: 要卸载的应用
    ///   - files: 用户勾选的待删除文件（可能包含应用包本身）
    ///   - output: brew 命令输出回调
    static func uninstall(_ app: InstalledApp, files: [LibraryFile], output: @escaping @Sendable (String) -> Void) async -> UninstallOutcome {
        var remaining = files.map(\.url)
        if let token = app.caskToken {
            let result = await BrewService.shared.uninstallCask(token: token, output: output)
            guard result.succeeded else {
                return UninstallOutcome(failures: [:], errorMessage: "Homebrew 卸载失败，请查看日志")
            }
            // brew 已移除应用包，剩余的关联文件继续移到废纸篓
            remaining.removeAll { $0 == app.url }
        }
        output("移到废纸篓：\(remaining.count) 项\n")
        let failures = await Platform.current.trasher.moveToTrash(remaining)
        for (url, reason) in failures {
            output("失败：\(url.path)（\(reason)）\n")
        }
        return UninstallOutcome(failures: failures, errorMessage: nil)
    }
}
