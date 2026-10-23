import CodexNotchCore
import Foundation

enum CheckFailure: Error, CustomStringConvertible {
    case mismatch(String)

    var description: String {
        switch self {
        case let .mismatch(message): message
        }
    }
}

func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    guard condition() else { throw CheckFailure.mismatch(message) }
}

func runChecks() throws {
    let mixedData = #"{"local-projects":{"p1":{"id":"p1","name":"P06 示例项目","rootPaths":["/tmp/P06 示例项目"]},"a1":{"id":"a1","name":"A02 示例自动化","rootPaths":["/tmp/A02 示例自动化"]},"x1":{"id":"x1","name":"其他","rootPaths":["/tmp/其他"]}},"secret":"never-return"}"#.data(using: .utf8)!
    let mixedProjects = try ProjectStore.decodeProjects(from: mixedData)
    try expect(mixedProjects.map(\.code) == ["A02", "P06"], "仅应解析 A/P/C/L 编号项目")
    try expect(!mixedProjects.map(\.name).contains("never-return"), "不得读取 local-projects 之外的字段")

    let pathFallbackData = #"{"local-projects":{"l1":{"id":"l1","rootPaths":["/tmp/L01 示例生活"]}}}"#.data(using: .utf8)!
    let pathFallback = try ProjectStore.decodeProjects(from: pathFallbackData)
    try expect(pathFallback.first?.displayName == "L01 示例生活", "缺少名称时应使用目录名")

    let sortData = #"{"local-projects":{"p10":{"name":"P10 示例项目十","rootPaths":["/tmp/P10"]},"p2":{"name":"P02 示例项目二","rootPaths":["/tmp/P02"]},"p1":{"name":"P01 示例项目一","rootPaths":["/tmp/P01"]}}}"#.data(using: .utf8)!
    let sorted = try ProjectStore.decodeProjects(from: sortData)
    try expect(sorted.map(\.code) == ["P01", "P02", "P10"], "编号应按数字自然排序")

    let flexibleCodeData = #"{"local-projects":{"a1":{"name":"A1","rootPaths":["/tmp/A1"]},"p1234":{"name":"P1234 长编号项目","rootPaths":["/tmp/P1234"]}}}"#.data(using: .utf8)!
    let flexibleCodes = try ProjectStore.decodeProjects(from: flexibleCodeData)
    try expect(flexibleCodes.map(\.code) == ["A1", "P1234"], "项目编号不应限制为固定长度")
    try expect(flexibleCodes.map(\.name) == ["", "长编号项目"], "项目名称应允许省略")

    let visibilityData = #"{"project-order":["a02"],"local-projects":{"a02":{"name":"A02 示例自动化","rootPaths":["/tmp/A02"]},"p06":{"name":"P06 示例项目","rootPaths":["/tmp/example-user/Documents/P06 示例项目"]},"deleted-a5":{"name":"A5 已删除项目","rootPaths":["/tmp/example-user/.codex/.chatgpt-projects/A5"]}}}"#.data(using: .utf8)!
    let visible = try ProjectStore.decodeProjects(from: visibilityData)
    try expect(visible.map(\.code) == ["A02", "P06"], "应恢复未排序的真实项目，并隐藏旧兼容缓存中的删除项目")

    let threadData = #"{"project-order":["a02"],"local-projects":{"a02":{"name":"A02 示例自动化","rootPaths":["/tmp/A02"]}},"sidebar-project-thread-orders":{"a02":{"threadIds":["thread-old","thread-current"]}},"thread-project-assignments":{"thread-current":{"projectId":"a02"}}}"#.data(using: .utf8)!
    let activeThreads = [CodexThreadSummary(id: "thread-current", cwd: "/tmp/A02", recencyAtMs: 10)]
    let threaded = try ProjectStore.decodeProjects(from: threadData, activeThreads: activeThreads)
    try expect(threaded.first?.threadID == "thread-current", "应跳过失效任务并选择当前有效对话")

    let staleSidebar = #"{"local-projects":{"a01":{"name":"A01 示例自动化","rootPaths":["/tmp/A01"]}},"sidebar-project-thread-orders":{"a01":{"threadIds":["old"]}}}"#.data(using: .utf8)!
    let candidates = [
        CodexThreadSummary(id: "old", cwd: "/tmp/A01", recencyAtMs: 10),
        CodexThreadSummary(id: "new", cwd: "/tmp/A01", recencyAtMs: 20),
    ]
    let selected = try ProjectStore.decodeProjects(from: staleSidebar, activeThreads: candidates)
    try expect(selected.first?.threadID == "new", "不能锁在旧侧栏首项")
    let reversed = try ProjectStore.decodeProjects(from: staleSidebar, activeThreads: candidates.reversed())
    try expect(reversed.first?.threadID == "new", "选择结果不能依赖数据库返回顺序")

    let movedState = #"{"local-projects":{"a01":{"name":"A01 示例自动化","rootPaths":["/tmp/A01"]}},"sidebar-project-thread-orders":{"a01":{"threadIds":["moved"]}},"thread-project-assignments":{"moved":{"projectId":"p06"},"assigned":{"projectId":"a01"}}}"#.data(using: .utf8)!
    let moved = try ProjectStore.decodeProjects(from: movedState, activeThreads: [
        CodexThreadSummary(id: "moved", cwd: "/tmp/A01", recencyAtMs: 50),
        CodexThreadSummary(id: "assigned", cwd: "/tmp/other", recencyAtMs: 20),
    ])
    try expect(moved.first?.threadID == "assigned", "明确归属其他项目的对话不得通过旧侧栏或 cwd 串回 A01")
    let withoutValid = try ProjectStore.decodeProjects(from: staleSidebar)
    try expect(withoutValid.first?.threadID == nil, "没有有效数据时不能盲信旧侧栏对话")

    let filtered = try ProjectStore.decodeProjects(from: staleSidebar, activeThreads: [
        CodexThreadSummary(id: "old", cwd: "/tmp/A01", recencyAtMs: 90, threadSource: "subagent"),
        CodexThreadSummary(id: "automation", cwd: "/tmp/A01", recencyAtMs: 80, threadSource: "automation"),
        CodexThreadSummary(id: "child", cwd: "/tmp/A01", recencyAtMs: 70, isChild: 1),
        CodexThreadSummary(id: "unknown", cwd: "/tmp/A01", recencyAtMs: 60, threadSource: ""),
        CodexThreadSummary(id: "visible", cwd: "/tmp/A01", recencyAtMs: 20, threadSource: "agent_created_thread"),
        CodexThreadSummary(id: "user", cwd: "/tmp/A01", recencyAtMs: 10),
    ])
    try expect(filtered.first?.threadID == "visible", "项目定位须排除后台来源和父任务，同时保留可见的代理创建对话")

    let bundled = CodexLauncher.resolveCommand(
        existingPaths: [CodexLauncher.bundledCodexPath, "/opt/homebrew/bin/codex"],
        pathEnvironment: "/opt/homebrew/bin:/usr/bin"
    )
    try expect(bundled?.executablePath == CodexLauncher.bundledCodexPath, "应优先使用 Codex 桌面版内置命令")
    try expect(bundled?.arguments(for: "/tmp/P06") == ["app", "/tmp/P06"], "启动参数应保留项目路径")

    let fallback = CodexLauncher.resolveCommand(
        existingPaths: ["/opt/homebrew/bin/codex"],
        pathEnvironment: "/opt/homebrew/bin:/usr/bin"
    )
    try expect(fallback?.executablePath == "/opt/homebrew/bin/codex", "内置命令缺失时应回退到 PATH")
    try expect(
        CodexLauncher.threadURL(for: "00000000-0000-4000-8000-000000000001")?.absoluteString
            == "codex://threads/00000000-0000-4000-8000-000000000001",
        "对话链接必须使用 Codex 当前支持的 threads 路由"
    )
    let gNavigationData = #"{"project-order":["g-nav"],"local-projects":{"g-nav":{"name":"G  导航","rootPaths":["/tmp/G  导航"]}},"sidebar-project-thread-orders":{"g-nav":{"threadIds":["g-thread"]}}}"#.data(using: .utf8)!
    let gNavigation = try ProjectStore.decodeProjects(
        from: gNavigationData,
        activeThreads: [CodexThreadSummary(id: "g-thread", cwd: "/tmp/G  导航", recencyAtMs: 30)]
    )
    try expect(gNavigation.first?.code == "G", "G 导航应识别为固定导航项目")
    try expect(gNavigation.first?.threadID == "g-thread", "G 导航应自动跟随它的最新有效任务")
    let unreadState = #"{"electron-thread-read-state-v1":{"version":1,"unreadByIdentity":{"identity-a":{"local:host-a":["thread-old","thread-new","missing"]},"identity-b":{"local":["thread-new"],"remote:host":["remote-thread"]}}}}"#.data(using: .utf8)!
    let unreadRows = [
        UnreadThreadRow(id: "thread-old", title: "较早\n完成", recencyAtMs: 10, threadSource: "user"),
        UnreadThreadRow(id: "thread-new", title: "最近完成", recencyAtMs: 20, threadSource: "user"),
        UnreadThreadRow(id: "remote-thread", title: "远端完成", recencyAtMs: 30, threadSource: "user"),
    ]
    let unread = try UnreadThreadStore.decodeUnreadThreads(
        stateData: unreadState,
        rows: unreadRows
    )
    try expect(unread.map(\.id) == ["thread-new", "thread-old"], "红点应合并本机 host、去重、过滤失效与远端 ID，并按最近时间排序")
    try expect(unread.last?.title == "较早 完成", "红点标题应合并换行和多余空白")
    try expect(UnreadThreadStore.nextUnreadThread(in: unread, after: nil)?.id == "thread-new", "首次应打开最新红点")
    try expect(UnreadThreadStore.nextUnreadThread(in: unread, after: "thread-new")?.id == "thread-old", "连续点击应打开下一条红点")
    try expect(UnreadThreadStore.nextUnreadThread(in: unread, after: "thread-old")?.id == "thread-new", "到达末尾后应循环到第一条红点")

    let hiddenState = #"{"electron-thread-read-state-v1":{"version":1,"unreadByIdentity":{"account":{"local:host":["child","edge-child","automation","unknown","user"]}}}}"#.data(using: .utf8)!
    let hiddenRows = [
        UnreadThreadRow(id: "child", title: "后台子智能体", recencyAtMs: 90, threadSource: "subagent"),
        UnreadThreadRow(id: "edge-child", title: "有父任务的记录", recencyAtMs: 80, threadSource: "user", isChild: 1),
        UnreadThreadRow(id: "automation", title: "后台自动化", recencyAtMs: 70, threadSource: "automation"),
        UnreadThreadRow(id: "unknown", title: "来源不明", recencyAtMs: 60, threadSource: ""),
        UnreadThreadRow(id: "user", title: "自己的对话", recencyAtMs: 10, threadSource: "user"),
    ]
    let ownUnread = try UnreadThreadStore.decodeUnreadThreads(stateData: hiddenState, rows: hiddenRows)
    try expect(ownUnread.map(\.id) == ["user"], "即使后台任务更新，也只能跳转用户自己的对话")
    let onlyHidden = try UnreadThreadStore.decodeUnreadThreads(stateData: hiddenState, rows: Array(hiddenRows.dropLast()))
    try expect(onlyHidden.isEmpty, "只有子智能体等后台提醒时应显示已清")
    try expect(UnreadThreadStore.nextUnreadThread(in: onlyHidden, after: nil) == nil, "不应从隐藏任务回退跳转")

    var refreshState = UnreadRefreshState()
    try expect(refreshState.label == "读取中", "首次尚未读取不能显示已清")
    let checkedAt = Date(timeIntervalSince1970: 100)
    refreshState.receive(ownUnread, at: checkedAt)
    refreshState.fail("文件暂时不可读")
    try expect(refreshState.label == "重试" && refreshState.threads == ownUnread && refreshState.lastSuccess == checkedAt, "失败须保留旧数据及上次成功时间，不得伪装成零条")
    refreshState.receive([], at: Date(timeIntervalSince1970: 101))
    try expect(refreshState.label == "已清" && refreshState.error == nil, "只有成功读到零条才显示已清，重试成功应恢复状态")
}

do {
    if let flag = CommandLine.arguments.firstIndex(of: "--project"), flag + 1 < CommandLine.arguments.count {
        let code = CommandLine.arguments[flag + 1]
        guard let project = try ProjectStore().loadProjects().first(where: { $0.code == code }) else {
            throw CheckFailure.mismatch("没有找到项目 \(code)")
        }
        print("\(project.displayName)\n路径：\(project.path)\n目标：\(project.threadID ?? "仅工作区")")
    } else if CommandLine.arguments.contains("--live") {
        let projects = try ProjectStore().loadProjects()
        let unread = try UnreadThreadStore().loadUnreadThreads()
        let counts = ProjectCategory.allCases.map { category in
            "\(category.rawValue)=\(projects.count { $0.category == category })"
        }
        let threadCount = projects.count { $0.threadID != nil }
        print("本机可用项目：\(counts.joined(separator: " "))，合计 \(projects.count)，可直达项目对话 \(threadCount)，红点 \(unread.count)")
    } else {
        try runChecks()
        print("核心自检全部通过")
    }
} catch {
    FileHandle.standardError.write(Data("核心自检失败：\(error)\n".utf8))
    exit(1)
}
