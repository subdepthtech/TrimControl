import SwiftUI

struct FileTypeCommandContext {
    let selectAll: () -> Void
    let clearSelection: () -> Void
    let toggleFocused: () -> Void
}

private struct FileTypeCommandContextKey: FocusedValueKey {
    typealias Value = FileTypeCommandContext
}

extension FocusedValues {
    var fileTypeCommandContext: FileTypeCommandContext? {
        get { self[FileTypeCommandContextKey.self] }
        set { self[FileTypeCommandContextKey.self] = newValue }
    }
}

struct TrimControlCommands: Commands {
    @ObservedObject var appState: AppState
    @FocusedValue(\.fileTypeCommandContext) private var fileTypeCommandContext

    var body: some Commands {
        CommandGroup(replacing: .appSettings) {
            Button("Settings…") {
                appState.requestNavigation(to: SidebarDestination.general.rawValue)
            }
            .keyboardShortcut(",", modifiers: .command)
        }

        CommandMenu("Defaults") {
            Button("Apply All Defaults") {
                appState.applyAllDefaults()
            }
            .disabled(appState.isWorking)

            Button("Apply Selected") {
                appState.applySelectedDefaults()
            }
            .disabled(appState.isWorking)

            Button("Remove Selected") {
                appState.removeSelectedDefaults()
            }
            .disabled(appState.isWorking)

            Divider()

            Button("Verify Samples") {
                appState.verifySamples()
            }
            .keyboardShortcut("v", modifiers: [.command, .shift])
            .disabled(appState.isWorking)

            Button("Open Test File") {
                appState.openTestFile()
            }
            .keyboardShortcut(.return, modifiers: [.command])
            .disabled(appState.isWorking)

            Button("Refresh Status") {
                appState.refreshStatus()
            }
            .keyboardShortcut("r", modifiers: .command)
            .disabled(appState.isWorking)
        }

        CommandMenu("File Types") {
            Button("Select All In Current Mode") {
                fileTypeCommandContext?.selectAll()
            }
            .keyboardShortcut("a", modifiers: .command)
            .disabled(fileTypeCommandContext == nil || appState.isWorking)

            Button("Clear Current Mode") {
                fileTypeCommandContext?.clearSelection()
            }
            .keyboardShortcut(.escape, modifiers: [])
            .disabled(fileTypeCommandContext == nil || appState.isWorking)

            Button("Toggle Focused Row") {
                fileTypeCommandContext?.toggleFocused()
            }
            .disabled(fileTypeCommandContext == nil || appState.isWorking)
        }
    }
}
