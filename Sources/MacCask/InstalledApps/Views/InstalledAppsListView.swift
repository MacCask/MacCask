import SwiftUI

/// 已安装应用内容列：应用列表
struct InstalledAppsListView: View {
    @Bindable var model: InstalledAppsViewModel
    private let storeUpdates = AppStoreUpdates.shared

    var body: some View {
        Group {
            if model.isScanning && model.apps.isEmpty {
                LoadingView(text: L10n.tr("正在扫描应用…"))
            } else {
                List(selection: $model.selection) {
                    ForEach(model.visibleApps) { app in
                        AppRowView(app: app, size: model.totalSizes[app.id]?.bytes,
                                   isSizeComplete: model.totalSizes[app.id]?.isComplete ?? false,
                                   isUpdating: model.updatingAppIDs.contains(app.id),
                                   storeUpdateVersion: storeUpdates.update(for: app)?.version).tag(app.id)
                    }
                }
                .overlay {
                    if model.visibleApps.isEmpty {
                        ContentUnavailableView.search
                    }
                }
                .safeAreaInset(edge: .top, spacing: 0) { InstalledAppsListHeader(model: model) }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    ListStatusBar(text: L10n.tr("{0} 个应用 · 共 {1}", "\(model.visibleApps.count)", "\(model.visibleTotalSizeText)"))
                }
            }
        }
        .navigationTitle(L10n.tr("应用程序"))
        .searchable(text: $model.searchText, prompt: L10n.tr("搜索名称或 Bundle ID"))
        .task { await model.loadIfNeeded() }
        .task(id: model.apps) { await storeUpdates.refresh(model.apps) }
    }

}

/// 应用列表行
struct AppRowView: View {
    let app: InstalledApp
    let size: Int64?
    var isSizeComplete = true
    var isUpdating = false
    var storeUpdateVersion: String?

    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: BundleInfoReader.icon(for: app.id, size: 32))
                .resizable()
                .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(app.name).fontWeight(.medium).lineLimit(1)
                    if let storeUpdateVersion {
                        TagBadge(text: L10n.tr("可更新"), style: .outdated, symbol: "arrow.up")
                            .help(L10n.tr("商店版本 {0}", storeUpdateVersion))
                    }
                }
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
            if isUpdating {
                ProgressView().controlSize(.mini)
                    .accessibilityLabel(L10n.tr("正在计算应用大小…"))
            }
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
