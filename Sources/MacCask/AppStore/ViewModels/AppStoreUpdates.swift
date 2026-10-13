import Foundation
import Observation

/// 列表与详情共享商店结果，详情重新查询后列表标记同步更新。
@Observable
@MainActor
final class AppStoreUpdates {
    static let shared = AppStoreUpdates()
    let country = (Locale.current.region?.identifier ?? "US").lowercased()
    private(set) var apps: [String: StoreApp] = [:]
    private let fetch: @Sendable (String, String, Bool) async throws -> StoreApp?

    /// 测试可注入目录响应，正式实现复用公共查询服务。
    init(fetch: @escaping @Sendable (String, String, Bool) async throws -> StoreApp? = { id, country, force in
        try await AppStoreLookup.shared.lookup(bundleID: id, country: country, forceRefresh: force)
    }) {
        self.fetch = fetch
    }

    /// 顺序查询商店应用，复用服务缓存和限速；列表离开后停止安排新请求。
    func refresh(_ installed: [InstalledApp]) async {
        var checked = Set<String>()
        for app in installed where app.isAppStore {
            guard !Task.isCancelled else { return }
            guard let id = app.bundleID, checked.insert(id).inserted else { continue }
            _ = try? await lookup(bundleID: id)
        }
    }

    /// 统一发布查询结果；空结果或失败不保留过期的更新标记。
    func lookup(bundleID: String, forceRefresh: Bool = false) async throws -> StoreApp? {
        do {
            let result = try await fetch(bundleID, country, forceRefresh)
            apps[bundleID] = result
            return result
        } catch {
            apps[bundleID] = nil
            throw error
        }
    }

    /// 必须为商店来源且版本明确更高、系统兼容时才显示可更新。
    func update(for app: InstalledApp) -> StoreApp? {
        guard app.isAppStore, let id = app.bundleID, let local = app.version,
              let store = apps[id], !store.requiresNewerSystem,
              NumericVersion.compare(store.version, local) == .orderedDescending else { return nil }
        return store
    }
}
