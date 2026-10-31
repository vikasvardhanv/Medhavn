import Foundation

/// Things the assistant can look up or do in the app. Answers come from the user's real data,
/// so they stay correct even when the small on-device model is not loaded or would guess.
/// Anything that changes data says exactly what it changed.
@MainActor
enum IntuioAssistantTools {

    /// Returns a reply when the message is a data question or an action, otherwise nil.
    static func handle(_ text: String, appState: AppState) -> String? {
        let q = text.lowercased()

        if q.contains("dispenser") || q.contains("pill box") || q.contains("pillbox device") || q.contains("my device") {
            return "No pill dispenser is connected to Medhavn yet, so I cannot control one. Your reminders still arrive as notifications on this phone."
        }
        if q.contains("refill") && (q.contains("order") || q.contains("request") || q.contains("place")) {
            return "I cannot order refills from a pharmacy. " + stockReport(appState) + " When you collect a refill, add the pills in the Pharmacy tab."
        }
        if (q.contains("took") || q.contains("taken") || q.contains("mark")) && !q.contains("took too") && !q.contains("should i") {
            if let reply = markTaken(q, appState: appState) { return reply }
        }
        if q.contains("book") || q.contains("make an appointment") || q.contains("add an appointment") || q.contains("add appointment") || q.contains("schedule an appointment") || q.contains("schedule a ") && q.contains("appointment") {
            return bookAppointment(text, appState: appState)
        }
        if q.contains("next dose") || (q.contains("next") && (q.contains("pill") || q.contains("medic"))) || q.contains("what do i take") || q.contains("what should i take") {
            return nextDose(appState)
        }
        if q.contains("did i take") || q.contains("today's doses") || q.contains("todays doses") || q.contains("how am i doing") || q.contains("adherence") {
            return todaySummary(appState)
        }
        if q.contains("running low") || q.contains("pills left") || q.contains("how many pills") || q.contains("low on") || q.contains("running out") {
            return stockReport(appState)
        }
        if q.contains("my medications") || q.contains("what meds") || q.contains("what am i taking") || q.contains("list my med") {
            return medicationList(appState)
        }
        return nil
    }

    /// Short facts block for the language model, so its answers use the user's actual plan.
    static func context(appState: AppState) -> String {
        [
            "Today: " + todaySummary(appState),
            nextDose(appState),
            stockReport(appState),
            "Medications: " + medicationList(appState),
        ].joined(separator: "\n")
    }

    // MARK: - Reading

    private static let blocks = DayTimeBlock.allCases.sorted { $0.sortIndex < $1.sortIndex }

    private static func medicationList(_ appState: AppState) -> String {
        let items = appState.medCabinetItems
        guard !items.isEmpty else { return "You have no medications in the Pharmacy yet." }
        return items.prefix(12).map { item in
            let when = item.scheduledTimes.isEmpty
                ? item.scheduleBlocks.map(\.title).joined(separator: ", ")
                : item.scheduledTimes.map(\.displayString).joined(separator: ", ")
            return "\(item.name) \(item.dosageText)" + (when.isEmpty ? "" : " (\(when))")
        }.joined(separator: "; ")
    }

    private static func stockReport(_ appState: AppState) -> String {
        let items = appState.medCabinetItems
        guard !items.isEmpty else { return "No medications are tracked yet." }
        let low = items.filter { $0.remainingPills <= $0.refillThreshold }
        if low.isEmpty { return "No medication is running low." }
        return "Running low: " + low.map { "\($0.name) (\($0.remainingPills) left)" }.joined(separator: ", ") + "."
    }

    private static func nextDose(_ appState: AppState) -> String {
        let done = Set(appState.pillDoseStatuses.filter { $0.status != .pending }.map(\.key))
        let next = PillboxReminderPlanner.plan(specs: appState.reminderSpecs(), now: Date(), days: 2, isDone: { done.contains($0) }).first
        guard let next else { return "No upcoming doses in the next 2 days." }
        let dose = next.dosage.isEmpty ? "" : " (\(next.dosage))"
        return "Next dose: \(next.name)\(dose) at \(next.fire.formatted(date: .abbreviated, time: .shortened))."
    }

    private static func todaySummary(_ appState: AppState) -> String {
        let today = Date()
        var taken = 0, skipped = 0
        var pending: [String] = []
        let hour = Calendar.current.component(.hour, from: today)
        for block in blocks {
            for item in appState.items(for: block, on: today) {
                switch appState.statusForDose(itemID: item.id, block: block, date: today) {
                case .taken: taken += 1
                case .skipped: skipped += 1
                case .pending:
                    if startHour(of: block) <= hour { pending.append("\(item.name) (\(block.title.lowercased()))") }
                }
            }
        }
        if taken + skipped + pending.count == 0 { return "No doses were due so far today." }
        var text = "Today: \(taken) taken, \(skipped) skipped."
        if !pending.isEmpty { text += " Still to log: " + pending.joined(separator: ", ") + "." }
        return text
    }

    private static func startHour(of block: DayTimeBlock) -> Int {
        switch block {
        case .morning: return 0
        case .afternoon: return 12
        case .evening: return 17
        case .night: return 22
        }
    }

    // MARK: - Acting

    /// "I took my morning pills", "mark metformin as taken". Marks today's pending doses and says which.
    private static func markTaken(_ q: String, appState: AppState) -> String? {
        let today = Date()
        let hour = Calendar.current.component(.hour, from: today)
        let namedBlocks = blocks.filter { q.contains($0.rawValue) }
        let namedItems = appState.medCabinetItems.filter { q.contains($0.name.lowercased()) }
        guard !namedBlocks.isEmpty || !namedItems.isEmpty else { return nil }

        var marked: [String] = []
        for block in (namedBlocks.isEmpty ? blocks.filter { startHour(of: $0) <= hour } : namedBlocks) {
            for item in appState.items(for: block, on: today) where namedItems.isEmpty || namedItems.contains(where: { $0.id == item.id }) {
                if appState.statusForDose(itemID: item.id, block: block, date: today) == .pending {
                    appState.markDose(itemID: item.id, block: block, date: today, status: .taken)
                    marked.append("\(item.name) (\(block.title.lowercased()))")
                }
            }
        }
        if marked.isEmpty { return "Nothing was waiting to be logged for that. You can check Home to see today's doses." }
        return "Marked as taken: " + marked.joined(separator: ", ") + ". You can undo it on the Home tab."
    }

    /// Creates an appointment only when the message holds a real date. No guessed doctor or day.
    private static func bookAppointment(_ text: String, appState: AppState) -> String {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
        let found = detector?.firstMatch(in: text, range: NSRange(text.startIndex..., in: text))?.date
        guard let date = found, date > Date().addingTimeInterval(-3600) else {
            return "What day and time? For example: \"Book a dentist appointment on Friday at 3pm\"."
        }
        let q = text.lowercased()
        let type = q.contains("fast") || q.contains("lab") ? "Fasting Lab"
            : q.contains("blood") ? "Blood Test"
            : q.contains("vacc") ? "Vaccination"
            : "Routine Checkup"
        let title = q.contains("dentist") || q.contains("dental") ? "Dental Appointment" : "\(type) Appointment"
        appState.addAppointment(AppointmentRecord(id: UUID(), title: title, doctorName: "Not specified", date: date,
                                                  notes: "Added by the Medhavn assistant.", type: type))
        return "Added \(title) for \(date.formatted(date: .abbreviated, time: .shortened)). Open Hub, Appointments to add the doctor's name."
    }
}
