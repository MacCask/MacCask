import Foundation
import Observation

/// 一次命令执行会话：保存实时日志与执行状态，供日志面板展示
@Observable
@MainActor
final class CommandSession: Identifiable {
    let id = UUID()
    /// 面板标题
    let title: String
    /// 累积的输出日志
    private(set) var log = ""
    /// 是否仍在执行
    private(set) var isRunning = true
    /// 是否执行成功（结束后有效）
    private(set) var succeeded = false

    init(title: String) {
        self.title = title
    }

    /// 追加一段日志
    func append(_ text: String) {
        log += text
    }

    /// 标记执行结束
    func finish(succeeded: Bool) {
        self.succeeded = succeeded
        isRunning = false
        append(succeeded ? L10n.tr("\n✅ 完成\n") : L10n.tr("\n❌ 执行失败\n"))
    }

    /// 生成一个可在后台线程调用的日志回调
    nonisolated func outputHandler() -> @Sendable (String) -> Void {
        { [weak self] text in
            Task { @MainActor in self?.append(text) }
        }
    }
}
