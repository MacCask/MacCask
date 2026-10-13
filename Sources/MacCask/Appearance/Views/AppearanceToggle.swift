import SwiftUI

/// 首次跟随系统；单击切换当前实际外观，并将选择持久保存。
struct AppearanceToggle: View {
    @AppStorage(AppAppearance.preferenceKey) private var preference = AppAppearance.system.rawValue
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button {
            // 从实际显示的外观切换，确保系统深色下首次点击也会变为浅色。
            let next: AppAppearance = colorScheme == .dark ? .light : .dark
            preference = next.rawValue
            Platform.current.system.applyAppearance(next)
        } label: {
            Image(systemName: colorScheme == .dark ? "sun.max" : "moon")
                .font(.system(size: 16))
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(actionTitle)
        .accessibilityLabel(actionTitle)
    }

    /// 提示下一次点击将切换到的外观。
    private var actionTitle: String {
        colorScheme == .dark ? L10n.tr("切换到浅色") : L10n.tr("切换到深色")
    }
}
