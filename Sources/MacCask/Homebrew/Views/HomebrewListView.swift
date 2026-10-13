import SwiftUI

/// Homebrew 内容列：包列表
struct HomebrewListView: View {
    @Bindable var model: HomebrewViewModel

    var body: some View {
        Group {
            if !model.isBrewAvailable {
                ContentUnavailableView {
                    Label(L10n.tr("未安装 Homebrew"), systemImage: "mug")
                } description: {
                    Text(L10n.tr("Homebrew 是 macOS 上最流行的包管理器。"))
                } actions: {
                    Button(L10n.tr("访问 brew.sh")) { Platform.current.system.openURL(URL(string: "https://brew.sh")!) }
                }
            } else if model.isLoading && model.packages.isEmpty {
                LoadingView(text: L10n.tr("正在读取 Homebrew…"))
            } else if let error = model.errorMessage, model.packages.isEmpty {
                ContentUnavailableView(L10n.tr("读取失败"), systemImage: "exclamationmark.triangle", description: Text(error))
            } else {
                list
            }
        }
        .navigationTitle("Homebrew")
        .searchable(text: $model.searchText, placement: .toolbar, prompt: L10n.tr("搜索包"))
        .task { await model.loadIfNeeded() }
        .sheet(item: $model.activeSession) { session in
            CommandLogSheet(session: session)
        }
    }

    /// 包列表
    private var list: some View {
        List(selection: $model.selection) {
            ForEach(model.visiblePackages) { pkg in
                BrewPackageRow(package: pkg).tag(pkg.id)
            }
        }
        .overlay {
            if model.visiblePackages.isEmpty {
                ContentUnavailableView(model.onlyOutdated ? L10n.tr("全部是最新版本") : L10n.tr("没有匹配的包"),
                                       systemImage: model.onlyOutdated ? "checkmark.seal" : "magnifyingglass")
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) { HomebrewListHeader(model: model) }
        .safeAreaInset(edge: .bottom, spacing: 0) { HomebrewUpdateBar(model: model) }
    }

}

/// Homebrew 包列表行
struct BrewPackageRow: View {
    let package: BrewPackage

    var body: some View {
        HStack(spacing: 10) {
            BrewPackageIcon(package: package, size: 28)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(package.name).fontWeight(.medium).lineLimit(1)
                    if package.isPinned { TagBadge(text: L10n.tr("已锁定"), symbol: "pin.fill") }
                    if package.kind == .formula && !package.installedOnRequest {
                        TagBadge(text: L10n.tr("依赖"))
                    }
                }
                if let desc = package.desc {
                    Text(desc).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text(package.installedVersion)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if package.isOutdated {
                    TagBadge(text: package.latestVersion, style: .outdated, symbol: "arrow.up")
                }
            }
        }
        .padding(.vertical, 2)
    }
}

/// 包图标：cask 若能找到对应 app 则用 app 图标，否则使用符号
struct BrewPackageIcon: View {
    let package: BrewPackage
    let size: CGFloat

    var body: some View {
        if let appPath = appPath {
            Image(nsImage: BundleInfoReader.icon(for: appPath, size: size))
                .resizable()
                .frame(width: size, height: size)
        } else {
            Image(systemName: package.kind == .formula ? "terminal" : "macwindow")
                .font(.system(size: size * 0.5))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(
                    LinearGradient(colors: package.kind == .formula ? [.orange, .brown] : [.indigo, .purple],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                )
        }
    }

    /// cask 对应的 app 路径（在 /Applications 中查找）
    private var appPath: String? {
        for name in package.appNames {
            for dir in ["/Applications", LibraryLocations.home.appendingPathComponent("Applications").path] {
                let path = (dir as NSString).appendingPathComponent(name)
                if FileManager.default.fileExists(atPath: path) { return path }
            }
        }
        return nil
    }
}
