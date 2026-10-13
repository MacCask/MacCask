import AppKit

/// 从项目资源显式加载矢量模板，避免 SwiftUI 按名称查找 copy 资源时返回空图。
enum TemplateImageLoader {
    /// 设置逻辑尺寸和模板标志，由系统负责高分辨率栅格化与动态着色。
    static func load(name: String, size: NSSize) -> NSImage? {
        guard let url = AppResources.url(forResource: name, withExtension: "pdf"),
              let image = NSImage(contentsOf: url) else { return nil }
        image.size = size
        image.isTemplate = true
        return image
    }
}
