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

    func displayDidConnect(id: CGDirectDisplayID, uuid: String, name: String, resolution: CGSize) {
        connectCalls.append(ConnectCall(id: id, uuid: uuid, name: name, resolution: resolution))
    }

    func displayDidDisconnect(id: CGDirectDisplayID) {
        disconnectCalls.append(id)
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
        isOnline: @escaping @Sendable (CGDirectDisplayID) -> Bool = { _ in true }
    ) -> (monitor: DisplayMonitor, delegate: MockDisplayMonitorDelegate) {
        let monitor = DisplayMonitor(
            debounceInterval: testDebounce,
            isBuiltIn: { $0 == CGMainDisplayID() },
            isOnline: isOnline
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
            isOnline: { _ in true }
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

    // MARK: - Stop monitoring

    @Test("stopMonitoring cancels pending debounce tasks")
    func stopCancelsPendingEvents() async throws {
        let (monitor, delegate) = makeSUT()

        monitor.handleReconfiguration(displayID: fakeDisplayA, flags: .addFlag)
        monitor.stopMonitoring()

        // Let the MainActor task that cancels pending events execute,
        // then wait past the debounce interval.
        try await Task.sleep(for: debounceWait)

        #expect(delegate.connectCalls.isEmpty, "Pending event should have been cancelled by stopMonitoring")
    }
}
