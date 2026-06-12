import Foundation

public struct ExplanationGenerator: MedicationExplaining, Sendable {
    public init() {}

    public func patientDirections(for plan: ParsedMedicationPlan) -> String {
        var lines: [String] = []

        if let dose = plan.dose, let units = plan.units {
            lines.append("Take \(format(dose)) \(units)")
        } else {
            lines.append("Take your medication exactly as directed by your clinician")
        }

        if let route = plan.route {
            lines.append("Route: \(route.rawValue)")
        }

        if let frequency = plan.frequency {
            lines.append("Frequency: \(human(frequency))")
        }

        if let durationDays = plan.durationDays {
            lines.append("Duration: \(durationDays) days")
        }

        if let prn = plan.prnRule {
            lines.append("PRN: For \(prn.indication)")
            if let maxDoses = prn.maxPerDayDoses {
                lines.append("Do not exceed \(maxDoses) PRN doses per day")
            }
            if let maxAmount = prn.maxPer24HoursAmount, let units = plan.units {
                lines.append("Do not exceed \(format(maxAmount)) \(units) in 24 hours")
            }
        }

        if !plan.specialConstraints.isEmpty {
            let list = plan.specialConstraints.map { $0.rawValue.replacingOccurrences(of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression) }
            lines.append("Special instructions: \(list.joined(separator: ", "))")
        }

        lines.append("This app provides educational planning support and is not medical advice. Confirm unclear instructions with your pharmacist or clinician.")

        return lines.joined(separator: ". ") + "."
    }

    public func rationale(for plan: ParsedMedicationPlan, schedule: [DailyPlan]) -> String {
        var parts: [String] = []

        if let freq = plan.frequency {
            switch freq {
            case .twiceDaily:
                parts.append("Your prescription specifies twice daily, so morning and evening doses were scheduled.")
            case .everyHours(let h):
                parts.append("Your prescription specifies every \(h) hours, so doses were spaced accordingly.")
            default:
                parts.append("Doses were scheduled using the frequency stated in your prescription (\(human(freq))).")
            }
        }

        if let max = plan.maxPer24HoursAmount, let units = plan.units {
            parts.append("Your prescription specifies a maximum of \(format(max)) \(units) per 24 hours; a hard stop was applied at that limit.")
        } else if let maxCount = plan.maxPerDayDoses {
            parts.append("Your prescription specifies a maximum of \(maxCount) doses per day.")
        }

        if !plan.taperSteps.isEmpty {
            let first = plan.taperSteps[0]
            parts.append("Tapering starts on day \(first.startDay) as stated in your prescription and changes at each step.")
        }

        if plan.prnRule != nil {
            parts.append("PRN doses require symptom-based use as directed; daily limits from your prescription are enforced.")
        }

        if schedule.allSatisfy({ $0.events.isEmpty }) {
            parts.append("No scheduled doses were generated because key instructions are missing from your prescription or it is PRN-only.")
        }

        return parts.joined(separator: " ")
    }

    private func human(_ frequency: Frequency) -> String {
        switch frequency {
        case .onceDaily: return "once daily"
        case .twiceDaily: return "twice daily"
        case .threeTimesDaily: return "three times daily"
        case .fourTimesDaily: return "four times daily"
        case .everyHours(let h): return "every \(h) hours"
        case .asNeeded: return "as needed"
        case .customPerDay(let c): return "\(c) times per day"
        }
    }

    private func format(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }
        return String(format: "%.1f", value)
    }
}
