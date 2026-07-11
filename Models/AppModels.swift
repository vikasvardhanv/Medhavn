import Foundation

enum IngestionSource: String, Codable, CaseIterable {
    case pastedSig
    case scannedDocument
    case manualEntry
}

struct MedicationPlanRecord: Identifiable, Codable {
    let id: UUID
    let createdAt: Date
    let source: IngestionSource
    let sourceText: String
    let parsedJSON: String
    let patientDirections: String
    let rationale: String
    let needsConfirmation: Bool
}

struct DoseLogRecord: Identifiable, Codable {
    let id: UUID
    let planID: UUID
    let timestamp: Date
    let dose: Double
    let units: String
    let isPRN: Bool
}

struct DailyInsightNoteRecord: Identifiable, Codable {
    let id: UUID
    let planID: UUID
    let dayStart: Date
    let noteBody: String
    let modelName: String
    let createdAt: Date
}

enum DayTimeBlock: String, Codable, CaseIterable, Identifiable {
    case morning
    case afternoon
    case evening
    case night

    var id: String { rawValue }

    var title: String {
        switch self {
        case .morning: return "Morning"
        case .afternoon: return "Afternoon"
        case .evening: return "Evening"
        case .night: return "Night"
        }
    }

    var sortIndex: Int {
        switch self {
        case .morning: return 0
        case .afternoon: return 1
        case .evening: return 2
        case .night: return 3
        }
    }
}

enum PillShapeStyle: String, Codable, CaseIterable, Identifiable {
    case capsule
    case round
    case oval
    case tablet

    var id: String { rawValue }
}

struct UserProfile: Identifiable, Codable {
    let id: UUID
    var name: String
    var avatarSymbol: String
}

struct MedCabinetItem: Identifiable, Codable {
    let id: UUID
    var profileID: UUID
    var name: String
    var dosageText: String
    var scheduleBlocks: [DayTimeBlock]
    var remainingPills: Int
    var refillThreshold: Int
    var pillShape: PillShapeStyle
    var pillColorHex: String
    var contraindicationTags: [String]
    var createdAt: Date
    // Schedule enhancements
    var frequency: MedFrequency
    var scheduledTimes: [ScheduledTime]
    var scheduleStartDate: Date?
    var scheduleEndDate: Date?
    var specificDays: [Int]       // 1=Mon…7=Sun
    var intervalDays: Int         // every N days
    // Refill
    var refill: PrescriptionRefill

    init(
        id: UUID = UUID(),
        profileID: UUID,
        name: String,
        dosageText: String,
        scheduleBlocks: [DayTimeBlock],
        remainingPills: Int = 30,
        refillThreshold: Int = 5,
        pillShape: PillShapeStyle = .capsule,
        pillColorHex: String = "#2F80ED",
        contraindicationTags: [String] = [],
        createdAt: Date = Date(),
        frequency: MedFrequency = .everyDay,
        scheduledTimes: [ScheduledTime] = [],
        scheduleStartDate: Date? = nil,
        scheduleEndDate: Date? = nil,
        specificDays: [Int] = [],
        intervalDays: Int = 1,
        refill: PrescriptionRefill = PrescriptionRefill()
    ) {
        self.id = id
        self.profileID = profileID
        self.name = name
        self.dosageText = dosageText
        self.scheduleBlocks = scheduleBlocks
        self.remainingPills = remainingPills
        self.refillThreshold = refillThreshold
        self.pillShape = pillShape
        self.pillColorHex = pillColorHex
        self.contraindicationTags = contraindicationTags
        self.createdAt = createdAt
        self.frequency = frequency
        self.scheduledTimes = scheduledTimes
        self.scheduleStartDate = scheduleStartDate
        self.scheduleEndDate = scheduleEndDate
        self.specificDays = specificDays
        self.intervalDays = intervalDays
        self.refill = refill
    }
}

enum DoseStatusKind: String, Codable {
    case pending
    case taken
    case skipped
}

struct PillDoseStatusRecord: Identifiable, Codable {
    let id: UUID
    var key: String
    var status: DoseStatusKind
    var updatedAt: Date
}

enum UpdateCategory: String, Codable {
    case refill
    case adherence
    case interaction
    case caregiver
    case tip
}

struct UpdateFeedItem: Identifiable, Codable {
    let id: UUID
    var category: UpdateCategory
    var title: String
    var detail: String
    var timestamp: Date
}

// MARK: - Health Metric Types (expanded)
enum HealthMetricType: String, Codable, CaseIterable, Identifiable {
    // General
    case painLevel       = "Pain Level"
    case peakFlow        = "Peak Flow"
    case spO2            = "SpO2"
    // Reproductive
    case basalBodyTemp   = "Basal Body Temperature"
    case cervicalMucus   = "Cervical Mucus Quality"
    case ovulationTest   = "Ovulation Test Result"
    case sexualActivity  = "Sexual Activity"
    case spotting        = "Spotting"
    // Vitals
    case bloodPressure   = "Blood Pressure"
    case pulse           = "Pulse"
    case temperature     = "Temperature"
    // Metabolic
    case glucose         = "Glucose"
    case weight          = "Weight"

    var id: String { rawValue }

    enum Section: String { case general = "GENERAL", reproductive = "REPRODUCTIVE HEALTH", vitals = "VITALS", metabolic = "METABOLIC" }

    var section: Section {
        switch self {
        case .painLevel, .peakFlow, .spO2: return .general
        case .basalBodyTemp, .cervicalMucus, .ovulationTest, .sexualActivity, .spotting: return .reproductive
        case .bloodPressure, .pulse, .temperature: return .vitals
        case .glucose, .weight: return .metabolic
        }
    }

    var defaultUnit: String {
        switch self {
        case .painLevel: return "/10"
        case .peakFlow: return "L/min"
        case .spO2: return "%"
        case .basalBodyTemp: return "°F"
        case .cervicalMucus: return ""
        case .ovulationTest: return ""
        case .sexualActivity: return ""
        case .spotting: return ""
        case .bloodPressure: return "mmHg"
        case .pulse: return "bpm"
        case .temperature: return "°F"
        case .glucose: return "mg/dL"
        case .weight: return "lbs"
        }
    }

    var sfSymbol: String {
        switch self {
        case .painLevel: return "hand.raised.slash"
        case .peakFlow: return "wind"
        case .spO2: return "lungs.fill"
        case .basalBodyTemp: return "thermometer.medium"
        case .cervicalMucus: return "drop.fill"
        case .ovulationTest: return "circle.dotted"
        case .sexualActivity: return "heart.fill"
        case .spotting: return "drop"
        case .bloodPressure: return "waveform.path.ecg"
        case .pulse: return "heart.circle"
        case .temperature: return "thermometer.sun.fill"
        case .glucose: return "drop.circle"
        case .weight: return "scalemass.fill"
        }
    }
}

// MARK: - Medication Schedule
enum MedFrequency: String, Codable, CaseIterable, Identifiable {
    case asNeeded      = "As Needed"
    case everyDay      = "Every Day"
    case specificDays  = "Specific Days"
    case daysInterval  = "Days Interval"

    var id: String { rawValue }
}

struct ScheduledTime: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var hour: Int       // 0-23
    var minute: Int     // 0-59
    var quantityLabel: String = "Take 1"

    var displayString: String {
        let h = hour % 12 == 0 ? 12 : hour % 12
        let period = hour < 12 ? "AM" : "PM"
        return String(format: "%d:%02d %@", h, minute, period)
    }
}

// MARK: - Prescription Refill
struct PrescriptionRefill: Codable {
    var rxNumber: String = ""
    var pillsLeft: Int = 0
    var refillReminderEnabled: Bool = false
}

// MARK: - SafeCircle (care network)
struct SafeCircleContact: Identifiable, Codable {
    let id: UUID
    var name: String
    var contactInfo: String   // email or phone
    var relationship: String  // e.g. "Spouse", "Parent", "Doctor"
}

// MARK: - Dependent Profile
struct DependentProfile: Identifiable, Codable {
    let id: UUID
    var firstName: String
    var lastName: String
    var gender: String       // "Male", "Female", "Other"
    var birthYear: Int
    var avatarColor: String  // hex
}

// MARK: - Linked Parent Care
enum ParentLinkStatus: String, Codable, CaseIterable, Identifiable {
    case pending = "Pending"
    case linked = "Linked"
    case paused = "Paused"

    var id: String { rawValue }
}

struct LinkedParentProfile: Identifiable, Codable {
    let id: UUID
    var profileID: UUID
    var displayName: String
    var relationship: String
    var linkCode: String
    var parentAppUserID: String?
    var status: ParentLinkStatus
    var linkedAt: Date
}

enum ParentMedicationAlertKind: String, Codable {
    case missedDose
    case buzzSent
}

struct ParentMedicationAlert: Identifiable, Codable {
    let id: UUID
    var parentProfileID: UUID
    var medicationID: UUID
    var doseKey: String
    var medicationName: String
    var scheduledBlock: DayTimeBlock
    var scheduledDate: Date
    var kind: ParentMedicationAlertKind
    var buzzSentAt: Date?
    var createdAt: Date
}

// MARK: - Appointments
struct AppointmentRecord: Identifiable, Codable {
    let id: UUID
    var title: String
    var doctorName: String
    var date: Date
    var notes: String
}

// MARK: - Doctors
struct DoctorRecord: Identifiable, Codable {
    let id: UUID
    var name: String
    var specialty: String
    var phone: String
    var notes: String
}

// MARK: - Drug Interactions
enum InteractionSeverity: String, Codable {
    case mild     = "Mild possible interaction"
    case moderate = "Moderate possible interaction"
    case severe   = "Severe possible interaction"

    var color: String {
        switch self {
        case .mild: return "#4CAF50"
        case .moderate: return "#FF9800"
        case .severe: return "#F44336"
        }
    }
}

struct DrugInteractionRecord: Identifiable, Codable {
    let id: UUID
    var drug1: String
    var drug2: String
    var severity: InteractionSeverity
    var detail: String
}

struct HealthMetricRecord: Identifiable, Codable {
    let id: UUID
    var type: HealthMetricType
    var value: String
    var unit: String
    var timestamp: Date
}

struct DiaryEntryRecord: Identifiable, Codable {
    let id: UUID
    var text: String
    var timestamp: Date
}

// MARK: - Allergy Tracking

enum AllergyReaction: String, Codable, CaseIterable, Identifiable {
    case mild     = "Mild"
    case moderate = "Moderate"
    case severe   = "Severe"
    var id: String { rawValue }
}

struct AllergyRecord: Identifiable, Codable {
    var id: UUID      = UUID()
    var substance: String
    var reaction: AllergyReaction
    var notes: String = ""
    var dateAdded: Date = Date()
}

// MARK: - Fertility Tracking
enum FertilityCycleState: String, Codable, CaseIterable, Identifiable {
    case menstruation    = "Menstruation"
    case follicular      = "Follicular"
    case ovulationWindow = "Ovulation Window"
    case luteal         = "Luteal"

    var id: String { rawValue }

    var sfSymbol: String {
        switch self {
        case .menstruation:    return "drop.fill"
        case .follicular:      return "sun.max.fill"
        case .ovulationWindow: return "circle.dotted"
        case .luteal:          return "moon.fill"
        }
    }

    var color: String {
        switch self {
        case .menstruation:    return "#F44336"
        case .follicular:      return "#FF9800"
        case .ovulationWindow: return "#4CAF50"
        case .luteal:          return "#9C27B0"
        }
    }
}

struct FertilityCycleRecord: Identifiable, Codable {
    let id: UUID
    var startDate: Date
    var endDate: Date?
    var cycleLength: Int
    var periodLength: Int
    var predictedNextPeriod: Date?
    var predictedFertileWindow: (start: Date, end: Date)?
    var state: FertilityCycleState

    init(
        id: UUID = UUID(),
        startDate: Date = Date(),
        endDate: Date? = nil,
        cycleLength: Int = 28,
        periodLength: Int = 5,
        predictedNextPeriod: Date? = nil,
        predictedFertileWindow: (start: Date, end: Date)? = nil,
        state: FertilityCycleState = .menstruation
    ) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.cycleLength = cycleLength
        self.periodLength = periodLength
        self.predictedNextPeriod = predictedNextPeriod
        self.predictedFertileWindow = predictedFertileWindow
        self.state = state
    }

    enum CodingKeys: String, CodingKey {
        case id, startDate, endDate, cycleLength, periodLength
        case predictedNextPeriod, fertileWindowStart, fertileWindowEnd, state
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        startDate = try container.decode(Date.self, forKey: .startDate)
        endDate = try container.decodeIfPresent(Date.self, forKey: .endDate)
        cycleLength = try container.decode(Int.self, forKey: .cycleLength)
        periodLength = try container.decode(Int.self, forKey: .periodLength)
        predictedNextPeriod = try container.decodeIfPresent(Date.self, forKey: .predictedNextPeriod)
        if let fStart = try container.decodeIfPresent(Date.self, forKey: .fertileWindowStart),
           let fEnd = try container.decodeIfPresent(Date.self, forKey: .fertileWindowEnd) {
            predictedFertileWindow = (fStart, fEnd)
        }
        state = try container.decode(FertilityCycleState.self, forKey: .state)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(startDate, forKey: .startDate)
        try container.encodeIfPresent(endDate, forKey: .endDate)
        try container.encode(cycleLength, forKey: .cycleLength)
        try container.encode(periodLength, forKey: .periodLength)
        try container.encodeIfPresent(predictedNextPeriod, forKey: .predictedNextPeriod)
        try container.encodeIfPresent(predictedFertileWindow?.start, forKey: .fertileWindowStart)
        try container.encodeIfPresent(predictedFertileWindow?.end, forKey: .fertileWindowEnd)
        try container.encode(state, forKey: .state)
    }
}

struct FertilitySymptomRecord: Identifiable, Codable {
    let id: UUID
    var date: Date
    var symptomType: String
    var severity: Int // 1-10
    var notes: String
    var cervicalMucusQuality: String?
    var basalBodyTemp: Double?
    var ovulationTestPositive: Bool?
    var spotting: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        symptomType: String,
        severity: Int = 5,
        notes: String = "",
        cervicalMucusQuality: String? = nil,
        basalBodyTemp: Double? = nil,
        ovulationTestPositive: Bool? = nil,
        spotting: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.date = date
        self.symptomType = symptomType
        self.severity = severity
        self.notes = notes
        self.cervicalMucusQuality = cervicalMucusQuality
        self.basalBodyTemp = basalBodyTemp
        self.ovulationTestPositive = ovulationTestPositive
        self.spotting = spotting
        self.createdAt = createdAt
    }
}

struct FertilityTreatmentRecord: Identifiable, Codable {
    let id: UUID
    var treatmentType: String // e.g., "IVF", "IUI", "Clomid", "Letrozole"
    var medicationName: String
    var dosage: String
    var startDate: Date
    var endDate: Date?
    var instructions: String
    var cycleDay: Int?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        treatmentType: String = "",
        medicationName: String = "",
        dosage: String = "",
        startDate: Date = Date(),
        endDate: Date? = nil,
        instructions: String = "",
        cycleDay: Int? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.treatmentType = treatmentType
        self.medicationName = medicationName
        self.dosage = dosage
        self.startDate = startDate
        self.endDate = endDate
        self.instructions = instructions
        self.cycleDay = cycleDay
        self.createdAt = createdAt
    }
}

struct FertilityLabRecord: Identifiable, Codable {
    let id: UUID
    var testName: String
    var result: String
    var unit: String
    var referenceRange: String
    var date: Date
    var orderedBy: String
    var notes: String

    init(
        id: UUID = UUID(),
        testName: String = "",
        result: String = "",
        unit: String = "",
        referenceRange: String = "",
        date: Date = Date(),
        orderedBy: String = "",
        notes: String = ""
    ) {
        self.id = id
        self.testName = testName
        self.result = result
        self.unit = unit
        self.referenceRange = referenceRange
        self.date = date
        self.orderedBy = orderedBy
        self.notes = notes
    }
}

// MARK: - Tracker Preference

/// Determines which view occupies the third tab bar slot.
/// When `.period` or `.fertility` is chosen the Insights dashboard
/// moves into the Hub; when `.none` (the default) Insights stays in the tab bar.
enum TrackerPreference: String, Codable, CaseIterable {
    case none       // Default — show Insights in tab bar
    case period     // Show Period Tracker in tab bar
    case fertility  // Show Fertility Tracker in tab bar

    var displayName: String {
        switch self {
        case .none:      return "Insights (Default)"
        case .period:    return "Period Tracker"
        case .fertility: return "Fertility Tracker"
        }
    }
}

// MARK: - App Settings (persisted)

struct AppSettings: Codable {
    var firstUseDate: Date
    var cloudConsent: Bool
    var disclaimerAccepted: Bool
    var privacyPolicyAccepted: Bool
    var processingConsentAccepted: Bool
    var isLoggedIn: Bool
    var consentChecklistCompleted: Bool
    var authEmail: String?
    var authUserId: String?
    var authToken: String?
    var authRefreshToken: String?
    var remindersEnabled: Bool
    var hasPaid: Bool
    var pinLockEnabled: Bool
    var pinHash: String          // SHA-256 hex of the user's 4-digit PIN
    var biometricLockEnabled: Bool
    var trackerPreference: TrackerPreference
    var trackerSelectionCompleted: Bool

    static let `default` = AppSettings(
        firstUseDate: Date(),
        cloudConsent: false,
        disclaimerAccepted: false,
        privacyPolicyAccepted: false,
        processingConsentAccepted: false,
        isLoggedIn: false,
        consentChecklistCompleted: false,
        authEmail: nil,
        authUserId: nil,
        authToken: nil,
        authRefreshToken: nil,
        remindersEnabled: true,
        hasPaid: false,
        pinLockEnabled: false,
        pinHash: "",
        biometricLockEnabled: false,
        trackerPreference: .none,
        trackerSelectionCompleted: false
    )

    enum CodingKeys: String, CodingKey {
        case firstUseDate
        case cloudConsent
        case disclaimerAccepted
        case privacyPolicyAccepted
        case processingConsentAccepted
        case isLoggedIn
        case consentChecklistCompleted
        case authEmail
        case authUserId
        case authToken
        case authRefreshToken
        case remindersEnabled
        case hasPaid
        case pinLockEnabled
        case pinHash
        case biometricLockEnabled
        case trackerPreference
        case trackerSelectionCompleted
    }

    init(
        firstUseDate: Date,
        cloudConsent: Bool,
        disclaimerAccepted: Bool,
        privacyPolicyAccepted: Bool,
        processingConsentAccepted: Bool,
        isLoggedIn: Bool,
        consentChecklistCompleted: Bool,
        authEmail: String?,
        authUserId: String?,
        authToken: String?,
        authRefreshToken: String?,
        remindersEnabled: Bool,
        hasPaid: Bool,
        pinLockEnabled: Bool = false,
        pinHash: String = "",
        biometricLockEnabled: Bool = false,
        trackerPreference: TrackerPreference = .none,
        trackerSelectionCompleted: Bool = false
    ) {
        self.firstUseDate = firstUseDate
        self.cloudConsent = cloudConsent
        self.disclaimerAccepted = disclaimerAccepted
        self.privacyPolicyAccepted = privacyPolicyAccepted
        self.processingConsentAccepted = processingConsentAccepted
        self.isLoggedIn = isLoggedIn
        self.consentChecklistCompleted = consentChecklistCompleted
        self.authEmail = authEmail
        self.authUserId = authUserId
        self.authToken = authToken
        self.authRefreshToken = authRefreshToken
        self.remindersEnabled = remindersEnabled
        self.hasPaid = hasPaid
        self.pinLockEnabled = pinLockEnabled
        self.pinHash = pinHash
        self.biometricLockEnabled = biometricLockEnabled
        self.trackerPreference = trackerPreference
        self.trackerSelectionCompleted = trackerSelectionCompleted
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        firstUseDate = try container.decodeIfPresent(Date.self, forKey: .firstUseDate) ?? Date()
        cloudConsent = try container.decodeIfPresent(Bool.self, forKey: .cloudConsent) ?? false
        disclaimerAccepted = try container.decodeIfPresent(Bool.self, forKey: .disclaimerAccepted) ?? false
        privacyPolicyAccepted = try container.decodeIfPresent(Bool.self, forKey: .privacyPolicyAccepted) ?? false
        processingConsentAccepted = try container.decodeIfPresent(Bool.self, forKey: .processingConsentAccepted) ?? false
        isLoggedIn = try container.decodeIfPresent(Bool.self, forKey: .isLoggedIn) ?? false
        consentChecklistCompleted = try container.decodeIfPresent(Bool.self, forKey: .consentChecklistCompleted) ?? false
        authEmail = try container.decodeIfPresent(String.self, forKey: .authEmail)
        authUserId = try container.decodeIfPresent(String.self, forKey: .authUserId)
        authToken = try container.decodeIfPresent(String.self, forKey: .authToken)
        authRefreshToken = try container.decodeIfPresent(String.self, forKey: .authRefreshToken)
        remindersEnabled = try container.decodeIfPresent(Bool.self, forKey: .remindersEnabled) ?? true
        hasPaid = try container.decodeIfPresent(Bool.self, forKey: .hasPaid) ?? false
        pinLockEnabled = try container.decodeIfPresent(Bool.self, forKey: .pinLockEnabled) ?? false
        pinHash = try container.decodeIfPresent(String.self, forKey: .pinHash) ?? ""
        biometricLockEnabled = try container.decodeIfPresent(Bool.self, forKey: .biometricLockEnabled) ?? false
        trackerPreference = try container.decodeIfPresent(TrackerPreference.self, forKey: .trackerPreference) ?? .none
        trackerSelectionCompleted = try container.decodeIfPresent(Bool.self, forKey: .trackerSelectionCompleted) ?? false
    }
}
