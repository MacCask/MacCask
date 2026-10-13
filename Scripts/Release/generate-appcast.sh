#!/bin/bash
# 对单一架构目录生成并签署清单；密钥从标准输入读取，禁止输出到日志或参数。
set -euo pipefail
archive_directory="$1"
architecture="$2"
release_tag="$3"
repository="${GITHUB_REPOSITORY:-MacCask/MacCask}"
case "$architecture" in arm64|x86_64) ;; *) exit 1 ;; esac
: "${SPARKLE_PRIVATE_KEY:?Configure SPARKLE_PRIVATE_KEY}"
version="$(bash Scripts/Utils/read-version.sh VERSION)"
archive="MacCask-$version-macos-$architecture.dmg"
test -s "$archive_directory/$archive"
staging="$(mktemp -d "${TMPDIR:-/tmp}/maccask-appcast.XXXXXX")"
trap 'rm -rf "$staging"' EXIT
cp "$archive_directory/$archive" "$staging/$archive"
encoded_tag="$(python3 -c 'import sys,urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=""))' "$release_tag")"
# 说明随清单一同签名，使用固定文本和 Release 链接，不执行远程 HTML。
python3 - "$staging/${archive%.dmg}.html" "$version" "$repository" "$encoded_tag" <<'PYNOTES'
import html
import pathlib
import sys
path, version, repository, tag = sys.argv[1:]
url = f"https://github.com/{repository}/releases/tag/{tag}"
pathlib.Path(path).write_text(f'<p>MacCask {html.escape(version)}</p><p><a href="{html.escape(url, quote=True)}">View release notes on GitHub</a></p>')
PYNOTES
printf '%s' "$SPARKLE_PRIVATE_KEY" | .build/artifacts/sparkle/Sparkle/bin/generate_appcast \
    --ed-key-file - --maximum-deltas 0 \
    --download-url-prefix "https://github.com/$repository/releases/download/$encoded_tag/" \
    -o "$staging/appcast-$architecture.xml" "$staging"
cp "$staging/appcast-$architecture.xml" "$archive_directory/appcast-$architecture.xml"
test -s "$archive_directory/appcast-$architecture.xml"
# 独立验证生成清单的签名，失败时禁止发布。
printf '%s' "$SPARKLE_PRIVATE_KEY" | .build/artifacts/sparkle/Sparkle/bin/sign_update \
    --ed-key-file - --verify "$archive_directory/appcast-$architecture.xml"
