import Foundation
import CoreServices

/// FSEvents 的回调上下文只转发路径，不在通知线程执行目录扫描。
private final class FileEventCallback: @unchecked Sendable {
    let handler: @Sendable ([URL], Bool) -> Void
    /// 持有不会变化的回调，生命周期交给事件流管理。
    init(_ handler: @escaping @Sendable ([URL], Bool) -> Void) { self.handler = handler }
}

/// 目录级通知由系统合并，不订阅逐文件事件，不为内部文件创建独立监听器。
@MainActor
final class MacFileChangeMonitor: FileChangeMonitoring {
    private var stream: FSEventStreamRef?
    private let latency: TimeInterval
    /// 默认合并三秒内的变化，隔离测试可以缩短等待。
    init(latency: TimeInterval = 3) { self.latency = latency }

    /// 一条事件流覆盖所有业务根目录，失败时由前台过期核验兜底。
    @discardableResult
    func start(paths: [URL], onChange: @escaping @Sendable ([URL], Bool) -> Void) -> Bool {
        stop()
        // FSEvents 返回真实路径，预先记录别名，避免 /var 与 /private/var 导致归属匹配失败。
        let aliases = paths.map { (real: $0.resolvingSymlinksInPath().path, original: $0.standardizedFileURL.path) }
            .sorted { $0.real.count > $1.real.count }
        let callback = Unmanaged.passRetained(FileEventCallback { urls, rescan in
            let normalized = urls.map { url -> URL in
                let path = url.path
                guard let alias = aliases.first(where: { path == $0.real || path.hasPrefix($0.real + "/") }) else { return url }
                return URL(fileURLWithPath: alias.original + path.dropFirst(alias.real.count))
            }
            onChange(normalized, rescan)
        })
        var context = FSEventStreamContext(version: 0, info: callback.toOpaque(), retain: nil,
            release: { pointer in
                if let pointer { Unmanaged<FileEventCallback>.fromOpaque(pointer).release() }
            }, copyDescription: nil)
        let watched = Array(Set(paths.map { $0.resolvingSymlinksInPath().path })).sorted() as CFArray
        stream = FSEventStreamCreate(nil, { _, info, count, paths, flags, _ in
            guard let info else { return }
            let callback = Unmanaged<FileEventCallback>.fromOpaque(info).takeUnretainedValue()
            let names = unsafeBitCast(paths, to: NSArray.self) as? [String] ?? []
            let mustRescan = (0..<count).contains { index in
                flags[index] & FSEventStreamEventFlags(kFSEventStreamEventFlagUserDropped
                    | kFSEventStreamEventFlagKernelDropped | kFSEventStreamEventFlagEventIdsWrapped | kFSEventStreamEventFlagRootChanged) != 0
            }
            callback.handler(names.map { URL(fileURLWithPath: $0) }, mustRescan)
        }, &context, watched, FSEventStreamEventId(kFSEventStreamEventIdSinceNow), latency,
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagWatchRoot))
        guard let stream else { callback.release(); return false }
        // 忽略自身统计数据库，防止保存扫描缓存反过来触发新的扫描。
        let database = LibraryLocations.home.appendingPathComponent("Library/Application Support/MacCask")
        FSEventStreamSetExclusionPaths(stream, [database.resolvingSymlinksInPath().path] as CFArray)
        FSEventStreamSetDispatchQueue(stream, DispatchQueue(label: "MacCask.file-events", qos: .utility))
        if !FSEventStreamStart(stream) { stop(); return false }
        return true
    }

    /// 释放事件流及回调上下文。
    func stop() {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }

    /// 生命周期结束时释放系统资源。
    deinit {
        if let stream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
        }
    }
}
