import Foundation

/// 解析 `brew info --json=v2 --installed` 的输出
enum BrewJSONParser {
    /// 解析 JSON 数据为包列表
    static func parse(_ data: Data) throws -> [BrewPackage] {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw BrewError.invalidOutput
        }
        let formulae = (root["formulae"] as? [[String: Any]] ?? []).compactMap(parseFormula)
        let casks = (root["casks"] as? [[String: Any]] ?? []).compactMap(parseCask)
        return formulae + casks
    }

    /// 解析单个 formula
    private static func parseFormula(_ dict: [String: Any]) -> BrewPackage? {
        guard let name = dict["name"] as? String else { return nil }
        let installed = dict["installed"] as? [[String: Any]] ?? []
        // installed 数组按安装顺序排列，最后一个是当前版本
        let current = installed.last
        let versions = dict["versions"] as? [String: Any]
        let installedVersion = current?["version"] as? String ?? "?"
        let latest = versions?["stable"] as? String ?? installedVersion
        let time = (current?["time"] as? NSNumber).map { Date(timeIntervalSince1970: $0.doubleValue) }
        return BrewPackage(
            name: name,
            kind: .formula,
            displayName: name,
            desc: dict["desc"] as? String,
            homepage: (dict["homepage"] as? String).flatMap(URL.init(string:)),
            tap: dict["tap"] as? String,
            installedVersion: installedVersion,
            latestVersion: latest,
            isOutdated: dict["outdated"] as? Bool ?? false,
            isPinned: dict["pinned"] as? Bool ?? false,
            installedOnRequest: installed.contains { $0["installed_on_request"] as? Bool == true },
            installedAt: time,
            keptVersionCount: installed.count,
            appNames: [],
            autoUpdates: false
        )
    }

    /// 解析单个 cask
    private static func parseCask(_ dict: [String: Any]) -> BrewPackage? {
        guard let token = dict["token"] as? String else { return nil }
        let names = dict["name"] as? [String] ?? []
        let installedVersion = dict["installed"] as? String ?? "?"
        let latest = dict["version"] as? String ?? installedVersion
        let time = (dict["installed_time"] as? NSNumber).map { Date(timeIntervalSince1970: $0.doubleValue) }
        return BrewPackage(
            name: token,
            kind: .cask,
            displayName: names.first ?? token,
            desc: dict["desc"] as? String,
            homepage: (dict["homepage"] as? String).flatMap(URL.init(string:)),
            tap: dict["tap"] as? String,
            installedVersion: installedVersion,
            latestVersion: latest,
            isOutdated: dict["outdated"] as? Bool ?? false,
            isPinned: false,
            installedOnRequest: true,
            installedAt: time,
            keptVersionCount: 1,
            appNames: appArtifacts(dict["artifacts"]),
            autoUpdates: dict["auto_updates"] as? Bool ?? false
        )
    }

    /// 从 artifacts 中提取 app 文件名，结构形如 [{"app": ["Foo.app", {"target": "Bar.app"}]}]
    private static func appArtifacts(_ value: Any?) -> [String] {
        guard let artifacts = value as? [[String: Any]] else { return [] }
        var result: [String] = []
        for artifact in artifacts {
            guard let apps = artifact["app"] as? [Any] else { continue }
            for app in apps {
                if let name = app as? String {
                    result.append((name as NSString).lastPathComponent)
                } else if let dict = app as? [String: Any], let target = dict["target"] as? String {
                    // 带 target 的写法以 target 为最终名称，替换上一个源名称
                    if !result.isEmpty { result.removeLast() }
                    result.append((target as NSString).lastPathComponent)
                }
            }
        }
        return result
    }
}
