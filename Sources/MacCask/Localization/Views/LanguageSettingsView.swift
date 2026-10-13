import SwiftUI

/// 使用标准 macOS 设置窗口承载语言选择，主界面无需新增按钮。
struct LanguageSettingsView: View {
    @ObservedObject var updater: MacAppUpdater
    @AppStorage(AppLanguage.preferenceKey) private var preference = AppLanguage.system.rawValue

    var body: some View {
        Form {
            Picker(L10n.tr("语言"), selection: $preference) {
                ForEach(AppLanguage.allCases) { language in
                    Text(language.title).tag(language.rawValue)
                }
            }
            Text(L10n.tr("语言更改立即生效。"))
                .font(.caption).foregroundStyle(.secondary)
            UpdateSettingsView(updater: updater)
        }
        .formStyle(.grouped)
        .padding(12)
        .frame(width: 420, height: 280)
        .environment(\.locale, L10n.locale)
    }
}
