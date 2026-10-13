import Foundation

/// 商店版本仅比较纯数字分段，非标准版本保留未知，避免错误提示升级。
enum NumericVersion {
    /// 忽略末尾零分段，按数值比较每一段；无法识别时返回 nil。
    static func compare(_ lhs: String, _ rhs: String) -> ComparisonResult? {
        // 只接受 ASCII 数字段，不猜测开发者自定义的版本格式。
        func parts(_ value: String) -> [String]? {
            let segments = value.split(separator: ".", omittingEmptySubsequences: false)
            guard !segments.isEmpty, segments.allSatisfy({ !$0.isEmpty && $0.allSatisfy({ $0.isASCII && $0.isNumber }) }) else { return nil }
            return segments.map { String($0) }
        }
        guard let left = parts(lhs), let right = parts(rhs) else { return nil }
        for index in 0..<max(left.count, right.count) {
            let a = index < left.count ? left[index] : "0"
            let b = index < right.count ? right[index] : "0"
            let result = a.compare(b, options: .numeric)
            if result != .orderedSame { return result }
        }
        return .orderedSame
    }
}
