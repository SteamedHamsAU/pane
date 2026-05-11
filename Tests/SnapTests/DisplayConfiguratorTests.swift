import CoreGraphics
@testable import Snap
import Testing

// MARK: - Mock

@MainActor
final class MockDisplayTransactor: DisplayTransacting {
    struct OriginCall {
        let display: CGDirectDisplayID
        let x: Int32
        let y: Int32
    }

    struct MirrorCall {
        let display: CGDirectDisplayID
        let primary: CGDirectDisplayID
    }

    // nonisolated(unsafe) so deinit can deallocate without a Sendable warning
    nonisolated(unsafe) private let dummyRaw: UnsafeMutableRawPointer
    private let dummyRef: CGDisplayConfigRef

    var beginShouldSucceed = true
    var completeShouldSucceed = true

    var originCalls: [OriginCall] = []
    var mirrorCalls: [MirrorCall] = []
    var boundsCalls: [CGDirectDisplayID] = []
    var beginCalled = false
    var completeCalled = false

    var boundsMap: [CGDirectDisplayID: CGRect] = [:]
    var mirrorSetDisplays: Set<CGDirectDisplayID> = []

    init() {
        dummyRaw = UnsafeMutableRawPointer.allocate(byteCount: 1, alignment: 1)
        dummyRef = OpaquePointer(dummyRaw)
    }

    deinit {
        dummyRaw.deallocate()
    }

    func beginConfiguration() -> CGDisplayConfigRef? {
        beginCalled = true
        return beginShouldSucceed ? dummyRef : nil
    }

    func configureOrigin(_: CGDisplayConfigRef, display: CGDirectDisplayID, x: Int32, y: Int32) {
        originCalls.append(OriginCall(display: display, x: x, y: y))
    }

    func configureMirror(_: CGDisplayConfigRef, display: CGDirectDisplayID, primary: CGDirectDisplayID) {
        mirrorCalls.append(MirrorCall(display: display, primary: primary))
    }

    func completeConfiguration(_: CGDisplayConfigRef) -> Bool {
        completeCalled = true
        return completeShouldSucceed
    }

    func displayBounds(_ display: CGDirectDisplayID) -> CGRect {
        boundsCalls.append(display)
        return boundsMap[display] ?? .zero
    }

    func isInMirrorSet(_ display: CGDirectDisplayID) -> Bool {
        mirrorSetDisplays.contains(display)
    }
}

// MARK: - Tests

@MainActor
struct DisplayConfiguratorTests {
    private let primaryID: CGDirectDisplayID = 1
    private let externalID: CGDirectDisplayID = 2
    private let internalBounds = CGRect(x: 0, y: 0, width: 1440, height: 900)
    private let externalBounds = CGRect(x: 0, y: 0, width: 2560, height: 1440)

    private func makeTransactor() -> MockDisplayTransactor {
        let mock = MockDisplayTransactor()
        mock.boundsMap[primaryID] = internalBounds
        mock.boundsMap[externalID] = externalBounds
        return mock
    }

    private func makeConfig(
        mode: DisplayConfiguration.Mode,
        preset: DisplayConfiguration.ExtendPreset = .externalRight,
        mirror: DisplayConfiguration.MirrorTarget = .macBook
    ) -> DisplayConfiguration {
        DisplayConfiguration(
            mode: mode,
            extendPreset: preset,
            mirrorTarget: mirror,
            rememberThisDisplay: false
        )
    }

    // MARK: - Extend

    @Test("Extend right places external at right edge, vertically centred")
    func extendRight() {
        let mock = makeTransactor()
        let config = makeConfig(mode: .extend, preset: .externalRight)

        DisplayConfigurator.apply(config, primaryID: primaryID, externalID: externalID, transactor: mock)

        #expect(mock.originCalls.count == 1)
        let call = mock.originCalls[0]
        #expect(call.display == externalID)
        #expect(call.x == 1440)
        #expect(call.y == -270) // (900/2 - 1440/2) = -270
    }

    @Test("Extend left places external to the left, vertically centred")
    func extendLeft() {
        let mock = makeTransactor()
        let config = makeConfig(mode: .extend, preset: .externalLeft)

        DisplayConfigurator.apply(config, primaryID: primaryID, externalID: externalID, transactor: mock)

        #expect(mock.originCalls.count == 1)
        let call = mock.originCalls[0]
        #expect(call.display == externalID)
        #expect(call.x == -2560) // 0 - 2560
        #expect(call.y == -270)
    }

    @Test("Extend above places external centred on top")
    func extendAbove() {
        let mock = makeTransactor()
        let config = makeConfig(mode: .extend, preset: .externalAbove)

        DisplayConfigurator.apply(config, primaryID: primaryID, externalID: externalID, transactor: mock)

        #expect(mock.originCalls.count == 1)
        let call = mock.originCalls[0]
        #expect(call.display == externalID)
        #expect(call.x == -560) // (1440/2 - 2560/2) = -560
        #expect(call.y == -1440) // 0 - 1440
    }

    @Test("Extend unmirrors first when display is in mirror set")
    func extendUnmirrorsFirst() {
        let mock = makeTransactor()
        mock.mirrorSetDisplays.insert(externalID)
        let config = makeConfig(mode: .extend, preset: .externalRight)

        DisplayConfigurator.apply(config, primaryID: primaryID, externalID: externalID, transactor: mock)

        #expect(mock.mirrorCalls.count == 1)
        let unmirror = mock.mirrorCalls[0]
        #expect(unmirror.display == externalID)
        #expect(unmirror.primary == kCGNullDirectDisplay)
    }

    // MARK: - Mirror

    @Test("Mirror macBook mirrors external to primary")
    func mirrorMacBook() {
        let mock = makeTransactor()
        let config = makeConfig(mode: .mirror, mirror: .macBook)

        DisplayConfigurator.apply(config, primaryID: primaryID, externalID: externalID, transactor: mock)

        #expect(mock.mirrorCalls.count == 1)
        #expect(mock.mirrorCalls[0].display == externalID)
        #expect(mock.mirrorCalls[0].primary == primaryID)
        #expect(mock.originCalls.isEmpty)
    }

    @Test("Mirror external mirrors primary to external")
    func mirrorExternal() {
        let mock = makeTransactor()
        let config = makeConfig(mode: .mirror, mirror: .external)

        DisplayConfigurator.apply(config, primaryID: primaryID, externalID: externalID, transactor: mock)

        #expect(mock.mirrorCalls.count == 1)
        #expect(mock.mirrorCalls[0].display == primaryID)
        #expect(mock.mirrorCalls[0].primary == externalID)
        #expect(mock.originCalls.isEmpty)
    }

    // MARK: - Transaction lifecycle

    @Test("Begin failure aborts without configuring or completing")
    func beginFailure() {
        let mock = makeTransactor()
        mock.beginShouldSucceed = false
        let config = makeConfig(mode: .extend)

        DisplayConfigurator.apply(config, primaryID: primaryID, externalID: externalID, transactor: mock)

        #expect(mock.beginCalled)
        #expect(mock.originCalls.isEmpty)
        #expect(mock.mirrorCalls.isEmpty)
        #expect(!mock.completeCalled)
    }

    @Test("Unmirror complete failure aborts extend before positioning")
    func completeFailure() {
        let mock = makeTransactor()
        mock.mirrorSetDisplays.insert(externalID)
        mock.completeShouldSucceed = false
        let config = makeConfig(mode: .extend, preset: .externalRight)

        DisplayConfigurator.apply(config, primaryID: primaryID, externalID: externalID, transactor: mock)

        #expect(mock.completeCalled)
        #expect(mock.originCalls.isEmpty, "Unmirror failed — positioning should be skipped")
    }

    @Test("Successful apply calls complete")
    func completeSuccess() {
        let mock = makeTransactor()
        let config = makeConfig(mode: .extend, preset: .externalRight)

        DisplayConfigurator.apply(config, primaryID: primaryID, externalID: externalID, transactor: mock)

        #expect(mock.completeCalled)
    }

    @Test("Extend skips unmirror when display is not in mirror set (#86)")
    func extendSkipsUnmirrorWhenNotMirrored() {
        let mock = makeTransactor()
        // mirrorSetDisplays is empty — display is not mirrored
        let config = makeConfig(mode: .extend, preset: .externalRight)

        DisplayConfigurator.apply(config, primaryID: primaryID, externalID: externalID, transactor: mock)

        #expect(mock.mirrorCalls.isEmpty, "Should not attempt unmirror when not in mirror set")
        #expect(mock.originCalls.count == 1, "Should still position the display")
        let call = mock.originCalls[0]
        #expect(call.display == externalID)
        #expect(call.x == 1440)
        #expect(call.y == -270)
    }
}
