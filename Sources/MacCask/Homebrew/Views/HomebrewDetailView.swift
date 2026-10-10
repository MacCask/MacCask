import SwiftUI

/// Homebrew 详情列
struct HomebrewDetailView: View {
    let model: HomebrewViewModel

    var body: some View {
        if let pkg = model.selectedPackage {
            BrewPackageDetail(model: model, package: pkg)
                .id(pkg.id)
        } else {
            ContentUnavailableView("选择一个包", systemImage: "mug", description: Text("查看版本、安装位置并进行升级或卸载"))
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
                    GroupBox("简介") {
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
        .confirmationDialog("确定卸载 \(package.name)？", isPresented: $confirmUninstall) {
            Button("卸载", role: .destructive) { model.uninstall(package, zap: zap) }
            Button("取消", role: .cancel) {}
        } message: {
            Text(package.kind == .cask && zap ? "将同时清除该应用的配置与数据（--zap），此操作不可恢复。" : "将通过 Homebrew 卸载该包。")
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
                    if package.isOutdated { TagBadge(text: "可更新", style: .outdated, symbol: "arrow.up") }
                    if package.isPinned { TagBadge(text: "已锁定", symbol: "pin.fill") }
                    if package.autoUpdates { TagBadge(text: "自动更新", style: .success) }
                }
            }
            Spacer()
        }
    }

    /// 统计卡片
    private var stats: some View {
        HStack(spacing: 12) {
            StatCard(title: "已安装", value: package.installedVersion, symbol: "shippingbox")
            StatCard(title: "最新版本", value: package.latestVersion, symbol: "sparkles",
                     tint: package.isOutdated ? .green : .accentColor)
            StatCard(title: "占用空间", value: ByteFormatter.string(model.sizes[package.id]), symbol: "internaldrive")
        }
    }

    /// 详细信息表
    private var info: some View {
        GroupBox("信息") {
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                InfoRow(title: "名称", value: package.name, monospaced: true)
                if let tap = package.tap { InfoRow(title: "来源", value: tap) }
                if package.kind == .formula {
                    InfoRow(title: "安装方式", value: package.installedOnRequest ? "主动安装" : "作为依赖安装")
                    if package.keptVersionCount > 1 {
                        InfoRow(title: "保留版本", value: "\(package.keptVersionCount) 个（可清理旧版本）")
                    }
                }
                if !package.appNames.isEmpty {
                    InfoRow(title: "应用", value: package.appNames.joined(separator: "、"))
                }
                InfoRow(title: "安装时间", value: DateText.short(package.installedAt))
                if let installDir { InfoRow(title: "安装位置", value: installDir.path, monospaced: true) }
                if let homepage = package.homepage {
                    GridRow {
                        Text("主页").foregroundStyle(.secondary).gridColumnAlignment(.trailing)
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
                Button("在访达中显示") { Platform.current.system.revealInFinder([installDir]) }
            }
            if package.kind == .cask {
                Toggle("卸载时清除应用数据", isOn: $zap)
                    .toggleStyle(.checkbox)
                    .help("使用 --zap 同时删除该应用的偏好设置、缓存等数据")
            }
            Spacer()
            Button("卸载…", role: .destructive) { confirmUninstall = true }
            if package.isOutdated {
                Button("升级到 \(package.latestVersion)") { model.upgrade(package) }
                    .buttonStyle(.borderedProminent)
                    .disabled(package.isPinned)
            }
        }
        .disabled(model.activeSession?.isRunning == true)
        .padding(12)
        .background(.bar)
    }
}
