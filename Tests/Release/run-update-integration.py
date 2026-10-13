#!/usr/bin/env python3
"""使用本机 HTTP 服务和独立应用标识验证真实 Sparkle 更新，不修改正式安装。"""
import argparse
import functools
import http.server
import os
import pathlib
import plistlib
import shutil
import subprocess
import threading
import time
import uuid

ROOT = pathlib.Path(__file__).resolve().parents[2]


def run(arguments, **kwargs):
    """执行子进程，私钥仅由调用方通过 stdin 提供。"""
    return subprocess.run(arguments, cwd=ROOT, check=True, **kwargs)


def main():
    """构建两个隔离版本，签名清单后验证提醒、下载、安装及重启。"""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--scenario", choices=["install", "cancel"], default="install")
    scenario = parser.parse_args().scenario
    work = ROOT / "build" / ("update-integration-" + uuid.uuid4().hex[:8])
    work.mkdir(parents=True)
    identity = os.environ.get("SIGN_IDENTITY", "Flick Self-Signed Code Signing")
    key = (ROOT / ".signing/sparkle-private-key").read_text().strip()
    public_key = (ROOT / "Resources/SparklePublicKey.txt").read_text().strip()
    identifier = "com.maccask.update-test." + uuid.uuid4().hex
    served = work / "server"
    served.mkdir()
    requests = []

    class Handler(http.server.SimpleHTTPRequestHandler):
        """仅监听回环地址，记录请求以判定是否发生后台下载。"""
        def do_GET(self):
            requests.append((time.monotonic(), self.path))
            super().do_GET()
        def log_message(self, format, *args):
            pass

    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), functools.partial(Handler, directory=str(served)))
    threading.Thread(target=server.serve_forever, daemon=True).start()
    base = f"http://127.0.0.1:{server.server_port}/"
    framework = ROOT / ".build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64"
    updater = (ROOT / "Sources/MacCask/Platform/macOS/MacAppUpdater.swift").read_text()
    # 只在临时副本开放一次后台检查入口，生产策略、委托及页面组件保持原样。
    updater = updater.replace("    /// 用户主动检查时", "    func integrationStartBackgroundCheck() { controller?.updater.checkForUpdatesInBackground() }\n\n    /// 用户主动检查时")
    (work / "MacAppUpdater.swift").write_text(updater)
    (work / "L10n.swift").write_text('import Foundation\nenum L10n { static func tr(_ text: String, _ args: String...) -> String { args.enumerated().reduce(text) { $0.replacingOccurrences(of: "{\\($1.offset)}", with: $1.element) } } }\n')
    binary = work / "UpdateTest"
    run(["swiftc", "-parse-as-library", "-swift-version", "5", "-F", str(framework), "-framework", "Sparkle", "-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks", str(work / "MacAppUpdater.swift"), str(work / "L10n.swift"), "Sources/MacCask/Platform/AppUpdating.swift", "Sources/MacCask/Updates/Views/UpdateNoticeView.swift", "Tests/Release/UpdateIntegrationHarness.swift", "-o", str(binary)])
    apps = []
    for version, folder in [("9000.0.0", "installed"), ("9000.0.1", "new")]:
        app = work / folder / "MacCaskUpdateTest.app"
        (app / "Contents/MacOS").mkdir(parents=True)
        shutil.copy(binary, app / "Contents/MacOS/UpdateTest")
        info = dict(CFBundleIdentifier=identifier, CFBundleName="MacCaskUpdateTest", CFBundleDisplayName="MacCask Update Test", CFBundleExecutable="UpdateTest", CFBundlePackageType="APPL", CFBundleVersion=version, CFBundleShortVersionString=version, LSMinimumSystemVersion="15.0", NSPrincipalClass="NSApplication", SUPublicEDKey=public_key, SUFeedURL=base+"appcast.xml", SURequireSignedFeed=True, SUVerifyUpdateBeforeExtraction=True, SUEnableAutomaticChecks=False, SUAutomaticallyUpdate=False, SUAllowsAutomaticUpdates=False, SUShowReleaseNotes=False, NSAppTransportSecurity={"NSAllowsLocalNetworking": True}, IntegrationTestRoot=str(work), IntegrationScenario=scenario)
        (app / "Contents/Info.plist").write_bytes(plistlib.dumps(info))
        run(["bash", "Scripts/Release/embed-sparkle.sh", str(app), identity], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        run(["codesign", "--force", "--timestamp=none", "--sign", identity, str(app)])
        apps.append(app)
    run(["hdiutil", "create", "-volname", "MacCask Update Test", "-srcfolder", str(apps[1].parent), "-fs", "HFS+", "-format", "UDZO", str(served / "UpdateTest.dmg")], stdout=subprocess.DEVNULL)
    tools = ROOT / ".build/artifacts/sparkle/Sparkle/bin"
    run([str(tools / "generate_appcast"), "--ed-key-file", "-", "--maximum-deltas", "0", "--download-url-prefix", base, str(served)], input=key, text=True)
    launcher = subprocess.Popen(["open", "-n", "-W", str(apps[0])])
    deadline = time.monotonic() + 130
    background_checked = False
    try:
        while time.monotonic() < deadline:
            events = (work / "events.log").read_text() if (work / "events.log").exists() else ""
            if "NOTICE_WITHOUT_WINDOW" in events and "USER_OPEN_UPDATE" not in events:
                assert not any(path.endswith(".dmg") for _, path in requests), "更新前已发生 DMG 下载"
                background_checked = True
            if scenario == "cancel" and (work / "cancelled").exists():
                assert background_checked
                assert not any(path.endswith(".dmg") for _, path in requests), "稍后提醒仍触发了下载"
                installed = plistlib.loads((apps[0] / "Contents/Info.plist").read_bytes())
                assert installed["CFBundleVersion"] == "9000.0.0"
                assert not (work / "relaunched").exists()
                print("PASS: remind later clears notice without downloading or replacing app")
                print("Evidence:", work)
                return
            if (work / "relaunched").exists():
                assert scenario == "install", "取消场景不应安装新版"
                assert background_checked, "未验证后台等待阶段"
                installed = plistlib.loads((apps[0] / "Contents/Info.plist").read_bytes())
                assert installed["CFBundleVersion"] == "9000.0.1"
                run(["codesign", "--verify", "--deep", "--strict", str(apps[0])])
                assert "USER_INSTALL_UPDATE" in events and "USER_INSTALL_RELAUNCH" in events
                print("PASS: silent notice, user download, signed replacement and relaunch")
                print("Evidence:", work)
                return
            if "FAIL" in events:
                raise RuntimeError(events)
            time.sleep(0.2)
        raise RuntimeError("测试超时；证据目录: " + str(work))
    finally:
        server.shutdown()
        # 仅终止本次生成的应用，清理独立测试偏好，不影响 MacCask。
        subprocess.run(["pkill", "-f", str(apps[0] / "Contents/MacOS/UpdateTest")], capture_output=True)
        subprocess.run(["defaults", "delete", identifier], capture_output=True)
        if launcher.poll() is None:
            launcher.terminate()


if __name__ == "__main__":
    main()
