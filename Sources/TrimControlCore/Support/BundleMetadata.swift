import Foundation

public enum BundleMetadata {
    private static let defaultShortVersion = "0.1.0"
    private static let defaultBuildNumber = "1"

    public static func infoPlistData() throws -> Data {
        let plist: [String: Any] = [
            "CFBundleDevelopmentRegion": "en",
            "CFBundleDisplayName": AppConstants.appName,
            "CFBundleDocumentTypes": documentTypes(),
            "CFBundleExecutable": AppConstants.appName,
            "CFBundleIconFile": AppConstants.appName,
            "CFBundleIconName": AppConstants.appName,
            "CFBundleIdentifier": AppConstants.bundleIdentifier,
            "CFBundleInfoDictionaryVersion": "6.0",
            "CFBundleName": AppConstants.appName,
            "CFBundlePackageType": "APPL",
            "CFBundleShortVersionString": shortVersionString,
            "CFBundleVersion": buildNumber,
            "LSApplicationCategoryType": "public.app-category.utilities",
            "LSUIElement": true,
            "LSMinimumSystemVersion": AppConstants.minimumSystemVersion,
            "NSHighResolutionCapable": true,
            "NSPrincipalClass": "NSApplication",
            "UTExportedTypeDeclarations": exportedTypeDeclarations(),
        ]

        return try PropertyListSerialization.data(
            fromPropertyList: plist,
            format: .xml,
            options: 0
        )
    }

    public static func writeInfoPlist(to url: URL) throws {
        let data = try infoPlistData()
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: url, options: .atomic)
    }

    public static func documentTypes() -> [[String: Any]] {
        FileTypeCatalog.groups.map { group in
            [
                "CFBundleTypeExtensions": group.extensions,
                "CFBundleTypeName": group.title,
                "CFBundleTypeRole": "Editor",
                "LSHandlerRank": "Owner",
                "LSItemContentTypes": group.contentTypes,
            ]
        }
    }

    public static func exportedTypeDeclarations() -> [[String: Any]] {
        FileTypeCatalog.exportedTypes.map { type in
            [
                "UTTypeConformsTo": type.conformsTo,
                "UTTypeDescription": type.description,
                "UTTypeIdentifier": type.identifier,
                "UTTypeTagSpecification": [
                    "public.filename-extension": type.extensions
                ],
            ]
        }
    }

    private static var shortVersionString: String {
        sanitizedEnvironmentValue(named: "TRIMCONTROL_VERSION") ?? defaultShortVersion
    }

    private static var buildNumber: String {
        sanitizedEnvironmentValue(named: "TRIMCONTROL_BUILD_NUMBER") ?? defaultBuildNumber
    }

    private static func sanitizedEnvironmentValue(named name: String) -> String? {
        let rawValue = ProcessInfo.processInfo.environment[name]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let rawValue, !rawValue.isEmpty else {
            return nil
        }
        return rawValue
    }
}
