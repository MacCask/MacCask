import AppKit
import SwiftUI
import Sparkle

/// 隔离测试程序，仅操作当前测试进程的窗口和临时应用包。
@main
@MainActor
enum UpdateIntegrationHarness {
    static var delegate: HarnessDelegate!
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        app.appearance = NSAppearance(named: .aqua)
        delegate = HarnessDelegate()
        app.delegate = delegate
        app.run()
    }
}

/// 在自己的窗口中模拟用户点击，使用正式更新器与 Sparkle 标准安装流程。
@MainActor
final class HarnessDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow!
    private var root: URL { URL(fileURLWithPath: Bundle.main.object(forInfoDictionaryKey: "IntegrationTestRoot") as! String) }

    /// 记录测试状态，不访问正式应用数据。
    private func record(_ text: String) {
        let url = root.appendingPathComponent("events.log")
        let existing = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        try? (existing + text + "\n").write(to: url, atomically: true, encoding: .utf8)
    }

    /// 新版本启动即报告成功，旧版本触发后台检查及人工选择流程。
    func applicationDidFinishLaunching(_ notification: Notification) {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as! String
        record("LAUNCHED " + version)
        if version == "9000.0.1" {
            try? Data(version.utf8).write(to: root.appendingPathComponent("relaunched"))
            NSApp.terminate(nil)
            return
        }
        UserDefaults.standard.set(["en"], forKey: "AppleLanguages")
        window = NSWindow(contentRect: NSRect(x: -9000, y: -9000, width: 900, height: 150),
                          styleMask: [.titled], backing: .buffered, defer: false)
        window.title = "MacCask isolated update test"
        window.contentView = NSHostingView(rootView: UpdateNoticeView(updater: .shared).frame(width: 900, height: 100))
        window.orderFront(nil)
        let updater = MacAppUpdater.shared
        updater.integrationStartBackgroundCheck()
        Task { await run(updater) }
    }

    /// 递归查找当前测试窗口里的按钮，不使用跨进程辅助功能。
    private func buttons(_ view: NSView) -> [NSButton] {
        (view as? NSButton).map { [$0] } ?? view.subviews.flatMap(buttons)
    }

    /// 仅导出本测试进程的窗口内容，保留界面证据，不采集桌面。
    private func capture(_ view: NSView, name: String) {
        view.layoutSubtreeIfNeeded()
        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        if let data = bitmap.representation(using: .png, properties: [:]) {
            try? data.write(to: root.appendingPathComponent(name + ".png"))
        }
    }

    /// 等待页面提示，确认未下载，然后模拟用户打开详情并同意安装重启。
    private func run(_ updater: MacAppUpdater) async {
        for _ in 0..<150 {
            if updater.availableVersion != nil { break }
            try? await Task.sleep(for: .milliseconds(200))
        }
        let expected = Bundle.main.object(forInfoDictionaryKey: "IntegrationExpectedVersion") as? String ?? "9000.0.1"
        guard updater.availableVersion == expected else {
            record("FAIL no in-app notice"); NSApp.terminate(nil); return
        }
        let visible = NSApp.windows.filter { $0.isVisible && $0 !== window }
        guard visible.isEmpty else {
            record("FAIL unsolicited window: \(visible.map(\.title))"); NSApp.terminate(nil); return
        }
        // 停留两秒，供服务器确认未请求 DMG；用户尚未选择下载。
        capture(window.contentView!, name: "in-app-notice")
        record("NOTICE_WITHOUT_WINDOW")
        try? await Task.sleep(for: .seconds(2))
        record("USER_OPEN_UPDATE")
        updater.checkForUpdates()
        var clickedDownload = false
        var clickedInstall = false
        var lastButtons = ""
        for _ in 0..<450 {
            let all = NSApp.windows.filter { $0 !== window && $0.isVisible }
                .compactMap(\.contentView).flatMap(buttons)
            let visibleButtons = all.filter { !$0.isHiddenOrHasHiddenAncestor }
            let labels = visibleButtons.map(\.title).filter { !$0.isEmpty }.joined(separator: " | ")
            if labels != lastButtons { record("BUTTONS " + labels); lastButtons = labels }
            if !clickedDownload, let updateWindow = NSApp.windows.first(where: {
                $0 !== window && $0.isVisible && $0.contentView != nil
            }) { capture(updateWindow.contentView!, name: "sparkle-update-window") }
            if Bundle.main.object(forInfoDictionaryKey: "IntegrationScenario") as? String == "cancel",
               visibleButtons.contains(where: { $0.title == "Install Update" && $0.isEnabled }),
               let updateWindow = NSApp.windows.first(where: { $0 !== window && $0.isVisible }) {
                // Sparkle 2.10 将“稍后”交互放在窗口关闭动作中。
                record("USER_REMIND_LATER")
                updateWindow.performClose(nil)
                try? await Task.sleep(for: .seconds(1))
                guard updater.availableVersion == nil else {
                    record("FAIL stale update notice"); NSApp.terminate(nil); return
                }
                try? Data("cancelled".utf8).write(to: root.appendingPathComponent("cancelled"))
                record("CANCELLED_WITHOUT_INSTALL")
                NSApp.terminate(nil)
                return
            }
            if Bundle.main.object(forInfoDictionaryKey: "IntegrationScenario") as? String == "cancel" {
                try? await Task.sleep(for: .milliseconds(200))
                continue
            }
            if !clickedDownload, let button = visibleButtons.first(where: { $0.title == "Install Update" && $0.isEnabled }) {
                clickedDownload = true
                record("USER_INSTALL_UPDATE")
                button.performClick(nil)
            } else if clickedDownload && !clickedInstall,
                      let button = visibleButtons.first(where: { $0.title.contains("Relaunch") && $0.isEnabled }) {
                clickedInstall = true
                record("USER_INSTALL_RELAUNCH")
                button.performClick(nil)
            }
            try? await Task.sleep(for: .milliseconds(200))
        }
        record("FAIL timed out waiting for installation")
        NSApp.terminate(nil)
    }
}
