import SwiftUI

/// Mirror mode tab: two option cards for mirror target selection.
struct MirrorView: View {
    @Binding var selectedMirrorTarget: DisplayConfiguration.MirrorTarget

    var body: some View {
        HStack(spacing: 24) {
            ForEach(DisplayConfiguration.MirrorTarget.allCases, id: \.self) { target in
                Button {
                    selectedMirrorTarget = target
                } label: {
                    VStack(spacing: 14) {
                        MirrorDiagram(target: target, isSelected: selectedMirrorTarget == target)
                        VStack(spacing: 4) {
                            Text(target.displayName)
                                .font(.system(size: 16, weight: .medium))
                            Text(target.subtitle)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 200, height: 140)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                selectedMirrorTarget == target
                                    ? Color.accentColor.opacity(0.12)
                                    : Color.secondary.opacity(0.08)
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                selectedMirrorTarget == target ? Color.accentColor : Color.clear,
                                lineWidth: 2
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Diagram for mirror mode using branding assets.
struct MirrorDiagram: View {
    let target: DisplayConfiguration.MirrorTarget
    let isSelected: Bool

    var body: some View {
        Image(target.assetName)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .opacity(isSelected ? 1.0 : 0.5)
            .frame(width: 120, height: 60)
    }
}

private extension DisplayConfiguration.MirrorTarget {
    var assetName: String {
        switch self {
        case .macBook: "MirrorMacbook"
        case .external: "MirrorExternal"
        }
    }
}

extension DisplayConfiguration.MirrorTarget {
    var subtitle: String {
        switch self {
        case .macBook: "Uses MacBook resolution"
        case .external: "Uses external resolution"
        }
    }
}
