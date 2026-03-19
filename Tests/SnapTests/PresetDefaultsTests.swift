import Foundation
@testable import Snap
import Testing

@Suite("PresetDefaults")
struct PresetDefaultsTests {
    private func makeSuite(name: String = #function) -> UserDefaults {
        let suite = UserDefaults(suiteName: "PresetDefaultsTests.\(name)")!
        suite.removePersistentDomain(forName: "PresetDefaultsTests.\(name)")
        return suite
    }

    // MARK: - Defaults

    @Test("lastExtendPreset defaults to .externalRight when no value stored")
    func defaultExtendPreset() {
        let sut = PresetDefaults(defaults: makeSuite())
        #expect(sut.lastExtendPreset == .externalRight)
    }

    @Test("lastMirrorTarget defaults to .macBook when no value stored")
    func defaultMirrorTarget() {
        let sut = PresetDefaults(defaults: makeSuite())
        #expect(sut.lastMirrorTarget == .macBook)
    }

    // MARK: - Round-trip

    @Test("lastExtendPreset round-trips all cases")
    func extendPresetRoundTrip() {
        let sut = PresetDefaults(defaults: makeSuite())
        for preset in DisplayConfiguration.ExtendPreset.allCases {
            sut.lastExtendPreset = preset
            #expect(sut.lastExtendPreset == preset)
        }
    }

    @Test("lastMirrorTarget round-trips all cases")
    func mirrorTargetRoundTrip() {
        let sut = PresetDefaults(defaults: makeSuite())
        for target in DisplayConfiguration.MirrorTarget.allCases {
            sut.lastMirrorTarget = target
            #expect(sut.lastMirrorTarget == target)
        }
    }

    // MARK: - Persistence

    @Test("lastExtendPreset persists across separate PresetDefaults instances")
    func extendPresetPersists() {
        let suite = makeSuite()
        let first = PresetDefaults(defaults: suite)
        first.lastExtendPreset = .externalLeft
        let second = PresetDefaults(defaults: suite)
        #expect(second.lastExtendPreset == .externalLeft)
    }

    @Test("lastMirrorTarget persists across separate PresetDefaults instances")
    func mirrorTargetPersists() {
        let suite = makeSuite()
        let first = PresetDefaults(defaults: suite)
        first.lastMirrorTarget = .external
        let second = PresetDefaults(defaults: suite)
        #expect(second.lastMirrorTarget == .external)
    }

    // MARK: - Unknown raw value

    @Test("lastExtendPreset falls back to .externalRight for unknown raw value")
    func extendPresetFallback() {
        let suite = makeSuite()
        suite.set("unknownPreset", forKey: PresetDefaults.Key.lastExtendPreset)
        let sut = PresetDefaults(defaults: suite)
        #expect(sut.lastExtendPreset == .externalRight)
    }

    @Test("lastMirrorTarget falls back to .macBook for unknown raw value")
    func mirrorTargetFallback() {
        let suite = makeSuite()
        suite.set("unknownTarget", forKey: PresetDefaults.Key.lastMirrorTarget)
        let sut = PresetDefaults(defaults: suite)
        #expect(sut.lastMirrorTarget == .macBook)
    }
}
