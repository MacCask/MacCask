import Foundation
import SwiftData

/// 应用大小缓存仓储
@MainActor
struct SizeCacheRepository {
    private var context: ModelContext { DatabaseManager.shared.context }

    /// 批量查询指定路径的缓存（命中 path 唯一索引）
    func cachedEntries(for paths: [String]) -> [String: AppSizeCacheEntity] {
        guard !paths.isEmpty else { return [:] }
        let descriptor = FetchDescriptor<AppSizeCacheEntity>(predicate: #Predicate { paths.contains($0.path) })
        let entities = (try? context.fetch(descriptor)) ?? []
        return Dictionary(entities.map { ($0.path, $0) }, uniquingKeysWith: { first, _ in first })
    }

    /// 写入或更新一条缓存
    func upsert(path: String, modifiedAt: Date, sizeBytes: Int64) {
        var descriptor = FetchDescriptor<AppSizeCacheEntity>(predicate: #Predicate { $0.path == path })
        descriptor.fetchLimit = 1
        if let existing = try? context.fetch(descriptor).first {
            existing.modifiedAt = modifiedAt
            existing.sizeBytes = sizeBytes
            existing.updatedAt = Date()
        } else {
            context.insert(AppSizeCacheEntity(path: path, modifiedAt: modifiedAt, sizeBytes: sizeBytes))
        }
    }

    /// 提交改动
    func save() {
        DatabaseManager.shared.save()
    }
}
