import Foundation

/// Persists the last-used extend preset and mirror target in UserDefaults
/// so the prompt can pre-select them on next open.
///
/// See pane-spec Section 3 — Last-used preset.
struct PresetDefaults {
    // MARK: - Keys

    enum Key {
        static let lastExtendPreset = "lastExtendPreset"
        static let lastMirrorTarget = "lastMirrorTarget"
    }

    // MARK: - Storage

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - Properties

    /// The last-used extend preset. Defaults to `.externalRight`.
    var lastExtendPreset: DisplayConfiguration.ExtendPreset {
        get {
            guard let raw = defaults.string(forKey: Key.lastExtendPreset),
                  let value = DisplayConfiguration.ExtendPreset(rawValue: raw)
            else {
                return .externalRight
            }
            return value
        }
        nonmutating set {
            defaults.set(newValue.rawValue, forKey: Key.lastExtendPreset)
        }
    }

    /// The last-used mirror target. Defaults to `.macBook`.
    var lastMirrorTarget: DisplayConfiguration.MirrorTarget {
        get {
            guard let raw = defaults.string(forKey: Key.lastMirrorTarget),
                  let value = DisplayConfiguration.MirrorTarget(rawValue: raw)
            else {
                return .macBook
            }
            return value
        }
        nonmutating set {
            defaults.set(newValue.rawValue, forKey: Key.lastMirrorTarget)
        }
    }
}

// MARK: - Standard instance

extension PresetDefaults {
    /// Shared instance backed by `UserDefaults.standard`.
    static let standard = PresetDefaults()
}
