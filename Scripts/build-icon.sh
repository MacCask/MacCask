#!/bin/bash
# 使用苹果资源编译器生成系统图标、兼容 ICNS 和 SwiftPM 开发资源。
set -euo pipefail
cd "$(dirname "$0")/.."
output="build/icon-composer"
mkdir -p "$output" Sources/MacCask/App/Resources
swift Scripts/make-menubar-icon.swift
xcrun actool Resources/AppIcon.icon \
    --compile "$output" --platform macosx --minimum-deployment-target 15.0 \
    --app-icon AppIcon --output-partial-info-plist "$output/partial.plist" \
    --output-format human-readable-text
# 仅在内容变化时复制，避免无意义地触发 SwiftPM 资源重建。
for destination in Resources/AppIcon/AppIcon.icns Sources/MacCask/App/Resources/AppIcon.icns; do
    if ! cmp -s "$output/AppIcon.icns" "$destination"; then
        cp "$output/AppIcon.icns" "$destination"
    fi
done
