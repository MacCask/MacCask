#!/usr/bin/env python3
"""验证两个架构的更新配置及正式版本递增规则。"""
import pathlib
import plistlib
import subprocess
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]


class UpdateConfigurationTests(unittest.TestCase):
    """临时应用仅包含 plist，不启动更新器或访问网络。"""

    def test_architecture_feeds_and_verification(self):
        """架构分别指向自己的签名清单，默认不静默安装。"""
        with tempfile.TemporaryDirectory() as directory:
            app = pathlib.Path(directory) / "MacCask.app"
            (app / "Contents").mkdir(parents=True)
            path = app / "Contents/Info.plist"
            for arch in ("arm64", "x86_64"):
                path.write_bytes(plistlib.dumps({"CFBundleVersion": "1.1.0"}))
                subprocess.run(["python3", str(ROOT / "Scripts/Release/configure-updater.py"), str(app), arch], cwd=ROOT, check=True)
                info = plistlib.loads(path.read_bytes())
                self.assertTrue(info["SUFeedURL"].endswith(f"/appcast-{arch}.xml"))
                self.assertTrue(info["SURequireSignedFeed"])
                self.assertTrue(info["SUVerifyUpdateBeforeExtraction"])
                self.assertFalse(info["SUAutomaticallyUpdate"])
                self.assertFalse(info["SUAllowsAutomaticUpdates"])
                self.assertEqual(info["CFBundleVersion"], "1.1.0")
            result = subprocess.run(["python3", str(ROOT / "Scripts/Release/configure-updater.py"), str(app), "unknown"], cwd=ROOT, capture_output=True)
            self.assertNotEqual(result.returncode, 0)


if __name__ == "__main__":
    unittest.main()
