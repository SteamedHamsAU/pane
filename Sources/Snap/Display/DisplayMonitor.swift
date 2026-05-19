import AppKit
import ColorSync
import CoreGraphics
import Foundation

/// Delegate protocol for display connection events.
@MainActor
protocol DisplayMonitorDelegate: AnyObject {
    func displayDidConnect(
        id: CGDirectDisplayID,
        uuid: String,
        name: String,
        resolution: CGSize
    )
    func displayDidDisconnect(id: CGDirectDisplayID)

    /// Called when an external display enters a mirror set without being freshly
    /// connected — typically caused by macOS resetting to mirrored on wake/unlock.
    func displayDidEnterMirrorSet(
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
///
/// Marked `@unchecked Sendable` because the C callback bridge requires passing
/// `self` as an opaque pointer across thread boundaries. Thread safety is
/// maintained by dispatching all mutable state access to `@MainActor` via Task.
final class DisplayMonitor: @unchecked Sendable {
    @MainActor weak var delegate: DisplayMonitorDelegate?

    private let logger: SnapLogger

    /// Tracks pending debounce tasks per display ID so rapid events are coalesced.
    @MainActor private var pendingEvents: [CGDirectDisplayID: Task<Void, Never>] = [:]

    /// Tracks pending mirror-correction debounce tasks separately from connect/disconnect
    /// so that mirror events never cancel a pending connect or disconnect.
    @MainActor private var pendingMirrorCorrections: [CGDirectDisplayID: Task<Void, Never>] = [:]

    /// Set when monitoring stops; checked by in-flight debounce tasks to bail out.
    @MainActor private var isStopped = false

    /// How long to wait for additional events before dispatching.
    private let debounceInterval: Duration

    /// Returns whether a display ID is the built-in panel. Injectable for testing.
    private let isBuiltIn: @Sendable (CGDirectDisplayID) -> Bool

    /// Returns whether a display ID is currently online. Injectable for testing.
    private let isOnline: @Sendable (CGDirectDisplayID) -> Bool

    /// Returns whether a display ID is currently in a mirror set. Injectable for testing.
    private let isInMirrorSet: @Sendable (CGDirectDisplayID) -> Bool

    /// Returns the persistent UUID string for a display ID. Injectable for testing.
    private let displayUUIDProvider: @Sendable (CGDirectDisplayID) -> String

    /// Returns the display bounds for a display ID. Injectable for testing.
    private let displayBoundsProvider: @Sendable (CGDirectDisplayID) -> CGRect

    /// Returns the human-readable name for a display ID. Injectable for testing.
    private let displayNameProvider: @MainActor (CGDirectDisplayID) -> String

    /// The C callback for `CGDisplayRegisterReconfigurationCallback`.
    /// Bridges to the Swift instance via an `Unmanaged` pointer in `userInfo`.
    private static let reconfigurationCallback: CGDisplayReconfigurationCallBack = { displayID, flags, userInfo in
        guard let userInfo else { return }
        let monitor = Unmanaged<DisplayMonitor>.fromOpaque(userInfo).takeUnretainedValue()
        monitor.handleReconfiguration(displayID: displayID, flags: flags)
    }

    init(
        logStore: LogStore = LogStore(),
        debounceInterval: Duration = .milliseconds(500),
        isBuiltIn: @escaping @Sendable (CGDirectDisplayID) -> Bool = { CGDisplayIsBuiltin($0) != 0 },
        isOnline: @escaping @Sendable (CGDirectDisplayID) -> Bool = { displayID in
            var count: UInt32 = 0
            guard CGGetOnlineDisplayList(0, nil, &count) == .success, count > 0 else {
                return false
            }
            var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
            guard CGGetOnlineDisplayList(count, &ids, &count) == .success else {
                return false
            }
            return ids.contains(displayID)
        },
        isInMirrorSet: @escaping @Sendable (CGDirectDisplayID) -> Bool = { CGDisplayIsInMirrorSet($0) != 0 },
        displayUUID: @escaping @Sendable (CGDirectDisplayID) -> String = { displayID in
            guard let unmanagedUUID = CGDisplayCreateUUIDFromDisplayID(displayID) else {
                return "unknown-\(displayID)"
            }
            let cfUUID = unmanagedUUID.takeRetainedValue()
            guard let cfString = CFUUIDCreateString(nil, cfUUID) else {
                return "unknown-\(displayID)"
            }
            return cfString as String
        },
        displayBounds: @escaping @Sendable (CGDirectDisplayID) -> CGRect = { CGDisplayBounds($0) },
        displayName: @escaping @MainActor (CGDirectDisplayID) -> String = { displayID in
            for screen in NSScreen.screens {
                let screenID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
                if screenID == displayID {
                    return screen.localizedName
                }
            }
            return "External Display"
        }
    ) {
        self.logger = SnapLogger(category: "DisplayMonitor", logStore: logStore)
        self.debounceInterval = debounceInterval
        self.isBuiltIn = isBuiltIn
        self.isOnline = isOnline
        self.isInMirrorSet = isInMirrorSet
        self.displayUUIDProvider = displayUUID
        self.displayBoundsProvider = displayBounds
        self.displayNameProvider = displayName
    }

    // MARK: - Monitoring lifecycle

    /// Start listening for display configuration changes.
    @MainActor
    func startMonitoring() {
        isStopped = false
        let pointer = Unmanaged.passUnretained(self).toOpaque()
        let status = CGDisplayRegisterReconfigurationCallback(Self.reconfigurationCallback, pointer)
        if status != .success {
            logger.error("Failed to register display reconfiguration callback: \(status.rawValue)")
        } else {
            logger.notice("Display monitoring started")
        }
    }

    /// Stop listening for display configuration changes.
    @MainActor
    func stopMonitoring() {
        let pointer = Unmanaged.passUnretained(self).toOpaque()
        CGDisplayRemoveReconfigurationCallback(Self.reconfigurationCallback, pointer)
        isStopped = true
        cancelAllPendingEvents()
        logger.notice("Display monitoring stopped")
    }

    /// Cancel all in-flight debounce tasks to prevent stale delegate calls.
    @MainActor
    private func cancelAllPendingEvents() {
        for task in pendingEvents.values {
            task.cancel()
        }
        pendingEvents.removeAll()
        for task in pendingMirrorCorrections.values {
            task.cancel()
        }
        pendingMirrorCorrections.removeAll()
    }

    deinit {
        let pointer = Unmanaged.passUnretained(self).toOpaque()
        CGDisplayRemoveReconfigurationCallback(Self.reconfigurationCallback, pointer)
    }

    // MARK: - Reconfiguration handler

    func handleReconfiguration(displayID: CGDirectDisplayID, flags: CGDisplayChangeSummaryFlags) {
        // Log all events for debugging
        logger.notice(
            // swiftformat:disable:next wrap
            // swiftlint:disable:next line_length
            "Reconfiguration event: display=\(displayID) flags=\(flags.rawValue) add=\(flags.contains(.addFlag)) builtin=\(CGDisplayIsBuiltin(displayID)) mirror=\(CGDisplayIsInMirrorSet(displayID))"
        )

        guard !isBuiltIn(displayID) else { return }

        // When both removeFlag and addFlag are present, macOS is reconfiguring
        // the display (e.g. mirror/unmirror transition) — not a physical disconnect.
        // Suppress both connect and disconnect to avoid re-applying config in a loop.
        if flags.contains(.removeFlag), flags.contains(.addFlag) {
            logger.notice("Display \(displayID) reconfigured (add+remove) — no action needed")
            return
        }

        if flags.contains(.removeFlag) {
            logger.notice("External display disconnected: \(displayID)")
            Task { @MainActor [weak self] in
                self?.cancelPendingMirrorCorrection(for: displayID)
            }
            dispatchDebounced(displayID: displayID) { monitor in
                monitor.delegate?.displayDidDisconnect(id: displayID)
            }
            return
        }

        // Detect wake-from-sleep mirror: macOS can reset to mirrored without
        // add/remove flags. Fire a separate delegate method so the app can
        // re-apply the user's saved extend config.
        if flags.contains(.mirrorFlag), !flags.contains(.addFlag), !flags.contains(.beginConfigurationFlag) {
            handleMirrorSetEntry(displayID: displayID)
            return
        }

        guard flags.contains(.addFlag) else { return }

        // A real connect supersedes any pending mirror correction
        Task { @MainActor [weak self] in
            self?.cancelPendingMirrorCorrection(for: displayID)
        }

        // Don't filter on mirror set here — macOS may briefly mirror during reconfiguration.
        // The display might already be in a mirror set if macOS auto-mirrors on connect.

        let capturedUUID = displayUUID(for: displayID)
        let bounds = displayBoundsProvider(displayID)
        let resolution = bounds.size

        logger.notice(
            "External display connected: [\(capturedUUID)] \(Int(resolution.width))×\(Int(resolution.height))"
        )

        let isOnline = self.isOnline
        dispatchDebounced(displayID: displayID) { monitor in
            // Post-debounce validation: verify the display is still present and
            // hasn't been replaced by a different physical display reusing the ID.
            guard isOnline(displayID) else {
                monitor.logger.notice(
                    "Display \(displayID) went offline during debounce — dropping connect event"
                )
                return
            }
            let currentUUID = monitor.displayUUID(for: displayID)
            guard currentUUID == capturedUUID else {
                monitor.logger.notice(
                    "Display \(displayID) UUID changed during debounce (\(capturedUUID) → \(currentUUID)) — dropping"
                )
                return
            }

            // Re-read metadata post-debounce — values may have settled
            let name = monitor.displayName(for: displayID)
            let settledBounds = monitor.displayBoundsProvider(displayID)
            monitor.delegate?.displayDidConnect(
                id: displayID,
                uuid: currentUUID,
                name: name,
                resolution: settledBounds.size
            )
        }
    }

    /// Debounces rapid events for the same display ID.
    ///
    /// macOS can fire multiple reconfiguration callbacks for a single physical
    /// plug event. This coalesces them so only the last event within the
    /// debounce window is dispatched to the delegate.
    private func dispatchDebounced(
        displayID: CGDirectDisplayID,
        action: @escaping @MainActor (DisplayMonitor) -> Void
    ) {
        Task { @MainActor [weak self] in
            guard let self, !self.isStopped else { return }
            self.pendingEvents[displayID]?.cancel()
            self.pendingEvents[displayID] = Task { @MainActor [weak self] in
                guard let self else { return }
                try? await Task.sleep(for: self.debounceInterval)
                guard !Task.isCancelled, !self.isStopped else { return }
                self.pendingEvents.removeValue(forKey: displayID)
                action(self)
            }
        }
    }

    /// Debounces mirror-correction events separately from connect/disconnect
    /// so that a mirror event never cancels a pending connect or disconnect.
    private func dispatchMirrorCorrection(
        displayID: CGDirectDisplayID,
        action: @escaping @MainActor (DisplayMonitor) -> Void
    ) {
        Task { @MainActor [weak self] in
            guard let self, !self.isStopped else { return }
            self.pendingMirrorCorrections[displayID]?.cancel()
            self.pendingMirrorCorrections[displayID] = Task { @MainActor [weak self] in
                guard let self else { return }
                try? await Task.sleep(for: self.debounceInterval)
                guard !Task.isCancelled, !self.isStopped else { return }
                self.pendingMirrorCorrections.removeValue(forKey: displayID)
                action(self)
            }
        }
    }

    /// Cancels any pending mirror correction for the given display, e.g. when a
    /// real connect or disconnect event supersedes it.
    @MainActor
    private func cancelPendingMirrorCorrection(for displayID: CGDirectDisplayID) {
        pendingMirrorCorrections[displayID]?.cancel()
        pendingMirrorCorrections.removeValue(forKey: displayID)
    }

    // MARK: - Mirror set detection

    /// Handles a display entering a mirror set without being freshly connected
    /// (typically macOS resetting to mirrored on wake/unlock).
    private func handleMirrorSetEntry(displayID: CGDirectDisplayID) {
        let capturedUUID = displayUUID(for: displayID)
        let bounds = displayBoundsProvider(displayID)
        let resolution = bounds.size

        logger.notice(
            "Display \(displayID) entered mirror set (wake/reconfigure): "
                + "[\(capturedUUID)] \(Int(resolution.width))×\(Int(resolution.height))"
        )

        let isOnline = self.isOnline
        let isInMirrorSet = self.isInMirrorSet
        dispatchMirrorCorrection(displayID: displayID) { monitor in
            guard isOnline(displayID) else {
                monitor.logger.notice(
                    "Display \(displayID) went offline during debounce — dropping mirror event"
                )
                return
            }
            guard isInMirrorSet(displayID) else {
                monitor.logger.notice(
                    "Display \(displayID) no longer mirrored after debounce — dropping"
                )
                return
            }
            let currentUUID = monitor.displayUUID(for: displayID)
            guard currentUUID == capturedUUID else {
                monitor.logger.notice(
                    "Display \(displayID) UUID changed during debounce — dropping mirror event"
                )
                return
            }

            let name = monitor.displayName(for: displayID)
            let settledBounds = monitor.displayBoundsProvider(displayID)
            monitor.delegate?.displayDidEnterMirrorSet(
                id: displayID,
                uuid: currentUUID,
                name: name,
                resolution: settledBounds.size
            )
        }
    }

    // MARK: - Display helpers

    /// Returns a persistent UUID string for the given display.
    func displayUUID(for displayID: CGDirectDisplayID) -> String {
        let uuid = displayUUIDProvider(displayID)
        if uuid.hasPrefix("unknown-") {
            logger.warning("Could not create UUID for display \(displayID), using fallback")
        }
        return uuid
    }

    /// Returns the human-readable product name via NSScreen.
    @MainActor
    func displayName(for displayID: CGDirectDisplayID) -> String {
        let name = displayNameProvider(displayID)
        if name == "External Display" {
            logger.notice("No NSScreen match for display \(displayID), using fallback")
        }
        return name
    }
}

// MARK: - Boolean bridging for CGDisplay queries

private extension boolean_t {
    var boolValue: Bool {
        self != 0
    }
}
