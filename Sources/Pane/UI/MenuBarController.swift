import AppKit

/// Manages the menu bar status item and its dynamic menu.
@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {

    private var statusItem: NSStatusItem?
    private let configStore: DisplayConfigStore
    private var currentDisplay: ConnectedDisplay?
    var onRetriggerPrompt: (() -> Void)?
    var onOpenSettings: (() -> Void)?
    var onTestNotification: (() -> Void)?

    init(configStore: DisplayConfigStore) {
        self.configStore = configStore
        super.init()
    }

    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "display", accessibilityDescription: "Pane")
        }
        let menu = NSMenu()
        menu.delegate = self
        statusItem?.menu = menu
    }

    func updateCurrentDisplay(_ display: ConnectedDisplay?) {
        currentDisplay = display
    }

    // MARK: - NSMenuDelegate

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let optionHeld = NSEvent.modifierFlags.contains(.option)

        // Current display status
        if let display = currentDisplay {
            let statusText: String
            if let config = display.appliedConfig {
                statusText = "\(display.name) · \(config.mode.displayName) \(config.extendPreset.displayName)"
            } else {
                statusText = "\(display.name) · connected"
            }
            let statusItem = NSMenuItem(title: statusText, action: nil, keyEquivalent: "")
            statusItem.isEnabled = false
            menu.addItem(statusItem)
        } else {
            let noDisplay = NSMenuItem(title: "No display connected", action: nil, keyEquivalent: "")
            noDisplay.isEnabled = false
            menu.addItem(noDisplay)
        }

        menu.addItem(.separator())

        // Option-only: Re-trigger prompt
        if optionHeld {
            let retrigger = NSMenuItem(title: "Re-trigger prompt", action: #selector(retriggerPrompt), keyEquivalent: "")
            retrigger.target = self
            retrigger.isEnabled = currentDisplay != nil
            menu.addItem(retrigger)

            let testNotif = NSMenuItem(title: "Test notification", action: #selector(testNotification), keyEquivalent: "")
            testNotif.target = self
            menu.addItem(testNotif)

            menu.addItem(.separator())
        }

        // Remembered displays submenu
        let rememberedItem = NSMenuItem(title: "Remembered displays", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        let entries = configStore.allEntries()
        if entries.isEmpty {
            let empty = NSMenuItem(title: "No remembered displays", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            submenu.addItem(empty)
        } else {
            for entry in entries {
                let label = "\(entry.uuid.prefix(8))… · \(entry.config.mode.displayName) \(entry.config.extendPreset.displayName)"
                let item = NSMenuItem(title: label, action: nil, keyEquivalent: "")
                item.isEnabled = false
                submenu.addItem(item)
            }
        }
        rememberedItem.submenu = submenu
        menu.addItem(rememberedItem)

        // Open Settings
        let settings = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        menu.addItem(.separator())

        // Option-only: build number
        if optionHeld {
            let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
            let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
            let devSuffix: String
            #if DEV_BUILD
            devSuffix = " (Dev)"
            #else
            devSuffix = ""
            #endif
            let versionItem = NSMenuItem(title: "v\(version) build \(build)\(devSuffix)", action: nil, keyEquivalent: "")
            versionItem.isEnabled = false
            menu.addItem(versionItem)

            menu.addItem(.separator())
        }

        // Quit
        let quit = NSMenuItem(title: "Quit Pane", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }

    // MARK: - Actions

    @objc private func retriggerPrompt() {
        onRetriggerPrompt?()
    }

    @objc private func testNotification() {
        onTestNotification?()
    }

    @objc private func openSettings() {
        onOpenSettings?()
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}

/// Tracks a currently connected external display.
struct ConnectedDisplay {
    let id: CGDirectDisplayID
    let uuid: String
    let name: String
    let resolution: CGSize
    var appliedConfig: DisplayConfiguration?
}
