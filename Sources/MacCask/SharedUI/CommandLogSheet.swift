import SwiftUI

/// 命令实时日志面板
struct CommandLogSheet: View {
    let session: CommandSession
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                if session.isRunning {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: session.succeeded ? "checkmark.circle.fill" : "xmark.octagon.fill")
                        .foregroundStyle(session.succeeded ? .green : .red)
                }
                Text(session.title).font(.headline)
                Spacer()
            }
            .padding()

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    Text(session.log.isEmpty ? L10n.tr("等待输出…") : session.log)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                    Color.clear.frame(height: 1).id("bottom")
                }
                .background(Color(nsColor: .textBackgroundColor))
                // 日志更新时自动滚动到底部
                .onChange(of: session.log) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }

            Divider()

            HStack {
                Spacer()
                Button(session.isRunning ? L10n.tr("执行中…") : L10n.tr("完成")) { dismiss() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(session.isRunning)
            }
            .padding()
        }
        .frame(width: 640, height: 420)
        .interactiveDismissDisabled(session.isRunning)
    }
}
