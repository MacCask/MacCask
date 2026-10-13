import SwiftUI

/// 残留文件内容列：多选列表
struct LeftoversListView: View {
    @Bindable var model: LeftoversViewModel
    @State private var pendingTrash: Set<LeftoverGroup.ID> = []

    var body: some View {
        Group {
            if model.isScanning && model.groups.isEmpty {
                LoadingView(text: L10n.tr("正在扫描残留文件…"))
            } else {
                List(selection: $model.selection) {
                    ForEach(model.visibleGroups) { group in
                        LeftoverRow(group: group).tag(group.id)
                    }
                }
                .contextMenu(forSelectionType: LeftoverGroup.ID.self) { ids in
                    contextMenu(for: ids)
                }
                .overlay {
                    if model.visibleGroups.isEmpty && !model.isScanning {
                        ContentUnavailableView(L10n.tr("没有发现残留文件"), systemImage: "sparkles",
                                               description: Text(L10n.tr("已卸载应用留下的文件会显示在这里")))
                    }
                }
                .safeAreaInset(edge: .top, spacing: 0) {
                    if !model.hasFullDiskAccess { FullDiskAccessBanner() }
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    ListStatusBar(text: L10n.tr("{0} 项残留 · 共 {1}", "\(model.visibleGroups.count)", "\(ByteFormatter.string(model.visibleTotalSize))"))
                }
            }
        }
        .navigationTitle(L10n.tr("残留文件"))
        .searchable(text: $model.searchText, prompt: L10n.tr("搜索标识符"))
        .toolbar { toolbar }
        .confirmationDialog(trashTitle, isPresented: Binding(get: { !pendingTrash.isEmpty }, set: { if !$0 { pendingTrash = [] } })) {
            Button(L10n.tr("移到废纸篓"), role: .destructive) { model.moveToTrash(pendingTrash) }
            Button(L10n.tr("取消"), role: .cancel) {}
        } message: {
            Text(L10n.tr("文件会被移到废纸篓，清倒废纸篓前仍可恢复。"))
        }
        .alert(L10n.tr("提示"), isPresented: Binding(get: { model.alertMessage != nil }, set: { if !$0 { model.alertMessage = nil } })) {
            Button(L10n.tr("好")) {}
        } message: {
            Text(model.alertMessage ?? "")
        }
        .task { await model.loadIfNeeded() }
    }

    /// 删除确认标题
    private var trashTitle: String {
        let targets = model.groups.filter { pendingTrash.contains($0.id) }
        let size = targets.reduce(0) { $0 + $1.totalSize }
        return L10n.tr("将 {0} 项残留（{1}）移到废纸篓？", "\(targets.count)", "\(ByteFormatter.string(size))")
    }

    /// 请求删除（弹出确认）
    private func requestTrash(_ ids: Set<LeftoverGroup.ID>) {
        pendingTrash = ids
    }

    /// 右键菜单
    @ViewBuilder
    private func contextMenu(for ids: Set<LeftoverGroup.ID>) -> some View {
        let targets = model.groups.filter { ids.contains($0.id) }
        if !targets.isEmpty {
            Button(L10n.tr("在访达中显示")) {
                Platform.current.system.revealInFinder(targets.flatMap { $0.files.map(\.url) })
            }
            Divider()
            if targets.allSatisfy(\.isIgnored) {
                Button(L10n.tr("取消忽略")) { model.unignore(ids) }
            } else {
                Button(L10n.tr("忽略")) { model.ignore(ids) }
            }
            Button(L10n.tr("移到废纸篓…"), role: .destructive) { requestTrash(ids) }
        }
    }

    /// 工具栏：筛选、移到废纸篓、刷新
    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItemGroup {
            Menu {
                Toggle(L10n.tr("显示低可信度项"), isOn: $model.showLowConfidence)
                Toggle(L10n.tr("显示已忽略项"), isOn: $model.showIgnored)
            } label: {
                Label(L10n.tr("筛选"), systemImage: "line.3.horizontal.decrease.circle")
            }
            .help(L10n.tr("筛选"))

            Button {
                requestTrash(model.selection)
            } label: {
                Label(L10n.tr("移到废纸篓"), systemImage: "trash")
            }
            .disabled(model.selection.isEmpty || model.isTrashing)
            .help(L10n.tr("将选中的残留移到废纸篓"))

            Button {
                Task { await model.refresh() }
            } label: {
                Label(L10n.tr("重新扫描"), systemImage: "arrow.clockwise")
            }
            .disabled(model.isScanning)
            .help(L10n.tr("重新扫描残留文件"))
        }
    }
}

/// 残留分组行
struct LeftoverRow: View {
    let group: LeftoverGroup

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: group.categories.first?.symbol ?? "questionmark.folder")
                .font(.system(size: 14))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background((group.confidence == .high ? Color.orange : Color.gray).gradient,
                            in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(group.displayName).fontWeight(.medium).lineLimit(1)
                    if group.confidence == .low {
                        TagBadge(text: L10n.tr("低可信度"), style: .warning)
                            .help(L10n.tr("同一开发商仍有应用安装，可能是共享数据"))
                    }
                    if group.isIgnored { TagBadge(text: L10n.tr("已忽略")) }
                }
                Text(L10n.tr("{0} · {1} 个位置", "\(group.identifier)", "\(group.files.count)"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .opacity(group.isIgnored ? 0.55 : 1)
            Spacer(minLength: 8)
            Text(ByteFormatter.string(group.totalSize))
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
