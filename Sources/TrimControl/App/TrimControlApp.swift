import SwiftUI
import TrimControlCore

@main
struct TrimControlApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState: AppState

    init() {
        let appState = AppState()
        _appState = StateObject(wrappedValue: appState)
        SettingsWindowPresenter.configure { message in
            if let message {
                appState.lastMessage = message
            }

            SettingsWindowController.shared.show(appState: appState)
        }
    }

    var body: some Scene {
        MenuBarExtra("TrimControl", systemImage: "terminal") {
            MenuBarView()
                .environmentObject(appState)
        }
        .commands {
            TrimControlCommands(appState: appState)
        }
    }
}
