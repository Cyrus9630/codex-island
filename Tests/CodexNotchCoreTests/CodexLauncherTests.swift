#if canImport(XCTest)
import XCTest
@testable import CodexNotchCore

final class CodexLauncherTests: XCTestCase {
    func testPrefersBundledCodexBinary() {
        let command = CodexLauncher.resolveCommand(
            existingPaths: [CodexLauncher.bundledCodexPath, "/opt/homebrew/bin/codex"],
            pathEnvironment: "/opt/homebrew/bin:/usr/bin"
        )
        XCTAssertEqual(command?.executablePath, CodexLauncher.bundledCodexPath)
        XCTAssertEqual(command?.arguments(for: "/tmp/P06"), ["app", "/tmp/P06"])
    }

    func testFallsBackToPathCodex() {
        let command = CodexLauncher.resolveCommand(
            existingPaths: ["/opt/homebrew/bin/codex"],
            pathEnvironment: "/opt/homebrew/bin:/usr/bin"
        )
        XCTAssertEqual(command?.executablePath, "/opt/homebrew/bin/codex")
    }

    func testBuildsThreadRoute() {
        XCTAssertEqual(
            CodexLauncher.threadURL(for: "thread-id")?.absoluteString,
            "codex://threads/thread-id"
        )
    }
}
#endif
