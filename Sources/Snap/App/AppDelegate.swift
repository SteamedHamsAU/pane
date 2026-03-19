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
        subsystem: Bundle.main.bundleIdentifier ?? "au.steamedhams.snap",
        category: "AppDelegate"
    )

    func applicationDidFinishLaunching(_: Notification) {
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

        // Scan for displays already connected at launch
        scanForConnectedDisplays()

        Self.logger.notice("Snap started")
    }

    func applicationWillTerminate(_: Notification) {
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
        let diagonalInches = sqrt(
            physicalSize.width * physicalSize.width + physicalSize.height * physicalSize.height
        ) / 25.4
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

    // MARK: - Startup scan

    /// Finds external displays already connected when the app launches.
    private func scanForConnectedDisplays() {
        guard let monitor = displayMonitor else { return }

        var displayCount: UInt32 = 0
        guard CGGetOnlineDisplayList(0, nil, &displayCount) == .success,
              displayCount > 0
        else {
            Self.logger.notice("No online displays found at launch")
            return
        }

        var displayIDs = [CGDirectDisplayID](repeating: 0, count: Int(displayCount))
        guard CGGetOnlineDisplayList(displayCount, &displayIDs, &displayCount) == .success else {
            Self.logger.error("Failed to enumerate online displays")
            return
        }

        for id in displayIDs where CGDisplayIsBuiltin(id) == 0 {
            let uuid = monitor.displayUUID(for: id)
            let name = monitor.displayName(for: id)
            let bounds = CGDisplayBounds(id)
            Self.logger.notice(
                "Found external display at launch: \(name) [\(uuid)]"
            )
            displayDidConnect(
                id: id,
                uuid: uuid,
                name: name,
                resolution: bounds.size
            )
        }
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

            let modeName = savedConfig.mode.displayName.lowercased()
            let modeLabel: String
            switch savedConfig.mode {
            case .extend:
                let presetName = savedConfig.extendPreset.displayName.lowercased()
                modeLabel = "\(modeName) \(presetName)"
            case .mirror:
                let targetName = savedConfig.mirrorTarget.displayName.lowercased()
                modeLabel = "\(modeName) \(targetName)"
            }
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

    func displayDidDisconnect(id: CGDirectDisplayID) {
        guard currentDisplay?.id == id else { return }
        let name = currentDisplay?.name ?? "unknown"
        Self.logger.notice("Display disconnected: \(name) (ID \(id))")
        currentDisplay = nil
        menuBarController?.updateCurrentDisplay(nil)
    }
}
