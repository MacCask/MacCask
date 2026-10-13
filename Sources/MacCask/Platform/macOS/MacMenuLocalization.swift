import AppKit

/// 本地化系统生成的菜单，保留原有 action、图标、快捷键与响应链。
@MainActor
enum MacMenuLocalization {
    /// 根据稳定的系统动作或标准菜单标题更新文本，重复调用不会新增菜单项。
    static func update(_ menu: NSMenu, language: AppLanguage) {
        let chinese = language == .simplifiedChinese
        let actions: [String: (String, String)] = [
            "orderFrontStandardAboutPanel:": ("关于 MacCask", "About MacCask"),
            "hide:": ("隐藏 MacCask", "Hide MacCask"),
            "hideOtherApplications:": ("隐藏其他", "Hide Others"),
            "unhideAllApplications:": ("全部显示", "Show All"),
            "terminate:": ("退出 MacCask", "Quit MacCask"),
            "undo:": ("撤销", "Undo"), "redo:": ("重做", "Redo"),
            "cut:": ("剪切", "Cut"), "copy:": ("拷贝", "Copy"),
            "paste:": ("粘贴", "Paste"), "selectAll:": ("全选", "Select All"),
            "performClose:": ("关闭窗口", "Close Window"),
            "performMiniaturize:": ("最小化", "Minimize"),
            "performZoom:": ("缩放", "Zoom"),
            "arrangeInFront:": ("前置全部窗口", "Bring All to Front")
        ]
        let titles: [(String, String)] = [
            ("关于 MacCask", "About MacCask"), ("设置…", "Settings…"),
            ("服务", "Services"), ("文件", "File"), ("编辑", "Edit"),
            ("显示", "View"), ("窗口", "Window"), ("帮助", "Help"),
            ("隐藏 MacCask", "Hide MacCask"), ("隐藏其他", "Hide Others"),
            ("全部显示", "Show All"), ("退出 MacCask", "Quit MacCask"),
            ("进入全屏幕", "Enter Full Screen"), ("退出全屏幕", "Exit Full Screen")
        ]
        for item in menu.items {
            let action = item.action.map(NSStringFromSelector) ?? ""
            let pair: (String, String)?
            if item.keyEquivalent == ",", item.keyEquivalentModifierMask.contains(.command) {
                pair = ("设置…", "Settings…")
            } else {
                pair = actions[action] ?? titles.first { item.title == $0.0 || item.title == $0.1 }
            }
            if let pair { item.title = chinese ? pair.0 : pair.1 }
            // 服务提供者自己的命令由 macOS 本地化，不改写其他应用提供的标题。
            if let submenu = item.submenu, submenu !== NSApp.servicesMenu {
                update(submenu, language: language)
            }
        }
    }
}
