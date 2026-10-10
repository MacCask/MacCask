import AppKit

/// 应用代理：处理启动时的系统级设置
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// 启动完成后设为普通前台应用并激活窗口
    /// 通过 `swift run` 直接运行裸可执行文件时没有 Info.plist，系统会把进程当作后台程序（无 Dock 图标、窗口不前置）
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// 关闭最后一个窗口后退出应用
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
