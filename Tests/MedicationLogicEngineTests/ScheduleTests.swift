import XCTest
@testable import MedicationLogicEngine

final class ScheduleTests: XCTestCase {
    func testTwiceDailyGeneratesTwoEventsPerDay() {
        let generator = ScheduleGenerator()
        let plan = ParsedMedicationPlan(
            sourceText: "",
            dose: 500,
            units: "mg",
            route: .oral,
            frequency: .twiceDaily,
            durationDays: 5,
            maxPerDayDoses: 2
        )

        let schedule = generator.generate(from: plan, startDate: Date(timeIntervalSince1970: 0), days: 5)

        XCTAssertEqual(schedule.count, 5)
        XCTAssertTrue(schedule.allSatisfy { $0.events.count == 2 })
    }

    func testCycleRespectsOffDays() {
        let generator = ScheduleGenerator()
        let plan = ParsedMedicationPlan(
            sourceText: "",
            dose: 1,
            units: "tablet",
            route: .oral,
            frequency: .onceDaily,
            durationDays: 6,
            cycleRule: CycleRule(daysOn: 2, daysOff: 1)
        )

        let schedule = generator.generate(from: plan, startDate: Date(timeIntervalSince1970: 0), days: 6)
        let counts = schedule.map { $0.events.count }

        XCTAssertEqual(counts, [1, 1, 0, 1, 1, 0])
    }

    func testTaperUsesStepDose() {
        let generator = ScheduleGenerator()
        let plan = ParsedMedicationPlan(
            sourceText: "",
            dose: 20,
            units: "mg",
            route: .oral,
            frequency: .onceDaily,
            durationDays: 6,
            taperSteps: [
                TaperStep(startDay: 1, endDay: 3, dose: 20, frequency: .onceDaily),
                TaperStep(startDay: 4, endDay: 6, dose: 10, frequency: .onceDaily)
            ]
        )

        let schedule = generator.generate(from: plan, startDate: Date(timeIntervalSince1970: 0), days: 6)
        let day4Dose = schedule[3].events.first?.dose

        XCTAssertEqual(day4Dose, 10)
    }
}
