import SwiftUI

/// 导航底部只保留文件删除方式提示，操作入口放在对应模块行内。
struct SidebarFooter: View {
    var body: some View {
        Label(L10n.tr("文件均移到废纸篓，可恢复"), systemImage: "arrow.uturn.backward.circle")
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
