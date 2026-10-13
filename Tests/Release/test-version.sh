#!/bin/bash
# 验证版本文件与 tag 的接受范围，确保错误版本不会进入发布构建。
set -euo pipefail
cd "$(dirname "$0")/../.."
temporary_directory="$(mktemp -d)"
trap 'rm -rf "$temporary_directory"' EXIT
version_file="$temporary_directory/VERSION"

for version in 1.0.0 0.1.0 12.34.56; do
    printf '%s\n' "$version" > "$version_file"
    test "$(bash Scripts/Utils/read-version.sh "$version_file")" = "$version"
    test "$(bash Scripts/Utils/read-version.sh "$version_file" "$version")" = "$version"
    test "$(bash Scripts/Utils/read-version.sh "$version_file" "v$version")" = "$version"
done

# 非数值、额外行、前导零及预发布后缀不能用作应用包版本。
for version in '' 1.0 v1.0.0 01.0.0 1.0.0-beta '1.0.0 extra' $'1.0.0\n2.0.0'; do
    printf '%s\n' "$version" > "$version_file"
    if bash Scripts/Utils/read-version.sh "$version_file" > /dev/null 2>&1; then
        echo "错误接受了无效版本：$version" >&2
        exit 1
    fi
done
printf '1.0.0\n' > "$version_file"
for tag in v1.0.1 1.0.1 release-1.0.0 vv1.0.0; do
    if bash Scripts/Utils/read-version.sh "$version_file" "$tag" > "$temporary_directory/error" 2>&1; then
        echo "错误接受了不匹配的 tag：$tag" >&2
        exit 1
    fi
    grep -q '发布 tag 必须是' "$temporary_directory/error"
done
if bash Scripts/Utils/read-version.sh "$temporary_directory/missing" > /dev/null 2>&1; then
    echo "缺少版本文件时应失败" >&2
    exit 1
fi
echo "版本文件与 tag 校验测试通过"
