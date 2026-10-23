import Foundation

public enum ProjectStoreError: LocalizedError {
    case invalidRoot
    case missingLocalProjects

    public var errorDescription: String? {
        switch self {
        case .invalidRoot: "Codex 项目索引不是有效的 JSON 对象。"
        case .missingLocalProjects: "Codex 项目索引中没有 local-projects。"
        }
    }
}

public struct ProjectStore {
    public static let defaultStateURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".codex/.codex-global-state.json")
    public static let defaultDatabaseURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".codex/state_5.sqlite")

    public let stateURL: URL
    public let databaseURL: URL
    private let fileManager: FileManager

    public init(
        stateURL: URL = ProjectStore.defaultStateURL,
        databaseURL: URL = ProjectStore.defaultDatabaseURL,
        fileManager: FileManager = .default
    ) {
        self.stateURL = stateURL
        self.databaseURL = databaseURL
        self.fileManager = fileManager
    }

    public func loadProjects() throws -> [CodexProject] {
        let data = try Data(contentsOf: stateURL, options: [.mappedIfSafe, .uncached])
        let activeThreads = loadActiveThreads()
        return try Self.decodeProjects(from: data, activeThreads: activeThreads)
            .filter { fileManager.fileExists(atPath: $0.path) }
            .sorted(by: CodexProject.navigationSort)
    }

    public static func decodeProjects(
        from data: Data,
        activeThreads: [CodexThreadSummary] = []
    ) throws -> [CodexProject] {
        let raw = try JSONSerialization.jsonObject(with: data)
        guard let root = raw as? [String: Any] else {
            throw ProjectStoreError.invalidRoot
        }
        guard let localProjects = root["local-projects"] as? [String: Any] else {
            throw ProjectStoreError.missingLocalProjects
        }

        let orderedIDs = root["project-order"] as? [String] ?? []
        let pinnedIDs = root["pinned-project-ids"] as? [String] ?? []
        let visibleIDs = orderedIDs + pinnedIDs.filter { !orderedIDs.contains($0) }
        let visibleIDSet = Set(visibleIDs)
        let unlistedLocalIDs = localProjects.keys.filter { projectID in
            guard !visibleIDSet.contains(projectID),
                  let value = localProjects[projectID] as? [String: Any],
                  let rootPaths = value["rootPaths"] as? [String],
                  let path = rootPaths.first
            else {
                return false
            }

            // Codex may remove a real project from project-order when its sidebar
            // placement changes. Keep such projects available in the navigator.
            // Old ChatGPT compatibility records live in this cache directory and
            // should stay hidden unless Codex explicitly lists or pins them.
            return !isLegacyChatGPTCachePath(path)
        }.sorted()
        let projectIDs = visibleIDs + unlistedLocalIDs
        let sidebarOrders = root["sidebar-project-thread-orders"] as? [String: Any] ?? [:]
        let assignments = root["thread-project-assignments"] as? [String: Any] ?? [:]
        let visibleThreads = activeThreads.filter(\.isNavigable).sorted {
            if $0.recencyAtMs != $1.recencyAtMs { return $0.recencyAtMs > $1.recencyAtMs }
            return $0.id > $1.id
        }

        var decoded: [CodexProject] = []
        decoded.reserveCapacity(projectIDs.count)

        for dictionaryKey in projectIDs {
            guard let rawValue = localProjects[dictionaryKey] else { continue }
            guard let value = rawValue as? [String: Any],
                  let rootPaths = value["rootPaths"] as? [String],
                  let path = rootPaths.first,
                  !path.isEmpty
            else {
                continue
            }

            let id = (value["id"] as? String) ?? dictionaryKey
            let label = value["name"] as? String
            let sidebarThreadIDs = ((sidebarOrders[dictionaryKey] as? [String: Any])?["threadIds"] as? [String]) ?? []
            let threadID = resolveThreadID(
                projectID: dictionaryKey,
                path: path,
                sidebarThreadIDs: sidebarThreadIDs,
                assignments: assignments,
                activeThreads: visibleThreads
            )
            if let project = CodexProject.parse(id: id, label: label, path: path, threadID: threadID) {
                decoded.append(project)
            }
        }

        return decoded.sorted(by: CodexProject.navigationSort)
    }

    private static func isLegacyChatGPTCachePath(_ path: String) -> Bool {
        let normalizedPath = URL(fileURLWithPath: path).standardizedFileURL.path
        return normalizedPath.contains("/.codex/.chatgpt-projects/")
    }

    private static func resolveThreadID(
        projectID: String,
        path: String,
        sidebarThreadIDs: [String],
        assignments: [String: Any],
        activeThreads: [CodexThreadSummary]
    ) -> String? {
        let normalizedPath = URL(fileURLWithPath: path).standardizedFileURL.path
        let sidebarIDs = Set(sidebarThreadIDs)
        // Sidebar order is a membership hint, not a recency ranking. Explicit
        // reassignment must also prevent cwd/sidebar hints from opening a moved chat.
        return activeThreads.first(where: { thread in
            if let assignment = assignments[thread.id] as? [String: Any],
               let assignedProjectID = assignment["projectId"] as? String,
               !assignedProjectID.isEmpty {
                return assignedProjectID == projectID
            }
            return sidebarIDs.contains(thread.id)
                || URL(fileURLWithPath: thread.cwd).standardizedFileURL.path == normalizedPath
        })?.id
    }

    private func loadActiveThreads() -> [CodexThreadSummary] {
        guard fileManager.fileExists(atPath: databaseURL.path),
              fileManager.isExecutableFile(atPath: "/usr/bin/sqlite3")
        else {
            return []
        }

        let query = """
        SELECT id, cwd, recency_at_ms, coalesce(thread_source, '') AS thread_source,
               EXISTS(SELECT 1 FROM thread_spawn_edges e WHERE e.child_thread_id = threads.id) AS is_child
        FROM threads
        WHERE archived = 0 AND preview <> ''
          AND thread_source IN ('user', 'agent_created_thread')
          AND NOT EXISTS(SELECT 1 FROM thread_spawn_edges e WHERE e.child_thread_id = threads.id)
        ORDER BY recency_at_ms DESC, id DESC;
        """
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        process.arguments = ["-readonly", "-json", databaseURL.path, query]
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            let data = output.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return [] }
            return (try? JSONDecoder().decode([CodexThreadSummary].self, from: data)) ?? []
        } catch {
            return []
        }
    }
}

public struct CodexThreadSummary: Codable, Equatable, Sendable {
    public let id: String
    public let cwd: String
    public let recencyAtMs: Int64
    public let threadSource: String
    public let isChild: Int

    public var isNavigable: Bool {
        isChild == 0 && (threadSource == "user" || threadSource == "agent_created_thread")
    }

    enum CodingKeys: String, CodingKey {
        case id, cwd
        case recencyAtMs = "recency_at_ms"
        case threadSource = "thread_source"
        case isChild = "is_child"
    }

    public init(id: String, cwd: String, recencyAtMs: Int64, threadSource: String = "user", isChild: Int = 0) {
        self.id = id
        self.cwd = cwd
        self.recencyAtMs = recencyAtMs
        self.threadSource = threadSource
        self.isChild = isChild
    }
}
