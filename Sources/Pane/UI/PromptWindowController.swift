import AppKit
import SwiftUI

/// Controls the prompt panel that appears when an unknown display connects.
///
/// Uses `NSPanel` with `nonactivatingPanel` style so it appears without
/// stealing focus from the current app.
@MainActor
final class PromptWindowController {
    private var panel: NSPanel?

    /// Show the prompt for a newly connected display.
    func show(
        name: String,
        resolution: CGSize,
        onApply: @escaping (DisplayConfiguration) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        dismiss()

        let promptView = PromptView(
            displayName: name,
            resolution: resolution,
            onApply: { [weak self] config in
                onApply(config)
                self?.dismiss()
            },
            onDismiss: { [weak self] in
                onDismiss()
                self?.dismiss()
            }
        )

        let hostingView = NSHostingView(rootView: promptView)

        // Size the panel to 60% of the built-in (MacBook) screen
        let targetScreen = builtInScreen() ?? NSScreen.main
        let screenFrame = targetScreen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let panelWidth = screenFrame.width * 0.6
        let panelHeight = screenFrame.height * 0.6

        let panelRect = NSRect(origin: .zero, size: NSSize(width: panelWidth, height: panelHeight))

        let panel = NSPanel(
            contentRect: panelRect,
            styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.titleVisibility = .hidden
        panel.contentView = hostingView
        panel.isReleasedWhenClosed = false

        // Centre on the built-in display (MacBook screen)
        let x = screenFrame.midX - panelWidth / 2
        let y = screenFrame.midY - panelHeight / 2
        panel.setFrameOrigin(NSPoint(x: x, y: y))

        panel.orderFrontRegardless()
        self.panel = panel
    }

    /// Dismiss the prompt panel.
    func dismiss() {
        panel?.close()
        panel = nil
    }

    /// Find the NSScreen corresponding to a CGDirectDisplayID.
    private func screenForDisplay(_ displayID: CGDirectDisplayID) -> NSScreen? {
        NSScreen.screens.first { screen in
            let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
            return screenNumber == displayID
        }
    }

    /// Find the built-in MacBook display.
    private func builtInScreen() -> NSScreen? {
        NSScreen.screens.first { screen in
            let key = NSDeviceDescriptionKey("NSScreenNumber")
            guard let screenNumber = screen.deviceDescription[key] as? CGDirectDisplayID else {
                return false
            }
            return CGDisplayIsBuiltin(screenNumber) != 0
        }
    }
}
