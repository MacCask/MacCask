import Foundation
import Observation

/// 启动项模块视图模型
@Observable
@MainActor
final class LaunchItemsViewModel {
    /// 全部启动项
    private(set) var items: [LaunchItem] = []
    /// 是否正在加载
    private(set) var isLoading = false
    /// 是否已加载过
    private(set) var hasLoaded = false
    /// 登录项读取失败的提示
    private(set) var loginItemError: String?
    /// 正在切换状态的项
    private(set) var togglingIDs: Set<LaunchItem.ID> = []
    /// 搜索关键字
    var searchText = ""
    /// 当前选中项
    var selection: LaunchItem.ID?
    /// 错误提示
    var alertMessage: String?

    private let disabledRepository = DisabledLoginItemRepository()

    /// 当前选中项
    var selectedItem: LaunchItem? {
        guard let selection else { return nil }
        return items.first { $0.id == selection }
    }

    /// 已启用数量（侧边栏徽标）
    var enabledCount: Int { items.filter(\.isEnabled).count }

    /// 某来源下经过搜索过滤的启动项
    func items(in source: LaunchItemSource) -> [LaunchItem] {
        let keyword = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        return items
            .filter { $0.source == source }
            .filter { keyword.isEmpty || $0.displayName.lowercased().contains(keyword) || $0.label.lowercased().contains(keyword) }
            .sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
    }

    /// 首次进入时加载
    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        await refresh()
    }

    /// 重新扫描全部启动项
    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false; hasLoaded = true }
        async let launchd = LaunchItemScanner.scanLaunchdItems()
        let loginItems = await loadLoginItems()
        items = loginItems + (await launchd)
        if let selection, !items.contains(where: { $0.id == selection }) {
            self.selection = nil
        }
    }

    /// 读取登录项，并合并数据库中记录的已关闭登录项
    private func loadLoginItems() async -> [LaunchItem] {
        var result: [LaunchItem] = []
        switch await Platform.current.loginItems.listLoginItems() {
        case .success(let list):
            loginItemError = nil
            result = list.map { LaunchItemScanner.makeLoginItem(name: $0.name, path: $0.path, enabled: true) }
        case .failure(let error):
            loginItemError = error.localizedDescription
        }
        let activePaths = Set(result.compactMap(\.program))
        for disabled in disabledRepository.allDisabled() where !activePaths.contains(disabled.path) {
            // 应用已被删除的记录不再展示
            guard FileManager.default.fileExists(atPath: disabled.path) else { continue }
            result.append(LaunchItemScanner.makeLoginItem(name: disabled.name, path: disabled.path, enabled: false))
        }
        return result
    }

    /// 切换启用状态
    func setEnabled(_ item: LaunchItem, _ enabled: Bool) {
        guard item.isEnabled != enabled, !togglingIDs.contains(item.id) else { return }
        togglingIDs.insert(item.id)
        Task {
            defer { togglingIDs.remove(item.id) }
            let result: CommandResult
            if item.source == .loginItem {
                result = await toggleLoginItem(item, enabled)
            } else {
                result = await LaunchItemController.setEnabled(item, enabled: enabled)
            }
            if result.succeeded {
                if let index = items.firstIndex(where: { $0.id == item.id }) {
                    items[index].isEnabled = enabled
                }
            } else {
                alertMessage = L10n.tr("无法{0}「{1}」：\n{2}", "\(enabled ? L10n.tr("开启") : L10n.tr("关闭"))", "\(item.displayName)", "\(result.output.trimmingCharacters(in: .whitespacesAndNewlines))")
            }
        }
    }

    /// 登录项开关：关闭即移除并记录，开启即重新添加并删除记录
    private func toggleLoginItem(_ item: LaunchItem, _ enabled: Bool) async -> CommandResult {
        guard let path = item.program else { return .failure(L10n.tr("缺少应用路径")) }
        if enabled {
            let result = await Platform.current.loginItems.addLoginItem(path: path)
            if result.succeeded { disabledRepository.remove(path: path) }
            return result
        } else {
            let result = await Platform.current.loginItems.removeLoginItem(name: item.label)
            if result.succeeded { disabledRepository.markDisabled(path: path, name: item.label) }
            return result
        }
    }
}
