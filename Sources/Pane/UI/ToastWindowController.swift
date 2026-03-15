import AppKit
import SwiftUI

/// Ephemeral toast notification for known-display auto-apply events.
///
/// Appears bottom-right of the built-in display, auto-dismisses after configurable duration.
@MainActor
final class ToastWindowController {

    private var panel: NSPanel?
    private var dismissTask: Task<Void, Never>?

    func show(
        message: String,
        duration: TimeInterval = 4,
        onChangeTapped: @escaping () -> Void
    ) {
        dismiss()

        let toastView = ToastView(message: message, onChangeTapped: {
            onChangeTapped()
        })

        let hostingView = NSHostingView(rootView: toastView)
        hostingView.setFrameSize(hostingView.fittingSize)

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: hostingView.fittingSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.contentView = hostingView
        panel.isReleasedWhenClosed = false

        // Position bottom-right of built-in screen, 20pt inset
        let screen = builtInScreen() ?? NSScreen.main ?? NSScreen.screens.first
        if let screenFrame = screen?.visibleFrame {
            let panelSize = panel.frame.size
            let x = screenFrame.maxX - panelSize.width - 20
            let y = screenFrame.minY + 20
            panel.setFrameOrigin(NSPoint(x: x, y: y - 12)) // start 12pt lower for slide-up
        }

        panel.alphaValue = 0
        panel.orderFrontRegardless()
        self.panel = panel

        // Animate in: slide up 12pt + fade in
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
            var origin = panel.frame.origin
            origin.y += 12
            panel.animator().setFrameOrigin(origin)
        }

        // Schedule auto-dismiss
        dismissTask = Task {
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            animateOut()
        }
    }

    func dismiss() {
        dismissTask?.cancel()
        panel?.close()
        panel = nil
    }

    private func animateOut() {
        guard let panel else { return }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.panel?.close()
            self?.panel = nil
        })
    }

    private func builtInScreen() -> NSScreen? {
        NSScreen.screens.first { screen in
            guard let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
                return false
            }
            return CGDisplayIsBuiltin(screenNumber) != 0
        }
    }
}

/// SwiftUI view for the toast notification content.
struct ToastView: View {
    let message: String
    let onChangeTapped: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(.green)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 2) {
                Text(message)
                    .font(.system(size: 13, weight: .medium))
                HStack(spacing: 4) {
                    Text("from memory ·")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Button("change") {
                        onChangeTapped()
                    }
                    .font(.system(size: 11))
                    .buttonStyle(.link)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
        )
    }
}
