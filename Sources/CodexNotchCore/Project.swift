import Foundation

public enum ProjectCategory: String, CaseIterable, Sendable {
    case automation = "A"
    case project = "P"
    case client = "C"
    case life = "L"

    public var title: String {
        switch self {
        case .automation: "自动化"
        case .project: "项目"
        case .client: "案件"
        case .life: "生活"
        }
    }

    public var order: Int {
        switch self {
        case .automation: 0
        case .project: 1
        case .client: 2
        case .life: 3
        }
    }
}

public struct CodexProject: Identifiable, Equatable, Hashable, Sendable {
    public let id: String
    public let code: String
    public let name: String
    public let path: String
    public let threadID: String?
    public let category: ProjectCategory
    public let number: Int

    public init(
        id: String,
        code: String,
        name: String,
        path: String,
        threadID: String? = nil,
        category: ProjectCategory,
        number: Int
    ) {
        self.id = id
        self.code = code
        self.name = name
        self.path = path
        self.threadID = threadID
        self.category = category
        self.number = number
    }

    public var displayName: String {
        name.isEmpty ? code : "\(code) \(name)"
    }

    public static func parse(
        id: String,
        label: String?,
        path: String,
        threadID: String? = nil
    ) -> CodexProject? {
        let pathLabel = URL(fileURLWithPath: path).lastPathComponent
        let candidate = (label?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
            ? label!.trimmingCharacters(in: .whitespacesAndNewlines)
            : pathLabel

        let normalizedCandidate = candidate
            .split(whereSeparator: \Character.isWhitespace)
            .joined(separator: " ")
        if normalizedCandidate == "G 导航" {
            return CodexProject(
                id: id,
                code: "G",
                name: "导航",
                path: path,
                threadID: threadID,
                category: .life,
                number: -1
            )
        }

        guard let match = candidate.firstMatch(of: /^([APCL])(\d+)(?:\s+|$)/),
              let category = ProjectCategory(rawValue: String(match.1)),
              let number = Int(match.2)
        else {
            return nil
        }

        let code = "\(match.1)\(match.2)"
        let suffix = String(candidate.dropFirst(match.0.count))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return CodexProject(
            id: id,
            code: code,
            name: suffix,
            path: path,
            threadID: threadID,
            category: category,
            number: number
        )
    }

    public static func navigationSort(_ lhs: CodexProject, _ rhs: CodexProject) -> Bool {
        if lhs.category.order != rhs.category.order {
            return lhs.category.order < rhs.category.order
        }
        if lhs.number != rhs.number {
            return lhs.number < rhs.number
        }
        return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
    }
}
