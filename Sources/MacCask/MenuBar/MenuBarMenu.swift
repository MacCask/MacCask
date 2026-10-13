import SwiftUI

/// 菜单栏入口只保留打开主窗口和退出，避免重复主界面的管理功能。
struct MenuBarMenu: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("打开 MacCask") {
            openWindow(id: "main")
            Platform.current.system.activateApplication()
        }
        Divider()
        Button("退出 MacCask") {
            Platform.current.system.terminateApplication()
        }
        .keyboardShortcut("q")
    }
}

/// 单色矢量模板由系统按菜单栏背景与选中状态着色。
struct MenuBarIcon: View {
    private static let template = TemplateImageLoader.load(
        name: "MenuBarTemplate", size: NSSize(width: 18, height: 18)) ?? NSImage(size: NSSize(width: 18, height: 18))

    var body: some View {
        Image(nsImage: Self.template)
            .renderingMode(.template)
            .resizable()
            .frame(width: 18, height: 18)
            .accessibilityLabel("MacCask")
    }
}
