import SwiftUI

/// Root SwiftUI view for the display configuration prompt.
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
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 10) {
                Image(systemName: "display")
                    .font(.system(size: 22))
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(displayName)
                        .font(.system(size: 14, weight: .medium))
                    Text("\(Int(resolution.width))×\(Int(resolution.height))")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            Divider()

            // Mode picker
            Picker("Mode", selection: $selectedMode) {
                Text("Extend").tag(DisplayConfiguration.Mode.extend)
                Text("Mirror").tag(DisplayConfiguration.Mode.mirror)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            // Mode content
            Group {
                switch selectedMode {
                case .extend:
                    ExtendView(selectedPreset: $selectedPreset)
                case .mirror:
                    MirrorView(selectedMirrorTarget: $selectedMirrorTarget)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)

            Divider()

            // Footer
            HStack {
                Toggle("Remember for this display", isOn: $rememberDisplay)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 12))

                Spacer()

                Button("Dismiss") {
                    onDismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Apply") {
                    applyConfiguration()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(width: 380)
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
