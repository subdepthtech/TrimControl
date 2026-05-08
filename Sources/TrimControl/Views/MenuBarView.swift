import AppKit
import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Section("Status") {
            Text(appState.activeSummary)
                .font(TrimTokens.Typography.caption)
                .foregroundStyle(TrimTokens.Colors.textSecondary)
        }

        Divider()

        Section("Actions") {
            Button {
                appState.applyAllDefaults()
            } label: {
                Label("Apply All Defaults", systemImage: "sparkle")
            }

            Button {
                appState.applySelectedDefaults()
            } label: {
                Label("Apply Selected", systemImage: "checkmark.circle")
            }

            Button {
                appState.verifySamples()
            } label: {
                Label("Verify Defaults", systemImage: "checkmark.seal")
            }

            Button {
                appState.openTestFile()
            } label: {
                Label("Open Test File", systemImage: "play.rectangle")
            }
        }

        Divider()

        Button {
            openMain(at: "general")
        } label: {
            Label("Open Settings", systemImage: "gearshape")
        }

        Button {
            openMain(at: nil)
        } label: {
            Label("Open Window", systemImage: "macwindow")
        }

        Divider()

        Button("Quit TrimControl") {
            NSApp.terminate(nil)
        }
    }

    private func openMain(at destinationID: String?) {
        if let destinationID {
            appState.requestNavigation(to: destinationID)
        }
        SettingsWindowPresenter.show()
    }
}
