import XCTest
@testable import MedicationLogicEngine

final class ParserTests: XCTestCase {
    func testParsesBasicBIDSig() {
        let parser = SigTextParser()
        let text = "Metformin 500 mg by mouth twice daily for 10 days with food"

        let plan = parser.parse(text: text)

        XCTAssertEqual(plan.drugName, "Metformin")
        XCTAssertEqual(plan.dose, 500)
        XCTAssertEqual(plan.units, "mg")
        XCTAssertEqual(plan.route, .oral)
        XCTAssertEqual(plan.frequency, .twiceDaily)
        XCTAssertEqual(plan.durationDays, 10)
        XCTAssertTrue(plan.specialConstraints.contains(.withFood))
    }

    func testParsesPRNAndMaxes() {
        let parser = SigTextParser()
        let text = "Ibuprofen 400 mg by mouth every 8 hours as needed for pain max 3 doses per day max 1200 mg in 24 hours"

        let plan = parser.parse(text: text)

        XCTAssertEqual(plan.frequency, .everyHours(8))
        XCTAssertEqual(plan.prnRule?.maxPerDayDoses, 3)
        XCTAssertEqual(plan.prnRule?.maxPer24HoursAmount, 1200)
        XCTAssertFalse(plan.needsClinicianConfirmation)
    }

    func testFlagsAmbiguousAbbreviation() {
        let parser = SigTextParser()
        let text = "Insulin 5 U qd"

        let plan = parser.parse(text: text)

        XCTAssertTrue(plan.needsClinicianConfirmation)
        XCTAssertFalse(plan.ambiguityQuestions.isEmpty)
    }
}
