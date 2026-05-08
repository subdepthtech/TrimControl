import Foundation

public struct BundleVerificationResult: Hashable, Sendable {
    public let messages: [String]
    public let errors: [String]

    public var succeeded: Bool {
        errors.isEmpty
    }
}

public struct BundleVerifier {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func verify(appURL: URL) -> BundleVerificationResult {
        var messages: [String] = []
        var errors: [String] = []

        let infoPlistURL = appURL.appendingPathComponent("Contents/Info.plist")
        guard let plist = NSDictionary(contentsOf: infoPlistURL) as? [String: Any] else {
            return BundleVerificationResult(
                messages: messages,
                errors: ["Cannot read \(infoPlistURL.path)."]
            )
        }

        checkString(
            plist,
            key: "CFBundleIdentifier",
            expected: AppConstants.bundleIdentifier,
            messages: &messages,
            errors: &errors
        )
        checkString(
            plist,
            key: "CFBundleExecutable",
            expected: AppConstants.appName,
            messages: &messages,
            errors: &errors
        )
        checkString(
            plist,
            key: "CFBundleIconFile",
            expected: AppConstants.appName,
            messages: &messages,
            errors: &errors
        )
        checkString(
            plist,
            key: "CFBundlePackageType",
            expected: "APPL",
            messages: &messages,
            errors: &errors
        )

        let executableURL = appURL
            .appendingPathComponent("Contents/MacOS")
            .appendingPathComponent(AppConstants.appName)
        if fileManager.isExecutableFile(atPath: executableURL.path) {
            messages.append("Executable exists: \(executableURL.path)")
        } else {
            errors.append("Executable is missing or not executable: \(executableURL.path)")
        }

        let iconURL = appURL
            .appendingPathComponent("Contents/Resources")
            .appendingPathComponent("\(AppConstants.appName).icns")
        if fileManager.fileExists(atPath: iconURL.path) {
            messages.append("Icon exists: \(iconURL.path)")
        } else {
            errors.append("Icon is missing: \(iconURL.path)")
        }

        let advertisedExtensions = Self.advertisedExtensions(in: plist)
        let missingExtensions = Set(FileTypeCatalog.allExtensions).subtracting(advertisedExtensions)
        if missingExtensions.isEmpty {
            messages.append("All catalog extensions are advertised.")
        } else {
            errors.append("Missing advertised extensions: \(missingExtensions.sorted().joined(separator: ", "))")
        }

        if advertisedExtensions.contains("ts") {
            errors.append("Bundle advertises .ts, which v1 must not claim.")
        } else {
            messages.append("Bundle does not advertise .ts.")
        }

        let exportedIdentifiers = Self.exportedTypeIdentifiers(in: plist)
        let expectedExportedIdentifiers = Set(FileTypeCatalog.exportedTypes.map(\.identifier))
        let missingExportedIdentifiers = expectedExportedIdentifiers.subtracting(exportedIdentifiers)
        if missingExportedIdentifiers.isEmpty {
            messages.append("All app-owned UTIs are exported.")
        } else {
            errors.append(
                "Missing exported UTIs: \(missingExportedIdentifiers.sorted().joined(separator: ", "))"
            )
        }

        let foreignOwnedIdentifiers = exportedIdentifiers.filter {
            !$0.hasPrefix("\(AppConstants.bundleIdentifier).")
        }
        if foreignOwnedIdentifiers.isEmpty {
            messages.append("Exported UTIs are app-owned.")
        } else {
            errors.append(
                "Found non-TrimControl exported UTIs: \(foreignOwnedIdentifiers.sorted().joined(separator: ", "))"
            )
        }

        return BundleVerificationResult(messages: messages, errors: errors)
    }

    private func checkString(
        _ plist: [String: Any],
        key: String,
        expected: String,
        messages: inout [String],
        errors: inout [String]
    ) {
        let actual = plist[key] as? String
        if actual == expected {
            messages.append("\(key): \(expected)")
        } else {
            errors.append("\(key) expected \(expected), found \(actual ?? "<missing>").")
        }
    }

    private static func advertisedExtensions(in plist: [String: Any]) -> Set<String> {
        guard let documentTypes = plist["CFBundleDocumentTypes"] as? [[String: Any]] else {
            return []
        }

        return Set(
            documentTypes.flatMap { documentType in
                documentType["CFBundleTypeExtensions"] as? [String] ?? []
            }
        )
    }

    private static func exportedTypeIdentifiers(in plist: [String: Any]) -> Set<String> {
        guard let typeDeclarations = plist["UTExportedTypeDeclarations"] as? [[String: Any]] else {
            return []
        }

        return Set(typeDeclarations.compactMap { $0["UTTypeIdentifier"] as? String })
    }
}
