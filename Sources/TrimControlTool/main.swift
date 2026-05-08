import Foundation
import TrimControlCore

enum ToolError: Error, CustomStringConvertible {
    case missingArgument(String)
    case unknownCommand(String)
    case verificationFailed([String])

    var description: String {
        switch self {
        case .missingArgument(let argument):
            return "Missing argument: \(argument)"
        case .unknownCommand(let command):
            return "Unknown command: \(command)"
        case .verificationFailed(let errors):
            return errors.joined(separator: "\n")
        }
    }
}

@main
struct TrimControlTool {
    static func main() {
        do {
            try run()
        } catch {
            fputs("\(error)\n", stderr)
            exit(1)
        }
    }

    private static func run() throws {
        var arguments = Array(CommandLine.arguments.dropFirst())
        guard let command = arguments.first else {
            printUsage()
            return
        }
        arguments.removeFirst()

        switch command {
        case "generate-info-plist":
            let output = try requiredValue(after: "--output", in: arguments)
            try BundleMetadata.writeInfoPlist(to: URL(fileURLWithPath: output))
            print("Wrote \(output)")

        case "register-app":
            let appPath = value(after: "--app", in: arguments) ?? AppConstants.installedAppPath
            let result = try LaunchServicesManager().registerInstalledApp(at: URL(fileURLWithPath: appPath))
            if !result.succeeded {
                throw ToolError.verificationFailed([
                    "lsregister failed with status \(result.terminationStatus).",
                    result.standardError,
                ].filter { !$0.isEmpty })
            }
            print("Registered \(appPath)")

        case "apply-defaults":
            let appPath = value(after: "--app", in: arguments) ?? AppConstants.installedAppPath
            let groups = parseGroups(from: arguments)
            let manager = LaunchServicesManager()
            try manager.registerInstalledApp(at: URL(fileURLWithPath: appPath))
            let results = manager.applyDefaults(for: groups)
            try report(operation: "Applied", results: results)

        case "remove-defaults":
            let groups = parseGroups(from: arguments)
            let results = LaunchServicesManager().removeDefaults(for: groups)
            try report(operation: "Removed", results: results)

        case "status":
            let statuses = LaunchServicesManager().statuses()
            for status in statuses {
                let group = FileTypeCatalog.group(with: status.groupID)
                print("\(group?.title ?? status.groupID.rawValue): \(status.status.label) (\(status.matchedCount)/\(status.totalCount))")
            }

        case "verify-bundle":
            let appPath = value(after: "--app", in: arguments) ?? AppConstants.installedAppPath
            let result = BundleVerifier().verify(appURL: URL(fileURLWithPath: appPath))
            for message in result.messages {
                print("ok: \(message)")
            }
            if !result.succeeded {
                throw ToolError.verificationFailed(result.errors.map { "error: \($0)" })
            }

        case "verify-defaults":
            let appPath = value(after: "--app", in: arguments) ?? AppConstants.installedAppPath
            let requireDefaults = arguments.contains("--require-defaults")
            let manager = LaunchServicesManager()
            _ = try? manager.registerInstalledApp(at: URL(fileURLWithPath: appPath))
            let results = try manager.verifyExtensions(expectedAppPath: appPath)
            for result in results {
                let resolved = result.resolvedAppPath ?? "<none>"
                let prefix = result.matchesExpectedApp ? "ok" : "info"
                print("\(prefix): .\(result.extensionName) -> \(resolved)")
            }
            if requireDefaults {
                let failures = results.filter { !$0.matchesExpectedApp }
                if !failures.isEmpty {
                    throw ToolError.verificationFailed(
                        failures.map {
                            "error: .\($0.extensionName) resolved to \($0.resolvedAppPath ?? "<none>"), expected \(appPath)"
                        }
                    )
                }
            }

        case "list-groups":
            for group in FileTypeCatalog.groups {
                print("\(group.id.rawValue): \(group.title)")
            }

        default:
            throw ToolError.unknownCommand(command)
        }
    }

    private static func parseGroups(from arguments: [String]) -> [FileTypeGroup] {
        let rawGroups = value(after: "--groups", in: arguments)?
            .split(separator: ",")
            .map { String($0) } ?? ["all"]
        return FileTypeCatalog.selectedGroups(from: rawGroups)
    }

    private static func report(operation: String, results: [DefaultOperationResult]) throws {
        let failed = results.filter { !$0.succeeded }
        print("\(operation) \(results.count - failed.count)/\(results.count) defaults.")

        if !failed.isEmpty {
            throw ToolError.verificationFailed(
                failed.map { "error: \($0.contentType) failed with status \($0.status)" }
            )
        }
    }

    private static func value(after option: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: option) else {
            return nil
        }

        let valueIndex = arguments.index(after: index)
        guard valueIndex < arguments.endIndex else {
            return nil
        }

        return arguments[valueIndex]
    }

    private static func requiredValue(after option: String, in arguments: [String]) throws -> String {
        guard let value = value(after: option, in: arguments) else {
            throw ToolError.missingArgument(option)
        }

        return value
    }

    private static func printUsage() {
        print(
            """
            Usage:
              trimcontrol-tool generate-info-plist --output <path>
              trimcontrol-tool register-app --app <app>
              trimcontrol-tool apply-defaults --app <app> --groups all
              trimcontrol-tool remove-defaults --groups all
              trimcontrol-tool status
              trimcontrol-tool verify-bundle --app <app>
              trimcontrol-tool verify-defaults --app <app> [--require-defaults]
              trimcontrol-tool list-groups
            """
        )
    }
}
