import AppKit
import Foundation

public struct NeovimLauncher {
    private let defaults: UserDefaults
    private let fileManager: FileManager

    public init(
        defaults: UserDefaults = .standard,
        fileManager: FileManager = .default
    ) {
        self.defaults = defaults
        self.fileManager = fileManager
    }

    public func open(fileURLs: [URL]) throws {
        try open(
            fileURLs: fileURLs,
            preferences: TerminalBackendDefaults.preferences(from: defaults)
        )
    }

    public func open(
        fileURLs: [URL],
        preferences: TerminalBackendPreferences
    ) throws {
        let paths = fileURLs
            .filter { $0.isFileURL }
            .map { $0.standardizedFileURL.path }

        switch preferences.selectedBackendID {
        case .appleTerminal:
            try launchAppleTerminal(neovimPath: preferences.neovimPath, filePaths: paths)
        case .iTerm2:
            try launchITerm2(neovimPath: preferences.neovimPath, filePaths: paths)
        case .ghostty:
            try launchDirectTerminal(
                name: TerminalBackendID.ghostty.displayName,
                executablePath: executablePath(
                    preferredPath: "/Applications/Ghostty.app/Contents/MacOS/ghostty",
                    bundleIdentifier: "com.mitchellh.ghostty",
                    relativeExecutablePath: "Contents/MacOS/ghostty"
                ),
                arguments: ghosttyArguments(neovimPath: preferences.neovimPath, filePaths: paths),
                neovimPath: preferences.neovimPath
            )
        case .wezTerm:
            try launchDirectTerminal(
                name: TerminalBackendID.wezTerm.displayName,
                executablePath: executablePath(
                    preferredPath: "/Applications/WezTerm.app/Contents/MacOS/wezterm",
                    bundleIdentifier: "com.github.wez.wezterm",
                    relativeExecutablePath: "Contents/MacOS/wezterm"
                ),
                arguments: wezTermArguments(neovimPath: preferences.neovimPath, filePaths: paths),
                neovimPath: preferences.neovimPath
            )
        case .alacritty:
            try launchDirectTerminal(
                name: TerminalBackendID.alacritty.displayName,
                executablePath: executablePath(
                    preferredPath: "/Applications/Alacritty.app/Contents/MacOS/alacritty",
                    bundleIdentifier: "org.alacritty",
                    relativeExecutablePath: "Contents/MacOS/alacritty"
                ),
                arguments: alacrittyArguments(neovimPath: preferences.neovimPath, filePaths: paths),
                neovimPath: preferences.neovimPath
            )
        case .customCommand:
            try launchCustomCommand(
                configuration: preferences.customCommand,
                neovimPath: preferences.neovimPath,
                filePaths: paths
            )
        }
    }

    private func launchAppleTerminal(neovimPath: String, filePaths: [String]) throws {
        try requireNeovim(at: neovimPath)
        _ = try requireApplication(
            name: TerminalBackendID.appleTerminal.displayName,
            bundleIdentifier: "com.apple.Terminal",
            fallbackPaths: [
                "/System/Applications/Utilities/Terminal.app",
                "/Applications/Utilities/Terminal.app",
            ]
        )

        let script = """
        tell application id "com.apple.Terminal"
            activate
            do script \(appleScriptLiteral(shellCommand(neovimPath: neovimPath, filePaths: filePaths)))
        end tell
        """
        try runAppleScript(script, applicationName: TerminalBackendID.appleTerminal.displayName)
    }

    private func launchITerm2(neovimPath: String, filePaths: [String]) throws {
        try requireNeovim(at: neovimPath)
        _ = try requireApplication(
            name: TerminalBackendID.iTerm2.displayName,
            bundleIdentifier: "com.googlecode.iterm2",
            fallbackPaths: [
                "/Applications/iTerm.app",
                "/Applications/iTerm2.app",
            ]
        )

        let command = appleScriptLiteral(shellCommand(neovimPath: neovimPath, filePaths: filePaths))
        let script = """
        tell application id "com.googlecode.iterm2"
            activate
            if (count of windows) = 0 then
                create window with default profile command \(command)
            else
                tell current window
                    create tab with default profile command \(command)
                end tell
            end if
        end tell
        """
        try runAppleScript(script, applicationName: TerminalBackendID.iTerm2.displayName)
    }

    private func launchDirectTerminal(
        name: String,
        executablePath: String,
        arguments: [String],
        neovimPath: String
    ) throws {
        try requireNeovim(at: neovimPath)
        guard fileManager.isExecutableFile(atPath: executablePath) else {
            throw TerminalLaunchError.missingApplication(name: name, expectedPath: executablePath)
        }

        try ProcessRunner.run(
            executable: executablePath,
            arguments: arguments,
            waitUntilExit: false
        )
    }

    private func launchCustomCommand(
        configuration: CustomCommandConfiguration,
        neovimPath: String,
        filePaths: [String]
    ) throws {
        let executablePath = configuration.executablePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !executablePath.isEmpty else {
            throw TerminalLaunchError.emptyCustomExecutable
        }

        guard fileManager.fileExists(atPath: executablePath) else {
            throw TerminalLaunchError.missingCustomExecutable(path: executablePath)
        }

        guard fileManager.isExecutableFile(atPath: executablePath) else {
            throw TerminalLaunchError.customExecutableNotExecutable(path: executablePath)
        }

        let arguments = try expandedCustomArguments(
            configuration.arguments,
            neovimPath: neovimPath,
            filePaths: filePaths
        )

        if let customNeovimPath = customNeovimPath(
            in: configuration.arguments,
            configuredNeovimPath: neovimPath
        ) {
            try requireNeovim(at: customNeovimPath)
        }

        try ProcessRunner.run(
            executable: executablePath,
            arguments: arguments,
            waitUntilExit: false
        )
    }

    private func ghosttyArguments(neovimPath: String, filePaths: [String]) -> [String] {
        terminalArguments(prefix: ["-e", neovimPath], filePaths: filePaths)
    }

    private func wezTermArguments(neovimPath: String, filePaths: [String]) -> [String] {
        terminalArguments(prefix: ["start", "--", neovimPath], filePaths: filePaths)
    }

    private func alacrittyArguments(neovimPath: String, filePaths: [String]) -> [String] {
        terminalArguments(prefix: ["-e", neovimPath], filePaths: filePaths)
    }

    private func terminalArguments(prefix: [String], filePaths: [String]) -> [String] {
        var arguments = prefix

        if !filePaths.isEmpty {
            arguments.append("--")
            arguments.append(contentsOf: filePaths)
        }

        return arguments
    }

    private func expandedCustomArguments(
        _ arguments: [String],
        neovimPath: String,
        filePaths: [String]
    ) throws -> [String] {
        var expanded: [String] = []
        var insertedFiles = false

        for argument in arguments {
            if argument == "{files}" {
                expanded.append(contentsOf: filePaths)
                insertedFiles = true
                continue
            }

            if argument.contains("{files}") {
                throw TerminalLaunchError.invalidFilesPlaceholder
            }

            expanded.append(argument.replacingOccurrences(of: "{nvim}", with: neovimPath))
        }

        if !insertedFiles {
            expanded.append(contentsOf: filePaths)
        }

        return expanded
    }

    private func customNeovimPath(
        in arguments: [String],
        configuredNeovimPath: String
    ) -> String? {
        if arguments.contains(where: { $0.contains("{nvim}") }) {
            return configuredNeovimPath
        }

        return arguments.first { argument in
            argument == configuredNeovimPath
                || argument == AppConstants.neovimPath
                || argument.hasSuffix("/nvim")
        }
    }

    private func executablePath(
        preferredPath: String,
        bundleIdentifier: String,
        relativeExecutablePath: String
    ) -> String {
        if fileManager.isExecutableFile(atPath: preferredPath) {
            return preferredPath
        }

        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            return preferredPath
        }

        return appURL.appendingPathComponent(relativeExecutablePath).path
    }

    private func requireApplication(
        name: String,
        bundleIdentifier: String,
        fallbackPaths: [String]
    ) throws -> URL {
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            return appURL
        }

        for fallbackPath in fallbackPaths where fileManager.fileExists(atPath: fallbackPath) {
            return URL(fileURLWithPath: fallbackPath)
        }

        throw TerminalLaunchError.missingApplication(
            name: name,
            expectedPath: fallbackPaths.first ?? bundleIdentifier
        )
    }

    private func requireNeovim(at path: String) throws {
        guard fileManager.isExecutableFile(atPath: path) else {
            throw TerminalLaunchError.missingNeovim(path: path)
        }
    }

    private func shellCommand(neovimPath: String, filePaths: [String]) -> String {
        var command = [shellQuoted(neovimPath)]
        if !filePaths.isEmpty {
            command.append("--")
            command.append(contentsOf: filePaths.map(shellQuoted))
        }

        return command.joined(separator: " ")
    }

    private func shellQuoted(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }

    private func appleScriptLiteral(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }

    private func runAppleScript(_ script: String, applicationName: String) throws {
        let result = try ProcessRunner.run(
            executable: "/usr/bin/osascript",
            arguments: ["-e", script]
        )

        guard result.succeeded else {
            throw TerminalLaunchError.launchFailed(
                backendName: applicationName,
                detail: result.standardError.isEmpty ? result.standardOutput : result.standardError
            )
        }
    }
}

public enum TerminalLaunchError: LocalizedError {
    case missingApplication(name: String, expectedPath: String)
    case missingNeovim(path: String)
    case emptyCustomExecutable
    case missingCustomExecutable(path: String)
    case customExecutableNotExecutable(path: String)
    case invalidFilesPlaceholder
    case launchFailed(backendName: String, detail: String)

    public var errorDescription: String? {
        switch self {
        case let .missingApplication(name, expectedPath):
            return "\(name) is missing. Install it or choose another terminal backend. Expected \(expectedPath)."
        case let .missingNeovim(path):
            return "Neovim is missing or not executable at \(path). Choose Neovim or install nvim."
        case .emptyCustomExecutable:
            return "Custom Command executable path cannot be empty."
        case let .missingCustomExecutable(path):
            return "Custom Command executable does not exist at \(path)."
        case let .customExecutableNotExecutable(path):
            return "Custom Command executable is not runnable at \(path)."
        case .invalidFilesPlaceholder:
            return "Use {files} as its own Custom Command argument so it can expand to one or many file paths."
        case let .launchFailed(backendName, detail):
            let suffix = detail.isEmpty ? "" : " \(detail)"
            return "\(backendName) launch failed. macOS may prompt for Automation permission when AppleScript is used.\(suffix)"
        }
    }
}
