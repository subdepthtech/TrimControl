import AppKit
import Combine
import Foundation
import TrimControlCore
import UniformTypeIdentifiers

struct CustomFileTypeEntry: Codable, Hashable, Identifiable {
    let groupID: FileTypeGroupID
    let extensionName: String
    let contentType: String

    var id: String {
        "custom:\(groupID.rawValue):\(extensionName)"
    }

    var choice: FileTypeChoice {
        FileTypeChoice(
            id: id,
            groupID: groupID,
            title: "Custom .\(extensionName)",
            extensions: [extensionName],
            contentTypes: [contentType],
            isCustom: true
        )
    }
}

private struct FileTypePreset: Codable {
    let version: Int
    let appBundleIdentifier: String
    let exportedAt: Date
    let selectedChoiceIDs: [String]
    let customFileTypes: [CustomFileTypeEntry]
}

private enum PresetError: LocalizedError {
    case unsupportedVersion(Int)

    var errorDescription: String? {
        switch self {
        case let .unsupportedVersion(version):
            return "Unsupported preset version \(version)."
        }
    }
}

@MainActor
final class AppState: ObservableObject {
    @Published var selectedGroupIDs: Set<FileTypeGroupID>
    @Published var selectedFileTypeChoiceIDs: Set<String>
    @Published var customFileTypes: [CustomFileTypeEntry]
    @Published var selectedTerminalBackendID: TerminalBackendID
    @Published var neovimPath: String
    @Published var customCommandName: String
    @Published var customCommandExecutablePath: String
    @Published var customCommandArguments: [String]
    @Published var externalOpenerRules: [ExternalOpenerRule]
    @Published var groupStatuses: [FileTypeGroupID: GroupDefaultStatus] = [:]
    @Published var contentTypeHandlers: [String: String] = [:]
    @Published var lastMessage = "Ready."
    @Published var isWorking = false
    @Published var pendingNavigationDestination: String?

    let groups = FileTypeCatalog.groups
    let fileTypeChoices = FileTypeCatalog.fileTypeChoices

    private let launchServices = LaunchServicesManager()
    private let launcher = NeovimLauncher()
    private let defaults = UserDefaults.standard
    private let selectedGroupsKey = "selectedFileTypeGroups"
    private let selectedFileTypeChoicesKey = "selectedFileTypeChoices"
    private let customFileTypesKey = "customFileTypes"

    init() {
        let terminalPreferences = TerminalBackendDefaults.preferences(from: defaults)
        selectedTerminalBackendID = terminalPreferences.selectedBackendID
        neovimPath = terminalPreferences.neovimPath
        customCommandName = terminalPreferences.customCommand.name
        customCommandExecutablePath = terminalPreferences.customCommand.executablePath
        customCommandArguments = terminalPreferences.customCommand.arguments
        externalOpenerRules = AppState.loadExternalOpenerRules(from: defaults)

        let stored = defaults.stringArray(forKey: selectedGroupsKey) ?? []
        let restored = Set(stored.compactMap(FileTypeGroupID.init(rawValue:)))
        selectedGroupIDs = restored.isEmpty ? Set(FileTypeGroupID.allCases) : restored

        let loadedCustomFileTypes: [CustomFileTypeEntry]
        if let data = defaults.data(forKey: customFileTypesKey),
            let decoded = try? JSONDecoder().decode([CustomFileTypeEntry].self, from: data) {
            loadedCustomFileTypes = decoded
        } else {
            loadedCustomFileTypes = []
        }
        customFileTypes = loadedCustomFileTypes

        let storedChoiceIDs = defaults.stringArray(forKey: selectedFileTypeChoicesKey) ?? []
        let validChoiceIDs = Set((FileTypeCatalog.fileTypeChoices + loadedCustomFileTypes.map(\.choice)).map(\.id))
        let restoredChoiceIDs = Set(storedChoiceIDs).intersection(validChoiceIDs)
        if defaults.object(forKey: selectedFileTypeChoicesKey) == nil {
            selectedFileTypeChoiceIDs = validChoiceIDs
        } else {
            selectedFileTypeChoiceIDs = restoredChoiceIDs
        }
    }

    var selectedGroups: [FileTypeGroup] {
        groups.filter { selectedGroupIDs.contains($0.id) }
    }

    var selectedFileTypeChoices: [FileTypeChoice] {
        allFileTypeChoices.filter { selectedFileTypeChoiceIDs.contains($0.id) }
    }

    var allFileTypeChoices: [FileTypeChoice] {
        fileTypeChoices + customFileTypes.map(\.choice)
    }

    var activeSummary: String {
        let active = groups.filter { groupStatuses[$0.id]?.status == .all }.map(\.shortTitle)
        return active.isEmpty ? "No groups active" : "Active: \(active.joined(separator: " + "))"
    }

    var terminalBackendPreferences: TerminalBackendPreferences {
        TerminalBackendPreferences(
            selectedBackendID: selectedTerminalBackendID,
            neovimPath: neovimPath,
            customCommand: CustomCommandConfiguration(
                name: customCommandName,
                executablePath: customCommandExecutablePath,
                arguments: customCommandArguments
            )
        )
    }

    var selectedTerminalBackendDisplayName: String {
        if selectedTerminalBackendID == .customCommand {
            let trimmedName = customCommandName.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmedName.isEmpty ? TerminalBackendID.customCommand.displayName : trimmedName
        }

        return selectedTerminalBackendID.displayName
    }

    func requestNavigation(to destinationID: String) {
        pendingNavigationDestination = destinationID
    }

    func toggleGroup(_ group: FileTypeGroup) {
        if selectedGroupIDs.contains(group.id) {
            selectedGroupIDs.remove(group.id)
        } else {
            selectedGroupIDs.insert(group.id)
        }

        defaults.set(selectedGroupIDs.map(\.rawValue).sorted(), forKey: selectedGroupsKey)
    }

    func refreshStatus(message: String? = "Status refreshed.") {
        let statuses = launchServices.statuses()
        groupStatuses = Dictionary(uniqueKeysWithValues: statuses.map { ($0.groupID, $0) })
        contentTypeHandlers = Dictionary(
            uniqueKeysWithValues: allContentTypes().compactMap { contentType in
                guard let handler = launchServices.currentHandler(for: contentType) else {
                    return nil
                }

                return (contentType, handler)
            }
        )
        if let message {
            lastMessage = message
        }
    }

    func applySelectedDefaults() {
        runOperation(emptySelectionMessage: "Select at least one file type to apply.") {
            try launchServices.registerInstalledApp(at: Bundle.main.bundleURL)
            let results = launchServices.applyDefaults(forContentTypes: selectedContentTypes())
            return summarize(results: results, verb: "Applied")
        }
    }

    func applyAllDefaults() {
        runOperation(emptySelectionMessage: nil) {
            try launchServices.registerInstalledApp(at: Bundle.main.bundleURL)
            let results = launchServices.applyDefaults(forContentTypes: allContentTypes())
            return summarize(results: results, verb: "Applied")
        }
    }

    func removeSelectedDefaults() {
        runOperation(emptySelectionMessage: "Select at least one file type to remove.") {
            let results = launchServices.removeDefaults(forContentTypes: selectedContentTypes())
            return summarize(results: results, verb: "Removed")
        }
    }

    func verifySamples() {
        runOperation(emptySelectionMessage: nil) {
            let results = try launchServices.verifyExtensions(expectedAppPath: Bundle.main.bundleURL.path)
            let matched = results.filter(\.matchesExpectedApp).count
            return "Verified \(matched)/\(results.count) sample extensions against this app."
        }
    }

    func openTestFile() {
        runOperation(emptySelectionMessage: nil) {
            let testURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("trimcontrol-test-\(UUID().uuidString).json")
            try "{ \"openedBy\": \"TrimControl\" }\n".write(to: testURL, atomically: true, encoding: .utf8)
            try launcher.open(fileURLs: [testURL], preferences: terminalBackendPreferences)
            return "Test terminal opened a temporary JSON file with \(selectedTerminalBackendDisplayName)."
        }
    }

    func selectTerminalBackend(_ backendID: TerminalBackendID) {
        selectedTerminalBackendID = backendID
        persistTerminalBackendPreferences()
        lastMessage = "Terminal backend set to \(selectedTerminalBackendDisplayName)."
    }

    func setNeovimPath(_ path: String) {
        neovimPath = path
        persistTerminalBackendPreferences()
    }

    func chooseNeovim() {
        let panel = NSOpenPanel()
        panel.title = "Choose Neovim"
        panel.message = "Choose the nvim executable TrimControl should pass to terminal backends."
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: (neovimPath as NSString).deletingLastPathComponent)

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        setNeovimPath(url.path)
        lastMessage = "Neovim path set to \(url.path)."
    }

    func setCustomCommandName(_ name: String) {
        customCommandName = name
        persistTerminalBackendPreferences()
    }

    func setCustomCommandExecutablePath(_ path: String) {
        customCommandExecutablePath = path
        persistTerminalBackendPreferences()
    }

    func chooseCustomCommandExecutable() {
        let panel = NSOpenPanel()
        panel.title = "Choose Custom Command"
        panel.message = "Choose the executable TrimControl should run for the Custom Command backend."
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if !customCommandExecutablePath.isEmpty {
            panel.directoryURL = URL(
                fileURLWithPath: (customCommandExecutablePath as NSString).deletingLastPathComponent
            )
        }

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        setCustomCommandExecutablePath(url.path)
        lastMessage = "Custom Command executable set to \(url.path)."
    }

    func updateCustomCommandArgument(at index: Int, value: String) {
        guard customCommandArguments.indices.contains(index) else {
            return
        }

        customCommandArguments[index] = value
        persistTerminalBackendPreferences()
    }

    func addCustomCommandArgument() {
        customCommandArguments.append("")
        persistTerminalBackendPreferences()
    }

    func removeCustomCommandArgument(at index: Int) {
        guard customCommandArguments.indices.contains(index) else {
            return
        }

        customCommandArguments.remove(at: index)
        persistTerminalBackendPreferences()
    }

    func applyTridentCustomCommandPreset() {
        let preset = CustomCommandConfiguration.tridentPreset
        selectedTerminalBackendID = .customCommand
        customCommandName = preset.name
        customCommandExecutablePath = preset.executablePath
        customCommandArguments = preset.arguments
        persistTerminalBackendPreferences()
        lastMessage = "Loaded the Trident Custom Command preset."
    }

    func chooseExternalOpener(for rule: ExternalOpenerRule) {
        let panel = NSOpenPanel()
        panel.title = "Choose App for \(rule.categoryName)"
        panel.message = "Choose the app TrimControl should use for \(rule.displayExtensions)."
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        panel.allowedContentTypes = [.applicationBundle]

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        let appBundle = Bundle(url: url)
        let bundleIdentifier = appBundle?.bundleIdentifier
        let displayName = appBundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? appBundle?.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? url.deletingPathExtension().lastPathComponent

        updateExternalOpener(ruleID: rule.id) { currentRule in
            currentRule.selectedAppBundleIdentifier = bundleIdentifier
            currentRule.selectedAppDisplayName = displayName
            currentRule.selectedAppIconPath = url.path
            currentRule.usesSystemDefault = false
            currentRule.status = bundleIdentifier == nil ? .missingApp : .custom
        }

        guard let updatedRule = externalOpenerRules.first(where: { $0.id == rule.id }) else {
            lastMessage = "\(displayName) selected for \(rule.categoryName)."
            return
        }

        let results = ExternalOpenerDefaultApplicator.apply(rule: updatedRule)
        let succeeded = results.filter(\.succeeded).count
        let failed = results.count - succeeded
        let ruleWithPreviousHandlers = ExternalOpenerDefaultApplicator.rule(
            updatedRule,
            recordingPreviousHandlersFrom: results
        )
        replaceExternalOpener(ruleWithPreviousHandlers)

        if failed == 0 {
            lastMessage = "\(displayName) selected for \(rule.categoryName) and applied \(succeeded) macOS defaults."
        } else {
            updateExternalOpener(ruleID: rule.id) { currentRule in
                currentRule.status = .needsPermission
            }
            lastMessage = "\(displayName) selected for \(rule.categoryName), but \(failed) macOS defaults failed to apply."
        }
    }

    func setExternalOpenerUsesSystemDefault(_ usesSystemDefault: Bool, for rule: ExternalOpenerRule) {
        if usesSystemDefault {
            restoreExternalOpenerToSystemDefault(rule)
            return
        }

        updateExternalOpener(ruleID: rule.id) { currentRule in
            currentRule.usesSystemDefault = usesSystemDefault
            currentRule.status = currentRule.selectedAppBundleIdentifier == nil ? .missingApp : .custom
        }

        lastMessage = "\(rule.categoryName) is ready for a custom app choice."
    }

    func resetExternalOpener(_ rule: ExternalOpenerRule) {
        restoreExternalOpenerToSystemDefault(rule)
    }

    func resetAllExternalOpeners() {
        let results = externalOpenerRules.flatMap {
            ExternalOpenerDefaultApplicator.restoreSystemDefault(rule: $0)
        }
        let succeeded = results.filter(\.succeeded).count
        let failed = results.count - succeeded

        externalOpenerRules = ExternalOpenerCatalog.defaultRules
        persistExternalOpenerRules()

        if failed == 0 {
            lastMessage = "Reset all Default Openers and restored \(succeeded) macOS defaults."
        } else {
            lastMessage = "Reset all Default Openers, but \(failed) macOS defaults failed to restore."
        }
    }

    func exportPreset() {
        let panel = NSSavePanel()
        panel.title = "Export TrimControl Preset"
        panel.nameFieldStringValue = "trimcontrol-preset.json"
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        do {
            let preset = FileTypePreset(
                version: 1,
                appBundleIdentifier: AppConstants.bundleIdentifier,
                exportedAt: Date(),
                selectedChoiceIDs: selectedFileTypeChoiceIDs.sorted(),
                customFileTypes: customFileTypes.sorted {
                    ($0.groupID.rawValue, $0.extensionName) < ($1.groupID.rawValue, $1.extensionName)
                }
            )
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(preset)
            try data.write(to: url, options: .atomic)
            lastMessage = "Exported preset to \(url.lastPathComponent)."
        } catch {
            lastMessage = "Preset export failed: \(error.localizedDescription)"
        }
    }

    func importPreset() {
        let panel = NSOpenPanel()
        panel.title = "Import TrimControl Preset"
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let preset = try decoder.decode(FileTypePreset.self, from: data)
            try applyPreset(preset)
        } catch {
            lastMessage = "Preset import failed: \(error.localizedDescription)"
        }
    }

    func choices(in group: FileTypeGroup) -> [FileTypeChoice] {
        allFileTypeChoices.filter { $0.groupID == group.id }
    }

    func isSelected(_ choice: FileTypeChoice) -> Bool {
        selectedFileTypeChoiceIDs.contains(choice.id)
    }

    func toggleFileTypeChoice(_ choice: FileTypeChoice) {
        if selectedFileTypeChoiceIDs.contains(choice.id) {
            selectedFileTypeChoiceIDs.remove(choice.id)
        } else {
            selectedFileTypeChoiceIDs.insert(choice.id)
        }

        persistSelectedFileTypeChoices()
    }

    func selectAll(in group: FileTypeGroup) {
        selectedFileTypeChoiceIDs.formUnion(choices(in: group).map(\.id))
        persistSelectedFileTypeChoices()
    }

    func clearAll(in group: FileTypeGroup) {
        selectedFileTypeChoiceIDs.subtract(choices(in: group).map(\.id))
        persistSelectedFileTypeChoices()
    }

    func status(for choice: FileTypeChoice) -> DefaultStatus {
        let matched = choice.contentTypes.filter {
            contentTypeHandlers[$0] == AppConstants.bundleIdentifier
        }.count

        if matched == choice.contentTypes.count {
            return .all
        }

        if matched == 0 {
            return .none
        }

        return .partial
    }

    func addCustomExtension(_ rawExtension: String, to group: FileTypeGroup) {
        let sanitized = sanitizeExtension(rawExtension)

        guard let extensionName = sanitized else {
            lastMessage = "Enter a file extension like .foo."
            return
        }

        guard !isBlockedExtension(extensionName) else {
            lastMessage = ".\(extensionName) is blocked because macOS treats that family as transport-stream media."
            return
        }

        guard !allFileTypeChoices.contains(where: { $0.extensions.contains(extensionName) }) else {
            lastMessage = ".\(extensionName) is already listed."
            return
        }

        let contentType = UTType(filenameExtension: extensionName)?.identifier
            ?? fallbackContentTypeIdentifier(for: extensionName)
        let entry = CustomFileTypeEntry(
            groupID: group.id,
            extensionName: extensionName,
            contentType: contentType
        )

        customFileTypes.append(entry)
        selectedFileTypeChoiceIDs.insert(entry.id)
        persistCustomFileTypes()
        persistSelectedFileTypeChoices()
        refreshStatus(message: "Added .\(extensionName).")
    }

    func removeCustomFileType(_ choice: FileTypeChoice) {
        customFileTypes.removeAll { $0.id == choice.id }
        selectedFileTypeChoiceIDs.remove(choice.id)
        persistCustomFileTypes()
        persistSelectedFileTypeChoices()
        refreshStatus(message: "Removed \(choice.displayExtensions).")
    }

    private func runOperation(
        emptySelectionMessage: String?,
        _ operation: () throws -> String
    ) {
        guard emptySelectionMessage == nil || !selectedFileTypeChoices.isEmpty else {
            lastMessage = emptySelectionMessage ?? "Nothing selected."
            return
        }

        isWorking = true
        defer {
            isWorking = false
        }

        do {
            let message = try operation()
            refreshStatus(message: message)
        } catch {
            lastMessage = error.localizedDescription
            refreshStatus(message: lastMessage)
        }
    }

    private func summarize(results: [DefaultOperationResult], verb: String) -> String {
        let succeeded = results.filter(\.succeeded).count
        let failed = results.count - succeeded

        if failed == 0 {
            return "\(verb) \(succeeded) LaunchServices defaults."
        }

        return "\(verb) \(succeeded) defaults; \(failed) failed."
    }

    private func selectedContentTypes() -> [String] {
        uniqued(selectedFileTypeChoices.flatMap(\.contentTypes))
    }

    private func allContentTypes() -> [String] {
        uniqued(allFileTypeChoices.flatMap(\.contentTypes))
    }

    private func persistSelectedFileTypeChoices() {
        defaults.set(selectedFileTypeChoiceIDs.sorted(), forKey: selectedFileTypeChoicesKey)
    }

    private func persistCustomFileTypes() {
        guard let data = try? JSONEncoder().encode(customFileTypes) else {
            return
        }

        defaults.set(data, forKey: customFileTypesKey)
    }

    private func persistExternalOpenerRules() {
        ExternalOpenerDefaults.save(externalOpenerRules, to: defaults)
    }

    private func persistTerminalBackendPreferences() {
        TerminalBackendDefaults.save(preferences: terminalBackendPreferences, to: defaults)
    }

    private func applyPreset(_ preset: FileTypePreset) throws {
        guard preset.version == 1 else {
            throw PresetError.unsupportedVersion(preset.version)
        }

        let importedCustomFileTypes = normalizedCustomFileTypes(from: preset.customFileTypes)
        let validChoiceIDs = Set((fileTypeChoices + importedCustomFileTypes.map(\.choice)).map(\.id))

        customFileTypes = importedCustomFileTypes
        selectedFileTypeChoiceIDs = Set(preset.selectedChoiceIDs).intersection(validChoiceIDs)

        persistCustomFileTypes()
        persistSelectedFileTypeChoices()
        refreshStatus(
            message: "Imported preset with \(selectedFileTypeChoiceIDs.count) selected file types and \(customFileTypes.count) custom extensions."
        )
    }

    private func normalizedCustomFileTypes(from entries: [CustomFileTypeEntry]) -> [CustomFileTypeEntry] {
        var usedExtensions = Set(fileTypeChoices.flatMap(\.extensions))
        var result: [CustomFileTypeEntry] = []

        for entry in entries {
            guard let extensionName = sanitizeExtension(entry.extensionName),
                !isBlockedExtension(extensionName),
                usedExtensions.insert(extensionName).inserted else {
                continue
            }

            let contentType = UTType(filenameExtension: extensionName)?.identifier
                ?? fallbackContentTypeIdentifier(for: extensionName)
            result.append(
                CustomFileTypeEntry(
                    groupID: entry.groupID,
                    extensionName: extensionName,
                    contentType: contentType
                )
            )
        }

        return result
    }

    private func sanitizeExtension(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
            .lowercased()

        guard !trimmed.isEmpty else {
            return nil
        }

        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
        guard trimmed.rangeOfCharacter(from: allowed.inverted) == nil else {
            return nil
        }

        return trimmed
    }

    private func isBlockedExtension(_ extensionName: String) -> Bool {
        extensionName == "ts" || extensionName == "mts" || extensionName.hasSuffix(".ts")
    }

    private func fallbackContentTypeIdentifier(for extensionName: String) -> String {
        "dyn.trimcontrol.\(extensionName)"
    }

    private func updateExternalOpener(
        ruleID: ExternalOpenerRule.ID,
        update: (inout ExternalOpenerRule) -> Void
    ) {
        guard let index = externalOpenerRules.firstIndex(where: { $0.id == ruleID }) else {
            return
        }

        update(&externalOpenerRules[index])
        externalOpenerRules[index] = refreshedExternalOpenerStatus(externalOpenerRules[index])
        persistExternalOpenerRules()
    }

    private func replaceExternalOpener(_ rule: ExternalOpenerRule) {
        guard let index = externalOpenerRules.firstIndex(where: { $0.id == rule.id }) else {
            return
        }

        externalOpenerRules[index] = rule
        persistExternalOpenerRules()
    }

    private func restoreExternalOpenerToSystemDefault(_ rule: ExternalOpenerRule) {
        guard let defaultRule = ExternalOpenerCatalog.defaultRule(id: rule.id) else {
            return
        }

        let results = ExternalOpenerDefaultApplicator.restoreSystemDefault(rule: rule)
        let succeeded = results.filter(\.succeeded).count
        let failed = results.count - succeeded

        replaceExternalOpener(defaultRule)

        if failed == 0 {
            lastMessage = "Reset \(rule.categoryName) and restored \(succeeded) macOS defaults."
        } else {
            lastMessage = "Reset \(rule.categoryName), but \(failed) macOS defaults failed to restore."
        }
    }

    private func refreshedExternalOpenerStatus(_ rule: ExternalOpenerRule) -> ExternalOpenerRule {
        var refreshedRule = rule

        guard !refreshedRule.usesSystemDefault else {
            refreshedRule.status = .systemDefault
            return refreshedRule
        }

        if refreshedRule.status == .needsPermission {
            return refreshedRule
        }

        guard let bundleIdentifier = refreshedRule.selectedAppBundleIdentifier else {
            refreshedRule.status = .missingApp
            return refreshedRule
        }

        if NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) != nil {
            refreshedRule.status = .custom
            return refreshedRule
        }

        if let iconPath = refreshedRule.selectedAppIconPath,
            FileManager.default.fileExists(atPath: iconPath) {
            refreshedRule.status = .custom
            return refreshedRule
        }

        refreshedRule.status = .missingApp
        return refreshedRule
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

    private static func loadExternalOpenerRules(from defaults: UserDefaults) -> [ExternalOpenerRule] {
        ExternalOpenerDefaults.rules(from: defaults)
    }
}
