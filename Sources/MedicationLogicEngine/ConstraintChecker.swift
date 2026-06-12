import Foundation

public struct ConstraintChecker: Sendable {
    public init() {}

    public func validate(plan: ParsedMedicationPlan, schedule: [DailyPlan]) -> [SafetyFlag] {
        var flags: [SafetyFlag] = []

        for day in schedule {
            let totalDose = day.events.reduce(0.0) { $0 + $1.dose }

            if let maxPerDayDoses = plan.maxPerDayDoses, day.events.count > maxPerDayDoses {
                flags.append(SafetyFlag(severity: .critical, message: "Day \(day.dayOffset + 1) exceeds max daily dose count."))
            }

            if let maxAmount = plan.maxPer24HoursAmount, totalDose > maxAmount {
                flags.append(SafetyFlag(severity: .critical, message: "Day \(day.dayOffset + 1) exceeds max amount per 24 hours."))
            }

            if let minHours = plan.minimumHoursBetweenDoses {
                let sorted = day.events.sorted { $0.date < $1.date }
                for pair in zip(sorted, sorted.dropFirst()) {
                    let diff = pair.1.date.timeIntervalSince(pair.0.date) / 3600
                    if diff < Double(minHours) {
                        flags.append(SafetyFlag(severity: .critical, message: "Day \(day.dayOffset + 1) has doses less than \(minHours)h apart."))
                        break
                    }
                }
            }
        }

        return flags
    }

    public func remainingPRNAllowance(
        plan: ParsedMedicationPlan,
        todayPRNEvents: [DoseEvent],
        now: Date = Date()
    ) -> (remainingDoses: Int?, remainingAmount: Double?) {
        let todayEvents = todayPRNEvents.filter {
            Calendar.current.isDate($0.date, inSameDayAs: now)
        }

        let remainingDoses = plan.prnRule?.maxPerDayDoses.map { max(0, $0 - todayEvents.count) }
        let totalAmount = todayEvents.reduce(0.0) { $0 + $1.dose }
        let remainingAmount = plan.prnRule?.maxPer24HoursAmount.map { max(0, $0 - totalAmount) }

        return (remainingDoses, remainingAmount)
    }
}
