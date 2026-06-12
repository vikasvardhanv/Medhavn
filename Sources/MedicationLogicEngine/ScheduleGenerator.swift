import Foundation

public struct ScheduleGenerator: MedicationScheduleGenerating, Sendable {
    public init() {}

    public func generate(from plan: ParsedMedicationPlan, startDate: Date, days: Int) -> [DailyPlan] {
        let calendar = Calendar.current
        return (0..<max(1, days)).map { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: startDate) ?? startDate
            let inCycle = isActiveCycle(plan: plan, dayOffset: offset)
            let inDuration = plan.durationDays.map { offset < $0 } ?? true

            if !inCycle || !inDuration {
                return DailyPlan(dayOffset: offset, date: date, events: [])
            }

            let step = activeTaperStep(plan: plan, dayOffset: offset)
            let dose = step?.dose ?? plan.dose ?? 0
            let units = plan.units ?? "unit"
            let frequency = step?.frequency ?? plan.frequency

            let events = generateEvents(
                date: date,
                dose: dose,
                units: units,
                frequency: frequency,
                minHoursBetween: plan.minimumHoursBetweenDoses,
                maxPerDay: plan.maxPerDayDoses
            )

            return DailyPlan(dayOffset: offset, date: date, events: events)
        }
    }

    private func isActiveCycle(plan: ParsedMedicationPlan, dayOffset: Int) -> Bool {
        guard let cycle = plan.cycleRule else { return true }
        let block = cycle.daysOn + cycle.daysOff
        guard block > 0 else { return true }
        let position = dayOffset % block
        return position < cycle.daysOn
    }

    private func activeTaperStep(plan: ParsedMedicationPlan, dayOffset: Int) -> TaperStep? {
        let day = dayOffset + 1
        return plan.taperSteps.first(where: { day >= $0.startDay && day <= $0.endDay })
    }

    private func generateEvents(
        date: Date,
        dose: Double,
        units: String,
        frequency: Frequency?,
        minHoursBetween: Int?,
        maxPerDay: Int?
    ) -> [DoseEvent] {
        guard let frequency else { return [] }

        if case .asNeeded = frequency {
            return []
        }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)

        var count = frequency.dosesPerDay ?? 0
        if let maxPerDay {
            count = min(count, maxPerDay)
        }
        count = max(0, count)

        guard count > 0 else { return [] }

        let intervalHours: Int
        if let minHoursBetween {
            intervalHours = max(minHoursBetween, Int(floor(24.0 / Double(count))))
        } else {
            intervalHours = max(1, Int(floor(24.0 / Double(count))))
        }

        return (0..<count).compactMap { idx in
            let hour = min(23, idx * intervalHours)
            guard let eventDate = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: startOfDay) else {
                return nil
            }
            return DoseEvent(date: eventDate, dose: dose, units: units)
        }
    }
}
