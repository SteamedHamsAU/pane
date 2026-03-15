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
        subsystem: Bundle.main.bundleIdentifier ?? "au.steamedhams.pane",
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
            let origin: CGPoint

            switch config.extendPreset {
            case .externalRight:
                origin = CGPoint(x: internalBounds.maxX, y: internalBounds.minY)
            case .externalLeft:
                origin = CGPoint(x: internalBounds.minX - externalBounds.width, y: internalBounds.minY)
            case .externalAbove:
                origin = CGPoint(x: internalBounds.minX, y: internalBounds.minY - externalBounds.height)
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
