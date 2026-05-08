import XCTest
@testable import TrimControlCore

final class ExternalOpenerCatalogTests: XCTestCase {
    func testDefaultRulesCoverCompanionFileCategories() {
        let rules = ExternalOpenerCatalog.defaultRules
        let categories = Set(rules.map(\.categoryName))

        XCTAssertTrue(categories.contains("PDF Documents"))
        XCTAssertTrue(categories.contains("Images"))
        XCTAssertTrue(categories.contains("Videos"))
        XCTAssertTrue(categories.contains("Archives"))
        XCTAssertTrue(categories.contains("Spreadsheets"))
        XCTAssertTrue(categories.contains("Presentations"))
        XCTAssertTrue(categories.contains("Documents"))
        XCTAssertTrue(categories.contains("Web Files"))
        XCTAssertTrue(categories.contains("Code Files"))

        XCTAssertTrue(rules.contains { $0.extensions.contains("pdf") })
        XCTAssertTrue(rules.contains { $0.extensions.contains("png") })
        XCTAssertTrue(rules.contains { $0.extensions.contains("mp4") })
        XCTAssertTrue(rules.contains { $0.extensions.contains("zip") })
        XCTAssertTrue(rules.contains { $0.extensions.contains("xlsx") })
        XCTAssertTrue(rules.contains { $0.extensions.contains("pptx") })
    }

    func testDefaultRulesStartAsSystemDefaultRoutes() {
        XCTAssertFalse(ExternalOpenerCatalog.defaultRules.isEmpty)

        for rule in ExternalOpenerCatalog.defaultRules {
            XCTAssertNil(rule.selectedAppBundleIdentifier)
            XCTAssertNil(rule.selectedAppDisplayName)
            XCTAssertTrue(rule.usesSystemDefault)
            XCTAssertEqual(rule.status, .systemDefault)
        }
    }

    func testExternalCompanionTypesDoNotBecomeNeovimFileTypeDefaults() {
        let neovimExtensions = Set(FileTypeCatalog.allExtensions.map { $0.lowercased() })

        XCTAssertFalse(neovimExtensions.contains("pdf"))
        XCTAssertFalse(neovimExtensions.contains("png"))
        XCTAssertFalse(neovimExtensions.contains("jpg"))
        XCTAssertFalse(neovimExtensions.contains("mp4"))
        XCTAssertFalse(neovimExtensions.contains("zip"))
        XCTAssertFalse(neovimExtensions.contains("xlsx"))
        XCTAssertFalse(neovimExtensions.contains("pptx"))
        XCTAssertFalse(neovimExtensions.contains("docx"))
    }

    func testRouterKeepsNeovimCatalogFilesInNeovimWhenExternalRuleUsesSystemDefault() {
        let suiteName = "ExternalOpenerRouterTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let router = ExternalOpenerRouter(defaults: defaults)
        let result = router.partition(fileURLs: [
            URL(fileURLWithPath: "/tmp/example.pdf"),
            URL(fileURLWithPath: "/tmp/example.html"),
            URL(fileURLWithPath: "/tmp/example.md"),
        ])

        XCTAssertEqual(result.externalFileURLs.map(\.path), ["/tmp/example.pdf"])
        XCTAssertEqual(result.neovimFileURLs.map(\.path), ["/tmp/example.html", "/tmp/example.md"])
    }

    func testRouterAllowsCustomExternalOverrideForOverlappingCodeOrWebExtensions() {
        let suiteName = "ExternalOpenerRouterTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        var rules = ExternalOpenerCatalog.defaultRules
        let webRuleIndex = rules.firstIndex { $0.categoryName == "Web Files" }!
        rules[webRuleIndex].usesSystemDefault = false
        rules[webRuleIndex].selectedAppBundleIdentifier = "com.apple.Safari"
        rules[webRuleIndex].selectedAppDisplayName = "Safari"
        rules[webRuleIndex].status = .custom
        ExternalOpenerDefaults.save(rules, to: defaults)

        let router = ExternalOpenerRouter(defaults: defaults)
        let result = router.partition(fileURLs: [
            URL(fileURLWithPath: "/tmp/example.html"),
        ])

        XCTAssertEqual(result.externalFileURLs.map(\.path), ["/tmp/example.html"])
        XCTAssertTrue(result.neovimFileURLs.isEmpty)
    }

    func testDefaultApplicatorResolvesPdfLaunchServicesContentType() {
        let pdfRule = ExternalOpenerCatalog.defaultRules.first { $0.categoryName == "PDF Documents" }!

        XCTAssertEqual(
            ExternalOpenerDefaultApplicator.contentTypeIdentifiers(for: pdfRule),
            ["com.adobe.pdf"]
        )
    }

    func testExternalOpenerDefaultsPreservePreviousHandlerMap() {
        let suiteName = "ExternalOpenerDefaultsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        var rules = ExternalOpenerCatalog.defaultRules
        let pdfRuleIndex = rules.firstIndex { $0.categoryName == "PDF Documents" }!
        rules[pdfRuleIndex].previousHandlerBundleIdentifiersByContentType = [
            "com.adobe.pdf": "com.apple.Preview"
        ]

        ExternalOpenerDefaults.save(rules, to: defaults)

        let restored = ExternalOpenerDefaults.rules(from: defaults)
        let pdfRule = restored.first { $0.categoryName == "PDF Documents" }!
        XCTAssertEqual(
            pdfRule.previousHandlerBundleIdentifiersByContentType["com.adobe.pdf"],
            "com.apple.Preview"
        )
    }

    func testRestorationTargetPrefersStoredPreviousHandler() {
        XCTAssertEqual(
            ExternalOpenerDefaultApplicator.restorationTarget(
                storedPreviousHandler: "com.apple.Preview",
                selectedBundleIdentifier: "com.example.CustomPDF",
                availableHandlers: ["com.example.CustomPDF", "com.apple.Preview"]
            ),
            "com.apple.Preview"
        )
    }

    func testRestorationTargetFallsBackToAvailableNonCustomHandler() {
        XCTAssertEqual(
            ExternalOpenerDefaultApplicator.restorationTarget(
                storedPreviousHandler: nil,
                selectedBundleIdentifier: "com.example.CustomPDF",
                availableHandlers: ["com.example.CustomPDF", "com.apple.Preview"]
            ),
            "com.apple.Preview"
        )
    }

    func testSystemDefaultRuleDoesNotRequireRestoration() {
        let pdfRule = ExternalOpenerCatalog.defaultRules.first { $0.categoryName == "PDF Documents" }!

        XCTAssertFalse(ExternalOpenerDefaultApplicator.requiresRestoration(rule: pdfRule))
    }
}
