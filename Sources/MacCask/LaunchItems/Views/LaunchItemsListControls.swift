import SwiftUI

/// 启动项列表头仅展示总量与开启状态，具体开关留在条目旁。
struct LaunchItemsListHeader: View {
    let model: LaunchItemsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.tr("启动项")).font(.title2.weight(.semibold))
            Text(L10n.tr("{0} 个项目 · {1} 个已开启", "\(model.items.count)", "\(model.enabledCount)"))
                .font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16).background(.bar)
        .overlay(alignment: .bottom) { Divider() }
    }
}

/// 系统设置属于启动项辅助操作，固定放在列表底部。
struct LaunchItemsSettingsLink: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                Platform.current.system.openLoginItemsSettings()
            } label: {
                Label(L10n.tr("系统登录项设置"), systemImage: "arrow.up.right.square")
            }
            .buttonStyle(.link)
            Text(L10n.tr("管理“允许在后台”项目"))
                .font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12).background(.bar)
        .overlay(alignment: .top) { Divider() }
    }
}
