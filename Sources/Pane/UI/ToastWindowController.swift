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

        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error {
                print("Notification auth error: \(error)")
            }
            print("Notification permission granted: \(granted)")
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

        let identifier = UUID().uuidString

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("Failed to add notification: \(error)")
                return
            }

            guard duration > 0 else {
                return
            }

            Task.detached {
                let nanoseconds = UInt64(max(duration, 0) * 1_000_000_000)
                try? await Task.sleep(nanoseconds: nanoseconds)
                UNUserNotificationCenter.current()
                    .removeDeliveredNotifications(withIdentifiers: [identifier])
            }
        }
    }

    func dismiss() {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }

    /// Show banner even when app is in foreground
    nonisolated func userNotificationCenter(
        _: UNUserNotificationCenter,
        willPresent _: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    /// Handle "Change" action
    nonisolated func userNotificationCenter(
        _: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        if response.actionIdentifier == Self.changeActionID {
            await MainActor.run {
                onChangeTapped?()
            }
        }
    }
}
