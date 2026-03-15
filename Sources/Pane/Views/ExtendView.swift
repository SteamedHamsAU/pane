import SwiftUI

/// Extend mode tab: three preset cards showing display arrangement options.
struct ExtendView: View {

    @Binding var selectedPreset: DisplayConfiguration.ExtendPreset

    var body: some View {
        HStack(spacing: 24) {
            ForEach(DisplayConfiguration.ExtendPreset.allCases, id: \.self) { preset in
                Button {
                    selectedPreset = preset
                } label: {
                    VStack(spacing: 14) {
                        ExtendPresetDiagram(
                            preset: preset,
                            isSelected: selectedPreset == preset
                        )
                        Text(preset.displayName)
                            .font(.system(size: 16, weight: .medium))
                    }
                    .frame(width: 160, height: 140)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(selectedPreset == preset ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                selectedPreset == preset ? Color.accentColor : Color.clear,
                                lineWidth: 2
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}
