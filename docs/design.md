这是一个macos的应用程序管理软件，能管理已经安装的，也能管理homebrew的软件，页面设计符合使用习惯，页面好看现代化，用swift编写

#设计
    - 查看当前安装的软件，分析其分别在哪些目录下有对应文件，占用大小
    - 检查homebrew安装的软件，查看对应版本，提供升级，卸载
    - 检查开机启动项，可以关闭开机启动项
    - 检查以前安装的残留文件
    - 如果是系统软件，需要有个tag提示

---

# 详细设计

## 1. 技术选型

| 项目 | 选择 | 说明 |
| --- | --- | --- |
| 语言 | Swift 6 工具链（Swift 5 语言模式） | 避免严格并发检查带来的大量样板代码 |
| UI | SwiftUI（macOS 15+） | `NavigationSplitView` 三栏布局，原生现代风格 |
| 状态管理 | Observation（`@Observable`） | 每个模块一个 ViewModel |
| 数据库 | SwiftData（Apple 官方 ORM） | 所有实体均使用 `#Index` 建立索引 |
| 构建 | Swift Package Manager + Makefile | `make app` 直接产出签名后的 `.app` |
| 签名 | 系统钥匙串中已有的自签证书 | Makefile 自动探测第一个可用的代码签名身份 |

## 2. 目录结构

```
MacCask/
├── Package.swift
├── Makefile                      # 构建、打包、签名
├── Resources/Info.plist          # .app 的 Info.plist 模板
├── Scripts/make-icon.swift       # 生成应用图标
├── docs/
└── Sources/MacCask/
    ├── App/                      # 入口、应用代理、主窗口、侧边栏导航、全局状态
    ├── Overview/                 # 模块：概览分析页
    ├── Platform/                 # 平台接口（协议）
    │   └── macOS/                # macOS 平台实现
    ├── Utils/                    # 通用工具函数（大小计算、路径、标识符匹配等）
    ├── Storage/                  # SwiftData 数据库：容器、实体、仓储
    ├── SharedUI/                 # 通用 UI 组件（标签、空状态、命令日志面板等）
    ├── InstalledApps/            # 模块：已安装应用
    ├── Homebrew/                 # 模块：Homebrew 管理
    ├── LaunchItems/              # 模块：开机启动项
    └── Leftovers/                # 模块：残留文件
```

每个业务模块内部再按 `Models / Services / ViewModels / Views` 拆分文件。模块之间只通过 Service 层的公开接口交互，View 不跨模块引用。

## 3. 平台抽象层（Platform）

所有与操作系统交互的调用都通过协议封装，macOS 实现放在 `Platform/macOS/`，将来如需支持其他平台，只需新增对应实现，业务代码不受影响。

| 协议 | 职责 | macOS 实现 |
| --- | --- | --- |
| `CommandRunning` | 执行外部命令，支持流式输出 | `Process` + `Pipe` |
| `PrivilegedCommandRunning` | 以管理员权限执行命令 | `osascript ... with administrator privileges` |
| `FileTrashing` | 把文件移到废纸篓 | `FileManager.trashItem`，无权限时回退到管理员 `mv` |
| `LoginItemManaging` | 读取/添加/移除登录项 | AppleScript（System Events） |
| `SystemIntegrating` | 在访达中显示、打开系统设置、权限检测、磁盘容量 | `NSWorkspace`、`URLResourceValues` |

统一入口：`Platform.current`（`PlatformServices` 结构体），业务层只依赖协议。

## 4. 数据库设计（SwiftData）

数据库文件：`~/Library/Application Support/MacCask/MacCask.store`

### 4.1 AppSizeCacheEntity —— 应用大小缓存
计算 `.app` 大小需要遍历整个包，耗时较长，按「路径 + 修改时间」缓存。

| 字段 | 类型 | 索引 | 说明 |
| --- | --- | --- | --- |
| path | String | 唯一索引 | 应用路径 |
| modifiedAt | Date | | 应用包修改时间，变化则缓存失效 |
| sizeBytes | Int64 | | 占用大小 |
| updatedAt | Date | 索引 | 缓存写入时间 |

查询：`paths.contains($0.path)`，按扫描到的路径批量查询，命中唯一索引。

### 4.2 IgnoredLeftoverEntity —— 已忽略的残留项

| 字段 | 类型 | 索引 | 说明 |
| --- | --- | --- | --- |
| identifier | String | 唯一索引 | 残留项标识（通常是 bundle id） |
| createdAt | Date | 索引 | 忽略时间 |

查询：`ids.contains($0.identifier)`，只查询本次扫描出的标识符。

### 4.3 DisabledLoginItemEntity —— 已关闭的登录项
macOS 没有「禁用登录项」的公开接口，关闭即从登录项中移除；为了能再次开启，需记录被关闭的登录项。

| 字段 | 类型 | 索引 | 说明 |
| --- | --- | --- | --- |
| path | String | 唯一索引 | 登录项应用路径 |
| name | String | | 显示名称 |
| disabledAt | Date | 索引 | 关闭时间 |

查询：按 `disabledAt` 排序读取全部记录（业务语义上就是「所有被关闭的登录项」，符合「条件过滤出来是全表」的例外）；删除时按 `path` 唯一索引定位。

## 5. 功能模块设计

### 5.0 概览（Overview）
启动后的默认页面，整页仪表盘（两栏布局：侧边栏 + 仪表盘），汇总其他模块的数据。

- **磁盘占用**：启动磁盘的已用百分比（大号数字），分段条按占整个磁盘的比例展示
  第三方应用 / Homebrew（Cellar + Caskroom）/ 用户缓存（~/Library/Caches）/ 残留文件（不含缓存目录中的部分，避免重复计算）/ 其他已用 / 可用；
  图例逐项列出大小与占磁盘百分比，悬停高亮对应分段，点击跳转到对应模块。剩余空间低于 20% / 10% 时显示警告标签。
- **状态磁贴**：应用程序、Homebrew（含可更新数）、启动项（已开启 / 运行中）、残留文件（可清理大小），点击跳转。
- **占用最多的应用**：前 8 个第三方应用的横向条形列表，显示大小与占磁盘比例，悬停高亮，点击跳到该应用详情。
- **应用来源**：环形图（第三方 / Homebrew / App Store / 系统），悬停时中心显示该来源数量。
- **使用活跃度**：按上次使用时间分组（7 天内、30 天内、半年内、一年内、超过一年、未知）的柱状图，悬停显示该组合计大小；标题右侧显示超过一年未使用应用的占用。
- **建议**：磁盘空间不足、Homebrew 可更新、残留可清理、长期未使用的应用、守护进程过多等，按严重程度排序，点击跳转处理。
- **配色**：分类色按固定顺序（蓝、橙、青、黄），浅色/深色模式各自取值，已通过色盲区分度校验；「其他」与「未知」使用中性灰；状态色（警告/严重）只用于建议与警告标签，并始终配合图标与文字。
- 磁盘分段与来源环形图中，同一实体颜色一致（如 Homebrew 始终为橙色）。

### 5.1 已安装应用（InstalledApps）
- **扫描范围**：`/Applications`（含一级子目录，如 Utilities）、`~/Applications`、`/System/Applications`（含 Utilities）。
- **应用信息**：名称、Bundle ID、版本、图标、上次使用时间（Spotlight `kMDItemLastUsedDate`）。
- **标签**：
  - `系统`：位于 `/System/` 下，或 Bundle ID 为 `com.apple.*` 且非 App Store 安装 —— 系统应用禁止卸载；
  - `App Store`：包内存在 `Contents/_MASReceipt`；
  - `Homebrew`：与 Homebrew Cask 的 `app` artifact 匹配。
- **大小**：后台并发计算，结果写入 `AppSizeCacheEntity` 缓存。
- **关联文件分析**：在 `~/Library` 与 `/Library` 的常见目录（Application Support、Caches、Preferences、Containers、Group Containers、Saved Application State、Logs、HTTPStorages、WebKit、Cookies、LaunchAgents、LaunchDaemons、PrivilegedHelperTools）中，按 Bundle ID / 应用名匹配，列出每个路径及其大小。
- **卸载**：勾选需要删除的关联文件，确认后统一移到废纸篓（可恢复）；Homebrew 安装的应用改为调用 `brew uninstall --cask`；应用运行中时阻止卸载并提示。
- **列表交互**：搜索、分类筛选（全部/第三方/系统/App Store/Homebrew）、排序（名称/大小/上次使用）。

### 5.2 Homebrew（Homebrew）
- 通过 `brew info --json=v2 --installed` 一次获取所有 Formula 与 Cask 的安装版本、最新版本、是否过期、描述、主页。
- 分段切换 Formula / Cask，可筛选「仅显示可更新」。
- 详情：版本对比、是否主动安装（区分依赖）、安装目录与占用大小、主页链接。
- 操作：升级单个、全部升级、卸载、更新 Homebrew 源（`brew update`）。
- 所有命令通过流式日志面板展示实时输出，执行完毕后自动刷新列表。
- 未安装 Homebrew 时显示空状态与安装指引。

### 5.3 开机启动项（LaunchItems）
- **登录项**：通过 System Events 读取；关闭 = 移除并写入 `DisabledLoginItemEntity`，开启 = 重新添加并删除记录。
- **用户代理**：`~/Library/LaunchAgents`；**全局代理**：`/Library/LaunchAgents`；
  开关使用 `launchctl disable/enable gui/<uid>/<label>` 并 `bootout/bootstrap`。
- **系统守护进程**：`/Library/LaunchDaemons`，开关需要管理员权限（`system/<label>` 域）。
- 启用状态 = `launchctl print-disabled` 覆盖值优先，其次 plist 的 `Disabled` 键。
- 运行状态来自 `launchctl list`。
- 详情展示 Label、执行程序、参数、RunAtLoad、KeepAlive、plist 路径；可在访达中显示。
- 提供「打开系统登录项设置」入口，管理 macOS 13+ 的后台项目（SMAppService）。
- 苹果自身（`com.apple.*`）的启动项不展示，避免误操作。

### 5.4 残留文件（Leftovers）
- 扫描与关联文件分析相同的 Library 目录，从文件名中提取标识符（去掉 `.plist`/`.savedState`/`.binarycookies` 后缀、ByHost 的 UUID 后缀、Group Container 的 `group.` / TeamID 前缀）。
- 只处理反向域名格式的标识符（如 `com.vendor.app`），降低误报。
- 已安装集合 = 扫描到的应用 + Spotlight 全盘 `.app` 索引（含辅助程序）+ 正在运行的应用。
- 判定：标识符不以 `com.apple.` 等系统前缀开头，且与任何已安装 Bundle ID 不相等、不互为前缀，即为残留。
- 可信度：同厂商（前两段相同）仍有应用安装的，标记为「低可信度」。
- 按标识符分组，展示总大小、位置；支持多选移到废纸篓、忽略（持久化）、显示已忽略。
- 未授予「完全磁盘访问权限」时显示提示条，引导打开系统设置。

## 6. UI 设计

- 主窗口 `NavigationSplitView` 三栏：侧边栏（模块）→ 内容列（列表）→ 详情列。
- 侧边栏显示每个模块的数量徽标（如可更新数量、残留数量）。
- 工具栏只放与当前模块相关的主要操作：刷新、批量操作；破坏性操作必须二次确认。
- 次要操作放入右键菜单（在访达中显示、拷贝路径、忽略等），不额外增加按钮。
- 统一的标签组件（系统/App Store/Homebrew/可更新/低可信度），颜色语义一致。
- 长耗时任务显示进度；命令类任务显示实时日志面板。
- 支持浅色/深色模式（使用系统语义色）。

## 7. 打包

- `make build`：Release 编译
- `make app`：生成 `build/MacCask.app`，写入 Info.plist、图标，并用系统中现有的自签证书签名
- `make run`：打包并启动
- `make install`：复制到 `/Applications`
- `make clean`：清理
