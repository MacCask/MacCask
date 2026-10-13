import SwiftUI

/// 已发现更新时占用独立提示行，切换业务模块不影响提示，不抢占窗口焦点。
struct UpdateNoticeView: View {
    @ObservedObject var updater: MacAppUpdater

    var body: some View {
        if let version = updater.availableVersion {
            UpdateNoticeContent(version: version) { updater.checkForUpdates() }
        }
    }
}

/// 提示布局独立于更新服务，可使用虚构版本渲染，按钮只打开更新详情。
struct UpdateNoticeContent: View {
    let version: String
    let showUpdate: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.down.circle")
                .font(.title3).foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 3) {
                Text(L10n.tr("MacCask {0} 可更新", version)).font(.callout.weight(.medium))
                Text(L10n.tr("准备好时再下载安装。"))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 12)
            Button(L10n.tr("查看更新…"), action: showUpdate)
                .buttonStyle(.bordered)
        }
        .padding(.horizontal, 20).padding(.vertical, 10)
        .background(.bar)
        .overlay(alignment: .bottom) { Divider() }
    }
}
