import Foundation

extension URL {
    /// 按完整路径边界判断包含关系，避免将同名前缀的相邻目录混为一项。
    func isWithin(_ directory: URL) -> Bool {
        let child = standardizedFileURL.path
        let parent = directory.standardizedFileURL.path
        return PathHierarchy.contains(child, in: parent)
    }
}

/// 纯字符串路径层级工具，不读取磁盘，也不解析符号链接。
enum PathHierarchy {
    /// 判断已标准化的路径边界，可复用预处理后的字符串以避免反复创建 URL。
    static func contains(_ child: String, in parent: String) -> Bool {
        child == parent || child.hasPrefix(parent.hasSuffix("/") ? parent : parent + "/")
    }

    /// 返回已标准化绝对路径自身及各级父目录，保留完整组件边界。
    static func ancestors(of path: String) -> [String] {
        var result = [path]
        var cursor = path.startIndex
        while let slash = path[cursor...].firstIndex(of: "/") {
            let parent = slash == path.startIndex ? "/" : String(path[..<slash])
            if parent != path { result.append(parent) }
            cursor = path.index(after: slash)
        }
        return result
    }
}
