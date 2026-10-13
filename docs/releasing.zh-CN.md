# 发布 Release

[English](releasing.md)

推送与 `VERSION` 一致的 tag 后，`.github/workflows/release.yml` 会使用 Xcode 26.3，在 `macos-15-intel` 上测试和构建 x86_64，在 `macos-15` 上测试和构建 arm64。两个架构都成功后才公开 GitHub Release。应用使用你的自签证书，不执行 Apple 公证。

## 配置仓库 Secrets

进入 **Settings → Secrets and variables → Actions → New repository secret**，添加：

| Secret | 内容 |
| --- | --- |
| `BUILD_CERTIFICATE_BASE64` | 同时包含签名证书和**私钥**的 `.p12` 文件，经 Base64 编码后的内容 |
| `P12_PASSWORD` | 导出这个 `.p12` 时自己设置的密码 |

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

- `MacCask-1.0.0-macos-x86_64.zip`：Intel Mac。
- `MacCask-1.0.0-macos-arm64.zip`：Apple Silicon Mac。
- `SHA256SUMS`：两个压缩包的校验和。

每个 ZIP 中包含 `MacCask.app`。归档前会验证应用版本、签名和准确的 CPU 架构。新 Release 先保持草稿，附件全部上传成功后再公开。重新运行同一 tag 的工作流，可以替换已有 Release 中的同名附件。

## 本地生成发布包

```sh
make release ARCH=x86_64
make release ARCH=arm64
```

压缩包写入 `build/releases/`，应用包仍位于 `build/MacCask.app`。最后一次构建会替换应用包，因此需要本地运行时，请最后构建本机架构。CI 为两个架构分别使用原生 runner 并运行测试。

## 验证

推送 `ci/release-validation` 分支可测试完整流程，不创建 Release。工作流合入默认分支后，也可以在 **Actions → Build and release → Run workflow** 手动运行。这两种入口会构建、签名并上传双架构附件，只有推送 tag 才发布 Release。

```sh
bash Tests/Release/test-version.sh
bash Tests/Release/test-signing-selection.sh
swift test
make release
```

runner 标签与 Xcode 版本依据 [GitHub runner 镜像](https://github.com/actions/runner-images)；证书导入参考 [GitHub macOS 签名文档](https://docs.github.com/en/actions/how-tos/deploy/deploy-to-third-party-platforms/sign-xcode-applications)，另为自签证书增加信任设置。
