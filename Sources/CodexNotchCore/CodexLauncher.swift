import Foundation

public enum CodexLauncherError: LocalizedError {
    case commandUnavailable
    case threadOpenFailed

    public var errorDescription: String? {
        switch self {
        case .commandUnavailable:
            "没有找到 Codex 桌面启动命令。"
        case .threadOpenFailed:
            "Codex 没有接受这个对话链接。"
        }
    }
}

public struct CodexLaunchCommand: Equatable, Sendable {
    public let executablePath: String

    public init(executablePath: String) {
        self.executablePath = executablePath
    }

    public func arguments(for projectPath: String) -> [String] {
        ["app", projectPath]
    }
}

public struct CodexLauncher: Sendable {
    public static let bundledCodexPath = "/Applications/ChatGPT.app/Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex"
    public static let bundledCodexPaths = [
        bundledCodexPath,
        "/Applications/Codex.app/Contents/Resources/codex",
        "/Applications/ChatGPT.app/Contents/Resources/codex",
    ]

    public init() {}

    public static func threadURL(for threadID: String) -> URL? {
        URL(string: "codex://threads/\(threadID)")
    }

    public static func resolveCommand(
        existingPaths: Set<String>,
        pathEnvironment: String? = ProcessInfo.processInfo.environment["PATH"]
    ) -> CodexLaunchCommand? {
        if let bundled = bundledCodexPaths.first(where: { existingPaths.contains($0) }) {
            return CodexLaunchCommand(executablePath: bundled)
        }

        let pathEntries = (pathEnvironment ?? "").split(separator: ":").map(String.init)
        for directory in pathEntries {
            let candidate = URL(fileURLWithPath: directory).appendingPathComponent("codex").path
            if existingPaths.contains(candidate) {
                return CodexLaunchCommand(executablePath: candidate)
            }
        }
        return nil
    }

    public func open(project: CodexProject) throws {
        if let threadID = project.threadID {
            try open(threadID: threadID)
            return
        }

        let fileManager = FileManager.default
        let candidates = Set(Set(
            Self.bundledCodexPaths +
            ((ProcessInfo.processInfo.environment["PATH"] ?? "")
                .split(separator: ":")
                .map { URL(fileURLWithPath: String($0)).appendingPathComponent("codex").path })
        ).filter { fileManager.isExecutableFile(atPath: $0) })

        guard let command = Self.resolveCommand(existingPaths: candidates) else {
            throw CodexLauncherError.commandUnavailable
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: command.executablePath)
        process.arguments = command.arguments(for: project.path)
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
    }

    public func open(threadID: String) throws {
        guard let threadURL = Self.threadURL(for: threadID) else {
            throw CodexLauncherError.threadOpenFailed
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = [threadURL.absoluteString]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw CodexLauncherError.threadOpenFailed
        }
    }

}
