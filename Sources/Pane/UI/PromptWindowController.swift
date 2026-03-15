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
        displayID: CGDirectDisplayID,
        uuid: String,
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
        hostingView.setFrameSize(hostingView.fittingSize)

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: hostingView.fittingSize),
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

        // Centre on the connected display or main screen
        if let screen = screenForDisplay(displayID) ?? NSScreen.main {
            let screenFrame = screen.visibleFrame
            let panelSize = panel.frame.size
            let x = screenFrame.midX - panelSize.width / 2
            let y = screenFrame.midY - panelSize.height / 2
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

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
}
