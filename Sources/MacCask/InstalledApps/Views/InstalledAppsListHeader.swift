import SwiftUI

/// 列表内的分类和排序：作用范围限于当前应用列表，不占用窗口搜索工具栏。
struct InstalledAppsListHeader: View {
    @Bindable var model: InstalledAppsViewModel

    var body: some View {
        VStack(spacing: 10) {
            Text(model.filter.navigationTitle)
                .font(.title2.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack {
                Text(L10n.tr("{0} 个应用", "\(model.visibleApps.count)"))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 8)
                Menu {
                    Picker(L10n.tr("排序方式"), selection: $model.sortOrder) {
                        ForEach(AppSortOrder.allCases) { order in
                            Text(order.title).tag(order)
                        }
                    }
                    .pickerStyle(.inline)
                } label: {
                    Text(L10n.tr("排序：{0}", model.sortOrder.title))
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help(L10n.tr("排序方式"))
            }
            .font(.caption)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(.bar)
        .overlay(alignment: .bottom) { Divider() }
    }
}
