import SwiftUI

/// 已安装应用内容列：应用列表
struct InstalledAppsListView: View {
    @Bindable var model: InstalledAppsViewModel

    var body: some View {
        Group {
            if model.isScanning && model.apps.isEmpty {
                LoadingView(text: L10n.tr("正在扫描应用…"))
            } else {
                List(selection: $model.selection) {
                    ForEach(model.visibleApps) { app in
                        AppRowView(app: app, size: model.totalSizes[app.id]?.bytes,
                                   isSizeComplete: model.totalSizes[app.id]?.isComplete ?? false).tag(app.id)
                    }
                }
                .overlay {
                    if model.visibleApps.isEmpty {
                        ContentUnavailableView.search
                    }
                }
                .safeAreaInset(edge: .top, spacing: 0) { filterBar }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    ListStatusBar(text: L10n.tr("{0} 个应用 · 共 {1}", "\(model.visibleApps.count)", "\(model.visibleTotalSizeText)"))
                }
            }
        }
        .navigationTitle(L10n.tr("应用程序"))
        .searchable(text: $model.searchText, prompt: L10n.tr("搜索名称或 Bundle ID"))
        .toolbar { toolbar }
        .task { await model.loadIfNeeded() }
    }

    /// 顶部分类筛选
    private var filterBar: some View {
        Picker(L10n.tr("分类"), selection: $model.filter) {
            ForEach(AppFilter.allCases) { filter in
                Text(filter.title).tag(filter)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    /// 工具栏：排序、刷新
    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItemGroup {
            Menu {
                Picker(L10n.tr("排序方式"), selection: $model.sortOrder) {
                    ForEach(AppSortOrder.allCases) { order in
                        Text(order.title).tag(order)
                    }
                }
                .pickerStyle(.inline)
            } label: {
                Label(L10n.tr("排序"), systemImage: "arrow.up.arrow.down")
            }
            .help(L10n.tr("排序方式"))

            Button {
                Task { await model.refresh() }
            } label: {
                Label(L10n.tr("刷新"), systemImage: "arrow.clockwise")
            }
            .disabled(model.isScanning)
            .help(L10n.tr("重新扫描应用"))
        }
    }
}

/// 应用列表行
struct AppRowView: View {
    let app: InstalledApp
    let size: Int64?
    var isSizeComplete = true

    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: BundleInfoReader.icon(for: app.id, size: 32))
                .resizable()
                .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 3) {
                Text(app.name).fontWeight(.medium).lineLimit(1)
                HStack(spacing: 4) {
                    AppTags(app: app)
                    if let version = app.version {
                        Text(version)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            Spacer(minLength: 8)
            Text(size.map { ByteFormatter.measured($0, isComplete: isSizeComplete) } ?? L10n.tr("计算中…"))
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
                .help(L10n.tr("总占用：应用包和关联数据"))
        }
        .padding(.vertical, 2)
        .contextMenu { FileContextMenu(urls: [app.url]) }
    }
}

/// 应用标签组：系统 / App Store / Homebrew
struct AppTags: View {
    let app: InstalledApp

    var body: some View {
        if app.isSystem { TagBadge(text: L10n.tr("系统"), style: .system, symbol: "apple.logo") }
        if app.isAppStore { TagBadge(text: "App Store", style: .appStore) }
        if app.isHomebrew { TagBadge(text: "Homebrew", style: .homebrew) }
    }
}
