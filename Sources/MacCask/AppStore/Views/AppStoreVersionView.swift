import SwiftUI

/// 商店状态位于应用版本统计下方，更新入口与查询结果相邻。
struct AppStoreVersionView: View {
    let app: InstalledApp
    @State private var storeApp: StoreApp?
    @State private var isLoading = true
    @State private var failed = false
    private let updates = AppStoreUpdates.shared
    private var country: String { updates.country }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("App Store").font(.callout.weight(.medium))
                if isLoading {
                    Text(L10n.tr("正在查询商店版本…"))
                } else if let storeApp {
                    Text(L10n.tr("商店版本 {0}", storeApp.version))
                    if storeApp.requiresNewerSystem {
                        Text(L10n.tr("需要 macOS {0} 或更新版本", storeApp.minimumOsVersion ?? ""))
                    }
                } else {
                    Text(L10n.tr(failed ? "商店版本查询失败" : "当前地区未找到此应用"))
                }
                Text(L10n.tr("查询地区：{0}", country.uppercased()))
                    .foregroundStyle(.tertiary)
            }
            .font(.caption).foregroundStyle(.secondary)
            Spacer(minLength: 12)
            if isLoading {
                ProgressView().controlSize(.small)
            } else if let storeApp {
                Button(L10n.tr(hasUpdate(storeApp) && !storeApp.requiresNewerSystem ? "在 App Store 中更新" : "在 App Store 中查看")) {
                    Platform.current.system.openURL(storeApp.storeURL(country: country))
                }
                .buttonStyle(.bordered)
            } else if failed {
                Button(L10n.tr("重试")) { Task { await load() } }
                    .buttonStyle(.borderless)
            }
        }
        .padding(.bottom, 16)
        .overlay(alignment: .bottom) { Divider() }
        .contextMenu {
            Button(L10n.tr("重新查询商店版本")) { Task { await load(forceRefresh: true) } }
                .disabled(isLoading)
        }
        .task(id: app.bundleID) { await load() }
    }

    /// 只有明确高于本地版本时才将入口标为更新。
    private func hasUpdate(_ store: StoreApp) -> Bool {
        guard let local = app.version else { return false }
        return NumericVersion.compare(store.version, local) == .orderedDescending
    }

    /// 详情切换取消后不发布旧结果；失败可重试，不阻塞文件分析。
    @MainActor private func load(forceRefresh: Bool = false) async {
        isLoading = true
        failed = false
        storeApp = nil
        guard let id = app.bundleID else { isLoading = false; return }
        do {
            let result = try await updates.lookup(bundleID: id, forceRefresh: forceRefresh)
            guard !Task.isCancelled else { return }
            storeApp = result
        } catch {
            guard !Task.isCancelled else { return }
            failed = true
        }
        isLoading = false
    }
}
