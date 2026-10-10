# 开发步骤

- [已完成] Step 1：工程骨架 —— Package.swift、Makefile、Info.plist、图标脚本、自签名打包
- [已完成] Step 2：平台抽象层 —— CommandRunning / PrivilegedCommandRunning / FileTrashing / LoginItemManaging / SystemIntegrating 协议及 macOS 实现
- [已完成] Step 3：通用工具 —— 大小计算、大小格式化、Library 目录定义、标识符解析与匹配、Shell 转义、Bundle 信息读取
- [已完成] Step 4：数据库 —— SwiftData 容器、AppSizeCache / IgnoredLeftover / DisabledLoginItem 实体（带索引）及仓储
- [已完成] Step 5：主界面 —— 三栏导航、侧边栏徽标、通用 UI 组件（标签、空状态、命令日志面板、权限提示条）
- [已完成] Step 6：已安装应用模块 —— 扫描、标签（系统/App Store/Homebrew）、大小缓存、关联文件分析、卸载
- [已完成] Step 7：Homebrew 模块 —— 列表、版本对比、升级/全部升级/卸载/更新源、流式日志
- [已完成] Step 8：启动项模块 —— 登录项、用户/全局代理、系统守护进程的查看与开关
- [已完成] Step 9：残留文件模块 —— 扫描、可信度、分组、移到废纸篓、忽略
- [已完成] Step 10：单元测试 —— 标识符解析/匹配、已安装索引、launchctl 输出解析、brew JSON 解析、转义工具（`swift test`）
- [已完成] Step 11：真机数据校准 —— 显示名改用访达本地化名称；关联文件按文件名/CFBundleName/可执行名匹配；排除 SDK 与工具链共享缓存；程序仍存在的 launchd 项不计为残留
- [已完成] Step 12：`swift run` 直接运行修复 —— 增加 AppDelegate，启动时设为前台应用并激活窗口
- [已完成] Step 13：概览分析页 —— 磁盘占用分段条、状态磁贴、占用最多的应用、应用来源环形图、使用活跃度、优化建议；平台接口增加磁盘容量读取；图表配色统一到 ChartPalette
- [已完成] Step 14：概览页性能优化 —— 应用图标按显示尺寸缓存缩略图；条形列表悬停状态下沉到行；环形图/柱状图选择值只在分块变化时更新并加入过渡动画；自适应布局改用 AnyLayout 避免重复测量；磁盘分段每次刷新只计算一次
- [已完成] Step 15：侧边栏徽标补全 —— 应用程序显示第三方应用数，启动项显示已开启数
