import Foundation
import MedicationLogicEngine
import UserNotifications

protocol MedicationNotificationServicing {
    func requestAuthorization() async -> Bool
    func authorizationStatus() async -> UNAuthorizationStatus
    func clearAllMedicationReminders() async
    func scheduleDoseReminders(planName: String, planID: UUID, events: [DoseEvent]) async throws -> Int
    func scheduleAppointmentAlert(title: String, doctorName: String, date: Date, appointmentID: UUID) async throws
    func schedulePillReminders(_ doses: [PlannedDose]) async -> Int
    func cancelPillReminder(key: String) async
    func clearPillReminders() async
}

struct MedicationNotificationService: MedicationNotificationServicing {
    private let center = UNUserNotificationCenter.current()
    private let reminderPrefix = "medhavn-dose-"
    private let appointmentPrefix = "medhavn-appt-"
    private let pillPrefix = "medhavn-pill-"

    init() {
        registerCategories()
    }

    private func registerCategories() {
        let takenAction = UNNotificationAction(
            identifier: "TAKEN_ACTION",
            title: "Mark as Taken",
            options: [.foreground]
        )
        let missedAction = UNNotificationAction(
            identifier: "MISSED_ACTION",
            title: "Skip / Missed",
            options: [.destructive]
        )
        
        let category = UNNotificationCategory(
            identifier: "SUPPLEMENT_REMINDER",
            actions: [takenAction, missedAction],
            intentIdentifiers: [],
            options: []
        )
        // Pillbox reminders: three buttons on the notification. Tapping the body opens the app.
        let pillCategory = UNNotificationCategory(
            identifier: NotificationRouter.pillCategory,
            actions: [
                UNNotificationAction(identifier: NotificationRouter.takenAction, title: "Taken", options: []),
                UNNotificationAction(identifier: NotificationRouter.snoozeAction, title: "Snooze 10 min", options: []),
                UNNotificationAction(identifier: NotificationRouter.skipAction, title: "Skip", options: [.destructive]),
            ],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([category, pillCategory])
    }

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
            content.categoryIdentifier = "SUPPLEMENT_REMINDER"

            let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: event.date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let id = "\(reminderPrefix)\(planID.uuidString)-\(event.id.uuidString)"
            let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
            try await center.add(request)
            scheduledCount += 1
        }

        return scheduledCount
    }

    func scheduleAppointmentAlert(title: String, doctorName: String, date: Date, appointmentID: UUID) async throws {
        let status = await authorizationStatus()
        guard status == .authorized || status == .provisional else { return }

        // Alert exactly 12 hours prior
        guard let alertDate = Calendar.current.date(byAdding: .hour, value: -12, to: date), alertDate > Date() else {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Upcoming Appointment"
        
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        let timeStr = formatter.string(from: date)
        
        // If morning appointment, check if alert falls in evening/night prior
        let hour = Calendar.current.component(.hour, from: date)
        if hour < 12 {
            content.body = "Reminder: \(title) with \(doctorName) tomorrow morning at \(timeStr). Please remember any preparation like fasting."
        } else {
            content.body = "Reminder: \(title) with \(doctorName) tomorrow at \(timeStr)."
        }
        content.sound = .default

        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: alertDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let id = "\(appointmentPrefix)\(appointmentID.uuidString)"
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        try await center.add(request)
    }

    // MARK: - Pillbox reminders

    /// Replaces every pending pillbox reminder with `doses`. Returns how many were scheduled.
    func schedulePillReminders(_ doses: [PlannedDose]) async -> Int {
        let status = await authorizationStatus()
        guard status == .authorized || status == .provisional else { return 0 }
        await clearPillReminders()

        var count = 0
        for dose in doses {
            let content = UNMutableNotificationContent()
            content.title = "Time for \(dose.name)"
            content.body = dose.dosage.isEmpty ? "Tap to log your \(dose.block) dose." : "\(dose.dosage) · tap to log your \(dose.block) dose."
            content.sound = .default
            content.categoryIdentifier = NotificationRouter.pillCategory
            content.threadIdentifier = dose.itemID.uuidString
            content.userInfo = NotificationRouter.userInfo(for: dose)
            let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: dose.fire)
            let request = UNNotificationRequest(
                identifier: "\(pillPrefix)\(dose.key)",
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            )
            do {
                try await center.add(request)
                count += 1
            } catch {
                appLog("Could not schedule pill reminder: \(error.localizedDescription)", level: .warning, category: "Notifications")
            }
        }
        return count
    }

    /// Drops the pending reminder (and any snooze) for one dose, for example once it is logged.
    func cancelPillReminder(key: String) async {
        center.removePendingNotificationRequests(withIdentifiers: ["\(pillPrefix)\(key)", "\(pillPrefix)snooze-\(key)"])
        center.removeDeliveredNotifications(withIdentifiers: ["\(pillPrefix)\(key)", "\(pillPrefix)snooze-\(key)"])
    }

    func clearPillReminders() async {
        await withCheckedContinuation { continuation in
            center.getPendingNotificationRequests { requests in
                let ids = requests.map(\.identifier).filter { $0.hasPrefix(pillPrefix) }
                if !ids.isEmpty { center.removePendingNotificationRequests(withIdentifiers: ids) }
                continuation.resume()
            }
        }
    }

    private func formatDose(_ value: Double) -> String {
        String(format: "%.1f", value)
    }
}
