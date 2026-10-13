import SwiftUI

/// 包列表头：类型、筛选与维护操作统一在当前列表范围内。
struct HomebrewListHeader: View {
    @Bindable var model: HomebrewViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Homebrew").font(.title2.weight(.semibold))
                Spacer()
                Menu(L10n.tr("维护")) {
                    Button(L10n.tr("更新 Homebrew 源")) { model.updateBrew() }
                    Button(L10n.tr("清理旧版本与缓存")) { model.cleanup() }
                }
                .menuStyle(.borderlessButton).fixedSize()
                .disabled(model.activeSession?.isRunning == true)
            }
            Text(L10n.tr("{0} 个已安装包", "\(model.packages.count)"))
                .font(.caption).foregroundStyle(.secondary)
            Picker(L10n.tr("类型"), selection: $model.kind) {
                ForEach(BrewPackageKind.allCases) { kind in
                    Text("\(kind.rawValue)  \(model.count(of: kind))").tag(kind)
                }
            }
            .pickerStyle(.segmented).labelsHidden()
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { filters }
                VStack(alignment: .leading, spacing: 8) { filters }
            }
            .font(.caption)
        }
        .padding(16).background(.bar)
        .overlay(alignment: .bottom) { Divider() }
    }

    /// 依赖项筛选只适用于 Formula，不改变已有筛选语义。
    @ViewBuilder private var filters: some View {
        Toggle(L10n.tr("仅显示可更新"), isOn: $model.onlyOutdated).toggleStyle(.checkbox)
        if model.kind == .formula {
            Toggle(L10n.tr("隐藏依赖项"), isOn: $model.hideDependencies).toggleStyle(.checkbox)
        }
    }
}

/// 批量升级紧邻当前类型的可更新数量，锁定包沿用服务层排除规则。
struct HomebrewUpdateBar: View {
    let model: HomebrewViewModel

    var body: some View {
        HStack(spacing: 8) {
            Text(model.outdatedPackages.isEmpty ? L10n.tr("全部是最新版本") :
                    L10n.tr("{0} 个包可更新", "\(model.outdatedPackages.count)"))
                .font(.callout).foregroundStyle(.secondary)
            Spacer(minLength: 4)
            if !model.outdatedPackages.isEmpty {
                Button(L10n.tr("全部升级")) { model.upgradeAll() }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.activeSession?.isRunning == true || model.isLoading ||
                              model.outdatedPackages.allSatisfy(\.isPinned))
                    .help(L10n.tr("升级当前类型中所有未锁定的可更新包"))
            }
        }
        .padding(12).background(.bar)
        .overlay(alignment: .top) { Divider() }
    }
}
