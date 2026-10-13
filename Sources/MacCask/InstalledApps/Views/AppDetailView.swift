import SwiftUI

/// 已安装应用详情列
struct AppDetailView: View {
    @Bindable var model: InstalledAppsViewModel

    var body: some View {
        if let app = model.selectedApp {
            AppDetailContent(model: model, app: app)
        } else {
            ContentUnavailableView(L10n.tr("选择一个应用"), systemImage: "square.grid.2x2",
                                   description: Text(L10n.tr("查看应用在磁盘上的所有文件及占用空间")))
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
                if !model.isAnalysisComplete { incompleteNotice }
                filesSection
            }
            .padding(24)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !app.isSystem { actionBar }
        }
        .confirmationDialog(L10n.tr("卸载「{0}」？", "\(app.name)"), isPresented: $confirmUninstall) {
            Button(L10n.tr("移到废纸篓"), role: .destructive) { model.uninstallSelected() }
            Button(L10n.tr("取消"), role: .cancel) {}
        } message: {
            Text(uninstallMessage)
        }
        .alert(L10n.tr("提示"), isPresented: Binding(get: { model.alertMessage != nil }, set: { if !$0 { model.alertMessage = nil } })) {
            Button(L10n.tr("好")) {}
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
        let size = ByteFormatter.measured(model.checkedSize, isComplete: model.relatedFiles.filter { model.checkedFiles.contains($0.id) }.allSatisfy(\.isSizeComplete))
        if app.isHomebrew {
            return L10n.tr("将通过 Homebrew（{0}）卸载，并把其余 {1} 项关联文件（{2}）移到废纸篓。", "\(app.caskToken ?? "")", "\(count)", "\(size)")
        }
        return L10n.tr("将把 {0} 项文件（共 {1}）移到废纸篓，可从废纸篓恢复。", "\(count)", "\(size)")
    }

    /// 顶部标题区
    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(nsImage: BundleInfoReader.icon(for: app.id, size: 72))
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
            StatCard(title: L10n.tr("版本"), value: app.version ?? L10n.tr("未知"), symbol: "tag")
            StatCard(title: L10n.tr("应用包大小"), value: ByteFormatter.string(model.sizes[app.id]), symbol: "app")
            StatCard(title: L10n.tr("关联数据"), value: model.isAnalyzing ? L10n.tr("分析中…") : ByteFormatter.measured(model.relatedDataSize, isComplete: model.isAnalysisComplete),
                     symbol: "folder", tint: .orange)
            StatCard(title: L10n.tr("上次使用"), value: DateText.relative(app.lastUsed), symbol: "clock", tint: .purple)
        }
    }

    /// 明确说明部分统计，并复用平台设置入口与现有刷新操作。
    private var incompleteNotice: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(L10n.tr("大小统计不完整"), systemImage: "exclamationmark.triangle")
                .font(.callout.weight(.semibold))
            Text(L10n.tr("部分目录无法读取，当前大小仅包含已读取的文件。请检查完全磁盘访问权限，授权后重启 MacCask；其他读取问题解决后可点击刷新。"))
                .font(.caption)
            Button(L10n.tr("打开系统设置")) { Platform.current.system.openFullDiskAccessSettings() }
                .buttonStyle(.link)
            DisclosureGroup(L10n.tr("无法读取的路径")) {
                Text(model.unreadableURLs.map(\.path).joined(separator: "\n"))
                    .font(.caption).textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(12)
        .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
    }

    /// 关联文件列表
    private var filesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L10n.tr("磁盘上的文件")).font(.headline)
                if !model.relatedFiles.isEmpty {
                    Text(L10n.tr("{0} 项 · {1}", "\(model.relatedFiles.count)", "\(ByteFormatter.measured(model.relatedFiles.totalSize, isComplete: model.isAnalysisComplete))"))
                        .font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
                if model.isAnalyzing { ProgressView().controlSize(.small) }
            }
            if app.isSystem {
                Label(L10n.tr("系统应用受 macOS 保护，无法卸载。"), systemImage: "lock.fill")
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
            Button(L10n.tr("在访达中显示")) { Platform.current.system.revealInFinder([app.url]) }
            Spacer()
            Text(L10n.tr("已选 {0} 项 · {1}", "\(model.checkedFiles.count)", "\(ByteFormatter.measured(model.checkedSize, isComplete: model.relatedFiles.filter { model.checkedFiles.contains($0.id) }.allSatisfy(\.isSizeComplete)))"))
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
            Button(L10n.tr("卸载…"), role: .destructive) { confirmUninstall = true }
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
