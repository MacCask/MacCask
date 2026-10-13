import Foundation
import Observation

/// 残留文件模块视图模型
@Observable
@MainActor
final class LeftoversViewModel {
    /// 扫描到的全部残留分组（含已忽略）
    private(set) var groups: [LeftoverGroup] = []
    /// 是否正在扫描
    private(set) var isScanning = false
    /// 是否已加载过
    private(set) var hasLoaded = false
    /// 是否拥有完全磁盘访问权限
    private(set) var hasFullDiskAccess = true
    /// 是否正在删除
    private(set) var isTrashing = false
    /// 多选的分组
    var selection: Set<LeftoverGroup.ID> = [] {
        didSet {
            // 多选后继续展示最近加入选择的分组，不让详情变成空白汇总。
            if let added = selection.subtracting(oldValue).sorted().first { focusedGroupID = added }
            if let focusedGroupID, !selection.contains(focusedGroupID) { self.focusedGroupID = selection.sorted().first }
        }
    }
    private var focusedGroupID: LeftoverGroup.ID?

    /// 多选操作针对全部选中项，详情只展示当前聚焦的分组。
    var detailGroup: LeftoverGroup? {
        groups.first { $0.id == focusedGroupID } ?? selectedGroups.first
    }
    /// 显示已忽略的项
    var showIgnored = false
    /// 显示低可信度的项
    var showLowConfidence = true
    /// 搜索关键字
    var searchText = ""
    /// 提示信息
    var alertMessage: String?

    private let ignoredRepository = IgnoredLeftoverRepository()

    /// 筛选后按大小降序排列的分组
    var visibleGroups: [LeftoverGroup] {
        let keyword = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        return groups
            .filter { showIgnored || !$0.isIgnored }
            .filter { showLowConfidence || $0.confidence == .high }
            .filter { keyword.isEmpty || $0.identifier.lowercased().contains(keyword) }
            .sorted { $0.totalSize > $1.totalSize }
    }

    /// 未忽略的残留数量（侧边栏徽标）
    var activeCount: Int { groups.filter { !$0.isIgnored }.count }

    /// 当前选中的分组
    var selectedGroups: [LeftoverGroup] {
        groups.filter { selection.contains($0.id) }
    }

    /// 可见分组合计大小
    var visibleTotalSize: Int64 { visibleGroups.reduce(0) { $0 + $1.totalSize } }

    /// 首次进入时加载
    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        await refresh()
    }

    /// 重新扫描
    func refresh() async {
        guard !isScanning else { return }
        isScanning = true
        defer { isScanning = false; hasLoaded = true }
        hasFullDiskAccess = Platform.current.system.hasFullDiskAccess()
        let ids = await LeftoverScanner.collectInstalledIDs()
        var scanned = await LeftoverScanner.scan(index: InstalledIdentifierIndex(bundleIDs: ids))
        // 标记已忽略项（只查询本次扫描到的标识符）
        let ignored = ignoredRepository.ignoredIdentifiers(in: scanned.map(\.id))
        for index in scanned.indices {
            scanned[index].isIgnored = ignored.contains(scanned[index].id)
        }
        groups = scanned
        selection = selection.filter { id in groups.contains { $0.id == id } }
    }

    /// 忽略选中项
    func ignore(_ ids: Set<LeftoverGroup.ID>) {
        ignoredRepository.ignore(Array(ids))
        setIgnored(ids, true)
    }

    /// 取消忽略
    func unignore(_ ids: Set<LeftoverGroup.ID>) {
        ignoredRepository.unignore(Array(ids))
        setIgnored(ids, false)
    }

    /// 更新内存中的忽略状态
    private func setIgnored(_ ids: Set<LeftoverGroup.ID>, _ value: Bool) {
        for index in groups.indices where ids.contains(groups[index].id) {
            groups[index].isIgnored = value
        }
        if value && !showIgnored { selection.subtract(ids) }
    }

    /// 右键与底部批量操作共享确认内容，以待处理快照计算数量及大小。
    func trashConfirmationTitle(for ids: Set<LeftoverGroup.ID>) -> String {
        let targets = groups.filter { ids.contains($0.id) }
        return L10n.tr("将 {0} 项残留（{1}）移到废纸篓？", "\(targets.count)",
                       "\(ByteFormatter.string(targets.reduce(0) { $0 + $1.totalSize }))")
    }

    /// 将指定分组的全部文件移到废纸篓
    func moveToTrash(_ ids: Set<LeftoverGroup.ID>) {
        let targets = groups.filter { ids.contains($0.id) }
        let urls = targets.flatMap { $0.files.map(\.url) }
        guard !urls.isEmpty, !isTrashing else { return }
        isTrashing = true
        Task {
            let failures = await Platform.current.trasher.moveToTrash(urls)
            // 移除已删除的文件，文件全部删除的分组从列表移除
            for index in groups.indices.reversed() where ids.contains(groups[index].id) {
                groups[index].files.removeAll { failures[$0.url] == nil }
                if groups[index].files.isEmpty { groups.remove(at: index) }
            }
            selection = selection.filter { id in groups.contains { $0.id == id } }
            if !failures.isEmpty {
                let list = failures.keys.map(\.path).sorted().joined(separator: "\n")
                alertMessage = L10n.tr("以下 {0} 项未能移到废纸篓：\n{1}", "\(failures.count)", "\(list)")
            }
            isTrashing = false
        }
    }
}
