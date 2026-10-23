import Foundation

public enum UnreadThreadStoreError: LocalizedError, Equatable {
    case invalidRoot
    case missingUnreadState
    case databaseUnavailable
    case databaseReadFailed

    public var errorDescription: String? {
        switch self {
        case .invalidRoot:
            "Codex 全局状态不是有效的 JSON 对象。"
        case .missingUnreadState:
            "Codex 全局状态中没有红点对话索引。"
        case .databaseUnavailable:
            "没有找到 Codex 对话数据库。"
        case .databaseReadFailed:
            "无法读取 Codex 红点对话。"
        }
    }
}

public struct UnreadThread: Identifiable, Equatable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let recencyAtMs: Int64

    public init(id: String, title: String, recencyAtMs: Int64) {
        self.id = id
        self.title = title
        self.recencyAtMs = recencyAtMs
    }
}

public struct UnreadThreadRow: Codable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let recencyAtMs: Int64
    public let threadSource: String
    public let isChild: Int

    enum CodingKeys: String, CodingKey {
        case id, title
        case recencyAtMs = "recency_at_ms"
        case threadSource = "thread_source"
        case isChild = "is_child"
    }

    public init(id: String, title: String, recencyAtMs: Int64, threadSource: String, isChild: Int = 0) {
        self.id = id
        self.title = title
        self.recencyAtMs = recencyAtMs
        self.threadSource = threadSource
        self.isChild = isChild
    }
}

public struct UnreadThreadStore {
    public static let defaultStateURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".codex/.codex-global-state.json")
    public static let defaultDatabaseURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".codex/state_5.sqlite")

    public let stateURL: URL
    public let databaseURL: URL
    private let fileManager: FileManager

    public init(
        stateURL: URL = UnreadThreadStore.defaultStateURL,
        databaseURL: URL = UnreadThreadStore.defaultDatabaseURL,
        fileManager: FileManager = .default
    ) {
        self.stateURL = stateURL
        self.databaseURL = databaseURL
        self.fileManager = fileManager
    }

    public func loadUnreadThreads() throws -> [UnreadThread] {
        let stateData = try Data(contentsOf: stateURL, options: [.mappedIfSafe, .uncached])
        let rows = try loadVisibleThreads()
        return try Self.decodeUnreadThreads(stateData: stateData, rows: rows)
    }

    public static func decodeUnreadThreads(
        stateData: Data,
        rows: [UnreadThreadRow]
    ) throws -> [UnreadThread] {
        let unreadIDs = try decodeLocalUnreadThreadIDs(from: stateData)
        return rows
            .filter { unreadIDs.contains($0.id) && $0.threadSource == "user" && $0.isChild == 0 }
            .sorted {
                if $0.recencyAtMs != $1.recencyAtMs {
                    return $0.recencyAtMs > $1.recencyAtMs
                }
                return $0.id > $1.id
            }
            .map {
                UnreadThread(
                    id: $0.id,
                    title: normalizedTitle($0.title),
                    recencyAtMs: $0.recencyAtMs
                )
            }
    }

    public static func decodeLocalUnreadThreadIDs(from data: Data) throws -> Set<String> {
        let raw = try JSONSerialization.jsonObject(with: data)
        guard let root = raw as? [String: Any] else {
            throw UnreadThreadStoreError.invalidRoot
        }
        guard let readState = root["electron-thread-read-state-v1"] as? [String: Any],
              let unreadByIdentity = readState["unreadByIdentity"] as? [String: Any]
        else {
            throw UnreadThreadStoreError.missingUnreadState
        }

        var ids = Set<String>()
        for rawHosts in unreadByIdentity.values {
            guard let hosts = rawHosts as? [String: Any] else { continue }
            for (hostID, rawIDs) in hosts
            where hostID == "local" || hostID.hasPrefix("local:") {
                guard let hostIDs = rawIDs as? [String] else { continue }
                ids.formUnion(hostIDs)
            }
        }
        return ids
    }

    public static func nextUnreadThread(
        in threads: [UnreadThread],
        after threadID: String?
    ) -> UnreadThread? {
        guard !threads.isEmpty else { return nil }
        guard let threadID,
              let currentIndex = threads.firstIndex(where: { $0.id == threadID })
        else {
            return threads.first
        }
        return threads[(currentIndex + 1) % threads.count]
    }

    private static func normalizedTitle(_ title: String) -> String {
        let normalized = title
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
        return normalized.isEmpty ? "未命名对话" : normalized
    }

    private func loadVisibleThreads() throws -> [UnreadThreadRow] {
        guard fileManager.fileExists(atPath: databaseURL.path),
              fileManager.isExecutableFile(atPath: "/usr/bin/sqlite3")
        else {
            throw UnreadThreadStoreError.databaseUnavailable
        }

        let query = """
        SELECT
            id,
            substr(
                replace(
                    replace(
                        coalesce(nullif(name, ''), nullif(title, ''), '未命名对话'),
                        char(10),
                        ' '
                    ),
                    char(13),
                    ' '
                ),
                1,
                160
            ) AS title,
            recency_at_ms,
            thread_source,
            EXISTS(SELECT 1 FROM thread_spawn_edges e WHERE e.child_thread_id = threads.id) AS is_child
        FROM threads
        WHERE archived = 0
          AND preview <> ''
          AND thread_source = 'user'
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
            guard process.terminationStatus == 0 else {
                throw UnreadThreadStoreError.databaseReadFailed
            }
            if data.isEmpty { return [] }
            return try JSONDecoder().decode([UnreadThreadRow].self, from: data)
        } catch let error as UnreadThreadStoreError {
            throw error
        } catch {
            throw UnreadThreadStoreError.databaseReadFailed
        }
    }
}
