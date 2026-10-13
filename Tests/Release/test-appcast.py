#!/usr/bin/env python3
"""校验清单目标、签名及篡改拒绝，不安装更新或连接网络。"""
import os
import pathlib
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET


def verify(path, signature=None):
    """密钥只通过标准输入传给官方验证工具，绝不写入命令参数。"""
    command = [".build/artifacts/sparkle/Sparkle/bin/sign_update", "--ed-key-file", "-", "--verify", str(path)]
    if signature:
        command.append(signature)
    return subprocess.run(command, input=os.environ["SPARKLE_PRIVATE_KEY"], text=True, capture_output=True).returncode


def main():
    """正确包可验证，任意改动清单或 DMG 后必须拒绝。"""
    directory, arch = pathlib.Path(sys.argv[1]), sys.argv[2]
    version = pathlib.Path("VERSION").read_text().strip()
    feed = directory / f"appcast-{arch}.xml"
    ns = {"s": "http://www.andymatuschak.org/xml-namespaces/sparkle"}
    item = ET.parse(feed).find("channel/item")
    assert item.find("s:version", ns).text == version
    enclosure = item.find("enclosure")
    archive = directory / f"MacCask-{version}-macos-{arch}.dmg"
    assert enclosure.attrib["url"].endswith("/" + archive.name)
    assert enclosure.attrib["url"].startswith("https://github.com/")
    assert int(enclosure.attrib["length"]) == archive.stat().st_size
    signature = enclosure.attrib[f'{{{ns["s"]}}}edSignature']
    assert verify(feed) == 0
    assert verify(archive, signature) == 0
    with tempfile.TemporaryDirectory() as temporary:
        damaged_feed = pathlib.Path(temporary) / "appcast.xml"
        damaged_feed.write_bytes(feed.read_bytes().replace(b"<title>MacCask</title>", b"<title>Modified</title>"))
        assert verify(damaged_feed) != 0
        damaged_archive = pathlib.Path(temporary) / archive.name
        damaged_archive.write_bytes(archive.read_bytes() + b"tampered")
        assert verify(damaged_archive, signature) != 0
    print(f"{arch}: feed, archive and tamper rejection verified")


if __name__ == "__main__":
    main()
