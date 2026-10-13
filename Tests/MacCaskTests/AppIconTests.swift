import AppKit
import XCTest
@testable import MacCask

/// 验证开发运行时的图标资源与平台加载链路，不依赖源码所在目录。
final class AppIconTests: XCTestCase {
    /// SwiftPM 必须分发可解码的 ICNS，否则直接 swift run 会丢失图标。
    func testPackagedDevelopmentIconIsReadable() throws {
        let url = try XCTUnwrap(Bundle.module.url(
            forResource: "AppIcon", withExtension: "icns", subdirectory: "Resources"))
        let image = try XCTUnwrap(NSImage(contentsOf: url))
        XCTAssertFalse(image.representations.isEmpty)
        XCTAssertGreaterThan(image.size.width, 0)
    }

    /// 实际经过 macOS 平台接口设置图标，验证解码后交给 NSApplication。
    @MainActor func testDevelopmentIconReachesApplication() throws {
        let app = NSApplication.shared
        let previous = app.applicationIconImage
        defer { app.applicationIconImage = previous }
        let url = try XCTUnwrap(Bundle.module.url(
            forResource: "AppIcon", withExtension: "icns", subdirectory: "Resources"))
        Platform.current.system.setApplicationIcon(from: url)
        let actual = try XCTUnwrap(app.applicationIconImage)
        XCTAssertGreaterThan(actual.size.width, 0)
        // NSApplication 会重建多尺寸表示，不能用 TIFF 编码字节判断同一图像。
        let cgImage = try XCTUnwrap(actual.cgImage(forProposedRect: nil, context: nil, hints: nil))
        let bitmap = NSBitmapImageRep(cgImage: cgImage)
        let side = try XCTUnwrap(bitmap.colorAt(
            x: bitmap.pixelsWide * 3 / 10, y: bitmap.pixelsHigh / 2)?.usingColorSpace(.deviceRGB))
        XCTAssertGreaterThan(side.blueComponent, side.redComponent + 0.15)
    }
}
