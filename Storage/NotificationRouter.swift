import Foundation
import UIKit
import UserNotifications

/// Receives notification taps and the Taken / Snooze / Skip buttons.
///
/// A button press can launch the app in the background before AppState has loaded, so the
/// action is written to a small queue in UserDefaults and applied as soon as AppState is ready.
final class NotificationRouter: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationRouter()

    static let pillCategory = "PILL_REMINDER"
    static let takenAction = "PILL_TAKEN"
    static let skipAction = "PILL_SKIP"
    static let snoozeAction = "PILL_SNOOZE"

    private static let queueKey = "medhavn.pendingDoseActions"
    private static let snoozeMinutes = 10.0

    /// Set once at launch from the app entry point.
    @MainActor weak var appState: AppState?

    static func userInfo(for dose: PlannedDose) -> [String: Any] {
        ["kind": "pill", "itemID": dose.itemID.uuidString, "block": dose.block, "day": dose.day, "key": dose.key]
    }

    // MARK: Delegate

    /// Show the reminder even when the app is open.
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let content = response.notification.request.content
        guard let info = content.userInfo as? [String: Any], info["kind"] as? String == "pill",
              let itemID = info["itemID"] as? String, let block = info["block"] as? String,
              let day = info["day"] as? String, let key = info["key"] as? String else { return }

        switch response.actionIdentifier {
        case Self.takenAction:
            Self.enqueue(["itemID": itemID, "block": block, "day": day, "status": "taken"])
        case Self.skipAction:
            Self.enqueue(["itemID": itemID, "block": block, "day": day, "status": "skipped"])
        case Self.snoozeAction:
            await snooze(content, key: key)
        default:
            // Tapped the notification itself: bring the dose screen forward.
            await MainActor.run { appState?.openHomeFromNotification() }
        }
        await MainActor.run { appState?.applyPendingDoseActions() }
    }

    private func snooze(_ content: UNNotificationContent, key: String) async {
        guard let copy = content.mutableCopy() as? UNMutableNotificationContent else { return }
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: Self.snoozeMinutes * 60, repeats: false)
        let request = UNNotificationRequest(identifier: "medhavn-pill-snooze-\(key)", content: copy, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
    }

    // MARK: Queue

    private static func enqueue(_ action: [String: String]) {
        var queue = UserDefaults.standard.array(forKey: queueKey) as? [[String: String]] ?? []
        queue.append(action)
        UserDefaults.standard.set(queue, forKey: queueKey)
    }

    /// Returns and clears the queued dose actions.
    static func drainQueue() -> [[String: String]] {
        let queue = UserDefaults.standard.array(forKey: queueKey) as? [[String: String]] ?? []
        UserDefaults.standard.removeObject(forKey: queueKey)
        return queue
    }
}
