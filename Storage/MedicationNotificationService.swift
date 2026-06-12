import Foundation
import MedicationLogicEngine
import UserNotifications

protocol MedicationNotificationServicing {
    func requestAuthorization() async -> Bool
    func authorizationStatus() async -> UNAuthorizationStatus
    func clearAllMedicationReminders() async
    func scheduleDoseReminders(planName: String, planID: UUID, events: [DoseEvent]) async throws -> Int
}

struct MedicationNotificationService: MedicationNotificationServicing {
    private let center = UNUserNotificationCenter.current()
    private let reminderPrefix = "medhavn-dose-"

    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await withCheckedContinuation { continuation in
            center.getNotificationSettings { settings in
                continuation.resume(returning: settings.authorizationStatus)
            }
        }
    }

    func clearAllMedicationReminders() async {
        await withCheckedContinuation { continuation in
            center.getPendingNotificationRequests { requests in
                let ids = requests
                    .map(\.identifier)
                    .filter { $0.hasPrefix(reminderPrefix) }
                if !ids.isEmpty {
                    center.removePendingNotificationRequests(withIdentifiers: ids)
                }
                continuation.resume()
            }
        }
    }

    func scheduleDoseReminders(planName: String, planID: UUID, events: [DoseEvent]) async throws -> Int {
        let status = await authorizationStatus()
        guard status == .authorized || status == .provisional else {
            return 0
        }

        await clearAllMedicationReminders()

        let now = Date()
        let horizon = Calendar.current.date(byAdding: .day, value: 2, to: now) ?? now
        let upcoming = events
            .filter { $0.date > now && $0.date <= horizon }
            .prefix(24)

        var scheduledCount = 0

        for event in upcoming {
            let content = UNMutableNotificationContent()
            content.title = "Medication reminder"
            content.body = "\(planName): take \(formatDose(event.dose)) \(event.units)"
            content.sound = .default

            let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: event.date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let id = "\(reminderPrefix)\(planID.uuidString)-\(event.id.uuidString)"
            let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
            try await center.add(request)
            scheduledCount += 1
        }

        return scheduledCount
    }

    private func formatDose(_ value: Double) -> String {
        String(format: "%.1f", value)
    }
}
