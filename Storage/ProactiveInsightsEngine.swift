import Foundation
import MedicationLogicEngine

struct ProactiveInsightsEngine {
    func buildSuggestions(
        plan: MedicationPlanRecord?,
        output: EngineOutput?,
        logs: [DoseLogRecord],
        remindersEnabled: Bool,
        notificationsAuthorized: Bool
    ) -> [ProactiveSuggestion] {
        guard let plan else {
            return [
                ProactiveSuggestion(
                    title: "Create your first plan",
                    detail: "Upload, scan, or paste medication instructions to activate smart reminders and adherence insights.",
                    priority: .info,
                    action: .none,
                    actionTitle: nil
                )
            ]
        }

        guard let output else {
            return [
                ProactiveSuggestion(
                    title: "Plan ready for analysis",
                    detail: "Open Add Medication Plan and rebuild to refresh schedule intelligence for proactive alerts.",
                    priority: .info,
                    action: .none,
                    actionTitle: nil
                )
            ]
        }

        var suggestions: [ProactiveSuggestion] = []

        if output.flags.contains(where: { $0.severity == .critical }) {
            suggestions.append(
                ProactiveSuggestion(
                    title: "Critical safety flag detected",
                    detail: "Please verify this plan with a pharmacist or clinician before following all instructions.",
                    priority: .critical,
                    action: .reviewSafety,
                    actionTitle: nil
                )
            )
        }

        if output.parsed.needsClinicianConfirmation || !output.parsed.ambiguityQuestions.isEmpty {
            let question = output.parsed.ambiguityQuestions.first ?? "One or more instructions need clarification."
            suggestions.append(
                ProactiveSuggestion(
                    title: "Clarification needed",
                    detail: question,
                    priority: .warning,
                    action: .reviewSafety,
                    actionTitle: nil
                )
            )
        }

        if !remindersEnabled {
            suggestions.append(
                ProactiveSuggestion(
                    title: "Enable proactive reminders",
                    detail: "Turn reminders on to receive upcoming dose alerts from your generated schedule.",
                    priority: .warning,
                    action: .enableReminders,
                    actionTitle: "Enable"
                )
            )
        } else if remindersEnabled && !notificationsAuthorized {
            suggestions.append(
                ProactiveSuggestion(
                    title: "Allow notification access",
                    detail: "Notification permission is required for dose reminders to fire on time.",
                    priority: .warning,
                    action: .grantNotificationAccess,
                    actionTitle: "Allow"
                )
            )
        }

        let now = Date()
        let todayEvents = output.schedule
            .flatMap(\.events)
            .filter { Calendar.current.isDateInToday($0.date) }
        let nextEvent = todayEvents.filter { $0.date > now }.sorted { $0.date < $1.date }.first

        if let nextEvent {
            let upcomingMinutes = Int(nextEvent.date.timeIntervalSince(now) / 60)
            if upcomingMinutes <= 90 && logs.isEmpty {
                suggestions.append(
                    ProactiveSuggestion(
                        title: "Upcoming dose soon",
                        detail: "Next dose is in about \(max(upcomingMinutes, 0)) min. Keep reminders active and log when taken.",
                        priority: .info,
                        action: .scheduleReminders,
                        actionTitle: "Refresh Reminders"
                    )
                )
            }
        }

        if let prnRule = output.parsed.prnRule, let maxPRN = prnRule.maxPerDayDoses {
            let prnTakenToday = logs.filter {
                $0.isPRN && Calendar.current.isDateInToday($0.timestamp)
            }.count
            if prnTakenToday >= maxPRN {
                suggestions.append(
                    ProactiveSuggestion(
                        title: "PRN daily cap reached",
                        detail: "You have logged \(prnTakenToday)/\(maxPRN) PRN doses today. Avoid extra PRN doses unless clinician-directed.",
                        priority: .critical,
                        action: .reviewSafety,
                        actionTitle: nil
                    )
                )
            }
        }

        if suggestions.isEmpty {
            suggestions.append(
                ProactiveSuggestion(
                    title: "Plan monitoring is healthy",
                    detail: "No urgent issues detected for \(plan.source.rawValue) input. Continue logging doses for better adherence insights.",
                    priority: .info,
                    action: .none,
                    actionTitle: nil
                )
            )
        }

        return suggestions
    }
}

struct IntuioNoteInput {
    let now: Date
    let parsed: ParsedMedicationPlan
    let output: EngineOutput
    let logsToday: [DoseLogRecord]
    let remindersEnabled: Bool
    let notificationsAuthorized: Bool
}

protocol IntuioLocalNoteGenerating {
    var modelName: String { get }
    func generateNote(input: IntuioNoteInput) async -> String
}

struct IntuioMicroSLMNoteEngine: IntuioLocalNoteGenerating {
    let modelName = "Intuio-MicroSLM-v0"

    func generateNote(input: IntuioNoteInput) async -> String {
        let planName = input.parsed.drugName ?? "medication"
        let todayEvents = input.output.schedule
            .flatMap(\.events)
            .filter { Calendar.current.isDateInToday($0.date) && !$0.isPRN }

        let takenScheduled = input.logsToday.filter { !$0.isPRN }.count
        let totalScheduled = todayEvents.count
        let remaining = max(0, totalScheduled - takenScheduled)

        let nextEvent = todayEvents
            .filter { $0.date > input.now }
            .sorted { $0.date < $1.date }
            .first

        let safetySeverity = input.output.flags.contains(where: { $0.severity == .critical })
            ? "critical"
            : (input.output.flags.contains(where: { $0.severity == .warning }) ? "warning" : "clear")

        let reminderState: String
        if !input.remindersEnabled {
            reminderState = "Reminders are currently off"
        } else if !input.notificationsAuthorized {
            reminderState = "Notification permission is not granted"
        } else {
            reminderState = "Reminders are active"
        }

        let prnNote: String
        if let prn = input.parsed.prnRule {
            let maxDoses = prn.maxPerDayDoses.map(String.init) ?? "not specified"
            let maxAmount = prn.maxPer24HoursAmount.map { String(format: "%.1f", $0) } ?? "not specified"
            prnNote = "PRN indication: \(prn.indication). Daily PRN limits: doses \(maxDoses), amount \(maxAmount)."
        } else {
            prnNote = "No PRN regimen is defined in this plan."
        }

        let nextDoseLine: String
        if let nextEvent {
            nextDoseLine = "Next scheduled dose is at \(nextEvent.date.formatted(date: .omitted, time: .shortened))."
        } else if remaining == 0 {
            nextDoseLine = "No scheduled doses remain today."
        } else {
            nextDoseLine = "No future scheduled dose time is currently available."
        }

        let safetyLine: String
        switch safetySeverity {
        case "critical":
            safetyLine = "A critical safety flag is present; verify this plan with a pharmacist or clinician."
        case "warning":
            safetyLine = "A safety warning is present; review plan details before taking additional doses."
        default:
            safetyLine = "No active safety flags are detected right now."
        }

        return """
        Daily note for \(planName): \(takenScheduled) of \(totalScheduled) scheduled dose(s) logged today, \(remaining) remaining. \(nextDoseLine)
        \(safetyLine)
        \(prnNote)
        \(reminderState).
        """
    }
}
