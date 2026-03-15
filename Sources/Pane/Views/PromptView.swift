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
            HStack(spacing: 14) {
                Image(systemName: "display")
                    .font(.system(size: 36))
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 4) {
                    Text(displayName)
                        .font(.system(size: 20, weight: .semibold))
                    Text("\(Int(resolution.width))×\(Int(resolution.height))")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 24)

            Divider()

            // Mode picker
            Picker("Mode", selection: $selectedMode) {
                Text("Extend").tag(DisplayConfiguration.Mode.extend)
                Text("Mirror").tag(DisplayConfiguration.Mode.mirror)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 32)
            .padding(.vertical, 20)

            // Mode content — expanded to fill
            Group {
                switch selectedMode {
                case .extend:
                    ExtendView(selectedPreset: $selectedPreset)
                case .mirror:
                    MirrorView(selectedMirrorTarget: $selectedMirrorTarget)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 32)
            .padding(.bottom, 20)

            Divider()

            // Remember checkbox
            HStack {
                Toggle("Remember for this display", isOn: $rememberDisplay)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 13))
                Spacer()
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 16)

            Divider()

            // Action buttons — centred on their own row
            HStack(spacing: 16) {
                Button("Dismiss") {
                    onDismiss()
                }
                .keyboardShortcut(.cancelAction)
                .controlSize(.large)

                Button("Apply") {
                    applyConfiguration()
                }
                .keyboardShortcut(.defaultAction)
                .controlSize(.large)
            }
            .padding(.vertical, 20)
        }
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
