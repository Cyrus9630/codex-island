# Codex 岛台

一个轻量的 macOS 顶部凹口导航工具，用鼠标快速找到 Codex 本地项目和待查看的完成对话。

Swift + AppKit + SwiftUI 实现；正常使用无需 AI、网络请求或 API Key。

## 功能

- 鼠标移到屏幕顶部凹口，展开项目类别；悬停类别显示编号和名称，点击进入项目最近的有效对话。
- 默认四类：A 自动化、P 项目、C 案件、L 生活 / G 对话。类别名称和编号规则可在源码中调整。
- 第四栏第一项可使用名为 `G 导航` 的本地项目作为快捷入口，其后显示 L 项目。
- 项目支持右键底色标记：默认、反转、红、橙、黄、绿、蓝、紫；重启保留。
- “下一个”按钮导航本机用户未读完成对话，过滤子智能体和后台自动化记录。
- 启动和展开时刷新；展开期间每 2 秒后台刷新；收起后停止项目数据的周期读取。
- 顶部浮层右键关闭。应用不显示 Dock 图标，不自动开机启动。

## 系统要求

- macOS 14 或更新版本。
- Swift 6 工具链（Xcode 或 Command Line Tools）。
- 本机安装并使用 Codex 桌面应用。
- 系统自带的 `sqlite3` 与 `codesign`。

没有第三方包依赖。项目导航不需要辅助功能权限。

## 构建和使用

下载源码后，在仓库根目录运行：

```sh
swift run CodexNotchCoreChecks
./scripts/build-app.sh
open 'dist/Codex 岛台.app'
```

也可以直接运行 `swift run CodexNotchNavigator`。

项目名称按 `A/P/C/L + 数字` 识别，例如 `A01 示例自动化`、`P02 示例项目`、`L01 示例生活`。项目目录必须存在。点击可用对话使用 `codex://threads/<id>`；没有有效对话时尝试通过 Codex 命令打开工作区。

在“L 生活 / G 对话”中使用 G 入口，需要先在 Codex 中创建一个名称为 `G 导航` 的本地项目；无需固定项目 ID。

## 隐私与数据

应用只读访问运行者本机的以下文件：

- `~/.codex/.codex-global-state.json`：项目索引、归属映射及未读索引。
- `~/.codex/state_5.sqlite`：对话状态元数据，通过 SQLite 只读连接访问。

不读取对话正文，不修改 Codex 项目、数据库或已读记录。底色仅存于岛台自己的 macOS 偏好域 `io.github.codex-island.navigator`。打开对话后的已读变化由 Codex 自己管理。

仓库与源码包不包含真实项目清单、对话记录、截图、账号配置、缓存、密钥或开发机器的绝对路径。测试使用虚构数据。没有遥测和自动上传。

## 当前边界

- 当前发布版支持本地项目，尚未接入 ChatGPT 云项目或远程项目；G 是本地导航锚点，不是普通云对话列表。
- 使用 Codex 的本机内部数据结构，客户端更新可能导致兼容性变化；不属于 OpenAI 官方产品。
- 未读数据取决于 Codex 写入本机索引的时机，可能与客户端提示短暂不同；多账号和远程未读没有完整覆盖。
- “已清”指当前可导航的用户对话为空，不表示清除了内部子任务红点。
- 自行构建使用本机 ad-hoc 签名，没有 Developer ID 公证。本仓库发布源码，不提供已签名安装包。

## 开发入口

| 文件 | 职责 |
| --- | --- |
| `Sources/CodexNotchCore/Project.swift` | 类别、编号、自然排序 |
| `Sources/CodexNotchCore/ProjectStore.swift` | 项目发现和最新有效对话选择 |
| `Sources/CodexNotchCore/CodexLauncher.swift` | 对话链接与工作区启动 |
| `Sources/CodexNotchCore/UnreadThreadStore.swift` | 用户未读筛选和循环导航 |
| `Sources/CodexNotchNavigator/NotchController.swift` | 浮窗位置、悬停、后台刷新 |
| `Sources/CodexNotchNavigator/Views.swift` | 字号、项目行、标记配色 |
| `Sources/CodexNotchNavigator/ProjectMarkerStore.swift` | 底色持久化 |
| `Sources/CodexNotchCoreChecks/main.swift` | 不依赖 XCTest 的核心自检 |

更多维护信息见 [开发说明](docs/DEVELOPMENT.md)。
