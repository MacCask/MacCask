# 发布 Release

[English](releasing.md)

推送与 `VERSION` 一致的 tag 后，`.github/workflows/release.yml` 会使用 Xcode 26.6 和 Apple Silicon `macos-26` runner。SwiftPM 通过 `--arch x86_64` 交叉编译 Intel 程序，arm64 原生构建。含图形渲染的完整测试在原生 arm64 作业运行；Intel 应用独立编译并打包为 DMG，并校验架构和签名。两个架构都成功后才公开 GitHub Release。应用使用你的自签证书，不执行 Apple 公证。

## 配置仓库 Secrets

进入 **Settings → Secrets and variables → Actions → New repository secret**，添加：

| Secret | 内容 |
| --- | --- |
| `BUILD_CERTIFICATE_BASE64` | 同时包含签名证书和**私钥**的 `.p12` 文件，经 Base64 编码后的内容 |
| `P12_PASSWORD` | 导出这个 `.p12` 时自己设置的密码 |
| `SPARKLE_PRIVATE_KEY` | Sparkle 更新签名私钥，直接粘贴导出文件内容，不要再次 Base64 编码 |

当前本机签名身份为 `Flick Self-Signed Code Signing`。工作流从导入的 `.p12` 自动识别签名身份，不需要单独设置名称 Secret；导出时只选择这一个签名身份及其私钥。

本机证书 SHA-1 指纹为 `F59A55AA31DD7E2DB36EF2ACD1FA467C2BE84547`。目前本地 Makefile 通过钥匙串签名，没有额外配置 P12 密码。导出密码需要你新设置，与 macOS 登录密码不同。

1. 打开**钥匙串访问 → 我的证书**，找到 `Flick Self-Signed Code Signing`，展开后确认有对应私钥。
2. 将该身份连同私钥导出为 `.p12`，保存到下载目录，命名为 `MacCask-signing.p12`。设置导出密码，并将这个密码填入 `P12_PASSWORD`。
3. 用下面的命令将 Base64 内容复制到剪贴板，再粘贴到 `BUILD_CERTIFICATE_BASE64`：

   ```sh
   base64 -i "$HOME/Downloads/MacCask-signing.p12" | pbcopy
   ```

不要提交 `.p12` 或密码。Git 已忽略 P12/PFX 文件及 `.signing/`。缺少 Secret 时，流程会在开始构建前报错，不会退回 ad-hoc 签名发布。

runner 会自行生成临时钥匙串密码，导入身份，在一次性 runner 上信任自签证书，并在结束后移除签名材料。不需要 provisioning profile、Apple 账号或手动设置 GitHub Token；发布任务使用 GitHub 自动提供的 Token，只给发布任务 `contents: write` 权限。

## 发布版本

`VERSION` 是唯一版本来源，初始内容为 `1.0.0`。版本格式为数字 `major.minor.patch`；提交前修改文件，Makefile 不接受 `VERSION=...` 覆盖。

提交版本和发布相关改动后，推送分支及匹配的 tag：

```sh
git push origin HEAD
git tag "v$(cat VERSION)"
git push origin "v$(cat VERSION)"
```

`VERSION` 为 `1.0.0` 时，支持 `v1.0.0` 和 `1.0.0`；不匹配的 tag 会校验失败。所有 tag 推送都会触发校验，tag 指向的提交必须包含 workflow 和匹配的版本文件。

发布附件：

- `MacCask-1.0.0-macos-x86_64.dmg`：Intel Mac。
- `MacCask-1.0.0-macos-arm64.dmg`：Apple Silicon Mac。
- `SHA256SUMS`：两个 DMG的校验和。

每个 DMG 中包含 `MacCask.app` 和 `Applications` 快捷方式，打开后将应用拖到 Applications 即可安装。归档前会验证应用版本、签名和准确的 CPU 架构。新 Release 先保持草稿，附件全部上传成功后再公开。重新运行同一 tag 的工作流，可以替换已有 Release 中的同名附件。

## 本地生成发布包

```sh
make release ARCH=x86_64
make release ARCH=arm64
```

DMG 写入 `build/releases/`，应用包仍位于 `build/MacCask.app`。最后一次构建会替换应用包，因此需要本地运行时，请最后构建本机架构。CI 为两种目标架构分别使用 Apple Silicon runner，完整测试在原生 arm64 作业运行。Intel GitHub 虚拟机无法可靠运行图形测试。

## 验证

推送 `ci/release-validation` 分支可测试完整流程，不创建 Release。工作流合入默认分支后，也可以在 **Actions → Build and release → Run workflow** 手动运行。这两种入口会构建、签名并上传双架构附件，只有推送 tag 才发布 Release。

```sh
bash Tests/Release/test-version.sh
bash Tests/Release/test-signing-selection.sh
swift test
make release
```

runner 标签与 Xcode 版本依据 [GitHub runner 镜像](https://github.com/actions/runner-images)；证书导入参考 [GitHub macOS 签名文档](https://docs.github.com/en/actions/how-tos/deploy/deploy-to-third-party-platforms/sign-xcode-applications)，另为自签证书增加信任设置。

## 应用内更新

Action 自动生成并签署 `appcast-arm64.xml` 和 `appcast-x86_64.xml`，与 DMG 一起作为 Release 附件发布。应用通过 `releases/latest/download/appcast-架构.xml` 获取最新稳定版；无需 GitHub Pages 或额外服务器。不要把缺少更新清单的旧版手动设置成 Latest。

在项目目录复制已生成的更新私钥，然后添加到仓库 Secret `SPARKLE_PRIVATE_KEY`：

```sh
pbcopy < .signing/sparkle-private-key
```

私钥也保存在登录钥匙串的 `com.maccask.app.sparkle` 账户；公钥在 `Resources/SparklePublicKey.txt`，会在打包时写入应用。务必备份私钥并在后续版本保持一致，不能每次发布重新生成。现有 P12 和密码两个 Secret 保持不变。

更新器同时验证清单与 DMG 签名，在解包前拒绝篡改。自动检查默认关闭，可在设置中开启；下载、安装与重启由标准更新窗口交互完成。应用需安装到可写位置，不能直接在只读 DMG 中更新。首次接入更新器需要手动安装。

正式版 `CFBundleVersion` 与 `CFBundleShortVersionString` 均取 `VERSION`；每次更新必须提高版本号，不沿用旧 CI 构建序号或本地时间戳。已有旧版没有更新器，因此首次手动安装完成版本规则切换。`BUILD` 仅用于开发验证，不应覆盖正式版本规则。

本地验证生成清单：

```sh
make release
SPARKLE_PRIVATE_KEY="$(cat .signing/sparkle-private-key)" bash Scripts/Release/generate-appcast.sh build/releases "$(uname -m)" "v$(cat VERSION)"
python3 Tests/Release/test-updater.py
```

自签不是 Apple 公证。发布前还应使用两个不同版本的已安装应用，在测试目录验证下载、退出、替换和重启全过程。不要为测试推送虚假的正式版本。

后台检查发现新版仅显示页面提示，不弹窗或自动下载；点击“查看更新…”后再选择下载与安装。

### 本机跨版本集成测试

在已解析 Sparkle 依赖、存在 `.signing/sparkle-private-key` 与本机签名身份的情况下运行：

```sh
python3 Tests/Release/run-update-integration.py
python3 Tests/Release/run-update-integration.py --scenario cancel
```

测试会短暂打开独立测试应用的 Sparkle 窗口，并在该进程内模拟用户操作。它复用正式更新服务和提示组件，使用本机回环服务器、临时 Bundle ID 和虚构版本；不会替换 Applications 中的应用。第一项实际下载、替换并重启到新版；第二项验证稍后提醒不下载或安装。日志保存在输出的 build/update-integration-* 目录。需要可用的 macOS 图形会话，不在无桌面的 CI 中运行。
