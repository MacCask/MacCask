import Foundation

/// macOS 废纸篓实现：优先使用 FileManager.trashItem，权限不足时改用管理员权限移动到用户废纸篓
struct MacFileTrasher: FileTrashing {
    let privilegedRunner: any PrivilegedCommandRunning

    /// 将文件移到废纸篓，返回失败项
    func moveToTrash(_ urls: [URL]) async -> [URL: String] {
        var needPrivilege: [URL] = []
        var failures: [URL: String] = [:]

        // 第一轮：普通权限
        for url in urls where FileManager.default.fileExists(atPath: url.path) || isSymlink(url) {
            do {
                try FileManager.default.trashItem(at: url, resultingItemURL: nil)
            } catch {
                needPrivilege.append(url)
            }
        }
        guard !needPrivilege.isEmpty else { return failures }

        // 第二轮：一次性申请管理员权限，批量移动到当前用户的废纸篓（文件名附加时间戳避免冲突）
        let trashDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".Trash")
        let stamp = Int(Date().timeIntervalSince1970)
        let commands = needPrivilege.map { url -> String in
            let target = trashDir.appendingPathComponent("\(url.lastPathComponent) \(stamp)")
            return "mv -f \(ShellEscaping.quote(url.path)) \(ShellEscaping.quote(target.path))"
        }
        let result = await privilegedRunner.runAsAdministrator(commands.joined(separator: " ; "))
        // 逐个确认是否已移动成功
        for url in needPrivilege where FileManager.default.fileExists(atPath: url.path) {
            failures[url] = result.succeeded ? "移动失败" : result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return failures
    }

    /// 判断路径是否为符号链接（fileExists 会跟随链接，失效链接需要单独判断）
    private func isSymlink(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true
    }
}
