// 从统一轮廓生成菜单栏矢量模板及 1x/2x PNG，不使用应用图标底板。
import AppKit

// 合并三个折面为单一轮廓，保留右侧开口，避免 18pt 下出现细缝。
let outline: [(String, [CGFloat])] = [
    ("M", [220,315]), ("L", [484,167]), ("Q", [512,151,539,169]),
    ("L", [799,307]), ("Q", [825,321,802,338]), ("L", [543,465]),
    ("Q", [525,474,507,465]), ("L", [414,416]), ("L", [414,606]),
    ("L", [537,668]), ("Q", [554,678,569,671]), ("L", [781,572]),
    ("Q", [816,555,816,591]), ("L", [816,678]), ("Q", [816,705,792,718]),
    ("L", [543,858]), ("Q", [515,875,489,860]), ("L", [222,701]),
    ("Q", [209,687,209,663]), ("L", [209,353]), ("Q", [209,326,220,315]), ("Z", [])
]

/// 根据同一组路径指令创建矢量轮廓，确保 PDF、SVG 和 PNG 一致。
func makeOutline() -> CGPath {
    let path = CGMutablePath()
    for (command, p) in outline {
        switch command {
        case "M": path.move(to: CGPoint(x: p[0], y: p[1]))
        case "L": path.addLine(to: CGPoint(x: p[0], y: p[1]))
        case "Q": path.addQuadCurve(to: CGPoint(x: p[2], y: p[3]), control: CGPoint(x: p[0], y: p[1]))
        default: path.closeSubpath()
        }
    }
    return path
}

/// 按 18pt 菜单栏画布居中绘制，宽留白保证与相邻系统图标间距一致。
func drawIcon(in context: CGContext, color: CGColor = CGColor(gray: 0, alpha: 1)) {
    context.saveGState()
    defer { context.restoreGState() }
    context.translateBy(x: -2.28, y: 20.25)
    context.scaleBy(x: 0.022, y: -0.022)
    context.setFillColor(color)
    context.addPath(makeOutline())
    context.fillPath()
}

/// 导出透明 PDF 模板及 PNG，SVG 仅作为可编辑设计资源。
func exportMenuBarIcon() throws {
    let folder = URL(fileURLWithPath: "Resources/MenuBar")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let pdf = folder.appendingPathComponent("MenuBarTemplate.pdf")
    var bounds = CGRect(x: 0, y: 0, width: 18, height: 18)
    guard let consumer = CGDataConsumer(url: pdf as CFURL),
          let context = CGContext(consumer: consumer, mediaBox: &bounds, nil) else {
        throw NSError(domain: "MacCask.MenuBarIcon", code: 1)
    }
    context.beginPDFPage(nil)
    drawIcon(in: context)
    context.endPDFPage()
    context.closePDF()
    for scale in [1, 2] {
        let pixels = 18 * scale
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        let graphics = NSGraphicsContext(bitmapImageRep: bitmap)!
        graphics.cgContext.clear(CGRect(x: 0, y: 0, width: pixels, height: pixels))
        graphics.cgContext.scaleBy(x: CGFloat(scale), y: CGFloat(scale))
        drawIcon(in: graphics.cgContext)
        let suffix = scale == 1 ? "" : "@2x"
        try bitmap.representation(using: .png, properties: [:])!
            .write(to: folder.appendingPathComponent("MenuBarTemplate\(suffix).png"))
    }
    let data = outline.map { $0.0 + $0.1.map { String(Double($0)) }.joined(separator: " ") }.joined(separator: " ")
    let svg = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"18\" height=\"18\" viewBox=\"0 0 18 18\"><path fill=\"black\" transform=\"matrix(.022 0 0 .022 -2.28 -2.25)\" d=\"\(data)\"/></svg>\n"
    try svg.write(to: folder.appendingPathComponent("MenuBarTemplate.svg"), atomically: true, encoding: .utf8)
    let destination = URL(fileURLWithPath: "Sources/MacCask/App/Resources/MenuBarTemplate.pdf")
    try Data(contentsOf: pdf).write(to: destination)
    try exportPreview(to: folder.appendingPathComponent("Preview.png"))
}

/// 在浅色与深色菜单栏背景上以实际 18pt 大小展示模板，便于检查小尺寸辨识度。
func exportPreview(to url: URL) throws {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 480, pixelsHigh: 112,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let context = NSGraphicsContext(bitmapImageRep: bitmap)!.cgContext
    context.scaleBy(x: 2, y: 2)
    for (index, background) in [CGFloat(0.94), CGFloat(0.12)].enumerated() {
        context.setFillColor(CGColor(gray: background, alpha: 1))
        context.fill(CGRect(x: index * 120, y: 0, width: 120, height: 56))
        context.saveGState()
        context.translateBy(x: CGFloat(index * 120 + 51), y: 19)
        drawIcon(in: context, color: CGColor(gray: index == 0 ? 0.1 : 0.95, alpha: 1))
        context.restoreGState()
    }
    try bitmap.representation(using: .png, properties: [:])!.write(to: url)
}

try exportMenuBarIcon()
