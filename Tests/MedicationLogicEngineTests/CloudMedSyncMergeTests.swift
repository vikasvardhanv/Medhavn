// Runs only in the Xcode MedhavnUnitTests target; the SwiftPM test target has no app module.
#if canImport(Medhavn)
import XCTest
@testable import Medhavn

final class CloudMedSyncMergeTests: XCTestCase {
    private let owner = UUID()

    private func row(_ id: UUID, remaining: Int) -> CloudMedSync.CabinetRow {
        CloudMedSync.CabinetRow(
            id: id.uuidString.lowercased(), name: "Metformin", dosage_text: "500 mg",
            schedule_blocks: #"["morning","evening"]"#, remaining_pills: remaining,
            refill_threshold: 5, pill_shape: "round", pill_color_hex: "#FFFFFF",
            contraindication_tags: "[]", created_at: "2026-10-27T08:00:00.123456+00:00",
            frequency: "everyDay", scheduled_times: "[]", schedule_start_date: nil,
            schedule_end_date: nil, specific_days: "[]", interval_days: 1,
            rx_number: "", pills_left: 0, refill_reminder_enabled: false)
    }

    func testCabinetAddsUnknownTakesLowerRemainingAndNeverDeletes() {
        let known = MedCabinetItem(profileID: owner, name: "Aspirin", dosageText: "81 mg", scheduleBlocks: [.morning], remainingPills: 20)
        let localOnly = MedCabinetItem(profileID: owner, name: "Vit D", dosageText: "1", scheduleBlocks: [.night], remainingPills: 10)
        let remoteOnly = UUID()

        let merge = CloudMedSync.mergeCabinet(
            local: [known, localOnly],
            remote: [row(known.id, remaining: 19), row(remoteOnly, remaining: 30)],
            profileID: owner, syncedProfileID: owner)

        XCTAssertEqual(merge.items.count, 3)
        XCTAssertEqual(merge.items.first { $0.id == known.id }?.remainingPills, 19)
        let added = merge.items.first { $0.id == remoteOnly }
        XCTAssertEqual(added?.scheduleBlocks, [.morning, .evening])
        XCTAssertEqual(added?.pillShape, .round)
        XCTAssertEqual(added?.profileID, owner)
        XCTAssertEqual(merge.toPush.map(\.id), [localOnly.id])

        // Server higher than local: local stays, and local is re-uploaded.
        let higher = CloudMedSync.mergeCabinet(local: [known], remote: [row(known.id, remaining: 25)], profileID: owner, syncedProfileID: owner)
        XCTAssertEqual(higher.items.first?.remainingPills, 20)
        XCTAssertEqual(higher.toPush.map(\.id), [known.id])

        // Empty server never deletes local data; everything is backfilled.
        let empty = CloudMedSync.mergeCabinet(local: [known, localOnly], remote: [], profileID: owner, syncedProfileID: owner)
        XCTAssertEqual(empty.items.count, 2)
        XCTAssertEqual(empty.toPush.count, 2)
        XCTAssertFalse(empty.changed)
    }

    func testStatusesNewerWinsTakenBeatsAutoSkip() {
        let item = UUID()
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        func key(_ block: String) -> String { "\(item.uuidString)|2026-10-28|\(block)" }
        func iso(_ d: Date) -> String { CloudMedSync.iso.string(from: d) }

        let local = [
            PillDoseStatusRecord(id: UUID(), key: key("morning"), status: .skipped, updatedAt: base.addingTimeInterval(3600)),
            PillDoseStatusRecord(id: UUID(), key: key("afternoon"), status: .pending, updatedAt: base),
            PillDoseStatusRecord(id: UUID(), key: key("evening"), status: .taken, updatedAt: base.addingTimeInterval(60)),
            PillDoseStatusRecord(id: UUID(), key: key("night"), status: .taken, updatedAt: base),
            PillDoseStatusRecord(id: UUID(), key: "\(UUID().uuidString)|2026-10-28|night", status: .taken, updatedAt: base)
        ]
        let remote = [
            CloudMedSync.StatusRow(key: key("morning"), status: "taken", updated_at: iso(base)),       // older taken vs newer auto-skip
            CloudMedSync.StatusRow(key: key("afternoon"), status: "taken", updated_at: iso(base.addingTimeInterval(120))), // newer
            CloudMedSync.StatusRow(key: key("evening"), status: "pending", updated_at: iso(base)),     // older: local wins
            CloudMedSync.StatusRow(key: "\(item.uuidString)|2026-10-27|night", status: "taken", updated_at: iso(base))
        ]

        let merge = CloudMedSync.mergeStatuses(local: local, remote: remote, syncedItemIDs: [item])
        let byKey = Dictionary(uniqueKeysWithValues: merge.statuses.map { ($0.key, $0.status) })

        XCTAssertEqual(byKey[key("morning")], .taken)
        XCTAssertEqual(byKey[key("afternoon")], .taken)
        XCTAssertEqual(byKey[key("evening")], .taken)
        XCTAssertEqual(byKey["\(item.uuidString)|2026-10-27|night"], .taken)
        XCTAssertEqual(merge.statuses.count, 6)
        // Uploads: local-newer evening + server-missing night; never the unsynced item's key.
        XCTAssertEqual(Set(merge.toPush.map(\.key)), [key("evening"), key("night")])
    }

    func testParsesPostgresMicrosecondTimestamps() {
        XCTAssertNotNil(CloudMedSync.parseDate("2026-10-28T12:34:56.123456+00:00"))
        XCTAssertNotNil(CloudMedSync.parseDate("2026-10-28T12:34:56+00:00"))
        XCTAssertEqual(CloudMedSync.frequency(from: "specificDays"), .specificDays)
        XCTAssertEqual(CloudMedSync.frequencyColumn(.everyDay), "everyDay")
    }
}
#endif
