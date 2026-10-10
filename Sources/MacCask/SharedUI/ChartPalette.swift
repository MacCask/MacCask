import AppKit
import SwiftUI

/// 图表配色：分类色按固定顺序使用，浅色/深色模式各自取值（已通过色盲区分度校验）
enum ChartPalette {
    /// 分类色 1：蓝
    static let blue = dynamic(light: 0x2a78d6, dark: 0x3987e5)
    /// 分类色 2：橙
    static let orange = dynamic(light: 0xeb6834, dark: 0xd95926)
    /// 分类色 3：青
    static let aqua = dynamic(light: 0x1baf7a, dark: 0x199e70)
    /// 分类色 4：黄
    static let yellow = dynamic(light: 0xeda100, dark: 0xc98500)
    /// 中性色：用于「其他」类数据
    static let neutral = dynamic(light: 0xa3a29c, dark: 0x6b6a65)
    /// 轨道色：用于「可用空间」等背景部分
    static let track = dynamic(light: 0xe7e6e1, dark: 0x2e2e2c)

    /// 状态色：正常
    static let good = Color(hex: 0x0ca30c)
    /// 状态色：警告
    static let warning = Color(hex: 0xfab219)
    /// 状态色：严重
    static let critical = Color(hex: 0xd03b3b)

    /// 生成随系统外观切换的颜色
    private static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor(hex: isDark ? dark : light)
        })
    }
}

extension NSColor {
    /// 由 0xRRGGBB 构造颜色
    convenience init(hex: UInt32) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xff) / 255,
                  green: CGFloat((hex >> 8) & 0xff) / 255,
                  blue: CGFloat(hex & 0xff) / 255,
                  alpha: 1)
    }
}

extension Color {
    /// 由 0xRRGGBB 构造颜色
    init(hex: UInt32) {
        self.init(nsColor: NSColor(hex: hex))
    }
}
