import Foundation

public struct SigTextParser: MedicationParser, Sendable {
    public init() {}

    public func parse(text: String) -> ParsedMedicationPlan {
        let lowered = text.lowercased()
        var plan = ParsedMedicationPlan(sourceText: text)

        plan.drugName = parseDrugName(from: text)
        plan.dose = parseDose(from: lowered)
        plan.units = parseUnits(from: lowered)
        plan.route = parseRoute(from: lowered)
        plan.frequency = parseFrequency(from: lowered)
        plan.durationDays = parseDurationDays(from: lowered)
        plan.minimumHoursBetweenDoses = parseMinimumHoursBetween(from: lowered)
        plan.maxPerDayDoses = parseMaxDosesPerDay(from: lowered)
        plan.maxPer24HoursAmount = parseMaxAmountPer24Hours(from: lowered)
        plan.maxPerDose = parseMaxPerDose(from: lowered)
        plan.prnRule = parsePRN(from: lowered, units: plan.units)
        plan.cycleRule = parseCycleRule(from: lowered)
        plan.taperSteps = parseTaperSteps(from: lowered, fallbackDose: plan.dose)
        plan.timingWindows = parseTimingWindows(from: lowered)
        plan.specialConstraints = parseConstraints(from: lowered)

        plan.ambiguityQuestions = ambiguityQuestions(from: plan, sourceText: lowered)
        plan.needsClinicianConfirmation = !plan.ambiguityQuestions.isEmpty

        return plan
    }

    private func parseDrugName(from text: String) -> String? {
        let pattern = #"^\s*([A-Za-z][A-Za-z0-9\-\s]{1,40}?)\s+\d+(?:\.\d+)?\s*(mg|mcg|g|ml|tablet|tab|capsule|cap|puff)\b"#
        guard let candidate = firstCapture(pattern: pattern, in: text) else {
            return nil
        }
        return candidate.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func parseDose(from text: String) -> Double? {
        firstMatch(pattern: #"(\d+(?:\.\d+)?)\s*(mg|mcg|g|ml|tablet|tab|capsule|cap|puff)"#, in: text)
            .flatMap(Double.init)
    }

    private func parseUnits(from text: String) -> String? {
        firstCapture(pattern: #"\d+(?:\.\d+)?\s*(mg|mcg|g|ml|tablets?|tabs?|capsules?|caps?|puffs?)"#, in: text)
    }

    private func parseRoute(from text: String) -> Route? {
        if text.contains("by mouth") || text.contains("po") || text.contains("oral") { return .oral }
        if text.contains("topical") || text.contains("apply") { return .topical }
        if text.contains("inhale") { return .inhaled }
        if text.contains("inject") || text.contains("subcut") || text.contains("intramuscular") { return .injection }
        if text.contains("eye") || text.contains("ophthalmic") { return .ophthalmic }
        if text.contains("ear") || text.contains("otic") { return .otic }
        return nil
    }

    private func parseFrequency(from text: String) -> Frequency? {
        if let hours = firstCapture(pattern: #"every\s*(\d{1,2})\s*hours?"#, in: text).flatMap(Int.init) {
            return .everyHours(hours)
        }

        if text.contains("twice daily") || text.contains("bid") || text.contains("2 times daily") { return .twiceDaily }
        if text.contains("three times daily") || text.contains("tid") { return .threeTimesDaily }
        if text.contains("four times daily") || text.contains("qid") { return .fourTimesDaily }

        if let perDay = firstCapture(pattern: #"(\d)\s*times\s*(a|per)\s*day"#, in: text).flatMap(Int.init) {
            return .customPerDay(perDay)
        }

        if text.contains("once daily") || text.contains("every day") || text.contains("daily") { return .onceDaily }

        if text.contains("prn") || text.contains("as needed") { return .asNeeded }
        return nil
    }

    private func parseDurationDays(from text: String) -> Int? {
        if let days = firstCapture(pattern: #"for\s*(\d{1,3})\s*days?"#, in: text).flatMap(Int.init) {
            return days
        }
        return nil
    }

    private func parseMinimumHoursBetween(from text: String) -> Int? {
        firstCapture(pattern: #"at least\s*(\d{1,2})\s*hours?\s*between"#, in: text).flatMap(Int.init)
    }

    private func parseMaxDosesPerDay(from text: String) -> Int? {
        firstCapture(pattern: #"max(?:imum)?\s*(\d{1,2})\s*(?:doses?|times)\s*(?:per|a)?\s*day"#, in: text).flatMap(Int.init)
    }

    private func parseMaxAmountPer24Hours(from text: String) -> Double? {
        firstCapture(pattern: #"max(?:imum)?\s*(\d+(?:\.\d+)?)\s*(mg|mcg|g|ml)\s*(?:in|per)?\s*24\s*hours"#, in: text).flatMap(Double.init)
    }

    private func parseMaxPerDose(from text: String) -> Double? {
        firstCapture(pattern: #"max(?:imum)?\s*(\d+(?:\.\d+)?)\s*(mg|mcg|g|ml)?\s*per\s*dose"#, in: text).flatMap(Double.init)
    }

    private func parsePRN(from text: String, units: String?) -> PRNRule? {
        guard text.contains("prn") || text.contains("as needed") else { return nil }
        let indication = firstCapture(pattern: #"(?:for|if)\s*([a-z\s]{3,40})"#, in: text)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "symptoms"
        return PRNRule(
            indication: indication,
            maxPerDose: parseMaxPerDose(from: text),
            maxPerDayDoses: parseMaxDosesPerDay(from: text),
            maxPer24HoursAmount: parseMaxAmountPer24Hours(from: text),
            minimumHoursBetweenDoses: parseMinimumHoursBetween(from: text)
        )
    }

    private func parseCycleRule(from text: String) -> CycleRule? {
        guard
            let on = firstCapture(pattern: #"(\d{1,3})\s*days?\s*on"#, in: text).flatMap(Int.init),
            let off = firstCapture(pattern: #"(\d{1,3})\s*days?\s*off"#, in: text).flatMap(Int.init)
        else { return nil }

        return CycleRule(daysOn: on, daysOff: off)
    }

    private func parseTaperSteps(from text: String, fallbackDose: Double?) -> [TaperStep] {
        guard text.contains("then") || text.contains("taper") else { return [] }

        let pattern = #"(\d+(?:\.\d+)?)\s*(mg|mcg|g|ml)?\s*(?:for\s*(\d{1,2})\s*days?)"#
        let matches = allMatches(pattern: pattern, in: text)
        guard !matches.isEmpty else { return [] }

        var dayCursor = 1
        var steps: [TaperStep] = []

        for match in matches {
            guard let doseStr = match[safe: 1], let dose = Double(doseStr), let lenStr = match[safe: 3], let length = Int(lenStr) else {
                continue
            }
            let end = dayCursor + length - 1
            steps.append(TaperStep(startDay: dayCursor, endDay: end, dose: dose, frequency: .onceDaily))
            dayCursor = end + 1
        }

        if steps.isEmpty, let fallbackDose {
            steps = [TaperStep(startDay: 1, endDay: 3, dose: fallbackDose, frequency: .onceDaily)]
        }

        return steps
    }

    private func parseTimingWindows(from text: String) -> [String] {
        var windows: [String] = []
        if text.contains("morning") { windows.append("morning") }
        if text.contains("afternoon") { windows.append("afternoon") }
        if text.contains("evening") { windows.append("evening") }
        if text.contains("bedtime") { windows.append("bedtime") }
        return windows
    }

    private func parseConstraints(from text: String) -> [SpecialConstraint] {
        var constraints: [SpecialConstraint] = []
        if text.contains("with food") { constraints.append(.withFood) }
        if text.contains("bedtime") { constraints.append(.bedtime) }
        if text.contains("avoid alcohol") { constraints.append(.avoidAlcohol) }
        if text.contains("do not combine") || text.contains("avoid combining") { constraints.append(.avoidCombining) }
        if text.contains("do not crush") { constraints.append(.doNotCrush) }
        return constraints
    }

    private func ambiguityQuestions(from plan: ParsedMedicationPlan, sourceText: String) -> [String] {
        var questions: [String] = []

        let ambiguousTokens = [" qd ", " u ", " iu ", " as directed "]
        for token in ambiguousTokens where sourceText.contains(token) {
            questions.append("The instruction includes an ambiguous abbreviation (\(token.trimmingCharacters(in: .whitespaces))). Please confirm with your pharmacist.")
        }

        if plan.route == nil {
            questions.append("Route is missing. Should this be oral, topical, inhaled, or another route?")
        }

        if plan.frequency == nil {
            questions.append("Frequency is unclear. How many times per day should this be taken?")
        }

        if plan.prnRule != nil && plan.maxPerDayDoses == nil && plan.maxPer24HoursAmount == nil {
            questions.append("PRN instructions are missing a maximum per day or per 24 hours. Please confirm a safe limit.")
        }

        if plan.durationDays == nil && plan.taperSteps.isEmpty && plan.cycleRule == nil && plan.prnRule == nil {
            questions.append("Duration is not specified. How long should this medication plan continue?")
        }

        return questions
    }

    private func firstMatch(pattern: String, in text: String) -> String? {
        let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex?.firstMatch(in: text, options: [], range: range), match.numberOfRanges > 1,
              let outRange = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return String(text[outRange])
    }

    private func firstCapture(pattern: String, in text: String) -> String? {
        firstMatch(pattern: pattern, in: text)
    }

    private func allMatches(pattern: String, in text: String) -> [[String]] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex.matches(in: text, options: [], range: range)
        return matches.map { match in
            (0..<match.numberOfRanges).compactMap { idx in
                guard let matchRange = Range(match.range(at: idx), in: text) else { return nil }
                return String(text[matchRange])
            }
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
