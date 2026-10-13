#!/usr/bin/env python3
"""在临时工程中使用虚构数据渲染原生界面，不启动正式应用或扫描本机。"""

import pathlib
import shutil
import subprocess
import tempfile
import argparse

ROOT = pathlib.Path(__file__).resolve().parents[2]


def replace_required(source, old, new):
    """隔离规则必须匹配，源码变化时立即停止，避免静默回退到真实数据。"""
    if old not in source:
        raise RuntimeError(f"截图隔离规则未匹配：{old}")
    return source.replace(old, new)


def remove_tasks(source):
    """移除视图的自动任务，确保截图期间不会触发扫描或命令。"""
    import re

    pattern = re.compile(r"\.task(?:\([^\n]*?\))?\s*\{")
    while match := pattern.search(source):
        end, depth = match.end(), 1
        while depth:
            depth += (source[end] == "{") - (source[end] == "}")
            end += 1
        source = source[:match.start()] + source[end:]
    return source


def prepare_sources(destination):
    """复制工程并隔离数据、用户路径及图标来源；正式源码保持不变。"""
    shutil.copytree(ROOT / "Sources", destination / "Sources")
    shutil.copy(ROOT / "Package.swift", destination / "Package.swift")
    shutil.copytree(ROOT / "Tests", destination / "Tests")
    sources = destination / "Sources/MacCask"
    shutil.copytree(ROOT / "Scripts/Documentation/Icons", sources / "App/Resources/DemoIcons")
    (sources / "App/MacCaskApp.swift").unlink()
    for path in sources.rglob("*.swift"):
        text = remove_tasks(path.read_text())
        if "ViewModels" in path.parts:
            text = text.replace("private(set) var", "var")
            text = text.replace("private var hasLoaded", "var hasLoaded")
        if path.name == "InstalledAppsViewModel.swift":
            text = replace_required(text, "didSet { if selection != oldValue { analyzeSelection() } }", "didSet {}")
        if path.name == "HomebrewViewModel.swift":
            text = replace_required(text, "var isBrewAvailable: Bool { service.isAvailable }", "var isBrewAvailable: Bool { true }")
        if path.name == "AppState.swift":
            text = replace_required(text, "InstalledAppsViewModel()", "InstalledAppsViewModel(useSizeCache: false)")
        if path.name == "AppearanceToggle.swift":
            text = replace_required(text, "@AppStorage(AppAppearance.preferenceKey)", "@State")
        if path.name == "SidebarView.swift":
            text = replace_required(text, '@AppStorage("appsNavigationExpanded")', '@State')
        if path.name == "LaunchItemsListView.swift":
            text = replace_required(text, "if let appPath = item.appPath, FileManager.default.fileExists(atPath: appPath) {",
                                    "if let appPath = item.appPath {")
        if path.name == "DatabaseManager.swift":
            text = replace_required(text, "ModelConfiguration(schema: schema, url: Self.storeURL())",
                                "ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)")
        if path.name == "LibraryLocations.swift":
            text = replace_required(text, "FileManager.default.homeDirectoryForCurrentUser",
                                'URL(fileURLWithPath: "/Users/demo")')
        if path.name == "BundleInfoReader.swift":
            text = replace_required(text, "NSWorkspace.shared.icon(forFile: path)",
                                'NSImage(contentsOf: AppResources.url(forResource: "DemoIcons/" + URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent, withExtension: "png")!)!')
        if path.name == "L10n.swift":
            text = replace_required(text,
                                    "AppLanguage.resolve(UserDefaults.standard.string(forKey: AppLanguage.preferenceKey))",
                                    'AppLanguage(rawValue: CommandLine.arguments[2]) ?? .english')
            text = replace_required(text, 'Locale.current.region?.identifier ?? "US"', '"US"')
        if path.name == "AppDetailView.swift":
            text = replace_required(text, "private struct AppDetailContent", "struct AppDetailContent")
        if path.name == "AppDetailView.swift":
            text = text.replace("ScrollView {", "VStack(alignment: .leading, spacing: 0) {")
            text = text.replace("private func groupDetail", "func groupDetail")
        if path.name == "LibraryFileRow.swift":
            text = replace_required(text, 'Toggle("", isOn: isChecked)\n                    .toggleStyle(.checkbox)\n                    .labelsHidden()',
                                    'Image(systemName: isChecked.wrappedValue ? "checkmark.square.fill" : "square").foregroundStyle(.blue)')
        path.write_text(text)
    shutil.copy(ROOT / "Scripts/Documentation/ScreenshotRenderer.swift", sources / "App/ScreenshotRenderer.swift")


def main():
    """构建隔离的渲染进程，只导出 SwiftUI 画布，不截图桌面。"""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--language", choices=["en", "zh-Hans"], default="en")
    parser.add_argument("--update-preview", action="store_true", help="使用虚构版本展示更新提示，不检查网络")
    parser.add_argument("--output", type=pathlib.Path, default=ROOT / "docs/screenshots")
    arguments = parser.parse_args()
    output = arguments.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="maccask-docs-") as temporary:
        project = pathlib.Path(temporary)
        prepare_sources(project)
        subprocess.run(["swift", "build", "--package-path", str(project)], check=True)
        subprocess.run([str(project / ".build/debug/MacCask"), str(output), arguments.language] + (["--update-preview"] if arguments.update_preview else []), check=True)


if __name__ == "__main__":
    main()
