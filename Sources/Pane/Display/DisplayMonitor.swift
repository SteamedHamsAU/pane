import ColorSync
import CoreGraphics
import Foundation
import IOKit
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
            Self.logger.info("Display monitoring started")
        }
    }

    /// Stop listening for display configuration changes.
    func stopMonitoring() {
        let pointer = Unmanaged.passUnretained(self).toOpaque()
        CGDisplayRemoveReconfigurationCallback(Self.reconfigurationCallback, pointer)
        Self.logger.info("Display monitoring stopped")
    }

    // MARK: - Reconfiguration handler

    func handleReconfiguration(displayID: CGDirectDisplayID, flags: CGDisplayChangeSummaryFlags) {
        guard flags.contains(.addFlag) else { return }
        guard !CGDisplayIsBuiltin(displayID).boolValue else { return }
        guard !CGDisplayIsInMirrorSet(displayID).boolValue else { return }

        let uuid = displayUUID(for: displayID)
        let name = displayName(for: displayID)
        let bounds = CGDisplayBounds(displayID)
        let resolution = bounds.size

        Self.logger.info("External display connected: \(name) [\(uuid)] \(Int(resolution.width))×\(Int(resolution.height))")

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

    /// Returns the human-readable product name via IOKit.
    func displayName(for displayID: CGDirectDisplayID) -> String {
        var serialPortIterator = io_iterator_t()
        let matching = IOServiceMatching("IODisplayConnect")

        let result = IOServiceGetMatchingServices(kIOMainPortDefault, matching, &serialPortIterator)
        guard result == KERN_SUCCESS else {
            Self.logger.warning("IOServiceGetMatchingServices failed for display \(displayID)")
            return "External Display"
        }
        defer { IOObjectRelease(serialPortIterator) }

        var service = IOIteratorNext(serialPortIterator)
        while service != IO_OBJECT_NULL {
            defer {
                IOObjectRelease(service)
                service = IOIteratorNext(serialPortIterator)
            }

            guard let info = IODisplayCreateInfoDictionary(service, IOOptionBits(kIODisplayOnlyPreferredName))?.takeRetainedValue() as? [String: Any] else {
                continue
            }

            // Match by vendor and product ID
            guard let vendorID = info[kDisplayVendorID] as? UInt32,
                  let productID = info[kDisplayProductID] as? UInt32 else {
                continue
            }

            if vendorID == CGDisplayVendorNumber(displayID),
               productID == CGDisplayModelNumber(displayID) {
                if let names = info[kDisplayProductName] as? [String: String],
                   let name = names.values.first {
                    return name
                }
            }
        }

        Self.logger.info("No IOKit product name found for display \(displayID), using fallback")
        return "External Display"
    }
}

// MARK: - Boolean bridging for CGDisplay queries

private extension boolean_t {
    var boolValue: Bool { self != 0 }
}
