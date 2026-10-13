# MacCask

使用 SwiftUI 构建的原生 macOS 应用管理工具。查看已安装软件及其磁盘占用，管理 Homebrew 软件包和启动项，并检查已卸载软件留下的文件。

[English](../README.md) · [从源码构建](#从源码构建) · [使用说明](#使用说明) · [参与贡献](#参与贡献) · [MIT 协议](../LICENSE)

![MacCask 概览](screenshots/overview.png)

*截图使用演示数据。*

## 功能

- **概览**：磁盘占用、占用最多的应用、应用来源、使用活跃度和清理建议。
- **应用程序**：搜索、筛选和排序已安装应用，查看版本、大小和 Library 关联文件，选择需要移除的文件。系统应用带有标签并禁止卸载。
- **Homebrew**：管理 Formula 和 Cask，筛选依赖及可更新软件包，升级、卸载、更新源，以及清理旧版本和缓存。操作过程中显示实时命令日志。
- **启动项**：查看和启用或关闭登录项、用户代理、全局代理及第三方系统守护进程。
- **残留文件**：按标识符、位置、大小和可信度检查可能的残留，忽略项目或将选中文件移到废纸篓。
- **原生界面**：浅色与深色外观、侧边栏导航、列表与详情布局，以及可选的菜单栏入口。
- **多语言**：支持英语和简体中文，默认跟随系统语言，也可以保存自己的选择。

## 应用更新

应用菜单提供“检查更新…”，设置中可开启自动检查。更新使用 GitHub Release 中对应架构的 DMG，并验证更新签名。旧版用户需先手动安装一次带更新功能的版本。

## 环境要求

| 项目 | 要求 |
| --- | --- |
| 操作系统 | macOS 15 或更新版本 |
| Swift | Swift 6 工具链；项目采用 Swift 5 语言模式 |
| 打包工具 | 完整 Xcode 26 或更新版本，并设为当前开发者目录，用于 Icon Composer 图标资源及 `actool` |
| Homebrew | 可选，仅管理 Homebrew 软件包时需要 |

项目使用 Swift Package Manager 和 Apple 框架，通过 Swift Package Manager 引入 Sparkle 更新框架。默认构建当前 Mac 架构的程序；Makefile 不生成通用二进制。

## 从源码构建

### 1. 配置 Xcode

安装 Xcode 26 或更新版本，并先打开一次，完成初始配置。检查当前工具链：

```sh
xcode-select --print-path
xcodebuild -version
xcrun swift --version
xcrun --find actool
```

如果当前目录指向 Command Line Tools 或其他 Xcode，请切换到完整 Xcode。以下命令适用于安装在标准位置的 Xcode：

```sh
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
```

### 2. 克隆仓库

```sh
git clone https://github.com/MacCask/MacCask.git
cd MacCask
```

后续命令均在项目根目录执行。

### 3. 构建并启动应用

```sh
make app
open build/MacCask.app
```

`make app` 会生成图标、编译 Release 程序、复制资源、组装 `build/MacCask.app` 并签名。直接执行 `make` 也会运行同一个默认目标。如果需要一条命令完成打包和启动：

```sh
make run
```

### 4. 安装到 Applications

```sh
make install
open /Applications/MacCask.app
```

`make install` 会重新构建，并替换已有的 `/Applications/MacCask.app`。也可以在访达中将 `build/MacCask.app` 复制到 Applications。

### 代码签名

当前 MacCask 应用使用自签名证书签名，尚未经过 Apple 公证。首次打开时，macOS 可能显示安全提示。

Makefile 默认使用钥匙串中第一个可用的代码签名身份；没有找到时使用 ad-hoc 签名。可以明确指定已有的自签身份：

```sh
security find-identity -v -p codesigning
make app SIGN_IDENTITY="你的代码签名身份名称"
```

如果要明确使用 ad-hoc 签名：

```sh
make app SIGN_IDENTITY=""
```

应用版本读取自 [VERSION](../VERSION)，初始为 `1.0.0`，修改版本时请编辑这个文件。构建号可以单独指定：

```sh
make app BUILD=1
```

打包流程只执行本地签名，不向 Apple 提交公证。验证生成的应用包：

```sh
codesign --verify --deep --strict build/MacCask.app
```

## 开发

不生成 `.app` 包，直接构建和运行 Debug 程序：

```sh
swift build
swift run MacCask
```

运行自动化测试：

```sh
swift test
```

| 命令 | 结果 |
| --- | --- |
| `swift build` | 在 `.build/` 下生成 Debug 程序及资源 |
| `swift run MacCask` | 构建并启动 Debug 程序 |
| `swift test` | 运行自动化测试 |
| `make build` | 生成图标并编译 Release 程序 |
| `make app` | 创建并签名 `build/MacCask.app` |
| `make release ARCH=arm64` | 构建 arm64 DMG 安装包到 `build/releases/`；Intel 使用 `ARCH=x86_64` |
| `make run` | 打包并启动应用 |
| `make install` | 打包并安装到 `/Applications` |
| `make clean` | 删除生成的 `build/` 和 `.build/` 目录 |

日常使用和配置权限时，建议运行安装到 Applications 中的应用包。

## 使用说明

1. 打开**概览**查看磁盘占用，进入需要处理的管理页面。
2. 在**应用程序**中选择软件，查看关联文件，选择需要移除的项目，再确认卸载。
3. 在 **Homebrew** 中切换 Formula 与 Cask，查看更新，并通过命令日志观察操作结果。
4. 在**启动项**中检查执行程序和来源，再修改启用状态。macOS 管理的后台项目通过**系统登录项设置**处理。
5. 在**残留文件**中检查路径和可信度；需要保留的项目可忽略，其余选中项目可移到废纸篓。

### 语言与菜单栏

打开 **MacCask → 设置…**（`⌘,`），选择**跟随系统**、**English** 或**简体中文**。修改后立即生效并保存。“跟随系统”匹配系统首选的受支持语言，没有匹配时回退到英语。应用名称、文件路径、软件包描述和外部命令输出保留原文。

通过**视图切换 → 显示菜单栏图标**控制菜单栏入口。开启时，关闭主窗口仍会保持运行，可从菜单栏重新打开；隐藏时，关闭最后一个窗口即退出。

### 权限

| 权限 | 用途 |
| --- | --- |
| 完全磁盘访问权限 | 检查受保护的 Library 目录；未授权时扫描结果可能不完整 |
| 自动化 → 系统事件 | 读取和管理登录项 |
| 管理员授权 | 按需修改受保护文件或系统守护进程 |

按需在**系统设置 → 隐私与安全性**中授权。授予完全磁盘访问权限后，请重新启动 MacCask。

### 清理行为

普通应用和残留清理会将选中文件移到废纸篓，清倒废纸篓前可以恢复。Homebrew 管理的应用和软件包调用 Homebrew 卸载命令；这些操作，包括 Cask 的 `zap` 清理，不具备同样的废纸篓恢复行为。

卸载前请退出正在运行的应用。残留检测基于标识符匹配，请检查拟删除的文件，尤其是可能与其他已安装应用共享数据的低可信度项目。

## 界面截图

### 应用程序与关联文件

![应用程序与关联文件](screenshots/applications.png)

### Homebrew 软件包

![Homebrew 软件包](screenshots/homebrew.png)

### 启动项

![启动项](screenshots/startup-items.png)

### 残留检查

![残留检查](screenshots/leftovers.png)

## 常见问题

| 问题 | 检查方法 |
| --- | --- |
| `xcodebuild` 提示需要 Xcode，或找不到 `actool` | 查看 `xcode-select --print-path`，按上文切换到完整 Xcode |
| Icon Composer 图标编译失败 | 执行 `xcodebuild -version`，确认当前 Xcode 为 26 或更新版本 |
| Swift 工具版本不匹配 | 执行 `xcrun swift --version`，确认当前工具链支持 Swift 6 |
| 找不到代码签名身份 | 执行 `security find-identity -v -p codesigning`，指定可用名称，或使用 `SIGN_IDENTITY=""` |
| 未检测到 Homebrew | 应用检查 `/opt/homebrew/bin/brew` 和 `/usr/local/bin/brew`，暂不支持自定义安装路径 |
| 关联文件或残留扫描不完整 | 检查完全磁盘访问权限，授权后重新启动打包后的应用 |
| 无法读取登录项 | 在隐私与安全性 → 自动化中，允许 MacCask 控制系统事件 |
| 安装时提示权限不足 | 使用访达将构建后的应用复制到 Applications，按 macOS 提示授权 |

报告问题时，请提供 macOS 与 Xcode 版本、启动方式、复现步骤和相关错误输出。分享日志或截图前，请移除个人路径等隐私信息。

## 参与贡献

欢迎通过 [Issues](https://github.com/MacCask/MacCask/issues) 和 [Pull Requests](https://github.com/MacCask/MacCask/pulls) 提交问题、改进和翻译。

修改代码时请遵守[开发约定](../agents.md)，运行 `swift test` 并验证 `make app`。界面改动应检查英语与简体中文，并在 PR 中说明改动和验证结果。

架构细节见[设计文档](design.md)。

维护者可按[发布配置说明](releasing.zh-CN.md)设置签名 Secrets。推送匹配版本的 tag 后，两个架构都构建成功才会发布 Intel 与 Apple Silicon 的独立 DMG 安装包。

## 许可证

MacCask 使用 [MIT 协议](../LICENSE)。文档中的第三方图标保留原有权利，来源见[图标说明](../Scripts/Documentation/Icons/README.md)。
