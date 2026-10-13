import SwiftUI

/// 应用入口
@main
struct MacCaskApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var state = AppState()
    @AppStorage("showsMenuBarIcon") private var showsMenuBarIcon = true

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView()
                .environment(state)
                .frame(minWidth: 980, minHeight: 600)
        }
        .defaultSize(width: 1240, height: 780)
        .windowToolbarStyle(.unified)
        .commands {
            // 去掉「新建窗口」，本应用只需要单窗口
            CommandGroup(replacing: .newItem) {}
            CommandMenu("视图切换") {
                Toggle("显示菜单栏图标", isOn: $showsMenuBarIcon)
                Divider()
                ForEach(Array(SidebarSection.allCases.enumerated()), id: \.element) { index, section in
                    Button(section.title) { state.section = section }
                        .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
                }
                Divider()
                Button("刷新") { Task { await state.refreshCurrentSection() } }
                    .keyboardShortcut("r", modifiers: .command)
            }
        }
        MenuBarExtra(isInserted: $showsMenuBarIcon) {
            MenuBarMenu()
        } label: {
            MenuBarIcon()
        }
        .menuBarExtraStyle(.menu)
    }
}

