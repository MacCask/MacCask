import Foundation

/// 统一解析 SwiftPM 开发资源和正式应用内的资源包，避免依赖构建机路径。
enum AppResources {
    /// 正式应用只查自身资源目录；裸可执行文件使用 SwiftPM 自动生成的资源定位。
    static var bundle: Bundle {
        if Bundle.main.bundleURL.pathExtension == "app" {
            guard let url = Bundle.main.resourceURL?.appendingPathComponent("MacCask_MacCask.bundle"),
                  let bundle = Bundle(url: url) else { return Bundle.main }
            return bundle
        }
        return Bundle.module
    }

    /// 读取 copy 类型资源的子目录，供开发图标和菜单栏图标共用。
    static func url(forResource name: String, withExtension ext: String) -> URL? {
        bundle.url(forResource: name, withExtension: ext, subdirectory: "Resources")
    }
}
