import AppKit
import os
import Sparkle

/// Central coordinator: sets up menu bar, display monitoring, and Sparkle updates.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var menuBarController: MenuBarController?
    private var displayMonitor: DisplayMonitor?
    private var promptController: PromptWindowController?
    private var toastController: ToastWindowController?
    private let configStore = DisplayConfigStore()
    private var currentDisplay: ConnectedDisplay?

    private let updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "au.steamedhams.pane",
        category: "AppDelegate"
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu bar
        let menuBar = MenuBarController(configStore: configStore)
        menuBar.onRetriggerPrompt = { [weak self] in
            self?.retriggerPrompt()
        }
        menuBar.setup()
        menuBarController = menuBar

        // Prompt and toast controllers
        promptController = PromptWindowController()
        toastController = ToastWindowController()

        // Display monitoring
        let monitor = DisplayMonitor()
        monitor.delegate = self
        monitor.startMonitoring()
        displayMonitor = monitor

        Self.logger.notice("Pane started")
    }

    func applicationWillTerminate(_ notification: Notification) {
        displayMonitor?.stopMonitoring()
    }

    // MARK: - Prompt

    private func showPrompt(
        displayID: CGDirectDisplayID,
        uuid: String,
        name: String,
        resolution: CGSize
    ) {
        promptController?.show(
            displayID: displayID,
            uuid: uuid,
            name: name,
            resolution: resolution,
            onApply: { [weak self] config in
                self?.applyAndSave(config: config, displayID: displayID, uuid: uuid, name: name, resolution: resolution)
            },
            onDismiss: {
                Self.logger.notice("Prompt dismissed for \(name)")
            }
        )
    }

    private func applyAndSave(
        config: DisplayConfiguration,
        displayID: CGDirectDisplayID,
        uuid: String,
        name: String,
        resolution: CGSize
    ) {
        DisplayConfigurator.apply(config, primaryID: CGMainDisplayID(), externalID: displayID)

        if config.rememberThisDisplay {
            configStore.save(config, for: uuid)
            Self.logger.notice("Saved config for \(name) [\(uuid)]")
        }

        currentDisplay = ConnectedDisplay(
            id: displayID, uuid: uuid, name: name, resolution: resolution, appliedConfig: config
        )
        menuBarController?.updateCurrentDisplay(currentDisplay)
    }

    private func retriggerPrompt() {
        guard let display = currentDisplay else { return }
        showPrompt(
            displayID: display.id,
            uuid: display.uuid,
            name: display.name,
            resolution: display.resolution
        )
    }
}

// MARK: - DisplayMonitorDelegate

extension AppDelegate: DisplayMonitorDelegate {
    func displayDidConnect(
        id: CGDirectDisplayID,
        uuid: String,
        name: String,
        resolution: CGSize
    ) {
        Self.logger.notice("Display connected: \(name) [\(uuid)]")

        if let savedConfig = configStore.configuration(for: uuid) {
            // Known display — apply silently
            DisplayConfigurator.apply(savedConfig, primaryID: CGMainDisplayID(), externalID: id)
            currentDisplay = ConnectedDisplay(
                id: id, uuid: uuid, name: name, resolution: resolution, appliedConfig: savedConfig
            )
            menuBarController?.updateCurrentDisplay(currentDisplay)

            let modeLabel = "\(savedConfig.mode.displayName.lowercased()) \(savedConfig.extendPreset.displayName.lowercased())"
            Self.logger.notice("Applied saved config: \(modeLabel)")

            // Show toast after a brief delay — the display reconfiguration
            // invalidates screen geometry, so we wait for it to settle
            let toastMessage = "\(name) — \(modeLabel) applied"
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(1.5))
                Self.logger.notice("Showing toast: \(toastMessage)")
                self?.toastController?.show(
                    message: toastMessage,
                    onChangeTapped: { [weak self] in
                        self?.toastController?.dismiss()
                        self?.showPrompt(displayID: id, uuid: uuid, name: name, resolution: resolution)
                    }
                )
            }
        } else {
            // Unknown display — show prompt
            currentDisplay = ConnectedDisplay(
                id: id, uuid: uuid, name: name, resolution: resolution, appliedConfig: nil
            )
            menuBarController?.updateCurrentDisplay(currentDisplay)
            showPrompt(displayID: id, uuid: uuid, name: name, resolution: resolution)
        }
    }
}
