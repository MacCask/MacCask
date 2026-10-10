import Foundation

/// 启动项扫描服务
enum LaunchItemScanner {
    /// 扫描所有 launchd 启动项（不含登录项），苹果自身的启动项会被过滤
    static func scanLaunchdItems() async -> [LaunchItem] {
        let runner = Platform.current.commandRunner
        let uid = getuid()
        // 并行读取 launchctl 状态
        async let guiDisabled = runner.run("/bin/launchctl", arguments: ["print-disabled", "gui/\(uid)"])
        async let systemDisabled = runner.run("/bin/launchctl", arguments: ["print-disabled", "system"])
        async let list = runner.run("/bin/launchctl", arguments: ["list"])
        let userOverrides = parseOverrides(await guiDisabled.output)
        let systemOverrides = parseOverrides(await systemDisabled.output)
        let running = parseRunning(await list.output)

        return await Task.detached(priority: .userInitiated) {
            let dirs: [(URL, LaunchItemSource)] = [
                (LibraryLocations.home.appendingPathComponent("Library/LaunchAgents"), .userAgent),
                (URL(fileURLWithPath: "/Library/LaunchAgents"), .globalAgent),
                (URL(fileURLWithPath: "/Library/LaunchDaemons"), .systemDaemon)
            ]
            var items: [LaunchItem] = []
            for (dir, source) in dirs {
                for url in LibraryLocations.entries(of: dir) where url.pathExtension == "plist" {
                    let overrides = source == .systemDaemon ? systemOverrides : userOverrides
                    if let item = makeItem(plist: url, source: source, overrides: overrides, running: running) {
                        items.append(item)
                    }
                }
            }
            return items
        }.value
    }

    /// 由 plist 构造启动项
    private static func makeItem(plist url: URL, source: LaunchItemSource,
                                 overrides: [String: Bool], running: [String: Int]) -> LaunchItem? {
        let dict = PlistReader.dictionary(at: url) ?? [:]
        let label = dict["Label"] as? String ?? url.deletingPathExtension().lastPathComponent
        guard !IdentifierMatcher.isSystemIdentifier(label) else { return nil }

        let arguments = dict["ProgramArguments"] as? [String] ?? []
        let program = dict["Program"] as? String ?? arguments.first
        // KeepAlive 可能是布尔值，也可能是条件字典（视为常驻）
        let keepAlive = (dict["KeepAlive"] as? Bool) ?? (dict["KeepAlive"] is [String: Any])
        let plistDisabled = dict["Disabled"] as? Bool ?? false
        // launchctl 覆盖值优先于 plist 中的 Disabled
        let disabled = overrides[label] ?? plistDisabled
        let appPath = program.flatMap(BundleInfoReader.enclosingAppPath(of:))
        let displayName = appPath.map { BundleInfoReader.read(URL(fileURLWithPath: $0)).name } ?? label

        return LaunchItem(label: label, source: source, plistURL: url, program: program,
                          arguments: Array(arguments.dropFirst(dict["Program"] == nil ? 1 : 0)),
                          runAtLoad: dict["RunAtLoad"] as? Bool ?? false, keepAlive: keepAlive,
                          isEnabled: !disabled, pid: running[label], appPath: appPath, displayName: displayName)
    }

    /// 由登录项构造启动项
    static func makeLoginItem(name: String, path: String, enabled: Bool) -> LaunchItem {
        LaunchItem(label: name, source: .loginItem, plistURL: nil, program: path, arguments: [],
                   runAtLoad: true, keepAlive: false, isEnabled: enabled, pid: nil,
                   appPath: path.hasSuffix(".app") ? path : BundleInfoReader.enclosingAppPath(of: path),
                   displayName: name)
    }

    /// 解析 `launchctl print-disabled` 输出：`"label" => disabled|enabled|true|false`
    /// - Returns: label → 是否被禁用
    static func parseOverrides(_ output: String) -> [String: Bool] {
        var result: [String: Bool] = [:]
        for line in output.split(separator: "\n") {
            let parts = line.components(separatedBy: "=>")
            guard parts.count == 2 else { continue }
            let label = parts[0].trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            let state = parts[1].trimmingCharacters(in: .whitespaces)
            result[label] = (state == "disabled" || state == "true")
        }
        return result
    }

    /// 解析 `launchctl list` 输出：`PID\tStatus\tLabel`，只保留正在运行（PID 非 -）的项
    static func parseRunning(_ output: String) -> [String: Int] {
        var result: [String: Int] = [:]
        for line in output.split(separator: "\n").dropFirst() {
            let cols = line.split(separator: "\t")
            guard cols.count == 3, let pid = Int(cols[0]) else { continue }
            result[String(cols[2])] = pid
        }
        return result
    }
}
