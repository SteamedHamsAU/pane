import AppKit
import SwiftUI

/// The About tab shown in Snap's settings window.
@MainActor
struct AboutView: View {
    let checkForUpdates: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 256, height: 256)

            Text("Snap")
                .font(.system(size: 22, weight: .semibold))

            HStack(spacing: 8) {
                let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
                let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
                Text("v\(version) · build \(build)")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)

                #if DEV_BUILD
                    Text("Dev")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(.orange))
                #endif
            }

            VStack(spacing: 4) {
                Text("Copyright © 2026 Steamed Hams Pty Ltd")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)

                Text("Licensed under the MIT License")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                Button("Check for Updates…") {
                    checkForUpdates()
                }
                .controlSize(.regular)

                Button("Source Code") {
                    if let url = URL(string: "https://github.com/SteamedHamsAU/snap") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .controlSize(.regular)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
