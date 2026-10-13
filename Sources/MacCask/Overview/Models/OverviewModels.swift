import SwiftUI

/// 磁盘占用分段（分段条的一段）
struct DiskSegment: Identifiable {
    let id: String
    /// 名称
    let title: String
    /// 占用大小（nil 表示仍在计算）
    let bytes: Int64?
    /// 颜色
    let color: Color
    /// 点击跳转的模块（nil 不跳转）
    var section: SidebarSection? = nil
    /// 读取不完整或尚未完成时，显示已知占用下限。
    var isComplete = true
}

/// 应用来源分类（环形图的一块）
struct AppSourceSlice: Identifiable {
    var id: String { title }
    let title: String
    let count: Int
    let color: Color
}

/// 应用活跃度分组（按上次使用时间）
struct ActivityBucket: Identifiable {
    var id: String { title }
    /// 分组名称，如「7 天内」
    let title: String
    /// 应用数量
    let count: Int
    /// 合计大小
    let bytes: Int64
    /// 是否属于长期未使用
    let isStale: Bool
    /// 是否为「未知」组（Spotlight 没有记录上次使用时间）
    var isUnknown = false
    /// 分组中所有应用的总占用是否已完整读取。
    var isComplete = true
}

/// 建议等级
enum InsightLevel {
    case info, warning, critical

    /// 等级图标
    var symbol: String {
        switch self {
        case .info: return "lightbulb"
        case .warning: return "exclamationmark.triangle.fill"
        case .critical: return "exclamationmark.octagon.fill"
        }
    }

    /// 等级颜色
    var color: Color {
        switch self {
        case .info: return ChartPalette.blue
        case .warning: return ChartPalette.warning
        case .critical: return ChartPalette.critical
        }
    }
}

/// 一条优化建议
struct Insight: Identifiable {
    var id: String { title }
    let level: InsightLevel
    let title: String
    let detail: String
    /// 点击跳转的模块
    let section: SidebarSection
}
