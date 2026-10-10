import Foundation
import SwiftData

/// 已忽略残留项仓储
@MainActor
struct IgnoredLeftoverRepository {
    private var context: ModelContext { DatabaseManager.shared.context }

    /// 在给定标识符中查询哪些已被忽略（命中 identifier 唯一索引）
    func ignoredIdentifiers(in identifiers: [String]) -> Set<String> {
        guard !identifiers.isEmpty else { return [] }
        let descriptor = FetchDescriptor<IgnoredLeftoverEntity>(predicate: #Predicate { identifiers.contains($0.identifier) })
        let entities = (try? context.fetch(descriptor)) ?? []
        return Set(entities.map(\.identifier))
    }

    /// 忽略一组残留项
    func ignore(_ identifiers: [String]) {
        let existing = ignoredIdentifiers(in: identifiers)
        for id in identifiers where !existing.contains(id) {
            context.insert(IgnoredLeftoverEntity(identifier: id))
        }
        DatabaseManager.shared.save()
    }

    /// 取消忽略一组残留项
    func unignore(_ identifiers: [String]) {
        guard !identifiers.isEmpty else { return }
        let descriptor = FetchDescriptor<IgnoredLeftoverEntity>(predicate: #Predicate { identifiers.contains($0.identifier) })
        for entity in (try? context.fetch(descriptor)) ?? [] {
            context.delete(entity)
        }
        DatabaseManager.shared.save()
    }
}
