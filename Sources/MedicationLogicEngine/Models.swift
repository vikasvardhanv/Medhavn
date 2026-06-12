import Foundation

public enum Route: String, Codable, CaseIterable, Sendable {
    case oral
    case topical
    case inhaled
    case injection
    case ophthalmic
    case otic
    case unknown
}

public enum Frequency: Codable, Equatable, Sendable {
    case onceDaily
    case twiceDaily
    case threeTimesDaily
    case fourTimesDaily
    case everyHours(Int)
    case asNeeded
    case customPerDay(Int)

    public var dosesPerDay: Int? {
        switch self {
        case .onceDaily: return 1
        case .twiceDaily: return 2
        case .threeTimesDaily: return 3
        case .fourTimesDaily: return 4
        case .everyHours(let hours): return max(1, 24 / max(1, hours))
        case .customPerDay(let count): return count
        case .asNeeded: return nil
        }
    }
}

public struct PRNRule: Codable, Equatable, Sendable {
    public var indication: String
    public var maxPerDose: Double?
    public var maxPerDayDoses: Int?
    public var maxPer24HoursAmount: Double?
    public var minimumHoursBetweenDoses: Int?

    public init(
        indication: String,
        maxPerDose: Double? = nil,
        maxPerDayDoses: Int? = nil,
        maxPer24HoursAmount: Double? = nil,
        minimumHoursBetweenDoses: Int? = nil
    ) {
        self.indication = indication
        self.maxPerDose = maxPerDose
        self.maxPerDayDoses = maxPerDayDoses
        self.maxPer24HoursAmount = maxPer24HoursAmount
        self.minimumHoursBetweenDoses = minimumHoursBetweenDoses
    }
}

public struct TaperStep: Codable, Equatable, Sendable {
    public var startDay: Int
    public var endDay: Int
    public var dose: Double
    public var frequency: Frequency

    public init(startDay: Int, endDay: Int, dose: Double, frequency: Frequency) {
        self.startDay = startDay
        self.endDay = endDay
        self.dose = dose
        self.frequency = frequency
    }
}

public struct CycleRule: Codable, Equatable, Sendable {
    public var daysOn: Int
    public var daysOff: Int

    public init(daysOn: Int, daysOff: Int) {
        self.daysOn = daysOn
        self.daysOff = daysOff
    }
}

public enum SpecialConstraint: String, Codable, CaseIterable, Sendable {
    case withFood
    case bedtime
    case avoidAlcohol
    case avoidCombining
    case doNotCrush
}

public struct ParsedMedicationPlan: Codable, Equatable, Sendable {
    public var sourceText: String
    public var drugName: String?
    public var dose: Double?
    public var units: String?
    public var route: Route?
    public var frequency: Frequency?
    public var timingWindows: [String]
    public var durationDays: Int?
    public var taperSteps: [TaperStep]
    public var cycleRule: CycleRule?
    public var prnRule: PRNRule?
    public var maxPerDose: Double?
    public var maxPerDayDoses: Int?
    public var maxPer24HoursAmount: Double?
    public var minimumHoursBetweenDoses: Int?
    public var specialConstraints: [SpecialConstraint]
    public var ambiguityQuestions: [String]
    public var needsClinicianConfirmation: Bool

    public init(
        sourceText: String,
        drugName: String? = nil,
        dose: Double? = nil,
        units: String? = nil,
        route: Route? = nil,
        frequency: Frequency? = nil,
        timingWindows: [String] = [],
        durationDays: Int? = nil,
        taperSteps: [TaperStep] = [],
        cycleRule: CycleRule? = nil,
        prnRule: PRNRule? = nil,
        maxPerDose: Double? = nil,
        maxPerDayDoses: Int? = nil,
        maxPer24HoursAmount: Double? = nil,
        minimumHoursBetweenDoses: Int? = nil,
        specialConstraints: [SpecialConstraint] = [],
        ambiguityQuestions: [String] = [],
        needsClinicianConfirmation: Bool = false
    ) {
        self.sourceText = sourceText
        self.drugName = drugName
        self.dose = dose
        self.units = units
        self.route = route
        self.frequency = frequency
        self.timingWindows = timingWindows
        self.durationDays = durationDays
        self.taperSteps = taperSteps
        self.cycleRule = cycleRule
        self.prnRule = prnRule
        self.maxPerDose = maxPerDose
        self.maxPerDayDoses = maxPerDayDoses
        self.maxPer24HoursAmount = maxPer24HoursAmount
        self.minimumHoursBetweenDoses = minimumHoursBetweenDoses
        self.specialConstraints = specialConstraints
        self.ambiguityQuestions = ambiguityQuestions
        self.needsClinicianConfirmation = needsClinicianConfirmation
    }
}

public enum SafetyFlagSeverity: String, Codable, Sendable {
    case info
    case warning
    case critical
}

public struct SafetyFlag: Codable, Equatable, Sendable {
    public var severity: SafetyFlagSeverity
    public var message: String

    public init(severity: SafetyFlagSeverity, message: String) {
        self.severity = severity
        self.message = message
    }
}

public struct DoseEvent: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var date: Date
    public var dose: Double
    public var units: String
    public var isPRN: Bool
    public var hardStop: Bool

    public init(id: UUID = UUID(), date: Date, dose: Double, units: String, isPRN: Bool = false, hardStop: Bool = false) {
        self.id = id
        self.date = date
        self.dose = dose
        self.units = units
        self.isPRN = isPRN
        self.hardStop = hardStop
    }
}

public struct DailyPlan: Codable, Equatable, Sendable {
    public var dayOffset: Int
    public var date: Date
    public var events: [DoseEvent]

    public init(dayOffset: Int, date: Date, events: [DoseEvent]) {
        self.dayOffset = dayOffset
        self.date = date
        self.events = events
    }
}

public struct EngineOutput: Sendable {
    public var parsed: ParsedMedicationPlan
    public var flags: [SafetyFlag]
    public var schedule: [DailyPlan]
    public var patientDirections: String
    public var rationale: String

    public init(parsed: ParsedMedicationPlan, flags: [SafetyFlag], schedule: [DailyPlan], patientDirections: String, rationale: String) {
        self.parsed = parsed
        self.flags = flags
        self.schedule = schedule
        self.patientDirections = patientDirections
        self.rationale = rationale
    }
}
