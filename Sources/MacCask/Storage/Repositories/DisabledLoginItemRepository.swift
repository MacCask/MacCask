import Foundation
import SwiftData

/// 已关闭登录项仓储
@MainActor
struct DisabledLoginItemRepository {
    private var context: ModelContext { DatabaseManager.shared.context }

    /// 读取全部已关闭的登录项（业务语义即全部记录），按关闭时间倒序，命中 disabledAt 索引
    func allDisabled() -> [DisabledLoginItemEntity] {
        var descriptor = FetchDescriptor<DisabledLoginItemEntity>(sortBy: [SortDescriptor(\.disabledAt, order: .reverse)])
        descriptor.fetchLimit = 500
        return (try? context.fetch(descriptor)) ?? []
    }

    /// 记录一个被关闭的登录项
    func markDisabled(path: String, name: String) {
        var descriptor = FetchDescriptor<DisabledLoginItemEntity>(predicate: #Predicate { $0.path == path })
        descriptor.fetchLimit = 1
        if let existing = try? context.fetch(descriptor).first {
            existing.name = name
            existing.disabledAt = Date()
        } else {
            context.insert(DisabledLoginItemEntity(path: path, name: name))
        }
        DatabaseManager.shared.save()
    }

    /// 删除记录（重新开启后调用），命中 path 唯一索引
    func remove(path: String) {
        var descriptor = FetchDescriptor<DisabledLoginItemEntity>(predicate: #Predicate { $0.path == path })
        descriptor.fetchLimit = 1
        if let existing = try? context.fetch(descriptor).first {
            context.delete(existing)
            DatabaseManager.shared.save()
        }
    }
}
