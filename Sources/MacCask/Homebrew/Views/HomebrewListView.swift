import SwiftUI

/// Homebrew 内容列：包列表
struct HomebrewListView: View {
    @Bindable var model: HomebrewViewModel

    var body: some View {
        Group {
            if !model.isBrewAvailable {
                ContentUnavailableView {
                    Label("未安装 Homebrew", systemImage: "mug")
                } description: {
                    Text("Homebrew 是 macOS 上最流行的包管理器。")
                } actions: {
                    Button("访问 brew.sh") { Platform.current.system.openURL(URL(string: "https://brew.sh")!) }
                }
            } else if model.isLoading && model.packages.isEmpty {
                LoadingView(text: "正在读取 Homebrew…")
            } else if let error = model.errorMessage, model.packages.isEmpty {
                ContentUnavailableView("读取失败", systemImage: "exclamationmark.triangle", description: Text(error))
            } else {
                list
            }
        }
        .navigationTitle("Homebrew")
        .searchable(text: $model.searchText, placement: .sidebar, prompt: "搜索包")
        .toolbar { toolbar }
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
                ContentUnavailableView(model.onlyOutdated ? "全部是最新版本" : "没有匹配的包",
                                       systemImage: model.onlyOutdated ? "checkmark.seal" : "magnifyingglass")
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            Picker("类型", selection: $model.kind) {
                ForEach(BrewPackageKind.allCases) { kind in
                    Text("\(kind.rawValue)  \(model.count(of: kind))").tag(kind)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            ListStatusBar(text: statusText)
        }
    }

    /// 底部状态栏文本
    private var statusText: String {
        let outdated = model.outdatedPackages.count
        let base = "\(model.visiblePackages.count) 个\(model.kind.title)"
        return outdated > 0 ? base + " · \(outdated) 个可更新" : base + " · 全部最新"
    }

    /// 工具栏：筛选、全部升级、刷新与更多操作
    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItemGroup {
            Menu {
                Toggle("仅显示可更新", isOn: $model.onlyOutdated)
                if model.kind == .formula {
                    Toggle("隐藏依赖项", isOn: $model.hideDependencies)
                }
            } label: {
                Label("筛选", systemImage: model.onlyOutdated || model.hideDependencies
                      ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
            }
            .help("筛选")

            if !model.outdatedPackages.isEmpty {
                Button {
                    model.upgradeAll()
                } label: {
                    Label("全部升级", systemImage: "arrow.up.circle")
                }
                .help("升级当前列表中所有可更新的包")
            }

            Menu {
                Button("更新 Homebrew 源") { model.updateBrew() }
                Button("清理旧版本与缓存") { model.cleanup() }
            } label: {
                Label("更多", systemImage: "ellipsis.circle")
            }
            .help("更多操作")

            Button {
                Task { await model.refresh() }
            } label: {
                Label("刷新", systemImage: "arrow.clockwise")
            }
            .disabled(model.isLoading)
            .help("重新读取已安装的包")
        }
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
                    if package.isPinned { TagBadge(text: "已锁定", symbol: "pin.fill") }
                    if package.kind == .formula && !package.installedOnRequest {
                        TagBadge(text: "依赖")
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
            Image(nsImage: BundleInfoReader.icon(for: appPath))
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
