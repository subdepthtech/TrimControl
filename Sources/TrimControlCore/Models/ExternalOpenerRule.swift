import Foundation

public enum ExternalOpenerStatus: String, Codable, Hashable, Sendable {
    case systemDefault
    case custom
    case missingApp
    case needsPermission
}

public struct ExternalOpenerRule: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var categoryName: String
    public var extensions: [String]
    public var selectedAppBundleIdentifier: String?
    public var selectedAppDisplayName: String?
    public var selectedAppIconPath: String?
    public var usesSystemDefault: Bool
    public var status: ExternalOpenerStatus
    public var previousHandlerBundleIdentifiersByContentType: [String: String]

    public init(
        id: UUID,
        categoryName: String,
        extensions: [String],
        selectedAppBundleIdentifier: String? = nil,
        selectedAppDisplayName: String? = nil,
        selectedAppIconPath: String? = nil,
        usesSystemDefault: Bool = true,
        status: ExternalOpenerStatus = .systemDefault,
        previousHandlerBundleIdentifiersByContentType: [String: String] = [:]
    ) {
        self.id = id
        self.categoryName = categoryName
        self.extensions = extensions
        self.selectedAppBundleIdentifier = selectedAppBundleIdentifier
        self.selectedAppDisplayName = selectedAppDisplayName
        self.selectedAppIconPath = selectedAppIconPath
        self.usesSystemDefault = usesSystemDefault
        self.status = status
        self.previousHandlerBundleIdentifiersByContentType = previousHandlerBundleIdentifiersByContentType
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case categoryName
        case extensions
        case selectedAppBundleIdentifier
        case selectedAppDisplayName
        case selectedAppIconPath
        case usesSystemDefault
        case status
        case previousHandlerBundleIdentifiersByContentType
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        categoryName = try container.decode(String.self, forKey: .categoryName)
        extensions = try container.decode([String].self, forKey: .extensions)
        selectedAppBundleIdentifier = try container.decodeIfPresent(String.self, forKey: .selectedAppBundleIdentifier)
        selectedAppDisplayName = try container.decodeIfPresent(String.self, forKey: .selectedAppDisplayName)
        selectedAppIconPath = try container.decodeIfPresent(String.self, forKey: .selectedAppIconPath)
        usesSystemDefault = try container.decode(Bool.self, forKey: .usesSystemDefault)
        status = try container.decode(ExternalOpenerStatus.self, forKey: .status)
        previousHandlerBundleIdentifiersByContentType = try container.decodeIfPresent(
            [String: String].self,
            forKey: .previousHandlerBundleIdentifiersByContentType
        ) ?? [:]
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(categoryName, forKey: .categoryName)
        try container.encode(extensions, forKey: .extensions)
        try container.encodeIfPresent(selectedAppBundleIdentifier, forKey: .selectedAppBundleIdentifier)
        try container.encodeIfPresent(selectedAppDisplayName, forKey: .selectedAppDisplayName)
        try container.encodeIfPresent(selectedAppIconPath, forKey: .selectedAppIconPath)
        try container.encode(usesSystemDefault, forKey: .usesSystemDefault)
        try container.encode(status, forKey: .status)
        try container.encode(
            previousHandlerBundleIdentifiersByContentType,
            forKey: .previousHandlerBundleIdentifiersByContentType
        )
    }

    public var displayExtensions: String {
        extensions.map { ".\($0)" }.joined(separator: ", ")
    }

    public var selectedAppSummary: String {
        if usesSystemDefault {
            return "macOS system default"
        }

        return selectedAppDisplayName ?? selectedAppBundleIdentifier ?? "No app selected"
    }
}

public enum ExternalOpenerCatalog {
    public static let defaultRules: [ExternalOpenerRule] = [
        rule("7AF70000-2E4F-4B56-8D83-000000000001", "PDF Documents", ["pdf"]),
        rule("7AF70000-2E4F-4B56-8D83-000000000002", "Images", [
            "png", "jpg", "jpeg", "gif", "webp", "heic", "svg",
        ]),
        rule("7AF70000-2E4F-4B56-8D83-000000000003", "Videos", [
            "mov", "mp4", "mkv", "avi",
        ]),
        rule("7AF70000-2E4F-4B56-8D83-000000000004", "Audio", [
            "mp3", "wav", "m4a", "flac",
        ]),
        rule("7AF70000-2E4F-4B56-8D83-000000000005", "Archives", [
            "zip", "tar", "gz", "rar", "7z",
        ]),
        rule("7AF70000-2E4F-4B56-8D83-000000000006", "Spreadsheets", [
            "xls", "xlsx", "csv", "numbers",
        ]),
        rule("7AF70000-2E4F-4B56-8D83-000000000007", "Presentations", [
            "ppt", "pptx", "key",
        ]),
        rule("7AF70000-2E4F-4B56-8D83-000000000008", "Documents", [
            "doc", "docx", "pages",
        ]),
        rule("7AF70000-2E4F-4B56-8D83-000000000009", "Web Files", [
            "html", "htm", "url", "webloc",
        ]),
        rule("7AF70000-2E4F-4B56-8D83-000000000010", "Code Files", [
            "swift", "py", "js", "ts", "rs", "go", "json", "yaml", "toml",
        ]),
    ]

    public static func defaultRule(id: UUID) -> ExternalOpenerRule? {
        defaultRules.first { $0.id == id }
    }

    public static func mergedRules(with storedRules: [ExternalOpenerRule]) -> [ExternalOpenerRule] {
        let storedByID = Dictionary(uniqueKeysWithValues: storedRules.map { ($0.id, $0) })

        return defaultRules.map { defaultRule in
            guard let storedRule = storedByID[defaultRule.id] else {
                return defaultRule
            }

            var mergedRule = defaultRule
            mergedRule.selectedAppBundleIdentifier = storedRule.selectedAppBundleIdentifier
            mergedRule.selectedAppDisplayName = storedRule.selectedAppDisplayName
            mergedRule.selectedAppIconPath = storedRule.selectedAppIconPath
            mergedRule.usesSystemDefault = storedRule.usesSystemDefault
            mergedRule.status = storedRule.status
            mergedRule.previousHandlerBundleIdentifiersByContentType =
                storedRule.previousHandlerBundleIdentifiersByContentType
            return mergedRule
        }
    }

    private static func rule(
        _ rawID: String,
        _ categoryName: String,
        _ extensions: [String]
    ) -> ExternalOpenerRule {
        ExternalOpenerRule(
            id: UUID(uuidString: rawID) ?? UUID(),
            categoryName: categoryName,
            extensions: extensions
        )
    }
}

public enum ExternalOpenerDefaults {
    public static let rulesKey = "externalOpenerRules"

    public static func rules(from defaults: UserDefaults) -> [ExternalOpenerRule] {
        guard let data = defaults.data(forKey: rulesKey),
            let decoded = try? JSONDecoder().decode([ExternalOpenerRule].self, from: data) else {
            return ExternalOpenerCatalog.defaultRules
        }

        return ExternalOpenerCatalog.mergedRules(with: decoded)
    }

    public static func save(_ rules: [ExternalOpenerRule], to defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(rules) else {
            return
        }

        defaults.set(data, forKey: rulesKey)
    }
}
