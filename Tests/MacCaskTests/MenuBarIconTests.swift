import AppKit
import SwiftUI
import XCTest
@testable import MacCask

/// 检查菜单栏矢量资源及实际 SwiftUI 标签渲染，避免打包后只有空白入口。
final class MenuBarIconTests: XCTestCase {
    /// PDF 模板必须随 SwiftPM 资源分发，画布固定为 18pt。
    func testTemplateResource() throws {
        let url = try XCTUnwrap(AppResources.url(forResource: "MenuBarTemplate", withExtension: "pdf"))
        let image = try XCTUnwrap(NSImage(contentsOf: url))
        XCTAssertEqual(image.size, NSSize(width: 18, height: 18))
    }

    /// 用真正的菜单栏标签渲染，验证资源名称解析正确且图形保留透明外边缘。
    @MainActor func testMenuBarLabelRendersVisibleGlyph() throws {
        let renderer = ImageRenderer(content: MenuBarIcon())
        renderer.scale = 2
        let image = try XCTUnwrap(renderer.cgImage)
        let bitmap = NSBitmapImageRep(cgImage: image)
        XCTAssertEqual(bitmap.pixelsWide, 36)
        XCTAssertEqual(bitmap.pixelsHigh, 36)
        var visible = 0
        for y in 0..<36 {
            for x in 0..<36 where (bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.5 {
                visible += 1
            }
        }
        XCTAssertGreaterThan(visible, 200)
        XCTAssertLessThan(visible, 900)
        XCTAssertEqual(bitmap.colorAt(x: 0, y: 0)?.alphaComponent, 0)
    }
}
