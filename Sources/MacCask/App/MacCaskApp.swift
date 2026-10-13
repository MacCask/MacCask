import SwiftUI

/// 应用入口
@main
struct MacCaskApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var state = AppState()
    @AppStorage("showsMenuBarIcon") private var showsMenuBarIcon = true
    @AppStorage(AppLanguage.preferenceKey) private var languagePreference = AppLanguage.system.rawValue

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView()
                .environment(state)
                .environment(\.locale, L10n.locale)
                // 重建展示视图以刷新动态文本，全局业务状态与任务继续保留。
                .id(languagePreference)
                .frame(minWidth: 980, minHeight: 600)
        }
        .defaultSize(width: 1240, height: 780)
        .windowToolbarStyle(.unified)
        .commands {
            // 去掉「新建窗口」，本应用只需要单窗口
            CommandGroup(replacing: .newItem) {}
            CommandGroup(replacing: .appSettings) {
                SettingsLink { Text(L10n.tr("设置…")) }
                    .keyboardShortcut(",", modifiers: .command)
            }
            CommandMenu(L10n.tr("视图切换")) {
                Toggle(L10n.tr("显示菜单栏图标"), isOn: $showsMenuBarIcon)
                Divider()
                ForEach(Array(SidebarSection.allCases.enumerated()), id: \.element) { index, section in
                    Button(section.title) { state.section = section }
                        .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
                }
                Divider()
                Button(L10n.tr("刷新")) { Task { await state.refreshCurrentSection() } }
                    .keyboardShortcut("r", modifiers: .command)
            }
        }
        MenuBarExtra(isInserted: $showsMenuBarIcon) {
            MenuBarMenu()
                .environment(\.locale, L10n.locale)
                .id(languagePreference)
        } label: {
            MenuBarIcon()
        }
        .menuBarExtraStyle(.menu)
        Settings {
            LanguageSettingsView()
        }
    }
}

