import SwiftUI

/// 更新设置放在标准设置窗口，自动检查开关直接绑定更新器偏好。
struct UpdateSettingsView: View {
    @ObservedObject var updater: MacAppUpdater
    var body: some View {
        Section(L10n.tr("软件更新")) {
            Toggle(L10n.tr("自动检查更新"), isOn: $updater.automaticallyChecksForUpdates)
            Button(L10n.tr("检查更新…")) { updater.checkForUpdates() }
                .disabled(!updater.canCheckForUpdates)
        }
    }
}
