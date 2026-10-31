import Foundation

/// Plain description of a pillbox item's schedule, so the planner needs no app types.
struct ReminderSpec {
    let id: UUID
    let name: String
    let dosage: String
    let frequency: String      // everyDay | specificDays | daysInterval | asNeeded
    let times: [(hour: Int, minute: Int)]
    let blocks: [String]       // morning | afternoon | evening | night
    let specificDays: [Int]    // 1 = Monday ... 7 = Sunday
    let intervalDays: Int
    let startDate: Date?
    let endDate: Date?
    let createdAt: Date
}

struct PlannedDose {
    let itemID: UUID
    let name: String
    let dosage: String
    let block: String
    let fire: Date
    let day: String            // yyyy-MM-dd
    /// Same format as AppState.doseKey, so a notification can mark the right dose.
    var key: String { "\(itemID.uuidString)|\(day)|\(block)" }
}

/// Works out which dose reminders to schedule next. Pure: no notifications, no app state.
enum PillboxReminderPlanner {
    static let defaultTimes: [String: (hour: Int, minute: Int)] = [
        "morning": (8, 0), "afternoon": (14, 0), "evening": (19, 0), "night": (22, 0),
    ]

    /// Matches the block expiry the app uses (morning ends 12:00, afternoon 17:00, evening 22:00).
    static func block(forHour hour: Int) -> String {
        hour < 12 ? "morning" : hour < 17 ? "afternoon" : hour < 22 ? "evening" : "night"
    }

    /// iOS keeps at most 64 pending notifications, so plan a short window and cap the count.
    static func plan(
        specs: [ReminderSpec],
        now: Date,
        days: Int = 7,
        limit: Int = 56,
        calendar: Calendar = .current,
        isDone: (String) -> Bool = { _ in false }
    ) -> [PlannedDose] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd" // same as AppState.doseKey
        formatter.timeZone = calendar.timeZone
        let today = calendar.startOfDay(for: now)
        var out: [PlannedDose] = []

        for spec in specs where spec.frequency != "asNeeded" {
            for offset in 0..<days {
                guard let day = calendar.date(byAdding: .day, value: offset, to: today),
                      applies(spec, on: day, calendar: calendar) else { continue }

                var slots: [(hour: Int, minute: Int, block: String)] = spec.times.map { ($0.hour, $0.minute, block(forHour: $0.hour)) }
                if slots.isEmpty {
                    slots = spec.blocks.compactMap { b in defaultTimes[b].map { ($0.hour, $0.minute, b) } }
                }
                for slot in slots {
                    guard let fire = calendar.date(bySettingHour: slot.hour, minute: slot.minute, second: 0, of: day), fire > now else { continue }
                    let dose = PlannedDose(itemID: spec.id, name: spec.name, dosage: spec.dosage, block: slot.block, fire: fire, day: formatter.string(from: day))
                    if !isDone(dose.key) { out.append(dose) }
                }
            }
        }
        // Two times in one block collapse to one key; keep the earliest.
        var seen = Set<String>()
        return out.sorted { $0.fire < $1.fire }.filter { seen.insert($0.key).inserted }.prefix(limit).map { $0 }
    }

    private static func applies(_ spec: ReminderSpec, on day: Date, calendar: Calendar) -> Bool {
        if let start = spec.startDate, day < calendar.startOfDay(for: start) { return false }
        if let end = spec.endDate, day > calendar.startOfDay(for: end) { return false }
        switch spec.frequency {
        case "specificDays":
            let weekday = calendar.component(.weekday, from: day) // 1 = Sunday
            return spec.specificDays.contains((weekday + 5) % 7 + 1)
        case "daysInterval":
            let anchor = calendar.startOfDay(for: spec.startDate ?? spec.createdAt)
            let diff = calendar.dateComponents([.day], from: anchor, to: day).day ?? 0
            return diff >= 0 && diff % max(1, spec.intervalDays) == 0
        default:
            return true
        }
    }
}
