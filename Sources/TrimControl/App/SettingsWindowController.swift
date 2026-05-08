import AppKit
import SwiftUI

@MainActor
enum SettingsWindowPresenter {
    private static var showHandler: ((String?) -> Void)?

    static func configure(showHandler: @escaping (String?) -> Void) {
        self.showHandler = showHandler
    }

    static func show(message: String? = nil) {
        showHandler?(message)
    }
}

@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    static let shared = SettingsWindowController()

    private var window: NSWindow?

    func show(appState: AppState) {
        NSApp.setActivationPolicy(.regular)

        if let window {
            window.makeKeyAndOrderFront(nil)
            activateApp()
            return
        }

        let rootView = ContentView()
            .environmentObject(appState)
            .frame(minWidth: 980, minHeight: 640)
            .onAppear {
                appState.refreshStatus()
            }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1120, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "TrimControl"
        window.minSize = NSSize(width: 980, height: 640)
        window.contentViewController = NSHostingController(rootView: rootView)
        window.delegate = self
        window.isReleasedWhenClosed = false
        window.center()
        window.makeKeyAndOrderFront(nil)

        self.window = window
        activateApp()
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
        NSApp.setActivationPolicy(.accessory)
    }

    private func activateApp() {
        NSApp.activate(ignoringOtherApps: true)
        NSRunningApplication.current.activate(options: [.activateAllWindows])
    }
}
