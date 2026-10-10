import SwiftUI

/// 启动项详情列
struct LaunchItemDetailView: View {
    let model: LaunchItemsViewModel

    var body: some View {
        if let item = model.selectedItem {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header(item)
                    info(item)
                    if !item.arguments.isEmpty {
                        GroupBox("启动参数") {
                            Text(item.arguments.joined(separator: "\n"))
                                .font(.callout.monospaced())
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(4)
                        }
                    }
                }
                .padding(24)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) { actionBar(item) }
        } else {
            ContentUnavailableView("选择一个启动项", systemImage: "power",
                                   description: Text("查看启动项的执行程序与运行方式"))
        }
    }

    /// 顶部标题区
    private func header(_ item: LaunchItem) -> some View {
        HStack(spacing: 16) {
            LaunchItemIcon(item: item, size: 56)
            VStack(alignment: .leading, spacing: 6) {
                Text(item.displayName).font(.title2.weight(.semibold))
                HStack(spacing: 6) {
                    TagBadge(text: item.source.rawValue, symbol: item.source.symbol)
                    TagBadge(text: item.isEnabled ? "已开启" : "已关闭", style: item.isEnabled ? .success : .neutral)
                    if item.isRunning { TagBadge(text: "运行中", style: .outdated, symbol: "circle.fill") }
                    if item.source.requiresAdmin { TagBadge(text: "需管理员", style: .warning, symbol: "lock.fill") }
                }
            }
            Spacer()
        }
    }

    /// 信息表
    private func info(_ item: LaunchItem) -> some View {
        GroupBox("信息") {
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                InfoRow(title: item.source == .loginItem ? "名称" : "Label", value: item.label, monospaced: item.source != .loginItem)
                if let program = item.program { InfoRow(title: "程序", value: program, monospaced: true) }
                if let plist = item.plistURL { InfoRow(title: "配置文件", value: plist.path, monospaced: true) }
                if item.source != .loginItem {
                    InfoRow(title: "开机运行", value: item.runAtLoad ? "是" : "否")
                    InfoRow(title: "保持常驻", value: item.keepAlive ? "是（退出后自动重启）" : "否")
                }
                if let pid = item.pid { InfoRow(title: "进程号", value: "\(pid)") }
                InfoRow(title: "说明", value: item.source.subtitle)
            }
            .padding(4)
        }
    }

    /// 底部操作栏
    private func actionBar(_ item: LaunchItem) -> some View {
        HStack {
            if let url = item.plistURL ?? item.appPath.map(URL.init(fileURLWithPath:)) {
                Button("在访达中显示") { Platform.current.system.revealInFinder([url]) }
            }
            Spacer()
            Button(item.isEnabled ? "关闭启动项" : "开启启动项") {
                model.setEnabled(item, !item.isEnabled)
            }
            .buttonStyle(.borderedProminent)
            .tint(item.isEnabled ? .red : .accentColor)
            .disabled(model.togglingIDs.contains(item.id))
        }
        .padding(12)
        .background(.bar)
    }
}
