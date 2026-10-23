import Foundation

public struct UnreadRefreshState: Sendable {
    public private(set) var threads: [UnreadThread] = []
    public private(set) var lastSuccess: Date?
    public private(set) var error: String?

    public init() {}

    public mutating func receive(_ threads: [UnreadThread], at date: Date = Date()) {
        self.threads = threads
        lastSuccess = date
        error = nil
    }

    public mutating func fail(_ message: String) {
        error = message
    }

    public var label: String {
        if error != nil { return "重试" }
        if lastSuccess == nil { return "读取中" }
        return threads.isEmpty ? "已清" : "下一个"
    }
}
