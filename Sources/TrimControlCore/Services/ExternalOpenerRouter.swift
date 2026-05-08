import Foundation

public struct ExternalOpenerRoutingResult: Hashable, Sendable {
    public let neovimFileURLs: [URL]
    public let externalFileURLs: [URL]

    public init(neovimFileURLs: [URL], externalFileURLs: [URL]) {
        self.neovimFileURLs = neovimFileURLs
        self.externalFileURLs = externalFileURLs
    }
}

public struct ExternalOpenerRouter {
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func partition(fileURLs: [URL]) -> ExternalOpenerRoutingResult {
        let rules = ExternalOpenerDefaults.rules(from: defaults)
        let neovimExtensions = Set(FileTypeCatalog.allExtensions.map { $0.lowercased() })
        var neovimFileURLs: [URL] = []
        var externalFileURLs: [URL] = []

        for fileURL in fileURLs where fileURL.isFileURL {
            if shouldOpenExternally(fileURL, rules: rules, neovimExtensions: neovimExtensions) {
                externalFileURLs.append(fileURL)
            } else {
                neovimFileURLs.append(fileURL)
            }
        }

        return ExternalOpenerRoutingResult(
            neovimFileURLs: neovimFileURLs,
            externalFileURLs: externalFileURLs
        )
    }

    public func openExternally(fileURLs: [URL]) throws {
        let rules = ExternalOpenerDefaults.rules(from: defaults)
        let groupedURLs = Dictionary(grouping: fileURLs) { fileURL in
            rule(for: fileURL, in: rules)?.id
        }

        for (ruleID, urls) in groupedURLs {
            guard let ruleID,
                let rule = rules.first(where: { $0.id == ruleID }) else {
                try openWithSystemDefault(fileURLs: urls)
                continue
            }

            try open(fileURLs: urls, with: rule)
        }
    }

    private func shouldOpenExternally(
        _ fileURL: URL,
        rules: [ExternalOpenerRule],
        neovimExtensions: Set<String>
    ) -> Bool {
        guard let rule = rule(for: fileURL, in: rules) else {
            return false
        }

        let extensionName = normalizedExtension(for: fileURL)

        if neovimExtensions.contains(extensionName) && rule.usesSystemDefault {
            return false
        }

        return true
    }

    private func open(fileURLs: [URL], with rule: ExternalOpenerRule) throws {
        if !rule.usesSystemDefault,
            let bundleIdentifier = rule.selectedAppBundleIdentifier,
            rule.status != .missingApp {
            try ProcessRunner.run(
                executable: "/usr/bin/open",
                arguments: ["-b", bundleIdentifier] + fileURLs.map(\.path),
                waitUntilExit: false
            )
            return
        }

        try openWithSystemDefault(fileURLs: fileURLs)
    }

    private func openWithSystemDefault(fileURLs: [URL]) throws {
        try ProcessRunner.run(
            executable: "/usr/bin/open",
            arguments: fileURLs.map(\.path),
            waitUntilExit: false
        )
    }

    private func rule(for fileURL: URL, in rules: [ExternalOpenerRule]) -> ExternalOpenerRule? {
        let extensionName = normalizedExtension(for: fileURL)
        guard !extensionName.isEmpty else {
            return nil
        }

        return rules.first { rule in
            rule.extensions.contains { $0.caseInsensitiveCompare(extensionName) == .orderedSame }
        }
    }

    private func normalizedExtension(for fileURL: URL) -> String {
        fileURL.pathExtension.trimmingCharacters(in: CharacterSet(charactersIn: ".")).lowercased()
    }
}
