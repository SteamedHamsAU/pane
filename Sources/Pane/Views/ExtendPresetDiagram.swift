import SwiftUI

/// Canvas-rendered diagram showing a display arrangement preset.
struct ExtendPresetDiagram: View {

    let preset: DisplayConfiguration.ExtendPreset
    let isSelected: Bool

    private let macBookSize = CGSize(width: 44, height: 30)
    private let externalSize = CGSize(width: 52, height: 36)
    private let cornerRadius: CGFloat = 4
    private let gap: CGFloat = 4

    var body: some View {
        Canvas { context, size in
            let midX = size.width / 2
            let midY = size.height / 2
            let externalColor: Color = isSelected ? .accentColor : .secondary

            switch preset {
            case .externalRight:
                let totalWidth = macBookSize.width + gap + externalSize.width
                let startX = midX - totalWidth / 2
                let macRect = CGRect(
                    x: startX,
                    y: midY - macBookSize.height / 2,
                    width: macBookSize.width,
                    height: macBookSize.height
                )
                let extRect = CGRect(
                    x: startX + macBookSize.width + gap,
                    y: midY - externalSize.height / 2,
                    width: externalSize.width,
                    height: externalSize.height
                )
                drawDisplay(context: context, rect: macRect, color: .secondary, radius: cornerRadius)
                drawDisplay(context: context, rect: extRect, color: externalColor, radius: cornerRadius)

            case .externalLeft:
                let totalWidth = externalSize.width + gap + macBookSize.width
                let startX = midX - totalWidth / 2
                let extRect = CGRect(
                    x: startX,
                    y: midY - externalSize.height / 2,
                    width: externalSize.width,
                    height: externalSize.height
                )
                let macRect = CGRect(
                    x: startX + externalSize.width + gap,
                    y: midY - macBookSize.height / 2,
                    width: macBookSize.width,
                    height: macBookSize.height
                )
                drawDisplay(context: context, rect: extRect, color: externalColor, radius: cornerRadius)
                drawDisplay(context: context, rect: macRect, color: .secondary, radius: cornerRadius)

            case .externalAbove:
                let totalHeight = externalSize.height + gap + macBookSize.height
                let startY = midY - totalHeight / 2
                let extRect = CGRect(
                    x: midX - externalSize.width / 2,
                    y: startY,
                    width: externalSize.width,
                    height: externalSize.height
                )
                let macRect = CGRect(
                    x: midX - macBookSize.width / 2,
                    y: startY + externalSize.height + gap,
                    width: macBookSize.width,
                    height: macBookSize.height
                )
                drawDisplay(context: context, rect: extRect, color: externalColor, radius: cornerRadius)
                drawDisplay(context: context, rect: macRect, color: .secondary, radius: cornerRadius)
            }
        }
        .frame(width: 120, height: 80)
    }

    private func drawDisplay(context: GraphicsContext, rect: CGRect, color: Color, radius: CGFloat) {
        let path = RoundedRectangle(cornerRadius: radius).path(in: rect)
        context.fill(path, with: .color(color.opacity(0.5)))
        context.stroke(path, with: .color(color.opacity(0.8)), lineWidth: 1.5)
    }
}
