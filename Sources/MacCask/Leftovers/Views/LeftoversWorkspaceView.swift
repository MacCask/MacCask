import SwiftUI

/// 残留工作区：列表与详情共用底部批量操作栏，明确删除作用于全部选中项。
struct LeftoversWorkspaceView: View {
    @Bindable var model: LeftoversViewModel
    @State private var pendingTrash: Set<LeftoverGroup.ID> = []

    var body: some View {
        VStack(spacing: 0) {
            HSplitView {
                LeftoversListView(model: model, showsSelectionBar: false)
                    .frame(minWidth: 340, idealWidth: 380, maxWidth: 560)
                LeftoverDetailView(model: model)
                    .frame(minWidth: 360, maxWidth: .infinity, maxHeight: .infinity)
                    .layoutPriority(1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            LeftoversSelectionBar(model: model) { pendingTrash = model.selection }
        }
        .confirmationDialog(model.trashConfirmationTitle(for: pendingTrash),
                            isPresented: Binding(get: { !pendingTrash.isEmpty }, set: { if !$0 { pendingTrash = [] } })) {
            Button(L10n.tr("移到废纸篓"), role: .destructive) { model.moveToTrash(pendingTrash) }
            Button(L10n.tr("取消"), role: .cancel) {}
        } message: {
            Text(L10n.tr("文件会被移到废纸篓，清倒废纸篓前仍可恢复。"))
        }
    }
}
