import Foundation
import SwiftData

/// 用户选择忽略的残留项
@Model
final class IgnoredLeftoverEntity {
    #Unique<IgnoredLeftoverEntity>([\.identifier])
    #Index<IgnoredLeftoverEntity>([\.identifier], [\.createdAt])

    /// 残留项标识（通常为 bundle id）
    var identifier: String
    /// 忽略时间
    var createdAt: Date

    init(identifier: String, createdAt: Date = Date()) {
        self.identifier = identifier
        self.createdAt = createdAt
    }
}
