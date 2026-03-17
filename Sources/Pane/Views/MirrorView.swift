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

/// Canvas diagram for mirror mode showing active/dimmed displays.
struct MirrorDiagram: View {
    let target: DisplayConfiguration.MirrorTarget
    let isSelected: Bool

    var body: some View {
        Canvas { context, size in
            let midX = size.width / 2
            let midY = size.height / 2
            let displaySize = CGSize(width: 48, height: 32)
            let overlap: CGFloat = 16

            let backRect = CGRect(
                x: midX - overlap / 2 - displaySize.width / 2,
                y: midY - displaySize.height / 2 - 4,
                width: displaySize.width,
                height: displaySize.height
            )
            let frontRect = CGRect(
                x: midX + overlap / 2 - displaySize.width / 2,
                y: midY - displaySize.height / 2 + 4,
                width: displaySize.width,
                height: displaySize.height
            )

            let activeColor: Color = isSelected ? .accentColor : .secondary
            let dimmedOpacity = 0.25
            let activeOpacity = 0.6

            switch target {
            case .macBook:
                // External is dimmed (back), MacBook is active (front)
                let backPath = RoundedRectangle(cornerRadius: 3).path(in: backRect)
                context.fill(backPath, with: .color(.secondary.opacity(dimmedOpacity)))
                context.stroke(backPath, with: .color(.secondary.opacity(0.4)), lineWidth: 1)
                let frontPath = RoundedRectangle(cornerRadius: 3).path(in: frontRect)
                context.fill(frontPath, with: .color(activeColor.opacity(activeOpacity)))
                context.stroke(frontPath, with: .color(activeColor.opacity(0.8)), lineWidth: 1.5)

            case .external:
                // MacBook is dimmed (back), external is active (front)
                let backPath = RoundedRectangle(cornerRadius: 3).path(in: backRect)
                context.fill(backPath, with: .color(.secondary.opacity(dimmedOpacity)))
                context.stroke(backPath, with: .color(.secondary.opacity(0.4)), lineWidth: 1)
                let frontPath = RoundedRectangle(cornerRadius: 3).path(in: frontRect)
                context.fill(frontPath, with: .color(activeColor.opacity(activeOpacity)))
                context.stroke(frontPath, with: .color(activeColor.opacity(0.8)), lineWidth: 1.5)
            }
        }
        .frame(width: 120, height: 60)
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
