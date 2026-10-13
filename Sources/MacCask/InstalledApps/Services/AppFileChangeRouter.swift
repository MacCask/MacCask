import Foundation

/// 将目录级变化匹配到应用；新关联目录沿用现有标识符与名称匹配规则。
enum AppFileChangeRouter {
    /// 缩小更新范围；父目录合并通知或事件丢失时采取保守失效策略。
    static func affectedApps(paths: [URL], apps: [InstalledApp], files: [String: [LibraryFile]],
                             locations: [LibraryLocation], rescanAll: Bool) -> Set<String> {
        if rescanAll { return Set(apps.map(\.id)) }
        // 每批通知只标准化一次；文件事件密集时不在主线程逐对重复处理 URL。
        let changed = paths.map { $0.standardizedFileURL.path }
        let roots = locations.map { (path: $0.url.standardizedFileURL.path, matchesByName: $0.matchesByName) }
        return Set(apps.filter { app in
            let known = [app.url.standardizedFileURL.path] + (files[app.id] ?? []).map { $0.url.standardizedFileURL.path }
            return changed.contains { path in
                if known.contains(where: { PathHierarchy.contains(path, in: $0) || PathHierarchy.contains($0, in: path) }) { return true }
                return roots.contains { location in
                    if PathHierarchy.contains(location.path, in: path) { return true }
                    guard PathHierarchy.contains(path, in: location.path) else { return false }
                    let relative = path.dropFirst(location.path.count)
                    guard let entry = relative.split(separator: "/").first else { return false }
                    return IdentifierMatcher.entry(String(entry), belongsTo: app.bundleID,
                        appNames: app.matchNames, allowNameMatch: location.matchesByName)
                }
            }
        }.map(\.id))
    }
}
