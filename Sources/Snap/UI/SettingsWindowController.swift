import AppKit
import Sparkle
import SwiftUI

/// Controls the settings window opened from the menu bar.
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let configStore: DisplayConfigStore
    private let logStore: LogStore
    private let updaterController: SPUStandardUpdaterController

    init(configStore: DisplayConfigStore, logStore: LogStore, updaterController: SPUStandardUpdaterController) {
        self.configStore = configStore
        self.logStore = logStore
        self.updaterController = updaterController
        super.init()
    }

    func show() {
        if let existing = window {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView(
            configStore: configStore,
            logStore: logStore,
            checkForUpdates: { [weak self] in
                self?.updaterController.checkForUpdates(nil)
            }
        )

        let hostingView = NSHostingView(rootView: settingsView)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 420),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Snap Settings"
        window.contentView = hostingView
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_: Notification) {
        window = nil
    }
}
