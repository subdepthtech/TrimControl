import XCTest
@testable import TrimControlCore

final class OpenFailureMessageTests: XCTestCase {
    func testUserMessageIsActionable() {
        let message = OpenFailureMessage.userMessage(
            for: NSError(
                domain: "TrimControlTests",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "nvim is missing"]
            )
        )

        XCTAssertTrue(message.contains("Open Settings"))
        XCTAssertTrue(message.contains("terminal backend"))
        XCTAssertTrue(message.contains("Neovim path"))
    }

    func testLogMessageRedactsLocalPaths() {
        let message = OpenFailureMessage.logMessage(
            for: NSError(
                domain: "TrimControlTests",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "failed for /Users/example/private/file.md"]
            )
        )

        XCTAssertFalse(message.contains("/Users/example"))
        XCTAssertFalse(message.contains("private/file.md"))
        XCTAssertTrue(message.contains("code 1"))
    }
}
