import SwiftUI

/// 导航底部左侧保留清理说明，右侧固定外观切换按钮。
struct SidebarFooter: View {
    var body: some View {
        HStack(spacing: 8) {
            Label(L10n.tr("文件均移到废纸篓，可恢复"), systemImage: "arrow.uturn.backward.circle")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Spacer(minLength: 0)
            AppearanceToggle()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
