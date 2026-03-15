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
            Spacer()

            // Header
            VStack(spacing: 8) {
                Image(systemName: "display")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(.secondary)

                Text(displayName)
                    .font(.system(size: 28, weight: .semibold))

                Text("\(Int(resolution.width))×\(Int(resolution.height))")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 32)

            // Mode picker
            Picker("Mode", selection: $selectedMode) {
                Text("Extend").tag(DisplayConfiguration.Mode.extend)
                Text("Mirror").tag(DisplayConfiguration.Mode.mirror)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 240)
            .padding(.bottom, 32)

            // Mode content
            Group {
                switch selectedMode {
                case .extend:
                    ExtendView(selectedPreset: $selectedPreset)
                case .mirror:
                    MirrorView(selectedMirrorTarget: $selectedMirrorTarget)
                }
            }

            Spacer()

            // Remember preference
            Picker("", selection: $rememberDisplay) {
                Text("Remember for this display").tag(true)
                Text("Prompt every time for this monitor").tag(false)
            }
            .labelsHidden()
            .frame(width: 320)
            .padding(.bottom, 24)

            // Action buttons
            HStack(spacing: 20) {
                Button {
                    onDismiss()
                } label: {
                    Text("Dismiss")
                        .frame(width: 120, height: 36)
                }
                .keyboardShortcut(.cancelAction)
                .controlSize(.large)

                Button {
                    applyConfiguration()
                } label: {
                    Text("Apply")
                        .frame(width: 120, height: 36)
                }
                .keyboardShortcut(.defaultAction)
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
            }
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
