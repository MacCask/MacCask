import AppKit
import SwiftUI

/// 文档专用入口：只在隔离的临时工程中编译，不加入正式应用。
@main
@MainActor
enum ScreenshotRenderer {
    static var state: AppState!
    static let sections: [(SidebarSection, String)] = [
        (.overview, "overview"), (.apps, "applications"), (.leftovers, "leftovers")
    ]

    /// 注入全部虚构数据，禁止首屏加载访问真实系统。
    static func seed() -> AppState {
        let state = AppState()
        let names = ["Visual Studio Code", "Firefox", "OBS Studio", "VLC", "HandBrake"]
        let identifiers = ["com.microsoft.VSCode", "org.mozilla.firefox", "com.obsproject.obs-studio",
                           "org.videolan.vlc", "fr.handbrake.HandBrake"]
        let casks: [String?] = [nil, "firefox", "obs", "vlc", nil]
        state.installedApps.apps = names.enumerated().map { index, name in
            InstalledApp(url: URL(fileURLWithPath: "/Applications/\(name).app"), name: name,
                         matchNames: [name], bundleID: identifiers[index],
                         version: "\(index % 3 + 1).\(index % 5).0", isSystem: false,
                         isAppStore: false, caskToken: casks[index],
                         lastUsed: Date().addingTimeInterval(-Double([1, 14, 90, 240, 450][index]) * 86400))
        }
        for (index, app) in state.installedApps.apps.enumerated() {
            state.installedApps.sizes[app.id] = Int64(1_900_000_000 - index * 150_000_000)
        }
        state.installedApps.hasLoaded = true
        state.installedApps.selection = state.installedApps.apps[0].id
        state.installedApps.relatedFiles = [
            LibraryFile(url: URL(fileURLWithPath: "/Applications/Visual Studio Code.app"), category: .application, sizeBytes: 1_900_000_000),
            LibraryFile(url: URL(fileURLWithPath: "/Users/demo/Library/Application Support/Code"), category: .applicationSupport, sizeBytes: 640_000_000),
            LibraryFile(url: URL(fileURLWithPath: "/Users/demo/Library/Caches/com.microsoft.VSCode"), category: .caches, sizeBytes: 180_000_000),
            LibraryFile(url: URL(fileURLWithPath: "/Users/demo/Library/Preferences/com.microsoft.VSCode.plist"), category: .preferences, sizeBytes: 8192),
            LibraryFile(url: URL(fileURLWithPath: "/Users/demo/Library/Saved Application State/com.microsoft.VSCode.savedState"), category: .savedState, sizeBytes: 2_400_000)
        ]
        state.installedApps.checkedFiles = Set(state.installedApps.relatedFiles.map(\.id))
        state.homebrew.packages = ["demo-cli", "demo-search", "demo-runtime", "demo-library"].enumerated().map { index, name in
            BrewPackage(name: name, kind: .formula, displayName: name, desc: "Example package",
                        homepage: nil, tap: "example/tools", installedVersion: "1.0.0", latestVersion: "1.1.0",
                        isOutdated: index < 2, isPinned: false, installedOnRequest: true,
                        installedAt: nil, keptVersionCount: 1, appNames: [], autoUpdates: false)
        }
        state.homebrew.hasLoaded = true
        for index in [1, 2, 3] {
            state.homebrew.packages.append(BrewPackage(name: casks[index]!, kind: .cask, displayName: names[index],
                desc: "Demo package", homepage: nil, tap: "homebrew/cask", installedVersion: "1.0.0",
                latestVersion: "1.0.0", isOutdated: false, isPinned: false, installedOnRequest: true,
                installedAt: nil, keptVersionCount: 1, appNames: [names[index] + ".app"], autoUpdates: false))
        }
        state.launchItems.items = ["Visual Studio Code", "Firefox", "OBS Studio"].enumerated().map { index, name in
            LaunchItem(label: name, source: .loginItem, plistURL: nil, program: "/Applications/\(name).app",
                       arguments: [], runAtLoad: true, keepAlive: false, isEnabled: index < 2,
                       pid: index == 0 ? 1234 : nil, appPath: nil, displayName: name)
        }
        state.launchItems.hasLoaded = true
        state.leftovers.groups = ["OldCanvas", "RetiredNotes", "DemoPlayer", "LegacySync"].enumerated().map { index, name in
            let identifier = "com.example.\(name.lowercased())"
            return LeftoverGroup(identifier: identifier, files: [
                LibraryFile(url: URL(fileURLWithPath: "/Users/demo/Library/Application Support/\(identifier)"),
                            category: .applicationSupport, sizeBytes: Int64(420_000_000 - index * 80_000_000)),
                LibraryFile(url: URL(fileURLWithPath: "/Users/demo/Library/Caches/\(identifier)"),
                            category: .caches, sizeBytes: Int64(120_000_000 - index * 20_000_000)),
                LibraryFile(url: URL(fileURLWithPath: "/Users/demo/Library/Preferences/\(identifier).plist"),
                            category: .preferences, sizeBytes: 4096)
            ], confidence: index == 3 ? .low : .high, isIgnored: false)
        }
        state.leftovers.hasLoaded = true
        state.leftovers.selection = [state.leftovers.groups[0].id]
        state.overview.disk = DiskUsage(volumeName: "Demo Volume", totalBytes: 512_000_000_000, availableBytes: 196_000_000_000)
        state.overview.homebrewBytes = 6_400_000_000
        state.overview.cacheBytes = 12_800_000_000
        state.overview.hasLoaded = true
        return state
    }

    /// 直接渲染 SwiftUI 画布，无需桌面截图或屏幕录制权限。
    static func main() {
        _ = NSApplication.shared
        NSApplication.shared.appearance = NSAppearance(named: .aqua)
        state = seed()
        for (section, name) in sections {
            state.section = section
            let renderer = ImageRenderer(content: ScreenshotCanvas(state: state)
                .environment(state).environment(\.colorScheme, .light)
                .environment(\.locale, L10n.locale)
                .frame(width: 1440, height: section == .overview ? 1150 : 760)
                .background(Color(nsColor: .windowBackgroundColor)))
            renderer.scale = 2
            guard let rendered = renderer.cgImage else { fatalError("无法渲染界面") }
            let bitmap = NSBitmapImageRep(cgImage: rendered)
            guard let data = bitmap.representation(using: .png, properties: [:]) else { fatalError("无法导出 PNG") }
            let url = URL(fileURLWithPath: CommandLine.arguments[1]).appendingPathComponent("\(name).png")
            do { try data.write(to: url) } catch { fatalError("写入截图失败：\(error)") }
            print("Rendered \(url.lastPathComponent)")
        }
    }
}

/// 文档画布：静态导航替代无法离屏导出的 AppKit 列表，内容复用真实业务组件。
@MainActor
struct ScreenshotCanvas: View {
    let state: AppState

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                ForEach([Color.red, .yellow, .green], id: \.self) { color in
                    Circle().fill(color.opacity(0.8)).frame(width: 12, height: 12)
                }
                Text("MacCask").font(.headline).padding(.leading, 16)
                Text("/  \(state.section.title)").foregroundStyle(.secondary)
                Spacer()
                Text(L10n.tr("演示数据")).font(.caption).foregroundStyle(.secondary)
            }.padding(.horizontal, 20).frame(height: 48)
            Divider()
            HStack(alignment: .top, spacing: 0) {
                sidebar
                Divider()
                if state.section == .overview {
                    OverviewDashboard().padding(20)
                } else {
                    itemList
                    Divider()
                    if state.section == .apps {
                        AppDetailContent(model: state.installedApps, app: state.installedApps.apps[0])
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    } else {
                        LeftoverDetailView(model: state.leftovers).groupDetail(state.leftovers.groups[0])
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    }
                }
            }
        }
        .foregroundStyle(Color.primary)
    }

    /// 使用真实模块名称和图标绘制静态侧边栏。
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.tr("管理")).font(.caption).foregroundStyle(.secondary).padding(.vertical, 8)
            ForEach(SidebarSection.allCases) { section in
                HStack {
                    Label(section.title, systemImage: section.symbol)
                    Spacer()
                    if state.badge(for: section) > 0 {
                        Text("\(state.badge(for: section))").foregroundStyle(.secondary)
                    }
                }
                .font(.system(size: 13))
                .padding(10)
                .background(section == state.section ? Color.blue.opacity(0.12) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 7))
            }
            Spacer()
            Text(L10n.tr("文件均移到废纸篓，可恢复")).font(.caption2).foregroundStyle(.secondary)
        }
        .padding(12).frame(width: 176).frame(maxHeight: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    /// 将固定演示集合绘制为列表，不访问系统应用或启动扫描。
    private var itemList: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(state.section.title).font(.headline).padding(16)
            Divider()
            if state.section == .apps {
                ForEach(state.installedApps.visibleApps) { app in
                    AppRowView(app: app, size: state.installedApps.sizes[app.id])
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(app.id == state.installedApps.selection ? Color.blue.opacity(0.1) : Color.clear)
                    Divider()
                }
            } else {
                ForEach(state.leftovers.visibleGroups) { group in
                    HStack(spacing: 10) {
                        Image(systemName: "folder.fill").font(.title2).foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(group.displayName).fontWeight(.medium)
                            Text(group.identifier).font(.caption).foregroundStyle(.secondary)
                            if group.confidence == .low { TagBadge(text: L10n.tr("低可信度"), style: .warning) }
                        }
                        Spacer()
                        Text(ByteFormatter.string(group.totalSize)).font(.callout).foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .background(state.leftovers.selection.contains(group.id) ? Color.blue.opacity(0.1) : Color.clear)
                    Divider()
                }
            }
            Spacer()
        }
        .frame(width: 340).frame(maxHeight: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}
