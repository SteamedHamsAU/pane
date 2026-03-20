import SwiftUI

/// Diagram showing a display arrangement preset using branding assets.
struct ExtendPresetDiagram: View {
    let preset: DisplayConfiguration.ExtendPreset
    let isSelected: Bool

    var body: some View {
        Image(preset.assetName)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .opacity(isSelected ? 1.0 : 0.5)
            .frame(width: 120, height: 80)
    }
}

private extension DisplayConfiguration.ExtendPreset {
    var assetName: String {
        switch self {
        case .externalRight: "ExtendRight"
        case .externalLeft: "ExtendLeft"
        case .externalAbove: "ExtendAbove"
        }
    }
}
