import AppKit
import TrimControlCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let launcher = NeovimLauncher()
    private let launchServices = LaunchServicesManager()
    private let externalOpenerRouter = ExternalOpenerRouter()
    private var launchSettingsTask: Task<Void, Never>?
    private var didReceiveFileOpenEventDuringLaunch = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        _ = try? launchServices.registerInstalledApp(at: Bundle.main.bundleURL)
        scheduleSettingsWindowForDirectLaunch()
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        cancelDirectLaunchSettingsWindow()
        let fileURLs = filenames.map { URL(fileURLWithPath: $0) }

        do {
            try open(fileURLs: fileURLs)
            sender.reply(toOpenOrPrint: .success)
        } catch {
            reportOpenFailure(error)
            sender.reply(toOpenOrPrint: .failure)
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        cancelDirectLaunchSettingsWindow()

        do {
            try open(fileURLs: urls)
        } catch {
            reportOpenFailure(error)
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        SettingsWindowPresenter.show()
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationDidResignActive(_ notification: Notification) {
        if !NSApp.windows.contains(where: \.isVisible) {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        launchSettingsTask?.cancel()
    }

    private func open(fileURLs: [URL]) throws {
        let routingResult = externalOpenerRouter.partition(fileURLs: fileURLs)

        if !routingResult.externalFileURLs.isEmpty {
            try externalOpenerRouter.openExternally(fileURLs: routingResult.externalFileURLs)
        }

        if !routingResult.neovimFileURLs.isEmpty {
            try launcher.open(fileURLs: routingResult.neovimFileURLs)
        }
    }

    private func reportOpenFailure(_ error: Error) {
        NSLog("%@", OpenFailureMessage.logMessage(for: error))
        Task { @MainActor in
            SettingsWindowPresenter.show(message: OpenFailureMessage.userMessage(for: error))
        }
    }

    private func scheduleSettingsWindowForDirectLaunch() {
        launchSettingsTask?.cancel()
        launchSettingsTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 700_000_000)
            guard let self, !Task.isCancelled, !self.didReceiveFileOpenEventDuringLaunch else {
                return
            }

            SettingsWindowPresenter.show()
        }
    }

    private func cancelDirectLaunchSettingsWindow() {
        didReceiveFileOpenEventDuringLaunch = true
        launchSettingsTask?.cancel()
        launchSettingsTask = nil
    }

}
