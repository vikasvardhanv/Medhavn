import Foundation

public struct RulesEngine: MedicationRulesChecking, Sendable {
    public init() {}

    public func evaluate(_ plan: ParsedMedicationPlan) -> [SafetyFlag] {
        var flags: [SafetyFlag] = []

        let source = " \(plan.sourceText.lowercased()) "
        [" qd ", " u ", " iu "].forEach { token in
            if source.contains(token) {
                flags.append(SafetyFlag(severity: .critical, message: "Ambiguous abbreviation detected: \(token.trimmingCharacters(in: .whitespaces))."))
            }
        }

        if plan.route == nil {
            flags.append(SafetyFlag(severity: .warning, message: "Route is missing."))
        }

        if plan.durationDays == nil && plan.taperSteps.isEmpty && plan.cycleRule == nil {
            flags.append(SafetyFlag(severity: .warning, message: "Duration is missing."))
        }

        if plan.prnRule != nil && plan.maxPer24HoursAmount == nil && plan.maxPerDayDoses == nil {
            flags.append(SafetyFlag(severity: .critical, message: "PRN regimen is missing max per day or max per 24 hours."))
        }

        if let frequency = plan.frequency,
           let dosesPerDay = frequency.dosesPerDay,
           let max = plan.maxPerDayDoses,
           dosesPerDay > max {
            flags.append(SafetyFlag(severity: .critical, message: "Frequency conflicts with maximum daily dose count."))
        }

        if let minHours = plan.minimumHoursBetweenDoses,
           let frequency = plan.frequency,
           case let .everyHours(freqHours) = frequency,
           freqHours < minHours {
            flags.append(SafetyFlag(severity: .critical, message: "Schedule frequency is tighter than required interval between doses."))
        }

        return flags
    }
}
