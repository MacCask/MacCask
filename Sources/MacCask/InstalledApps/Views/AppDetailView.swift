import SwiftUI

/// 已安装应用详情列
struct AppDetailView: View {
    @Bindable var model: InstalledAppsViewModel

    var body: some View {
        if let app = model.selectedApp {
            AppDetailContent(model: model, app: app)
        } else {
            ContentUnavailableView("选择一个应用", systemImage: "square.grid.2x2",
                                   description: Text("查看应用在磁盘上的所有文件及占用空间"))
        }
    }
}

/// 应用详情内容
private struct AppDetailContent: View {
    @Bindable var model: InstalledAppsViewModel
    let app: InstalledApp
    @State private var confirmUninstall = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                stats
                filesSection
            }
            .padding(24)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !app.isSystem { actionBar }
        }
        .confirmationDialog("卸载「\(app.name)」？", isPresented: $confirmUninstall) {
            Button("移到废纸篓", role: .destructive) { model.uninstallSelected() }
            Button("取消", role: .cancel) {}
        } message: {
            Text(uninstallMessage)
        }
        .alert("提示", isPresented: Binding(get: { model.alertMessage != nil }, set: { if !$0 { model.alertMessage = nil } })) {
            Button("好") {}
        } message: {
            Text(model.alertMessage ?? "")
        }
        .sheet(item: $model.activeSession) { session in
            CommandLogSheet(session: session)
        }
    }

    /// 卸载确认说明
    private var uninstallMessage: String {
        let count = model.checkedFiles.count
        let size = ByteFormatter.string(model.checkedSize)
        if app.isHomebrew {
            return "将通过 Homebrew（\(app.caskToken ?? "")）卸载，并把其余 \(count) 项关联文件（\(size)）移到废纸篓。"
        }
        return "将把 \(count) 项文件（共 \(size)）移到废纸篓，可从废纸篓恢复。"
    }

    /// 顶部标题区
    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(nsImage: BundleInfoReader.icon(for: app.id))
                .resizable()
                .frame(width: 72, height: 72)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(app.name).font(.title2.weight(.semibold))
                    AppTags(app: app)
                }
                if let bundleID = app.bundleID {
                    Text(bundleID).font(.callout.monospaced()).foregroundStyle(.secondary).textSelection(.enabled)
                }
                Text(app.url.path).font(.caption).foregroundStyle(.tertiary).textSelection(.enabled)
            }
            Spacer()
        }
    }

    /// 统计卡片
    private var stats: some View {
        HStack(spacing: 12) {
            StatCard(title: "版本", value: app.version ?? "未知", symbol: "tag")
            StatCard(title: "应用大小", value: ByteFormatter.string(model.sizes[app.id]), symbol: "app")
            StatCard(title: "关联数据", value: model.isAnalyzing ? "分析中…" : ByteFormatter.string(model.relatedDataSize),
                     symbol: "folder", tint: .orange)
            StatCard(title: "上次使用", value: DateText.relative(app.lastUsed), symbol: "clock", tint: .purple)
        }
    }

    /// 关联文件列表
    private var filesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("磁盘上的文件").font(.headline)
                if !model.relatedFiles.isEmpty {
                    Text("\(model.relatedFiles.count) 项 · \(ByteFormatter.string(model.relatedFiles.totalSize))")
                        .font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
                if model.isAnalyzing { ProgressView().controlSize(.small) }
            }
            if app.isSystem {
                Label("系统应用受 macOS 保护，无法卸载。", systemImage: "lock.fill")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            VStack(spacing: 0) {
                ForEach(model.relatedFiles) { file in
                    LibraryFileRow(file: file, isChecked: app.isSystem ? nil : checkBinding(for: file))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                    if file.id != model.relatedFiles.last?.id { Divider().padding(.leading, 12) }
                }
            }
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    /// 底部操作栏
    private var actionBar: some View {
        HStack {
            Button("在访达中显示") { Platform.current.system.revealInFinder([app.url]) }
            Spacer()
            Text("已选 \(model.checkedFiles.count) 项 · \(ByteFormatter.string(model.checkedSize))")
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
            Button("卸载…", role: .destructive) { confirmUninstall = true }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .disabled(model.isAnalyzing || model.checkedFiles.isEmpty || model.activeSession?.isRunning == true)
        }
        .padding(12)
        .background(.bar)
    }

    /// 单个文件的勾选绑定
    private func checkBinding(for file: LibraryFile) -> Binding<Bool> {
        Binding(
            get: { model.checkedFiles.contains(file.id) },
            set: { checked in
                if checked { model.checkedFiles.insert(file.id) } else { model.checkedFiles.remove(file.id) }
            }
        )
    }
}
