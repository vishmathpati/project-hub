import XCTest
@testable import ProjectHub

final class ConfigScanCacheTests: XCTestCase {
    override func setUp() {
        super.setUp()
        ConfigScanCache.directoryOverride = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProjectHubScanCache-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDown() {
        if let directory = ConfigScanCache.directoryOverride {
            try? FileManager.default.removeItem(at: directory)
        }
        ConfigScanCache.directoryOverride = nil
        super.tearDown()
    }

    func testRoundTripDoesNotUseUserConfigPaths() throws {
        let project = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProjectHubCacheProject-\(UUID().uuidString)", isDirectory: true)
        let result = CompatibilityScanResult(
            projectRoot: project.path,
            codexProfileSelection: nil,
            generatedAt: Date(timeIntervalSince1970: 1_700_000_000),
            matrix: [],
            servers: [],
            skills: [],
            skillSupport: [],
            plugins: [],
            settings: [],
            issues: []
        )

        ConfigScanCache.save(result)
        let loaded = try XCTUnwrap(ConfigScanCache.load(projectRoot: project.path))

        XCTAssertEqual(loaded.projectRoot, project.path)
        XCTAssertEqual(loaded.generatedAt, result.generatedAt)
        XCTAssertTrue(ConfigScanCache.fileURL(projectRoot: project.path, profileName: nil).path.contains("ProjectHubScanCache-"))
        XCTAssertFalse(ConfigScanCache.fileURL(projectRoot: project.path, profileName: nil).path.contains("/.claude/"))
    }

    func testGlobalAndProjectKeysAreDifferent() {
        XCTAssertNotEqual(
            ConfigScanCache.cacheKey(projectRoot: nil, profileName: nil),
            ConfigScanCache.cacheKey(projectRoot: "/tmp/app", profileName: nil)
        )
    }
}
