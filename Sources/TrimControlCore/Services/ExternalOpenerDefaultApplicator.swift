import CoreServices
import Foundation
import UniformTypeIdentifiers

public enum ExternalOpenerDefaultApplicator {
    public static func contentTypeIdentifiers(for rule: ExternalOpenerRule) -> [String] {
        uniqued(
            rule.extensions.compactMap { extensionName in
                UTType(filenameExtension: extensionName)?.identifier
            }
        )
    }

    public static func apply(rule: ExternalOpenerRule) -> [DefaultOperationResult] {
        guard !rule.usesSystemDefault,
            let bundleIdentifier = rule.selectedAppBundleIdentifier else {
            return []
        }

        return contentTypeIdentifiers(for: rule).map { contentType in
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

    public static func restoreSystemDefault(rule: ExternalOpenerRule) -> [DefaultOperationResult] {
        guard requiresRestoration(rule: rule) else {
            return []
        }

        return contentTypeIdentifiers(for: rule).map { contentType in
            let previousHandler = currentHandler(for: contentType)
            let targetHandler = restorationTarget(
                storedPreviousHandler: rule.previousHandlerBundleIdentifiersByContentType[contentType],
                selectedBundleIdentifier: rule.selectedAppBundleIdentifier,
                availableHandlers: availableHandlers(for: contentType)
            )

            guard let targetHandler else {
                return DefaultOperationResult(
                    contentType: contentType,
                    status: OSStatus(paramErr),
                    previousHandler: previousHandler,
                    newHandler: nil
                )
            }

            guard previousHandler != targetHandler else {
                return DefaultOperationResult(
                    contentType: contentType,
                    status: noErr,
                    previousHandler: previousHandler,
                    newHandler: targetHandler
                )
            }

            let status = LSSetDefaultRoleHandlerForContentType(
                contentType as CFString,
                .all,
                targetHandler as CFString
            )

            return DefaultOperationResult(
                contentType: contentType,
                status: status,
                previousHandler: previousHandler,
                newHandler: status == noErr ? targetHandler : nil
            )
        }
    }

    public static func restorationTarget(
        storedPreviousHandler: String?,
        selectedBundleIdentifier: String?,
        availableHandlers: [String]
    ) -> String? {
        let excludedBundleIdentifiers = Set(
            [AppConstants.bundleIdentifier, selectedBundleIdentifier].compactMap { $0 }
        )

        if let storedPreviousHandler,
            !excludedBundleIdentifiers.contains(storedPreviousHandler) {
            return storedPreviousHandler
        }

        return availableHandlers.first { !excludedBundleIdentifiers.contains($0) }
    }

    public static func requiresRestoration(rule: ExternalOpenerRule) -> Bool {
        !rule.usesSystemDefault
            || rule.selectedAppBundleIdentifier != nil
            || !rule.previousHandlerBundleIdentifiersByContentType.isEmpty
    }

    public static func rule(
        _ rule: ExternalOpenerRule,
        recordingPreviousHandlersFrom results: [DefaultOperationResult]
    ) -> ExternalOpenerRule {
        var updatedRule = rule

        for result in results where result.succeeded {
            guard let previousHandler = result.previousHandler,
                previousHandler != result.newHandler,
                previousHandler != rule.selectedAppBundleIdentifier else {
                continue
            }

            updatedRule.previousHandlerBundleIdentifiersByContentType[result.contentType] = previousHandler
        }

        return updatedRule
    }

    private static func currentHandler(for contentType: String) -> String? {
        guard let handler = LSCopyDefaultRoleHandlerForContentType(contentType as CFString, .all) else {
            return nil
        }

        return handler.takeRetainedValue() as String
    }

    private static func availableHandlers(for contentType: String) -> [String] {
        guard let handlers = LSCopyAllRoleHandlersForContentType(contentType as CFString, .all)?
            .takeRetainedValue() as? [String] else {
            return []
        }

        return handlers
    }

    private static func uniqued(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []

        for value in values where !seen.contains(value) {
            seen.insert(value)
            result.append(value)
        }

        return result
    }
}
