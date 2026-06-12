import Foundation

public protocol MedicationParser: Sendable {
    func parse(text: String) -> ParsedMedicationPlan
}

public protocol MedicationRulesChecking: Sendable {
    func evaluate(_ plan: ParsedMedicationPlan) -> [SafetyFlag]
}

public protocol MedicationScheduleGenerating: Sendable {
    func generate(from plan: ParsedMedicationPlan, startDate: Date, days: Int) -> [DailyPlan]
}

public protocol MedicationExplaining: Sendable {
    func patientDirections(for plan: ParsedMedicationPlan) -> String
    func rationale(for plan: ParsedMedicationPlan, schedule: [DailyPlan]) -> String
}

public struct MedicationLogicEngine: Sendable {
    private let parser: MedicationParser
    private let rulesEngine: MedicationRulesChecking
    private let scheduleGenerator: MedicationScheduleGenerating
    private let constraintChecker: ConstraintChecker
    private let explainer: MedicationExplaining

    public init(
        parser: MedicationParser = SigTextParser(),
        rulesEngine: MedicationRulesChecking = RulesEngine(),
        scheduleGenerator: MedicationScheduleGenerating = ScheduleGenerator(),
        constraintChecker: ConstraintChecker = ConstraintChecker(),
        explainer: MedicationExplaining = ExplanationGenerator()
    ) {
        self.parser = parser
        self.rulesEngine = rulesEngine
        self.scheduleGenerator = scheduleGenerator
        self.constraintChecker = constraintChecker
        self.explainer = explainer
    }

    public func process(text: String, startDate: Date = Date(), projectionDays: Int = 30) -> EngineOutput {
        var parsed = parser.parse(text: text)
        let safetyFromRules = rulesEngine.evaluate(parsed)
        let generated = scheduleGenerator.generate(from: parsed, startDate: startDate, days: projectionDays)
        let constraintFlags = constraintChecker.validate(plan: parsed, schedule: generated)
        let allFlags = safetyFromRules + constraintFlags

        if allFlags.contains(where: { $0.severity == .critical }) {
            parsed.needsClinicianConfirmation = true
        }

        let directions = explainer.patientDirections(for: parsed)
        let rationale = explainer.rationale(for: parsed, schedule: generated)

        return EngineOutput(
            parsed: parsed,
            flags: allFlags,
            schedule: generated,
            patientDirections: directions,
            rationale: rationale
        )
    }
}
