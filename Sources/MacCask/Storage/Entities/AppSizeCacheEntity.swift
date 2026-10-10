import Foundation
import SwiftData

/// 应用大小缓存：按「路径 + 修改时间」缓存 .app 占用大小
@Model
final class AppSizeCacheEntity {
    #Unique<AppSizeCacheEntity>([\.path])
    #Index<AppSizeCacheEntity>([\.path], [\.updatedAt])

    /// 应用路径
    var path: String
    /// 应用包修改时间，变化时缓存失效
    var modifiedAt: Date
    /// 占用大小（字节）
    var sizeBytes: Int64
    /// 缓存写入时间
    var updatedAt: Date

    init(path: String, modifiedAt: Date, sizeBytes: Int64, updatedAt: Date = Date()) {
        self.path = path
        self.modifiedAt = modifiedAt
        self.sizeBytes = sizeBytes
        self.updatedAt = updatedAt
    }
}
