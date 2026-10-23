#if canImport(XCTest)
import XCTest
@testable import CodexNotchCore

final class ProjectStoreTests: XCTestCase {
    func testLoadsOnlyLocalProjectsAndGroupsByPrefix() throws {
        let data = #"{"local-projects":{"p1":{"id":"p1","name":"P06 示例项目","rootPaths":["/tmp/P06 示例项目"]},"a1":{"id":"a1","name":"A02 示例自动化","rootPaths":["/tmp/A02 示例自动化"]},"x1":{"id":"x1","name":"其他","rootPaths":["/tmp/其他"]}},"secret":"never-return"}"#.data(using: .utf8)!

        let projects = try ProjectStore.decodeProjects(from: data)

        XCTAssertEqual(projects.map(\.code), ["A02", "P06"])
        XCTAssertEqual(projects.map(\.category), [.automation, .project])
        XCTAssertFalse(projects.map(\.name).contains("never-return"))
    }

    func testUsesPathNameWhenLabelIsMissing() throws {
        let data = #"{"local-projects":{"l1":{"id":"l1","rootPaths":["/tmp/L01 示例生活"]}}}"#.data(using: .utf8)!
        let projects = try ProjectStore.decodeProjects(from: data)
        XCTAssertEqual(projects.first?.code, "L01")
        XCTAssertEqual(projects.first?.name, "示例生活")
    }

    func testSortsNumericCodesNaturally() throws {
        let data = #"{"local-projects":{"p10":{"name":"P10 示例项目十","rootPaths":["/tmp/P10"]},"p2":{"name":"P02 示例项目二","rootPaths":["/tmp/P02"]},"p1":{"name":"P01 示例项目一","rootPaths":["/tmp/P01"]}}}"#.data(using: .utf8)!
        let projects = try ProjectStore.decodeProjects(from: data)
        XCTAssertEqual(projects.map(\.code), ["P01", "P02", "P10"])
    }

    func testAcceptsAnyLengthNumericCodeAndOptionalName() throws {
        let data = #"{"local-projects":{"a1":{"name":"A1","rootPaths":["/tmp/A1"]},"p1234":{"name":"P1234 长编号项目","rootPaths":["/tmp/P1234"]}}}"#.data(using: .utf8)!
        let projects = try ProjectStore.decodeProjects(from: data)

        XCTAssertEqual(projects.map(\.code), ["A1", "P1234"])
        XCTAssertEqual(projects.map(\.name), ["", "长编号项目"])
    }
}
#endif
