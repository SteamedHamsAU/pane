import AppKit
import UserNotifications

/// Shows native macOS notifications for known-display auto-apply events.
@MainActor
final class ToastWindowController: NSObject, UNUserNotificationCenterDelegate {

    private var onChangeTapped: (() -> Void)?
    private static let categoryID = "DISPLAY_APPLIED"
    private static let changeActionID = "CHANGE_ACTION"

    override init() {
        super.init()
        let center = UNUserNotificationCenter.current()
        center.delegate = self

        // Register "Change" action
        let changeAction = UNNotificationAction(
            identifier: Self.changeActionID,
            title: "Change",
            options: [.foreground]
        )
        let category = UNNotificationCategory(
            identifier: Self.categoryID,
            actions: [changeAction],
            intentIdentifiers: []
        )
        center.setNotificationCategories([category])

        // Request permission
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error {
                print("Notification permission error: \(error)")
            }
        }
    }

    func show(
        message: String,
        duration: TimeInterval = 4,
        onChangeTapped: @escaping () -> Void
    ) {
        self.onChangeTapped = onChangeTapped

        let content = UNMutableNotificationContent()
        content.title = "Pane"
        content.body = message
        content.sound = .default
        content.categoryIdentifier = Self.categoryID

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // deliver immediately
        )

        UNUserNotificationCenter.current().add(request)
    }

    func dismiss() {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }

    // MARK: - UNUserNotificationCenterDelegate

    // Show notification even when app is in foreground
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    // Handle "Change" action tap
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        if response.actionIdentifier == Self.changeActionID {
            await MainActor.run {
                onChangeTapped?()
            }
        }
    }
}
