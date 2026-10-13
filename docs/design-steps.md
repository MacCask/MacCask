# 开发步骤

- [已完成] Step 22：菜单栏/托盘图标 —— 单独设计 18pt 单色折叠 C，导出 SVG/PDF/1x/2x PNG；接入菜单栏打开/退出、显隐偏好和关闭窗口后的重新打开。十一项测试通过，包含 PDF 资源尺寸与实际 SwiftUI 标签可见性；打包内嵌 SwiftPM 资源包并通过签名校验。

- [已完成] Step 21：完整原生图标适配 —— 创建三层 SVG 的 Icon Composer `.icon`，通过 actool 编译系统外观与旧版 ICNS；补齐 SwiftPM 图标资源与平台加载接口。九项测试通过，含资源解码及 NSApplication 图标设置；已检查六种系统外观导出、Assets.car 中图层与外观、应用签名和开发启动。

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
- [已完成] Step 16：应用图标首轮设计 —— 四个独立概念预览与提示词已保存到 `docs/icon-concepts/`，覆盖应用匣、Cask、字母 C、应用矩阵方向；最终方案待用户选定。
- [已完成] Step 17：图标规格与打包接入 —— 用户选定 H「折叠」，已生成十项标准 iconset 表示及 ICNS；母版与导出保存在 `Resources/AppIcon/`，更新导出脚本与 Makefile 母版依赖。最新源图形态见 Step 20。
- [已完成] Step 20：平面图标源文件修正 —— 按用户要求移除预制圆角、立体材质与阴影，生成满版方形 H 源图；导出脚本取消圆角裁切，重新生成 PNG/ICNS 并验证尺寸、不透明画布和应用签名。
- [已完成] Step 18：图标极简方案重设计 —— 根据任务栏辨识度反馈，完成 E 开口 C、F 收纳匣、G 折线 M 三个纯色粗轮廓方案；原图与提示词保存在 `docs/icon-concepts/`，16/24/32/128 像素对比预览位于其 `review/` 子目录。用户选定后再执行 Step 17。
- [已完成] Step 19：图标造型与美感重设计 —— 完成 H 折叠、I 琥珀印记、J 归拢三个候选，原图和提示词保存在 `docs/icon-concepts/`，24/32/256 像素对比预览保存在 `review-round3/`；方案仍待用户选定，未接入应用。
