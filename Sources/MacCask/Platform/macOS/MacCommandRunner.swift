import Foundation

/// 线程安全的输出缓冲区，用于在管道回调中累积数据
private final class OutputBuffer: @unchecked Sendable {
    private var data = Data()
    private let lock = NSLock()

    /// 追加一段数据
    func append(_ chunk: Data) {
        lock.lock(); defer { lock.unlock() }
        data.append(chunk)
    }

    /// 读取全部数据并解码为字符串
    func string() -> String {
        lock.lock(); defer { lock.unlock() }
        return String(decoding: data, as: UTF8.self)
    }
}

/// macOS 外部命令执行实现：基于 Process + Pipe，stdout 与 stderr 合并
struct MacCommandRunner: CommandRunning {
    /// 执行命令并等待结束，支持流式输出
    func run(_ executable: String,
             arguments: [String],
             environment: [String: String],
             onOutput: (@Sendable (String) -> Void)?) async -> CommandResult {
        await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments

            // 合并环境变量，并补充常见的可执行路径（GUI 应用默认 PATH 很短）
            var env = ProcessInfo.processInfo.environment
            let extraPath = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
            env["PATH"] = [extraPath, env["PATH"]].compactMap { $0 }.joined(separator: ":")
            environment.forEach { env[$0.key] = $0.value }
            process.environment = env

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            process.standardInput = FileHandle.nullDevice

            let buffer = OutputBuffer()
            let handle = pipe.fileHandleForReading
            // 实时读取输出
            handle.readabilityHandler = { h in
                let chunk = h.availableData
                guard !chunk.isEmpty else { return }
                buffer.append(chunk)
                onOutput?(String(decoding: chunk, as: UTF8.self))
            }

            process.terminationHandler = { p in
                // 进程结束后关闭回调并读取管道中剩余的数据
                handle.readabilityHandler = nil
                let rest = handle.readDataToEndOfFile()
                if !rest.isEmpty {
                    buffer.append(rest)
                    onOutput?(String(decoding: rest, as: UTF8.self))
                }
                continuation.resume(returning: CommandResult(exitCode: p.terminationStatus, output: buffer.string()))
            }

            do {
                try process.run()
            } catch {
                handle.readabilityHandler = nil
                continuation.resume(returning: .failure("无法启动 \(executable)：\(error.localizedDescription)"))
            }
        }
    }
}
