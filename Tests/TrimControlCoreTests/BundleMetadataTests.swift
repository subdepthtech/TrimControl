import XCTest
@testable import TrimControlCore

final class BundleMetadataTests: XCTestCase {
    func testInfoPlistUsesDefaultReleaseVersion() throws {
        try withTemporaryEnvironment(version: nil, buildNumber: nil) {
            let plist = try decodedInfoPlist()

            XCTAssertEqual(plist["CFBundleShortVersionString"] as? String, "0.1.0")
            XCTAssertEqual(plist["CFBundleVersion"] as? String, "1")
        }
    }

    func testInfoPlistUsesReleaseEnvironmentVersion() throws {
        try withTemporaryEnvironment(version: "1.2.3", buildNumber: "456") {
            let plist = try decodedInfoPlist()

            XCTAssertEqual(plist["CFBundleShortVersionString"] as? String, "1.2.3")
            XCTAssertEqual(plist["CFBundleVersion"] as? String, "456")
        }
    }

    func testInfoPlistDeclaresBackgroundAgentApp() throws {
        let plist = try decodedInfoPlist()

        XCTAssertEqual(plist["LSUIElement"] as? Bool, true)
        XCTAssertNil(plist["LSBackgroundOnly"])
    }

    private func decodedInfoPlist() throws -> [String: Any] {
        let data = try BundleMetadata.infoPlistData()
        let plist = try PropertyListSerialization.propertyList(
            from: data,
            options: [],
            format: nil
        )
        return try XCTUnwrap(plist as? [String: Any])
    }

    private func withTemporaryEnvironment(
        version: String?,
        buildNumber: String?,
        run block: () throws -> Void
    ) throws {
        let previousVersion = environmentValue(named: "TRIMCONTROL_VERSION")
        let previousBuildNumber = environmentValue(named: "TRIMCONTROL_BUILD_NUMBER")

        setEnvironmentValue(version, forName: "TRIMCONTROL_VERSION")
        setEnvironmentValue(buildNumber, forName: "TRIMCONTROL_BUILD_NUMBER")

        defer {
            setEnvironmentValue(previousVersion, forName: "TRIMCONTROL_VERSION")
            setEnvironmentValue(previousBuildNumber, forName: "TRIMCONTROL_BUILD_NUMBER")
        }

        try block()
    }

    private func setEnvironmentValue(_ value: String?, forName name: String) {
        if let value {
            setenv(name, value, 1)
        } else {
            unsetenv(name)
        }
    }

    private func environmentValue(named name: String) -> String? {
        guard let value = getenv(name) else {
            return nil
        }
        return String(cString: value)
    }
}
