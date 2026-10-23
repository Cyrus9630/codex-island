# 开发说明

## 架构

`CodexNotchCore` 负责只读数据加载、目标选择和启动。`CodexNotchNavigator` 用两个 AppKit `NSPanel` 管理顶部岛台和下拉项目列表，SwiftUI 绘制界面。

项目候选对话按最近时间统一排序，旧侧栏顺序只提供归属线索，不覆盖最新时间。明确分配到其他项目的对话不会通过旧目录回退选回；数据库没有有效记录时不使用未经验证的旧对话 ID。

项目导航允许来源为 `user` 或 `agent_created_thread` 且没有父任务的有效对话；未读导航更严格，只允许 `user`，排除子任务与自动化。两套筛选规则请分别维护。

## 验证

```sh
swift run CodexNotchCoreChecks
swift build --product CodexNotchNavigator -c release
./scripts/build-app.sh
plutil -lint 'dist/Codex 岛台.app/Contents/Info.plist'
codesign --verify --deep --strict 'dist/Codex 岛台.app'
```

核心自检全部使用内存中的虚构索引，不读取本机个人项目。`swift test` 在缺少 XCTest 模块的工具链中可能执行零项，不能把这种结果记为测试通过；请始终运行核心自检。

可选的本机诊断会读取实际元数据，输出不要上传到公开仓库：

```sh
swift run CodexNotchCoreChecks --project A01
swift run CodexNotchCoreChecks --live
```

## 手工验收

1. 悬停顶部展开，再悬停四类，列表与屏幕边界正确。
2. 点项目进入最新有效对话；没有有效对话时使用工作区回退。
3. 右键改色、退出并重开，确认标记保持。
4. G 导航存在时位于第四栏第一行。
5. 红点不包含子智能体，重复点击按有效未读列表循环。
6. “已清”可手动刷新，错误保留旧值，展开时显示成功读取时间。
7. 顶部右键可退出。

## 发布检查

仅发布源码、通用图标、构建脚本及虚构测试。不得提交本机 `.codex` 文件、SQLite、日志、截图、用户偏好、访问凭据、构建产物或包含个人信息的历史提交。更新前检查 Git 暂存清单与提交元数据。
