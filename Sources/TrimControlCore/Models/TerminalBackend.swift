import Foundation

public enum TerminalBackendID: String, CaseIterable, Codable, Identifiable, Sendable {
    case appleTerminal = "apple-terminal"
    case iTerm2 = "iterm2"
    case ghostty
    case wezTerm = "wezterm"
    case alacritty
    case customCommand = "custom-command"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .appleTerminal:
            return "Apple Terminal.app"
        case .iTerm2:
            return "iTerm2"
        case .ghostty:
            return "Ghostty"
        case .wezTerm:
            return "WezTerm"
        case .alacritty:
            return "Alacritty"
        case .customCommand:
            return "Custom Command"
        }
    }

    public var systemImage: String {
        switch self {
        case .appleTerminal:
            return "terminal"
        case .iTerm2:
            return "rectangle.terminal"
        case .ghostty:
            return "sparkles"
        case .wezTerm:
            return "command"
        case .alacritty:
            return "bolt"
        case .customCommand:
            return "terminal.badge.plus"
        }
    }

    public static let builtInBackends: [TerminalBackendID] = [
        .appleTerminal,
        .iTerm2,
        .ghostty,
        .wezTerm,
        .alacritty,
    ]
}

public struct CustomCommandConfiguration: Codable, Hashable, Sendable {
    public var name: String
    public var executablePath: String
    public var arguments: [String]

    public init(name: String, executablePath: String, arguments: [String]) {
        self.name = name
        self.executablePath = executablePath
        self.arguments = arguments
    }

    public static let empty = CustomCommandConfiguration(
        name: "Custom Command",
        executablePath: "",
        arguments: []
    )

    public static let tridentPreset = CustomCommandConfiguration(
        name: "Trident",
        executablePath: AppConstants.openToolPath,
        arguments: [
            "-n",
            "-b",
            AppConstants.tridentBundleIdentifier,
            "--args",
            "-e",
            AppConstants.neovimPath,
            "--",
            "{files}",
        ]
    )
}

public struct TerminalBackendPreferences: Hashable, Sendable {
    public var selectedBackendID: TerminalBackendID
    public var neovimPath: String
    public var customCommand: CustomCommandConfiguration

    public init(
        selectedBackendID: TerminalBackendID,
        neovimPath: String,
        customCommand: CustomCommandConfiguration
    ) {
        self.selectedBackendID = selectedBackendID
        self.neovimPath = neovimPath
        self.customCommand = customCommand
    }
}

public enum TerminalBackendDefaults {
    public static let selectedBackendIDKey = "terminalBackendID"
    public static let neovimPathKey = "neovimPath"
    public static let customCommandNameKey = "customCommandName"
    public static let customCommandExecutablePathKey = "customCommandExecutablePath"
    public static let customCommandArgumentsKey = "customCommandArguments"

    public static func preferences(from defaults: UserDefaults = .standard) -> TerminalBackendPreferences {
        let backendID = TerminalBackendID(
            rawValue: defaults.string(forKey: selectedBackendIDKey) ?? ""
        ) ?? .appleTerminal

        let neovimPath = nonEmpty(
            defaults.string(forKey: neovimPathKey),
            fallback: AppConstants.neovimPath
        )

        let customCommand = CustomCommandConfiguration(
            name: nonEmpty(
                defaults.string(forKey: customCommandNameKey),
                fallback: CustomCommandConfiguration.empty.name
            ),
            executablePath: defaults.string(forKey: customCommandExecutablePathKey) ?? "",
            arguments: defaults.stringArray(forKey: customCommandArgumentsKey)
                ?? CustomCommandConfiguration.empty.arguments
        )

        return TerminalBackendPreferences(
            selectedBackendID: backendID,
            neovimPath: neovimPath,
            customCommand: customCommand
        )
    }

    public static func save(
        preferences: TerminalBackendPreferences,
        to defaults: UserDefaults = .standard
    ) {
        defaults.set(preferences.selectedBackendID.rawValue, forKey: selectedBackendIDKey)
        defaults.set(preferences.neovimPath, forKey: neovimPathKey)
        defaults.set(preferences.customCommand.name, forKey: customCommandNameKey)
        defaults.set(preferences.customCommand.executablePath, forKey: customCommandExecutablePathKey)
        defaults.set(preferences.customCommand.arguments, forKey: customCommandArgumentsKey)
    }

    private static func nonEmpty(_ value: String?, fallback: String) -> String {
        guard let value else {
            return fallback
        }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }
}
