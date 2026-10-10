import Foundation

/// Homebrew 相关错误
enum BrewError: LocalizedError {
    case notInstalled
    case invalidOutput
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case .notInstalled: return "未检测到 Homebrew"
        case .invalidOutput: return "无法解析 Homebrew 输出"
        case .commandFailed(let message): return message
        }
    }
}

/// Homebrew 服务：定位 brew、读取已安装包、执行升级/卸载等命令
/// 使用 actor 缓存最近一次的包列表，供多个模块共享，避免重复调用 brew
actor BrewService {
    /// 全局单例
    static let shared = BrewService()

    private var cachedPackages: [BrewPackage]?
    private var cachedPrefix: String?
    private var runner: any CommandRunning { Platform.current.commandRunner }

    /// brew 运行时使用的环境变量：关闭自动更新、颜色和提示，加快速度并方便解析
    private let brewEnvironment = [
        "HOMEBREW_NO_AUTO_UPDATE": "1",
        "HOMEBREW_NO_ENV_HINTS": "1",
        "HOMEBREW_NO_COLOR": "1",
        "HOMEBREW_NO_INSTALL_CLEANUP": "1"
    ]

    /// brew 可执行文件路径（Apple Silicon 与 Intel 的默认位置）
    nonisolated var brewPath: String? {
        ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"].first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    /// 是否已安装 Homebrew
    nonisolated var isAvailable: Bool { brewPath != nil }

    /// 读取全部已安装包；默认使用缓存，forceRefresh 时重新读取
    func installedPackages(forceRefresh: Bool = false) async throws -> [BrewPackage] {
        if !forceRefresh, let cachedPackages { return cachedPackages }
        guard let brew = brewPath else { throw BrewError.notInstalled }
        let result = await runner.run(brew, arguments: ["info", "--json=v2", "--installed"], environment: brewEnvironment, onOutput: nil)
        guard result.succeeded else { throw BrewError.commandFailed(result.output) }
        // 输出可能夹带警告文本，截取第一个「{」开始的 JSON 部分
        let json = result.output.firstIndex(of: "{").map { String(result.output[$0...]) } ?? result.output
        let packages = try BrewJSONParser.parse(Data(json.utf8))
        cachedPackages = packages
        return packages
    }

    /// cask 安装的 app 文件名 → cask token 的映射（供已安装应用模块打 Homebrew 标签）
    func caskAppMap() async -> [String: String] {
        guard let packages = try? await installedPackages() else { return [:] }
        var map: [String: String] = [:]
        for pkg in packages where pkg.kind == .cask {
            pkg.appNames.forEach { map[$0] = pkg.name }
        }
        return map
    }

    /// Homebrew 安装前缀（如 /opt/homebrew）
    func prefix() async -> String? {
        if let cachedPrefix { return cachedPrefix }
        guard let brew = brewPath else { return nil }
        let result = await runner.run(brew, arguments: ["--prefix"], environment: brewEnvironment, onOutput: nil)
        guard result.succeeded else { return nil }
        cachedPrefix = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        return cachedPrefix
    }

    /// 包在本地的安装目录（Cellar 或 Caskroom）
    func installDirectory(of package: BrewPackage) async -> URL? {
        guard let prefix = await prefix() else { return nil }
        let sub = package.kind == .formula ? "Cellar" : "Caskroom"
        return URL(fileURLWithPath: prefix).appendingPathComponent(sub).appendingPathComponent(package.name)
    }

    /// 升级指定包；names 为空时升级全部可更新的包
    func upgrade(_ packages: [BrewPackage], output: @escaping @Sendable (String) -> Void) async -> CommandResult {
        var args = ["upgrade"]
        let formulae = packages.filter { $0.kind == .formula }.map(\.name)
        let casks = packages.filter { $0.kind == .cask }.map(\.name)
        // brew upgrade 不允许在一次调用中混合 --formula 与 --cask 的指定包，分两次执行
        if !formulae.isEmpty && !casks.isEmpty {
            let first = await run(args + ["--formula"] + formulae, output: output)
            let second = await run(args + ["--cask"] + casks, output: output)
            return CommandResult(exitCode: first.succeeded && second.succeeded ? 0 : 1, output: first.output + second.output)
        }
        if !formulae.isEmpty { args += ["--formula"] + formulae }
        if !casks.isEmpty { args += ["--cask"] + casks }
        return await run(args, output: output)
    }

    /// 卸载包；zap 为 true 时（仅 cask）同时清除应用数据
    func uninstall(_ package: BrewPackage, zap: Bool, output: @escaping @Sendable (String) -> Void) async -> CommandResult {
        var args = ["uninstall", package.kind == .formula ? "--formula" : "--cask"]
        if zap && package.kind == .cask { args.append("--zap") }
        args.append(package.name)
        return await run(args, output: output)
    }

    /// 按 cask token 卸载（供已安装应用模块使用）
    func uninstallCask(token: String, output: @escaping @Sendable (String) -> Void) async -> CommandResult {
        await run(["uninstall", "--cask", token], output: output)
    }

    /// 更新 Homebrew 自身及软件源
    func update(output: @escaping @Sendable (String) -> Void) async -> CommandResult {
        await run(["update"], output: output)
    }

    /// 清理旧版本与下载缓存
    func cleanup(output: @escaping @Sendable (String) -> Void) async -> CommandResult {
        await run(["cleanup"], output: output)
    }

    /// 执行 brew 子命令并输出日志；执行后使缓存失效
    private func run(_ args: [String], output: @escaping @Sendable (String) -> Void) async -> CommandResult {
        guard let brew = brewPath else { return .failure(BrewError.notInstalled.localizedDescription) }
        output("$ brew \(args.joined(separator: " "))\n")
        let result = await runner.run(brew, arguments: args, environment: brewEnvironment, onOutput: output)
        cachedPackages = nil
        return result
    }
}
