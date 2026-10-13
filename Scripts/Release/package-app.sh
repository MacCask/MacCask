#!/bin/bash
# 验证签名、版本和单一 CPU 架构，再生成保留 macOS 资源的应用 ZIP。
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
archive="$output_directory/MacCask-$version-macos-$architecture.zip"
ditto -c -k --sequesterRsrc --keepParent "$app_bundle" "$archive"
unzip -tq "$archive"
echo "发布包：$archive"
