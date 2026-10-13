#!/bin/bash
# 验证签名、版本和单一 CPU 架构，再生成带 Applications 快捷方式的安装磁盘映像。
set -euo pipefail
cd "$(dirname "$0")/../.."

app_bundle="${1:-build/MacCask.app}"
architecture="${2:-$(uname -m)}"
output_directory="${3:-build/releases}"
version="$(bash Scripts/Utils/read-version.sh VERSION)"
if [ "$architecture" != "x86_64" ] && [ "$architecture" != "arm64" ]; then
    echo "不支持的发布架构：$architecture" >&2
    exit 1
fi
actual_architecture="$(lipo -archs "$app_bundle/Contents/MacOS/MacCask")"
if [ "$actual_architecture" != "$architecture" ]; then
    echo "架构不匹配：需要 ${architecture}，实际为 ${actual_architecture}" >&2
    exit 1
fi
bundle_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app_bundle/Contents/Info.plist")"
if [ "$bundle_version" != "$version" ]; then
    echo "应用版本 $bundle_version 与 VERSION 中的 $version 不一致" >&2
    exit 1
fi
codesign --verify --deep --strict "$app_bundle"
mkdir -p "$output_directory"
archive="$output_directory/MacCask-$version-macos-$architecture.dmg"
staging_directory="$(mktemp -d "${TMPDIR:-/tmp}/maccask-dmg.XXXXXX")"
# 退出时清理暂存目录；ditto 保留应用资源及已有代码签名。
trap 'rm -rf "$staging_directory"' EXIT
ditto "$app_bundle" "$staging_directory/MacCask.app"
ln -s /Applications "$staging_directory/Applications"
codesign --verify --deep --strict "$staging_directory/MacCask.app"
# 使用压缩只读 HFS+ 映像，支持拖动应用到 Applications 安装。
hdiutil create -volname "MacCask $version ($architecture)" \
    -srcfolder "$staging_directory" -fs HFS+ -format UDZO -ov "$archive"
hdiutil verify "$archive"
echo "发布包：$archive"
