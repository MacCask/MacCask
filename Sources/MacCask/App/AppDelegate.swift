import AppKit

/// 应用代理：处理启动时的系统级设置
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// 启动完成后设为普通前台应用并激活窗口
    /// 通过 `swift run` 直接运行裸可执行文件时没有 Info.plist，系统会把进程当作后台程序（无 Dock 图标、窗口不前置）
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        // 裸可执行文件使用 SwiftPM 资源；正式 .app 保留系统动态外观。
        if Bundle.main.bundleURL.pathExtension != "app",
           let iconURL = AppResources.url(forResource: "AppIcon", withExtension: "icns") {
            Platform.current.system.setApplicationIcon(from: iconURL)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    /// 菜单栏入口开启时允许关闭窗口后继续运行；隐藏入口时保留原有退出行为。
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        !(UserDefaults.standard.object(forKey: "showsMenuBarIcon") as? Bool ?? true)
    }
}
