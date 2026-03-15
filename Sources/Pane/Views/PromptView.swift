import SwiftUI

/// Root SwiftUI view for the display configuration prompt.
///
/// Structure per pane-spec Section 7:
/// - Header: icon, display name, resolution
/// - Segmented control: Extend | Mirror
/// - ExtendView or MirrorView
/// - Footer: remember checkbox, dismiss, apply
struct PromptView: View {

    let displayName: String
    let resolution: CGSize
    let onApply: (DisplayConfiguration) -> Void
    let onDismiss: () -> Void
    private let presetDefaults: PresetDefaults

    @State private var selectedMode: DisplayConfiguration.Mode = .extend
    @State private var selectedPreset: DisplayConfiguration.ExtendPreset
    @State private var selectedMirrorTarget: DisplayConfiguration.MirrorTarget
    @State private var rememberDisplay: Bool = true

    init(
        displayName: String,
        resolution: CGSize,
        presetDefaults: PresetDefaults = .standard,
        onApply: @escaping (DisplayConfiguration) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.displayName = displayName
        self.resolution = resolution
        self.onApply = onApply
        self.onDismiss = onDismiss
        self.presetDefaults = presetDefaults
        _selectedPreset = State(initialValue: presetDefaults.lastExtendPreset)
        _selectedMirrorTarget = State(initialValue: presetDefaults.lastMirrorTarget)
    }

    var body: some View {
        // TODO: Phase 2 — Layout per spec Section 7:
        // VStack spacing=0 {
        //   Header row (icon, name, resolution)
        //   Divider
        //   Segmented picker (Extend | Mirror)
        //   ExtendView or MirrorView
        //   Divider
        //   Footer (remember checkbox, dismiss, apply)
        // }
        VStack {
            Text("Configure \(displayName)")
                .font(.headline)
            Text("TODO: Full prompt UI")
                .foregroundStyle(.secondary)
        }
        .frame(width: 360)
        .padding()
    }

    private func applyConfiguration() {
        presetDefaults.lastExtendPreset = selectedPreset
        presetDefaults.lastMirrorTarget = selectedMirrorTarget
        onApply(buildConfiguration())
    }

    private func buildConfiguration() -> DisplayConfiguration {
        DisplayConfiguration(
            mode: selectedMode,
            extendPreset: selectedPreset,
            mirrorTarget: selectedMirrorTarget,
            rememberThisDisplay: rememberDisplay
        )
    }
}
