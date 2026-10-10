import Foundation
import SwiftData

/// 数据库管理：创建并持有 SwiftData 容器
@MainActor
final class DatabaseManager {
    /// 全局单例
    static let shared = DatabaseManager()

    /// SwiftData 容器
    let container: ModelContainer

    /// 主线程上下文，所有仓储都在主线程使用
    var context: ModelContext { container.mainContext }

    private init() {
        let schema = Schema([AppSizeCacheEntity.self, IgnoredLeftoverEntity.self, DisabledLoginItemEntity.self])
        do {
            let config = ModelConfiguration(schema: schema, url: Self.storeURL())
            container = try ModelContainer(for: schema, configurations: config)
        } catch {
            // 数据库损坏或无法创建时退化为内存数据库，保证应用可用
            NSLog("MacCask 数据库打开失败，改用内存数据库：\(error)")
            let memory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            container = try! ModelContainer(for: schema, configurations: memory)
        }
    }

    /// 数据库文件路径：~/Library/Application Support/MacCask/MacCask.store
    private static func storeURL() -> URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MacCask", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("MacCask.store")
    }

    /// 保存上下文改动
    func save() {
        do {
            try context.save()
        } catch {
            NSLog("MacCask 数据库保存失败：\(error)")
        }
    }
}
