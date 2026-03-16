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
    private var settingsController: SettingsWindowController?
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
        menuBar.onTestNotification = { [weak self] in
            self?.toastController?.show(
                message: "External Display — extend right applied",
                onChangeTapped: {
                    Self.logger.notice("Change tapped from test notification")
                }
            )
        }
        menuBar.setup()
        menuBarController = menuBar

        // Prompt, toast, and settings controllers
        promptController = PromptWindowController()
        toastController = ToastWindowController()
        settingsController = SettingsWindowController(configStore: configStore, updaterController: updaterController)
        menuBar.onOpenSettings = { [weak self] in
            self?.settingsController?.show()
        }

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

        // Always save the config so the display appears in Settings.
        // rememberThisDisplay controls whether to auto-apply silently next time.
        var savedConfig = config
        savedConfig.displayName = name
        let nativeW = CGDisplayPixelsWide(displayID)
        let nativeH = CGDisplayPixelsHigh(displayID)
        savedConfig.resolutionWidth = nativeW
        savedConfig.resolutionHeight = nativeH
        let physicalSize = CGDisplayScreenSize(displayID)
        let diagonalInches = sqrt(physicalSize.width * physicalSize.width + physicalSize.height * physicalSize.height) / 25.4
        savedConfig.screenSizeInches = Int(diagonalInches.rounded())
        configStore.save(savedConfig, for: uuid)
        Self.logger.notice("Saved config for \(name) [\(uuid)] (auto-apply: \(config.rememberThisDisplay))")

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

        if let savedConfig = configStore.configuration(for: uuid), savedConfig.rememberThisDisplay {
            // Known display with auto-apply — apply silently
            DisplayConfigurator.apply(savedConfig, primaryID: CGMainDisplayID(), externalID: id)
            currentDisplay = ConnectedDisplay(
                id: id, uuid: uuid, name: name, resolution: resolution, appliedConfig: savedConfig
            )
            menuBarController?.updateCurrentDisplay(currentDisplay)

            let modeLabel = "\(savedConfig.mode.displayName.lowercased()) \(savedConfig.extendPreset.displayName.lowercased())"
            Self.logger.notice("Applied saved config: \(modeLabel)")

            // Show toast after a brief delay — the display reconfiguration
            // invalidates screen geometry, so we wait for it to settle
            let showToast = UserDefaults.standard.object(forKey: "showToastOnKnownDisplay") as? Bool ?? true
            if showToast {
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
            }
        } else {
            // Unknown display or known but not auto-apply — show prompt
            currentDisplay = ConnectedDisplay(
                id: id, uuid: uuid, name: name, resolution: resolution, appliedConfig: nil
            )
            menuBarController?.updateCurrentDisplay(currentDisplay)
            showPrompt(displayID: id, uuid: uuid, name: name, resolution: resolution)
        }
    }
}
