import AppKit
import ColorSync
import CoreGraphics
import Foundation
import os

/// Delegate protocol for display connection events.
@MainActor
protocol DisplayMonitorDelegate: AnyObject {
    func displayDidConnect(
        id: CGDirectDisplayID,
        uuid: String,
        name: String,
        resolution: CGSize
    )
}

/// Registers for CGDisplay reconfiguration events and dispatches to delegate.
///
/// The CGDisplay callback arrives on an arbitrary thread — this class dispatches
/// all delegate calls to `@MainActor`.
final class DisplayMonitor: @unchecked Sendable {

    @MainActor weak var delegate: DisplayMonitorDelegate?

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "au.steamedhams.pane",
        category: "DisplayMonitor"
    )

    /// The C callback for `CGDisplayRegisterReconfigurationCallback`.
    /// Bridges to the Swift instance via an `Unmanaged` pointer in `userInfo`.
    private static let reconfigurationCallback: CGDisplayReconfigurationCallBack = {
        displayID, flags, userInfo in

        guard let userInfo else { return }
        let monitor = Unmanaged<DisplayMonitor>.fromOpaque(userInfo).takeUnretainedValue()
        monitor.handleReconfiguration(displayID: displayID, flags: flags)
    }

    init() {}

    // MARK: - Monitoring lifecycle

    /// Start listening for display configuration changes.
    func startMonitoring() {
        let pointer = Unmanaged.passUnretained(self).toOpaque()
        let status = CGDisplayRegisterReconfigurationCallback(Self.reconfigurationCallback, pointer)
        if status != .success {
            Self.logger.error("Failed to register display reconfiguration callback: \(status.rawValue)")
        } else {
            Self.logger.notice("Display monitoring started")
        }
    }

    /// Stop listening for display configuration changes.
    func stopMonitoring() {
        let pointer = Unmanaged.passUnretained(self).toOpaque()
        CGDisplayRemoveReconfigurationCallback(Self.reconfigurationCallback, pointer)
        Self.logger.notice("Display monitoring stopped")
    }

    // MARK: - Reconfiguration handler

    func handleReconfiguration(displayID: CGDirectDisplayID, flags: CGDisplayChangeSummaryFlags) {
        // Log all events for debugging
        Self.logger.notice("Reconfiguration event: display=\(displayID) flags=\(flags.rawValue) add=\(flags.contains(.addFlag)) builtin=\(CGDisplayIsBuiltin(displayID)) mirror=\(CGDisplayIsInMirrorSet(displayID))")

        guard flags.contains(.addFlag) else { return }
        guard !CGDisplayIsBuiltin(displayID).boolValue else { return }

        // Don't filter on mirror set here — macOS may briefly mirror during reconfiguration.
        // The display might already be in a mirror set if macOS auto-mirrors on connect.

        let uuid = displayUUID(for: displayID)
        let name = displayName(for: displayID)
        let bounds = CGDisplayBounds(displayID)
        let resolution = bounds.size

        Self.logger.notice("External display connected: \(name) [\(uuid)] \(Int(resolution.width))×\(Int(resolution.height))")

        Task { @MainActor in
            self.delegate?.displayDidConnect(
                id: displayID,
                uuid: uuid,
                name: name,
                resolution: resolution
            )
        }
    }

    // MARK: - Display helpers

    /// Returns a persistent UUID string for the given display.
    func displayUUID(for displayID: CGDirectDisplayID) -> String {
        guard let unmanagedUUID = CGDisplayCreateUUIDFromDisplayID(displayID) else {
            Self.logger.warning("Could not create UUID for display \(displayID), using fallback")
            return "unknown-\(displayID)"
        }
        let cfUUID = unmanagedUUID.takeRetainedValue()
        guard let cfString = CFUUIDCreateString(nil, cfUUID) else {
            return "unknown-\(displayID)"
        }
        return cfString as String
    }

    /// Returns the human-readable product name via NSScreen.
    func displayName(for displayID: CGDirectDisplayID) -> String {
        for screen in NSScreen.screens {
            let screenID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
            if screenID == displayID {
                return screen.localizedName
            }
        }
        Self.logger.notice("No NSScreen match for display \(displayID), using fallback")
        return "External Display"
    }
}

// MARK: - Boolean bridging for CGDisplay queries

private extension boolean_t {
    var boolValue: Bool { self != 0 }
}
