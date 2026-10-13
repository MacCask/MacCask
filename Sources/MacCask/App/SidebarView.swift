import SwiftUI

/// 模块导航与应用分类共享选择状态，刷新仅作用于所在行的模块。
struct SidebarView: View {
    @Environment(AppState.self) private var state
    @AppStorage("appsNavigationExpanded") private var appsExpanded = true

    private enum Destination: Hashable {
        case section(SidebarSection)
        case filter(AppFilter)
    }

    /// 子分类点击时切换到应用页；其他模块不改变已选择的应用分类。
    private var selection: Binding<Destination?> {
        Binding(get: {
            state.section == .apps ? .filter(state.installedApps.filter) : .section(state.section)
        }, set: { destination in
            switch destination {
            case .filter(let filter):
                state.installedApps.filter = filter
                state.section = .apps
            case .section(let section): state.section = section
            case nil: break
            }
        })
    }

    var body: some View {
        List(selection: selection) {
            moduleRow(.overview)
                .tag(Destination.section(.overview))
            DisclosureGroup(isExpanded: $appsExpanded) {
                ForEach(AppFilter.allCases) { filter in
                    HStack {
                        Text(filter.navigationTitle).lineLimit(1)
                        Spacer(minLength: 4)
                        Text("\(state.installedApps.count(for: filter))")
                            .foregroundStyle(.secondary).monospacedDigit()
                    }
                    .padding(.leading, 24)
                    .tag(Destination.filter(filter))
                }
            } label: {
                moduleRow(.apps)
                .tag(Destination.section(.apps))
            }
            ForEach([SidebarSection.homebrew, .launchItems, .leftovers]) { section in
                moduleRow(section)
                    .tag(Destination.section(section))
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom, spacing: 0) { SidebarFooter() }
        .onChange(of: state.section) { _, section in
            if section == .apps { appsExpanded = true }
        }
    }

    /// 一级模块行仅显示名称和数量，刷新收进该行的右键菜单。
    private func moduleRow(_ section: SidebarSection) -> some View {
        HStack(spacing: 8) {
            Label(section.title, systemImage: section.symbol)
                .lineLimit(1)
                .foregroundStyle(section == .apps && state.section == .apps ? Color.accentColor : Color.primary)
            Spacer(minLength: 4)
            if section != .apps, state.badge(for: section) > 0 {
                Text("\(state.badge(for: section))")
                    .foregroundStyle(.secondary).monospacedDigit()
            }
        }
        .contentShape(Rectangle())
        // 仅挂在一级行上，不能挂到 DisclosureGroup 或 List，以免二级分类继承菜单。
        .contextMenu {
            Button {
                Task { await state.refresh(section) }
            } label: {
                Label(L10n.tr(state.isRefreshing(section) ? "正在刷新…" : "刷新"),
                      systemImage: "arrow.clockwise")
            }
            .disabled(state.isRefreshing(section))
        }
    }
}
