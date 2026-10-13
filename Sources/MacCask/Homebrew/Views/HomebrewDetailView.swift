import SwiftUI

/// Homebrew 详情列
struct HomebrewDetailView: View {
    let model: HomebrewViewModel

    var body: some View {
        if let pkg = model.selectedPackage {
            BrewPackageDetail(model: model, package: pkg)
                .id(pkg.id)
        } else {
            ContentUnavailableView(L10n.tr("选择一个包"), systemImage: "mug", description: Text(L10n.tr("查看版本、安装位置并进行升级或卸载")))
        }
    }
}

/// 单个包的详情
private struct BrewPackageDetail: View {
    let model: HomebrewViewModel
    let package: BrewPackage
    @State private var confirmUninstall = false
    @State private var zap = false
    @State private var installDir: URL?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                stats
                info
                if let desc = package.desc {
                    GroupBox(L10n.tr("简介")) {
                        Text(desc).frame(maxWidth: .infinity, alignment: .leading).padding(4)
                    }
                }
            }
            .padding(24)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { actionBar }
        .task {
            installDir = await model.installDirectory(of: package)
            await model.loadSize(for: package)
        }
        .confirmationDialog(L10n.tr("确定卸载 {0}？", "\(package.name)"), isPresented: $confirmUninstall) {
            Button(L10n.tr("卸载"), role: .destructive) { model.uninstall(package, zap: zap) }
            Button(L10n.tr("取消"), role: .cancel) {}
        } message: {
            Text(package.kind == .cask && zap ? L10n.tr("将同时清除该应用的配置与数据（--zap），此操作不可恢复。") : L10n.tr("将通过 Homebrew 卸载该包。"))
        }
    }

    /// 顶部标题区
    private var header: some View {
        HStack(spacing: 16) {
            BrewPackageIcon(package: package, size: 56)
            VStack(alignment: .leading, spacing: 6) {
                Text(package.displayName).font(.title2.weight(.semibold))
                HStack(spacing: 6) {
                    TagBadge(text: package.kind.rawValue, style: .homebrew)
                    if package.isOutdated { TagBadge(text: L10n.tr("可更新"), style: .outdated, symbol: "arrow.up") }
                    if package.isPinned { TagBadge(text: L10n.tr("已锁定"), symbol: "pin.fill") }
                    if package.autoUpdates { TagBadge(text: L10n.tr("自动更新"), style: .success) }
                }
            }
            Spacer()
        }
    }

    /// 统计卡片
    private var stats: some View {
        HStack(spacing: 12) {
            StatCard(title: L10n.tr("已安装"), value: package.installedVersion, symbol: "shippingbox")
            StatCard(title: L10n.tr("最新版本"), value: package.latestVersion, symbol: "sparkles",
                     tint: package.isOutdated ? .green : .accentColor)
            StatCard(title: L10n.tr("占用空间"), value: ByteFormatter.string(model.sizes[package.id]), symbol: "internaldrive")
        }
    }

    /// 详细信息表
    private var info: some View {
        GroupBox(L10n.tr("信息")) {
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                InfoRow(title: L10n.tr("名称"), value: package.name, monospaced: true)
                if let tap = package.tap { InfoRow(title: L10n.tr("来源"), value: tap) }
                if package.kind == .formula {
                    InfoRow(title: L10n.tr("安装方式"), value: package.installedOnRequest ? L10n.tr("主动安装") : L10n.tr("作为依赖安装"))
                    if package.keptVersionCount > 1 {
                        InfoRow(title: L10n.tr("保留版本"), value: L10n.tr("{0} 个（可清理旧版本）", "\(package.keptVersionCount)"))
                    }
                }
                if !package.appNames.isEmpty {
                    InfoRow(title: L10n.tr("应用"), value: package.appNames.joined(separator: "、"))
                }
                InfoRow(title: L10n.tr("安装时间"), value: DateText.short(package.installedAt))
                if let installDir { InfoRow(title: L10n.tr("安装位置"), value: installDir.path, monospaced: true) }
                if let homepage = package.homepage {
                    GridRow {
                        Text(L10n.tr("主页")).foregroundStyle(.secondary).gridColumnAlignment(.trailing)
                        Link(homepage.absoluteString, destination: homepage).lineLimit(1)
                    }
                }
            }
            .padding(4)
        }
    }

    /// 底部操作栏
    private var actionBar: some View {
        HStack {
            if let installDir {
                Button(L10n.tr("在访达中显示")) { Platform.current.system.revealInFinder([installDir]) }
            }
            if package.kind == .cask {
                Toggle(L10n.tr("卸载时清除应用数据"), isOn: $zap)
                    .toggleStyle(.checkbox)
                    .help(L10n.tr("使用 --zap 同时删除该应用的偏好设置、缓存等数据"))
            }
            Spacer()
            Button(L10n.tr("卸载…"), role: .destructive) { confirmUninstall = true }
            if package.isOutdated {
                Button(L10n.tr("升级到 {0}", "\(package.latestVersion)")) { model.upgrade(package) }
                    .buttonStyle(.borderedProminent)
                    .disabled(package.isPinned)
            }
        }
        .disabled(model.activeSession?.isRunning == true)
        .padding(12)
        .background(.bar)
    }
}
