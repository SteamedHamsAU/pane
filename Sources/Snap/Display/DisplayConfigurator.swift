import CoreGraphics
import Foundation
import os

/// Applies display configurations using CGDisplay APIs.
///
/// All methods must be called from `@MainActor` (CGDisplay APIs are synchronous
/// and safe to call from the main thread).
@MainActor
enum DisplayConfigurator {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "au.steamedhams.snap",
        category: "DisplayConfigurator"
    )

    /// Apply the given configuration to the external display.
    ///
    /// Wraps all changes in a `CGBeginDisplayConfiguration` / `CGCompleteDisplayConfiguration` transaction.
    static func apply(
        _ config: DisplayConfiguration,
        primaryID: CGDirectDisplayID,
        externalID: CGDirectDisplayID
    ) {
        var configRef: CGDisplayConfigRef?
        let beginStatus = CGBeginDisplayConfiguration(&configRef)
        guard beginStatus == .success, let cfg = configRef else {
            logger.error("CGBeginDisplayConfiguration failed: \(beginStatus.rawValue)")
            return
        }

        switch config.mode {
        case .extend:
            // Always unmirror first (handles mirror → extend transition)
            CGConfigureDisplayMirrorOfDisplay(cfg, externalID, kCGNullDirectDisplay)

            let internalBounds = CGDisplayBounds(primaryID)
            let externalBounds = CGDisplayBounds(externalID)
            let origin = switch config.extendPreset {
            case .externalRight:
                CGPoint(
                    x: internalBounds.maxX,
                    y: internalBounds.midY - externalBounds.height / 2
                )
            case .externalLeft:
                CGPoint(
                    x: internalBounds.minX - externalBounds.width,
                    y: internalBounds.midY - externalBounds.height / 2
                )
            case .externalAbove:
                CGPoint(
                    x: internalBounds.midX - externalBounds.width / 2,
                    y: internalBounds.minY - externalBounds.height
                )
            }

            CGConfigureDisplayOrigin(cfg, externalID, Int32(origin.x), Int32(origin.y))
            logger.info("Applying extend preset: \(config.extendPreset.rawValue)")

        case .mirror:
            switch config.mirrorTarget {
            case .macBook:
                CGConfigureDisplayMirrorOfDisplay(cfg, externalID, primaryID)
            case .external:
                CGConfigureDisplayMirrorOfDisplay(cfg, primaryID, externalID)
            }
            logger.info("Applying mirror target: \(config.mirrorTarget.rawValue)")
        }

        let completeStatus = CGCompleteDisplayConfiguration(cfg, .permanently)
        if completeStatus == .success {
            logger.info("Display configuration applied successfully")
        } else {
            logger.error("CGCompleteDisplayConfiguration failed: \(completeStatus.rawValue)")
        }
    }
}
