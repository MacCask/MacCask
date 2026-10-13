import SwiftUI

/// 仪表盘卡片容器：标题 + 可选副标题 + 内容
struct DashboardCard<Content: View, Accessory: View>: View {
    let title: String
    var subtitle: String? = nil
    @ViewBuilder var accessory: () -> Accessory
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline)
                    if let subtitle {
                        Text(subtitle).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                accessory()
            }
            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.primary.opacity(0.06)))
    }
}

extension DashboardCard where Accessory == EmptyView {
    init(title: String, subtitle: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.init(title: title, subtitle: subtitle, accessory: { EmptyView() }, content: content)
    }
}

/// 状态磁贴：图标 + 大数字 + 说明，点击跳转到对应模块
struct StatTile: View {
    let title: String
    let value: String
    let detail: String
    let symbol: String
    let tint: Color
    /// 需要关注时显示的提示（如「52 个可更新」）
    var badge: String? = nil
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: symbol)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 26, height: 26)
                        .background(tint.gradient, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                    Text(title).font(.callout.weight(.medium)).foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .opacity(isHovering ? 1 : 0)
                }
                Text(value)
                    .font(.system(size: 28, weight: .semibold, design: .rounded).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                VStack(alignment: .leading, spacing: 6) {
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, minHeight: 28, alignment: .topLeading)
                    HStack {
                        if let badge {
                            TagBadge(text: badge, style: .warning, symbol: "exclamationmark.circle.fill")
                        }
                        Spacer(minLength: 0)
                    }
                    // 状态标签独占一行，避免较长的英文说明被压缩；所有磁贴保持等高。
                    .frame(height: 18)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(isHovering ? tint.opacity(0.5) : Color.primary.opacity(0.06)))
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.15), value: isHovering)
    }
}

/// 图例项：色块 + 名称 + 数值
struct LegendItem: View {
    let color: Color
    let title: String
    let value: String
    var secondary: String? = nil
    var isDimmed = false

    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 10, height: 10)
            Text(title).font(.callout)
            Spacer(minLength: 8)
            Text(value).font(.callout.monospacedDigit())
            if let secondary {
                Text(secondary)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 44, alignment: .trailing)
            }
        }
        .opacity(isDimmed ? 0.4 : 1)
    }
}
