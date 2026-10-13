import SwiftUI

/// 启动项内容列：按来源分组的列表
struct LaunchItemsListView: View {
    @Bindable var model: LaunchItemsViewModel

    var body: some View {
        Group {
            if model.isLoading && model.items.isEmpty {
                LoadingView(text: L10n.tr("正在读取启动项…"))
            } else {
                List(selection: $model.selection) {
                    if let error = model.loginItemError {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(LaunchItemSource.allCases) { source in
                        let items = model.items(in: source)
                        if !items.isEmpty {
                            Section {
                                ForEach(items) { item in
                                    LaunchItemRow(model: model, item: item).tag(item.id)
                                }
                            } header: {
                                HStack {
                                    Label(source.title, systemImage: source.symbol)
                                    Spacer()
                                    Text(L10n.tr("{0}/{1} 已开启", "\(items.filter(\.isEnabled).count)", "\(items.count)"))
                                        .monospacedDigit()
                                }
                                .help(source.subtitle)
                            }
                        }
                    }
                }
                .overlay {
                    if model.items.isEmpty {
                        ContentUnavailableView(L10n.tr("没有第三方启动项"), systemImage: "power")
                    }
                }
            }
        }
        .navigationTitle(L10n.tr("启动项"))
        .searchable(text: $model.searchText, prompt: L10n.tr("搜索启动项"))
        .toolbar {
            ToolbarItemGroup {
                Button {
                    Platform.current.system.openLoginItemsSettings()
                } label: {
                    Label(L10n.tr("系统登录项设置"), systemImage: "gearshape")
                }
                .help(L10n.tr("在系统设置中管理「允许在后台」的项目"))

                Button {
                    Task { await model.refresh() }
                } label: {
                    Label(L10n.tr("刷新"), systemImage: "arrow.clockwise")
                }
                .disabled(model.isLoading)
                .help(L10n.tr("重新读取启动项"))
            }
        }
        .alert(L10n.tr("操作失败"), isPresented: Binding(get: { model.alertMessage != nil }, set: { if !$0 { model.alertMessage = nil } })) {
            Button(L10n.tr("好")) {}
        } message: {
            Text(model.alertMessage ?? "")
        }
        .task { await model.loadIfNeeded() }
    }
}

/// 启动项行：图标 + 名称 + 运行状态 + 开关
struct LaunchItemRow: View {
    let model: LaunchItemsViewModel
    let item: LaunchItem

    var body: some View {
        HStack(spacing: 10) {
            LaunchItemIcon(item: item, size: 28)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.displayName).fontWeight(.medium).lineLimit(1)
                    if item.isRunning {
                        Circle().fill(.green).frame(width: 6, height: 6).help(L10n.tr("运行中"))
                    }
                }
                if item.displayName != item.label {
                    Text(item.label).font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                }
            }
            .opacity(item.isEnabled ? 1 : 0.55)
            Spacer(minLength: 8)
            if model.togglingIDs.contains(item.id) {
                ProgressView().controlSize(.small)
            }
            Toggle("", isOn: Binding(get: { item.isEnabled }, set: { model.setEnabled(item, $0) }))
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
                .disabled(model.togglingIDs.contains(item.id))
                .help(item.source.requiresAdmin ? L10n.tr("需要管理员权限") : (item.isEnabled ? L10n.tr("关闭") : L10n.tr("开启")))
        }
        .padding(.vertical, 2)
        .contextMenu {
            if let url = item.plistURL ?? item.appPath.map(URL.init(fileURLWithPath:)) {
                FileContextMenu(urls: [url])
            }
        }
    }
}

/// 启动项图标：有关联 app 时用 app 图标，否则使用来源符号
struct LaunchItemIcon: View {
    let item: LaunchItem
    let size: CGFloat

    var body: some View {
        if let appPath = item.appPath, FileManager.default.fileExists(atPath: appPath) {
            Image(nsImage: BundleInfoReader.icon(for: appPath, size: size))
                .resizable()
                .frame(width: size, height: size)
        } else {
            Image(systemName: item.source.symbol)
                .font(.system(size: size * 0.45))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(Color.gray.gradient, in: RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
        }
    }
}
