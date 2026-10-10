import SwiftUI

/// 标签样式，颜色语义在全应用统一
enum TagStyle {
    case system, appStore, homebrew, outdated, warning, neutral, success

    /// 标签主色
    var color: Color {
        switch self {
        case .system: return .gray
        case .appStore: return .blue
        case .homebrew: return .orange
        case .outdated: return .green
        case .warning: return .yellow
        case .neutral: return .secondary
        case .success: return .teal
        }
    }
}

/// 胶囊形状的小标签
struct TagBadge: View {
    let text: String
    var style: TagStyle = .neutral
    var symbol: String? = nil

    var body: some View {
        HStack(spacing: 3) {
            if let symbol {
                Image(systemName: symbol).imageScale(.small)
            }
            Text(text)
        }
        .font(.caption2.weight(.semibold))
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .foregroundStyle(style.color)
        .background(style.color.opacity(0.14), in: Capsule())
        .fixedSize()
    }
}
