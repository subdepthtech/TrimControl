import AppKit
import CoreServices
import Foundation

public struct LaunchServicesManager {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    @discardableResult
    public func registerInstalledApp(at appURL: URL = URL(fileURLWithPath: AppConstants.installedAppPath)) throws
        -> ProcessResult
    {
        try ProcessRunner.run(
            executable: AppConstants.lsregisterPath,
            arguments: ["-f", appURL.path]
        )
    }

    public func applyDefaults(
        for groups: [FileTypeGroup],
        bundleIdentifier: String = AppConstants.bundleIdentifier
    ) -> [DefaultOperationResult] {
        applyDefaults(
            forContentTypes: uniqued(groups.flatMap(\.contentTypes)),
            bundleIdentifier: bundleIdentifier
        )
    }

    public func applyDefaults(
        forContentTypes contentTypes: [String],
        bundleIdentifier: String = AppConstants.bundleIdentifier
    ) -> [DefaultOperationResult] {
        uniqued(contentTypes).map { contentType in
            let previousHandler = currentHandler(for: contentType)
            let status = LSSetDefaultRoleHandlerForContentType(
                contentType as CFString,
                .all,
                bundleIdentifier as CFString
            )

            return DefaultOperationResult(
                contentType: contentType,
                status: status,
                previousHandler: previousHandler,
                newHandler: status == noErr ? bundleIdentifier : nil
            )
        }
    }

    public func removeDefaults(for groups: [FileTypeGroup]) -> [DefaultOperationResult] {
        removeDefaults(forContentTypes: uniqued(groups.flatMap(\.contentTypes)))
    }

    public func removeDefaults(forContentTypes contentTypes: [String]) -> [DefaultOperationResult] {
        uniqued(contentTypes).map { contentType in
            let previousHandler = currentHandler(for: contentType)

            guard previousHandler == AppConstants.bundleIdentifier else {
                return DefaultOperationResult(
                    contentType: contentType,
                    status: noErr,
                    previousHandler: previousHandler,
                    newHandler: previousHandler
                )
            }

            let fallbackBundleIdentifier = fallbackBundleIdentifierForRemoval(contentType: contentType)

            guard let fallbackBundleIdentifier else {
                return DefaultOperationResult(
                    contentType: contentType,
                    status: OSStatus(paramErr),
                    previousHandler: previousHandler,
                    newHandler: nil
                )
            }

            let status = LSSetDefaultRoleHandlerForContentType(
                contentType as CFString,
                .all,
                fallbackBundleIdentifier as CFString
            )

            return DefaultOperationResult(
                contentType: contentType,
                status: status,
                previousHandler: previousHandler,
                newHandler: status == noErr ? fallbackBundleIdentifier : nil
            )
        }
    }

    public func currentHandler(for contentType: String) -> String? {
        guard let handler = LSCopyDefaultRoleHandlerForContentType(contentType as CFString, .all) else {
            return nil
        }

        return handler.takeRetainedValue() as String
    }

    public func statuses(
        for groups: [FileTypeGroup] = FileTypeCatalog.groups,
        bundleIdentifier: String = AppConstants.bundleIdentifier
    ) -> [GroupDefaultStatus] {
        groups.map { group in
            let matched = group.contentTypes.filter { currentHandler(for: $0) == bundleIdentifier }.count
            return GroupDefaultStatus(
                groupID: group.id,
                matchedCount: matched,
                totalCount: group.contentTypes.count
            )
        }
    }

    public func verifyExtensions(
        _ extensions: [String] = FileTypeCatalog.sampleExtensions,
        expectedAppPath: String = AppConstants.installedAppPath
    ) throws -> [ExtensionVerification] {
        let temporaryDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("trimcontrol-verification-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer {
            try? fileManager.removeItem(at: temporaryDirectory)
        }

        return try extensions.map { extensionName in
            let sampleURL = temporaryDirectory.appendingPathComponent("sample.\(extensionName)")
            try "TrimControl verification\n".write(to: sampleURL, atomically: true, encoding: .utf8)
            let resolvedAppPath = NSWorkspace.shared.urlForApplication(toOpen: sampleURL)?.path

            return ExtensionVerification(
                extensionName: extensionName,
                resolvedAppPath: resolvedAppPath,
                expectedAppPath: expectedAppPath
            )
        }
    }

    private func fallbackBundleIdentifierForRemoval(contentType: String) -> String? {
        let allowLegacyWrapper = fileManager.fileExists(atPath: AppConstants.legacyAppPath)

        if let handlers = LSCopyAllRoleHandlersForContentType(contentType as CFString, .all)?
            .takeRetainedValue() as? [String]
        {
            for handler in handlers
            where handler != AppConstants.bundleIdentifier
                && (allowLegacyWrapper || handler != AppConstants.legacyBundleIdentifier) {
                return handler
            }
        }

        return "com.apple.TextEdit"
    }

    private func uniqued(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []

        for value in values where !seen.contains(value) {
            seen.insert(value)
            result.append(value)
        }

        return result
    }
}
