#!/bin/bash
# 统一读取版本文件；发布时同时验证 tag，避免产物版本与 Release 名称不一致。
set -euo pipefail

version_file="${1:-VERSION}"
if [ ! -f "$version_file" ]; then
    echo "版本文件不存在：$version_file" >&2
    exit 1
fi
version="$(cat "$version_file")"
if [[ ! "$version" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]; then
    echo "VERSION 必须只包含 major.minor.patch，例如 1.0.0" >&2
    exit 1
fi
if [ "$#" -ge 2 ] && [ "${2#v}" != "$version" ]; then
    echo "发布 tag 必须是 ${version} 或 v${version}，且与 VERSION 一致" >&2
    exit 1
fi
printf '%s\n' "$version"
