import Foundation
import SwiftData

/// 被关闭的登录项（关闭即从系统登录项移除，这里记录以便重新开启）
@Model
final class DisabledLoginItemEntity {
    #Unique<DisabledLoginItemEntity>([\.path])
    #Index<DisabledLoginItemEntity>([\.path], [\.disabledAt])

    /// 登录项应用路径
    var path: String
    /// 显示名称
    var name: String
    /// 关闭时间
    var disabledAt: Date

    init(path: String, name: String, disabledAt: Date = Date()) {
        self.path = path
        self.name = name
        self.disabledAt = disabledAt
    }
}
