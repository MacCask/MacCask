#!/bin/bash
# 保留框架符号链接，并由内到外签名更新助手，避免依赖 --deep 的隐式行为。
set -euo pipefail
app_bundle="$1"
sign_identity="${2:--}"
framework="$app_bundle/Contents/Frameworks/Sparkle.framework"
mkdir -p "$app_bundle/Contents/Frameworks"
ditto .build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework "$framework"
for component in Autoupdate Updater.app XPCServices/Downloader.xpc XPCServices/Installer.xpc; do
    codesign --force --timestamp=none --sign "$sign_identity" "$framework/Versions/B/$component"
done
codesign --force --timestamp=none --sign "$sign_identity" "$framework"
