import CoreGraphics
@testable import Snap
import Testing

// MARK: - Mock delegate

@MainActor
private final class MockDisplayMonitorDelegate: DisplayMonitorDelegate {
    struct ConnectCall {
        let id: CGDirectDisplayID
        let uuid: String
        let name: String
        let resolution: CGSize
    }

    var connectCalls: [ConnectCall] = []
    var disconnectCalls: [CGDirectDisplayID] = []
    var mirrorCalls: [ConnectCall] = []

    func displayDidConnect(id: CGDirectDisplayID, uuid: String, name: String, resolution: CGSize) {
        connectCalls.append(ConnectCall(id: id, uuid: uuid, name: name, resolution: resolution))
    }

    func displayDidDisconnect(id: CGDirectDisplayID) {
        disconnectCalls.append(id)
    }

    func displayDidEnterMirrorSet(id: CGDirectDisplayID, uuid: String, name: String, resolution: CGSize) {
        mirrorCalls.append(ConnectCall(id: id, uuid: uuid, name: name, resolution: resolution))
    }
}

// MARK: - Tests

/// Non-built-in display IDs used in tests.
/// High IDs that won't match any real display, so `CGDisplayIsBuiltin` returns 0.
private let fakeDisplayA: CGDirectDisplayID = 999
private let fakeDisplayB: CGDirectDisplayID = 998

/// Slightly longer than the debounce interval to let it settle.
private let testDebounce: Duration = .milliseconds(100)
private let debounceWait: Duration = .milliseconds(250)

@MainActor
struct DisplayMonitorDebounceTests {
    private func makeSUT(
        isOnline: @escaping @Sendable (CGDirectDisplayID) -> Bool = { _ in true },
        isInMirrorSet: @escaping @Sendable (CGDirectDisplayID) -> Bool = { _ in false }
    ) -> (monitor: DisplayMonitor, delegate: MockDisplayMonitorDelegate) {
        let monitor = DisplayMonitor(
            debounceInterval: testDebounce,
            isBuiltIn: { $0 == CGMainDisplayID() },
            isOnline: isOnline,
            isInMirrorSet: isInMirrorSet,
            displayUUID: { "fake-uuid-\($0)" },
            displayBounds: { _ in CGRect(x: 0, y: 0, width: 2560, height: 1440) },
            displayName: { _ in "Fake Display" }
        )
        let delegate = MockDisplayMonitorDelegate()
        monitor.delegate = delegate
        return (monitor, delegate)
    }

    // MARK: - Connect

    @Test("Single connect dispatches after debounce")
    func singleConnect() async throws {
        let (monitor, delegate) = makeSUT()

        monitor.handleReconfiguration(displayID: fakeDisplayA, flags: .addFlag)

        // Immediately — debounce hasn't fired yet.
        #expect(delegate.connectCalls.isEmpty)

        try await Task.sleep(for: debounceWait)

        #expect(delegate.connectCalls.count == 1)
        #expect(delegate.connectCalls.first?.id == fakeDisplayA)
        #expect(delegate.connectCalls.first?.uuid == "fake-uuid-999")
        #expect(delegate.connectCalls.first?.name == "Fake Display")
        #expect(delegate.connectCalls.first?.resolution == CGSize(width: 2560, height: 1440))
    }

    @Test("Rapid connect events for same display coalesce into one")
    func rapidConnectsCoalesce() async throws {
        let (monitor, delegate) = makeSUT()

        monitor.handleReconfiguration(displayID: fakeDisplayA, flags: .addFlag)
        monitor.handleReconfiguration(displayID: fakeDisplayA, flags: .addFlag)
        monitor.handleReconfiguration(displayID: fakeDisplayA, flags: .addFlag)

        try await Task.sleep(for: debounceWait)

        #expect(delegate.connectCalls.count == 1)
    }

    @Test("Different displays dispatch independently")
    func differentDisplaysIndependent() async throws {
        let (monitor, delegate) = makeSUT()

        monitor.handleReconfiguration(displayID: fakeDisplayA, flags: .addFlag)
        monitor.handleReconfiguration(displayID: fakeDisplayB, flags: .addFlag)

        try await Task.sleep(for: debounceWait)

        let ids = Set(delegate.connectCalls.map(\.id))
        #expect(ids == [fakeDisplayA, fakeDisplayB])
    }

    // MARK: - Disconnect

    @Test("Single disconnect dispatches after debounce")
    func singleDisconnect() async throws {
        let (monitor, delegate) = makeSUT()

        monitor.handleReconfiguration(displayID: fakeDisplayA, flags: .removeFlag)

        #expect(delegate.disconnectCalls.isEmpty)

        try await Task.sleep(for: debounceWait)

        #expect(delegate.disconnectCalls.count == 1)
        #expect(delegate.disconnectCalls.first == fakeDisplayA)
    }

    // MARK: - Event replacement

    @Test("Disconnect replaces pending connect for same display")
    func disconnectReplacesConnect() async throws {
        let (monitor, delegate) = makeSUT()

        monitor.handleReconfiguration(displayID: fakeDisplayA, flags: .addFlag)
        monitor.handleReconfiguration(displayID: fakeDisplayA, flags: .removeFlag)

        try await Task.sleep(for: debounceWait)

        #expect(delegate.connectCalls.isEmpty, "Connect should have been cancelled")
        #expect(delegate.disconnectCalls.count == 1)
        #expect(delegate.disconnectCalls.first == fakeDisplayA)
    }

    // MARK: - Built-in filter

    @Test("Built-in display is filtered out")
    func builtInFiltered() async throws {
        let builtInID: CGDirectDisplayID = 42
        let monitor = DisplayMonitor(
            debounceInterval: testDebounce,
            isBuiltIn: { $0 == builtInID },
            isOnline: { _ in true },
            displayUUID: { "fake-uuid-\($0)" },
            displayBounds: { _ in CGRect(x: 0, y: 0, width: 2560, height: 1440) },
            displayName: { _ in "Fake Display" }
        )
        let delegate = MockDisplayMonitorDelegate()
        monitor.delegate = delegate

        monitor.handleReconfiguration(displayID: builtInID, flags: .addFlag)

        try await Task.sleep(for: debounceWait)

        #expect(delegate.connectCalls.isEmpty)
        #expect(delegate.disconnectCalls.isEmpty)
    }

    // MARK: - Post-debounce validation

    @Test("Phantom display gone during debounce does not trigger connect")
    func phantomDisplayDropped() async throws {
        // Display goes offline before debounce fires
        let (monitor, delegate) = makeSUT(isOnline: { _ in false })

        monitor.handleReconfiguration(displayID: fakeDisplayA, flags: .addFlag)

        try await Task.sleep(for: debounceWait)

        #expect(delegate.connectCalls.isEmpty, "Offline display should not trigger connect")
    }

    @Test("Display that stays online triggers connect normally")
    func onlineDisplayConnects() async throws {
        let (monitor, delegate) = makeSUT(isOnline: { _ in true })

        monitor.handleReconfiguration(displayID: fakeDisplayA, flags: .addFlag)

        try await Task.sleep(for: debounceWait)

        #expect(delegate.connectCalls.count == 1)
        #expect(delegate.connectCalls.first?.id == fakeDisplayA)
    }

    @Test("Disconnect events skip online check")
    func disconnectSkipsOnlineCheck() async throws {
        // isOnline returns false, but disconnects should still fire
        let (monitor, delegate) = makeSUT(isOnline: { _ in false })

        monitor.handleReconfiguration(displayID: fakeDisplayA, flags: .removeFlag)

        try await Task.sleep(for: debounceWait)

        #expect(delegate.disconnectCalls.count == 1, "Disconnect should fire regardless of online status")
    }

    // MARK: - Reconfiguration (add + remove)

    @Test("Reconfiguration with both add and remove flags is a no-op")
    func reconfigurationIsNoOp() async throws {
        let (monitor, delegate) = makeSUT()

        // macOS sends both flags during mirror/unmirror transitions
        let combined = CGDisplayChangeSummaryFlags(
            rawValue: CGDisplayChangeSummaryFlags.addFlag.rawValue
                | CGDisplayChangeSummaryFlags.removeFlag.rawValue
        )
        monitor.handleReconfiguration(displayID: fakeDisplayA, flags: combined)

        try await Task.sleep(for: debounceWait)

        #expect(delegate.connectCalls.isEmpty, "Should NOT treat as connect")
        #expect(delegate.disconnectCalls.isEmpty, "Should NOT treat as disconnect")
    }

    @Test("Remove-only flag still triggers disconnect")
    func removeOnlyStillDisconnects() async throws {
        let (monitor, delegate) = makeSUT()

        monitor.handleReconfiguration(displayID: fakeDisplayA, flags: .removeFlag)

        try await Task.sleep(for: debounceWait)

        #expect(delegate.disconnectCalls.count == 1)
        #expect(delegate.connectCalls.isEmpty)
    }

    // MARK: - Mirror set detection

    @Test("Mirror-only event fires displayDidEnterMirrorSet")
    func mirrorOnlyEventFiresMirrorDelegate() async throws {
        let (monitor, delegate) = makeSUT(isInMirrorSet: { _ in true })

        // Simulate wake-from-sleep: mirrorFlag without addFlag or removeFlag
        let mirrorFlags = CGDisplayChangeSummaryFlags(
            rawValue: CGDisplayChangeSummaryFlags.mirrorFlag.rawValue
                | CGDisplayChangeSummaryFlags.movedFlag.rawValue
                | CGDisplayChangeSummaryFlags.desktopShapeChangedFlag.rawValue
        )
        monitor.handleReconfiguration(displayID: fakeDisplayA, flags: mirrorFlags)

        try await Task.sleep(for: debounceWait)

        #expect(delegate.mirrorCalls.count == 1)
        #expect(delegate.mirrorCalls.first?.id == fakeDisplayA)
        #expect(delegate.mirrorCalls.first?.uuid == "fake-uuid-999")
        #expect(delegate.connectCalls.isEmpty, "Should NOT also fire connect")
    }

    @Test("Mirror event with addFlag fires connect, not mirror")
    func mirrorWithAddFlagsFiresConnect() async throws {
        let (monitor, delegate) = makeSUT(isInMirrorSet: { _ in true })

        // Display connected in mirrored state — addFlag present
        let flags = CGDisplayChangeSummaryFlags(
            rawValue: CGDisplayChangeSummaryFlags.addFlag.rawValue
                | CGDisplayChangeSummaryFlags.mirrorFlag.rawValue
        )
        monitor.handleReconfiguration(displayID: fakeDisplayA, flags: flags)

        try await Task.sleep(for: debounceWait)

        #expect(delegate.connectCalls.count == 1, "addFlag should trigger connect path")
        #expect(delegate.mirrorCalls.isEmpty, "Should NOT fire mirror delegate when addFlag present")
    }

    @Test("Built-in display mirror event is filtered")
    func builtInMirrorFiltered() async throws {
        let builtInID: CGDirectDisplayID = 42
        let monitor = DisplayMonitor(
            debounceInterval: testDebounce,
            isBuiltIn: { $0 == builtInID },
            isOnline: { _ in true },
            isInMirrorSet: { _ in true },
            displayUUID: { "fake-uuid-\($0)" },
            displayBounds: { _ in CGRect(x: 0, y: 0, width: 2560, height: 1440) },
            displayName: { _ in "Fake Display" }
        )
        let delegate = MockDisplayMonitorDelegate()
        monitor.delegate = delegate

        monitor.handleReconfiguration(displayID: builtInID, flags: .mirrorFlag)

        try await Task.sleep(for: debounceWait)

        #expect(delegate.mirrorCalls.isEmpty)
    }

    @Test("Mirror event dropped when display goes offline during debounce")
    func mirrorDroppedWhenOffline() async throws {
        let (monitor, delegate) = makeSUT(isOnline: { _ in false }, isInMirrorSet: { _ in true })

        monitor.handleReconfiguration(displayID: fakeDisplayA, flags: .mirrorFlag)

        try await Task.sleep(for: debounceWait)

        #expect(delegate.mirrorCalls.isEmpty, "Offline display should not fire mirror delegate")
    }

    @Test("Mirror event dropped when display is no longer mirrored after debounce")
    func mirrorDroppedWhenNoLongerMirrored() async throws {
        let (monitor, delegate) = makeSUT(isInMirrorSet: { _ in false })

        monitor.handleReconfiguration(displayID: fakeDisplayA, flags: .mirrorFlag)

        try await Task.sleep(for: debounceWait)

        #expect(delegate.mirrorCalls.isEmpty, "Should drop if no longer in mirror set")
    }

    @Test("Rapid mirror events coalesce into one")
    func rapidMirrorEventsCoalesce() async throws {
        let (monitor, delegate) = makeSUT(isInMirrorSet: { _ in true })

        monitor.handleReconfiguration(displayID: fakeDisplayA, flags: .mirrorFlag)
        monitor.handleReconfiguration(displayID: fakeDisplayA, flags: .mirrorFlag)
        monitor.handleReconfiguration(displayID: fakeDisplayA, flags: .mirrorFlag)

        try await Task.sleep(for: debounceWait)

        #expect(delegate.mirrorCalls.count == 1)
    }

    @Test("Connect event does not cancel pending mirror correction and vice versa")
    func mirrorAndConnectAreIndependent() async throws {
        let (monitor, delegate) = makeSUT(isInMirrorSet: { _ in true })

        // Fire mirror event, then connect event for the SAME display within debounce
        monitor.handleReconfiguration(displayID: fakeDisplayA, flags: .mirrorFlag)
        monitor.handleReconfiguration(displayID: fakeDisplayA, flags: .addFlag)

        try await Task.sleep(for: debounceWait)

        // Connect should fire (it cancels the mirror correction via priority)
        #expect(delegate.connectCalls.count == 1)
        // Mirror correction should have been cancelled by the connect
        #expect(delegate.mirrorCalls.isEmpty, "Connect supersedes mirror correction")
    }

    @Test("Disconnect cancels pending mirror correction")
    func disconnectCancelsMirrorCorrection() async throws {
        let (monitor, delegate) = makeSUT(isInMirrorSet: { _ in true })

        monitor.handleReconfiguration(displayID: fakeDisplayA, flags: .mirrorFlag)
        monitor.handleReconfiguration(displayID: fakeDisplayA, flags: .removeFlag)

        try await Task.sleep(for: debounceWait)

        #expect(delegate.disconnectCalls.count == 1)
        #expect(delegate.mirrorCalls.isEmpty, "Disconnect should cancel mirror correction")
    }

    @Test("stopMonitoring cancels pending mirror corrections")
    func stopCancelsPendingMirrorCorrections() async throws {
        let (monitor, delegate) = makeSUT(isInMirrorSet: { _ in true })

        monitor.handleReconfiguration(displayID: fakeDisplayA, flags: .mirrorFlag)
        await monitor.stopMonitoring()

        try await Task.sleep(for: debounceWait)

        #expect(delegate.mirrorCalls.isEmpty, "Pending mirror correction should have been cancelled")
    }

    @Test("Mirror event dropped when UUID changes during debounce")
    func mirrorDroppedWhenUUIDChanges() async throws {
        var uuidCounter = 0
        let monitor = DisplayMonitor(
            debounceInterval: testDebounce,
            isBuiltIn: { $0 == CGMainDisplayID() },
            isOnline: { _ in true },
            isInMirrorSet: { _ in true },
            displayUUID: { _ in
                uuidCounter += 1
                return "uuid-\(uuidCounter)"
            },
            displayBounds: { _ in CGRect(x: 0, y: 0, width: 2560, height: 1440) },
            displayName: { _ in "Fake Display" }
        )
        let delegate = MockDisplayMonitorDelegate()
        monitor.delegate = delegate

        // UUID will be "uuid-1" at capture, "uuid-2" at post-debounce check
        monitor.handleReconfiguration(displayID: fakeDisplayA, flags: .mirrorFlag)

        try await Task.sleep(for: debounceWait)

        #expect(delegate.mirrorCalls.isEmpty, "Should drop when UUID changes during debounce")
    }

    @Test("beginConfigurationFlag with mirrorFlag is ignored")
    func beginConfigWithMirrorFlagIgnored() async throws {
        let (monitor, delegate) = makeSUT(isInMirrorSet: { _ in true })

        // macOS may set mirror state visible during begin-configuration phase
        let beginMirrorFlags = CGDisplayChangeSummaryFlags(
            rawValue: CGDisplayChangeSummaryFlags.beginConfigurationFlag.rawValue
                | CGDisplayChangeSummaryFlags.mirrorFlag.rawValue
        )
        monitor.handleReconfiguration(displayID: fakeDisplayA, flags: beginMirrorFlags)

        try await Task.sleep(for: debounceWait)

        #expect(delegate.mirrorCalls.isEmpty, "Should not act on begin-configuration events")
    }

    // MARK: - Stop monitoring

    @Test("stopMonitoring cancels pending debounce tasks")
    func stopCancelsPendingEvents() async throws {
        let (monitor, delegate) = makeSUT()

        monitor.handleReconfiguration(displayID: fakeDisplayA, flags: .addFlag)
        await monitor.stopMonitoring()

        // Cancellation is synchronous on @MainActor now;
        // wait past the debounce interval to confirm nothing fires.
        try await Task.sleep(for: debounceWait)

        #expect(delegate.connectCalls.isEmpty, "Pending event should have been cancelled by stopMonitoring")
    }
}
