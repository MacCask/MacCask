#!/usr/bin/env python3
"""在签名前写入架构专属更新源和公开验证密钥。"""
import base64
import pathlib
import plistlib
import sys


def main():
    """拒绝缺失公钥或未知架构，发布包不能静默关闭验证。"""
    app, arch = pathlib.Path(sys.argv[1]), sys.argv[2]
    if arch not in ("arm64", "x86_64"):
        raise ValueError("未知更新架构")
    key = pathlib.Path("Resources/SparklePublicKey.txt").read_text().strip()
    if len(base64.b64decode(key, validate=True)) != 32:
        raise ValueError("Sparkle 公钥必须为 32 字节")
    path = app / "Contents/Info.plist"
    info = plistlib.loads(path.read_bytes())
    info.update(SUPublicEDKey=key,
                SUFeedURL=f"https://github.com/MacCask/MacCask/releases/latest/download/appcast-{arch}.xml",
                SUEnableAutomaticChecks=False,
                SUAutomaticallyUpdate=False,
                SUAllowsAutomaticUpdates=False,
                SUVerifyUpdateBeforeExtraction=True,
                SURequireSignedFeed=True)
    path.write_bytes(plistlib.dumps(info))


if __name__ == "__main__":
    main()
