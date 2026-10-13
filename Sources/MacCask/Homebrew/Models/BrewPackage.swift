import Foundation

/// Homebrew 包类型
enum BrewPackageKind: String, CaseIterable, Identifiable, Sendable {
    case formula = "Formula"
    case cask = "Cask"

    var id: String { rawValue }

    /// 中文说明
    var title: String {
        switch self {
        case .formula: return L10n.tr("命令行工具")
        case .cask: return L10n.tr("图形应用")
        }
    }
}

/// 一个已安装的 Homebrew 包
struct BrewPackage: Identifiable, Hashable, Sendable {
    /// 唯一标识：类型 + 名称
    var id: String { "\(kind.rawValue):\(name)" }
    /// 包名（formula 的 name 或 cask 的 token）
    let name: String
    /// 类型
    let kind: BrewPackageKind
    /// 展示名称（cask 的 name 字段，formula 同 name）
    let displayName: String
    /// 描述
    let desc: String?
    /// 主页
    let homepage: URL?
    /// 来源 tap
    let tap: String?
    /// 当前安装版本
    let installedVersion: String
    /// 最新版本
    let latestVersion: String
    /// 是否可更新
    let isOutdated: Bool
    /// 是否被 pin（锁定版本）
    let isPinned: Bool
    /// 是否主动安装（false 表示仅作为依赖被安装）
    let installedOnRequest: Bool
    /// 安装时间
    let installedAt: Date?
    /// 本地保留的版本数（大于 1 说明有旧版本可清理）
    let keptVersionCount: Int
    /// cask 安装的 .app 文件名（如 "Visual Studio Code.app"）
    let appNames: [String]
    /// cask 是否自带自动更新
    let autoUpdates: Bool
}
