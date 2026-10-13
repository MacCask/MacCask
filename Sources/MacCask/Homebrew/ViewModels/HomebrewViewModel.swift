import Foundation
import Observation

/// Homebrew 模块视图模型
@Observable
@MainActor
final class HomebrewViewModel {
    /// 全部已安装包
    private(set) var packages: [BrewPackage] = []
    /// 是否正在加载
    private(set) var isLoading = false
    /// 是否已加载过
    private(set) var hasLoaded = false
    /// 加载错误
    private(set) var errorMessage: String?
    /// 当前查看的包类型
    var kind: BrewPackageKind = .formula
    /// 仅显示可更新
    var onlyOutdated = false
    /// 仅显示主动安装（隐藏依赖）
    var hideDependencies = false
    /// 搜索关键字
    var searchText = ""
    /// 当前选中的包
    var selection: BrewPackage.ID?
    /// 安装目录占用大小缓存
    private(set) var sizes: [BrewPackage.ID: Int64] = [:]
    /// 当前执行中的命令会话（用于弹出日志面板）
    var activeSession: CommandSession?

    private let service = BrewService.shared

    /// 是否安装了 Homebrew
    var isBrewAvailable: Bool { service.isAvailable }

    /// 可更新数量（侧边栏徽标）
    var outdatedCount: Int { packages.filter(\.isOutdated).count }

    /// 当前类型下可更新的包
    var outdatedPackages: [BrewPackage] { packages.filter { $0.kind == kind && $0.isOutdated } }

    /// 当前选中的包
    var selectedPackage: BrewPackage? {
        guard let selection else { return nil }
        return packages.first { $0.id == selection }
    }

    /// 经过类型、筛选、搜索后的列表；可更新的排在前面
    var visiblePackages: [BrewPackage] {
        let keyword = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        return packages
            .filter { $0.kind == kind }
            .filter { !onlyOutdated || $0.isOutdated }
            .filter { !hideDependencies || $0.installedOnRequest }
            .filter {
                keyword.isEmpty
                    || $0.name.lowercased().contains(keyword)
                    || $0.displayName.lowercased().contains(keyword)
                    || ($0.desc?.lowercased().contains(keyword) ?? false)
            }
            .sorted {
                if $0.isOutdated != $1.isOutdated { return $0.isOutdated }
                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
    }

    /// 某类型的数量
    func count(of kind: BrewPackageKind) -> Int {
        packages.filter { $0.kind == kind }.count
    }

    /// 首次进入时加载
    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        await refresh(force: false)
    }

    /// 重新读取已安装包
    func refresh(force: Bool = true) async {
        guard isBrewAvailable, !isLoading else { return }
        isLoading = true
        defer { isLoading = false; hasLoaded = true }
        do {
            packages = try await service.installedPackages(forceRefresh: force)
            errorMessage = nil
            // 选中项已不存在时清空
            if let selection, !packages.contains(where: { $0.id == selection }) {
                self.selection = nil
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 计算选中包的安装目录大小
    func loadSize(for package: BrewPackage) async {
        guard sizes[package.id] == nil, let dir = await service.installDirectory(of: package) else { return }
        sizes[package.id] = await FileSizeCalculator.allocatedSizeInBackground(of: dir)
    }

    /// 包的安装目录
    func installDirectory(of package: BrewPackage) async -> URL? {
        await service.installDirectory(of: package)
    }

    /// 升级单个包
    func upgrade(_ package: BrewPackage) {
        perform(title: L10n.tr("升级 {0}", "\(package.name)")) { [service] output in
            await service.upgrade([package], output: output)
        }
    }

    /// 升级当前类型下所有可更新的包
    func upgradeAll() {
        let targets = outdatedPackages.filter { !$0.isPinned }
        guard !targets.isEmpty else { return }
        perform(title: L10n.tr("全部升级（{0} 个）", "\(targets.count)")) { [service] output in
            await service.upgrade(targets, output: output)
        }
    }

    /// 卸载包
    func uninstall(_ package: BrewPackage, zap: Bool) {
        perform(title: L10n.tr("卸载 {0}", "\(package.name)")) { [service] output in
            await service.uninstall(package, zap: zap, output: output)
        }
    }

    /// 更新 Homebrew 软件源
    func updateBrew() {
        perform(title: L10n.tr("更新 Homebrew")) { [service] output in
            await service.update(output: output)
        }
    }

    /// 清理旧版本
    func cleanup() {
        perform(title: L10n.tr("清理旧版本与缓存")) { [service] output in
            await service.cleanup(output: output)
        }
    }

    /// 执行命令：弹出日志面板，结束后刷新列表并清除大小缓存
    private func perform(title: String, _ action: @escaping @Sendable (@escaping @Sendable (String) -> Void) async -> CommandResult) {
        guard activeSession?.isRunning != true else { return }
        let session = CommandSession(title: title)
        activeSession = session
        Task {
            let result = await action(session.outputHandler())
            session.finish(succeeded: result.succeeded)
            sizes.removeAll()
            await refresh(force: true)
        }
    }
}
