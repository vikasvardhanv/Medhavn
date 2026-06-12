import Foundation
import SQLite3

final class SQLiteStore {
    private var db: OpaquePointer?
    private let dbURL: URL

    init(filename: String = "medhavn.sqlite") {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        dbURL = docs.appendingPathComponent(filename)
    }

    func open() throws {
        if sqlite3_open(dbURL.path, &db) != SQLITE_OK {
            throw StoreError.openFailed
        }
        try migrate()
    }

    deinit {
        sqlite3_close(db)
    }

    func migrate() throws {
        try exec("""
        CREATE TABLE IF NOT EXISTS plans (
            id TEXT PRIMARY KEY,
            created_at REAL NOT NULL,
            source TEXT NOT NULL,
            source_text TEXT NOT NULL,
            parsed_json TEXT NOT NULL,
            patient_directions TEXT NOT NULL,
            rationale TEXT NOT NULL,
            needs_confirmation INTEGER NOT NULL
        );
        """)

        try exec("""
        CREATE TABLE IF NOT EXISTS dose_logs (
            id TEXT PRIMARY KEY,
            plan_id TEXT NOT NULL,
            timestamp REAL NOT NULL,
            dose REAL NOT NULL,
            units TEXT NOT NULL,
            is_prn INTEGER NOT NULL
        );
        """)

        try exec("""
        CREATE TABLE IF NOT EXISTS settings (
            key TEXT PRIMARY KEY,
            payload TEXT NOT NULL
        );
        """)

        try exec("""
        CREATE TABLE IF NOT EXISTS daily_insight_notes (
            id TEXT PRIMARY KEY,
            plan_id TEXT NOT NULL,
            day_start REAL NOT NULL,
            note_body TEXT NOT NULL,
            model_name TEXT NOT NULL,
            created_at REAL NOT NULL,
            UNIQUE(plan_id, day_start)
        );
        """)
    }

    func fetchPlans() throws -> [MedicationPlanRecord] {
        let sql = "SELECT id, created_at, source, source_text, parsed_json, patient_directions, rationale, needs_confirmation FROM plans ORDER BY created_at DESC"
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }

        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw StoreError.queryFailed
        }

        var items: [MedicationPlanRecord] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            guard
                let idText = sqliteText(stmt, 0),
                let sourceText = sqliteText(stmt, 2),
                let source = IngestionSource(rawValue: sourceText),
                let sourceSig = sqliteText(stmt, 3),
                let parsed = sqliteText(stmt, 4),
                let directions = sqliteText(stmt, 5),
                let rationale = sqliteText(stmt, 6),
                let id = UUID(uuidString: idText)
            else { continue }

            let created = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 1))
            let needsConfirmation = sqlite3_column_int(stmt, 7) == 1

            items.append(MedicationPlanRecord(
                id: id,
                createdAt: created,
                source: source,
                sourceText: sourceSig,
                parsedJSON: parsed,
                patientDirections: directions,
                rationale: rationale,
                needsConfirmation: needsConfirmation
            ))
        }

        return items
    }

    func insertPlan(_ plan: MedicationPlanRecord) throws {
        let sql = "INSERT INTO plans (id, created_at, source, source_text, parsed_json, patient_directions, rationale, needs_confirmation) VALUES (?, ?, ?, ?, ?, ?, ?, ?)"
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }

        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw StoreError.queryFailed
        }

        bindText(stmt, 1, plan.id.uuidString)
        sqlite3_bind_double(stmt, 2, plan.createdAt.timeIntervalSince1970)
        bindText(stmt, 3, plan.source.rawValue)
        bindText(stmt, 4, plan.sourceText)
        bindText(stmt, 5, plan.parsedJSON)
        bindText(stmt, 6, plan.patientDirections)
        bindText(stmt, 7, plan.rationale)
        sqlite3_bind_int(stmt, 8, plan.needsConfirmation ? 1 : 0)

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw StoreError.insertFailed
        }
    }

    func fetchDoseLogs(for planID: UUID) throws -> [DoseLogRecord] {
        let sql = "SELECT id, plan_id, timestamp, dose, units, is_prn FROM dose_logs WHERE plan_id = ? ORDER BY timestamp DESC"
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }

        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw StoreError.queryFailed
        }
        bindText(stmt, 1, planID.uuidString)

        var out: [DoseLogRecord] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            guard
                let idText = sqliteText(stmt, 0),
                let planText = sqliteText(stmt, 1),
                let units = sqliteText(stmt, 4),
                let id = UUID(uuidString: idText),
                let pID = UUID(uuidString: planText)
            else { continue }

            out.append(DoseLogRecord(
                id: id,
                planID: pID,
                timestamp: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 2)),
                dose: sqlite3_column_double(stmt, 3),
                units: units,
                isPRN: sqlite3_column_int(stmt, 5) == 1
            ))
        }
        return out
    }

    func insertDoseLog(_ log: DoseLogRecord) throws {
        let sql = "INSERT INTO dose_logs (id, plan_id, timestamp, dose, units, is_prn) VALUES (?, ?, ?, ?, ?, ?)"
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }

        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw StoreError.queryFailed
        }

        bindText(stmt, 1, log.id.uuidString)
        bindText(stmt, 2, log.planID.uuidString)
        sqlite3_bind_double(stmt, 3, log.timestamp.timeIntervalSince1970)
        sqlite3_bind_double(stmt, 4, log.dose)
        bindText(stmt, 5, log.units)
        sqlite3_bind_int(stmt, 6, log.isPRN ? 1 : 0)

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw StoreError.insertFailed
        }
    }

    func loadSettings() throws -> AppSettings {
        let sql = "SELECT payload FROM settings WHERE key = 'app'"
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }

        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw StoreError.queryFailed
        }

        if sqlite3_step(stmt) == SQLITE_ROW, let payload = sqliteText(stmt, 0), let data = payload.data(using: .utf8), let settings = try? JSONDecoder().decode(AppSettings.self, from: data) {
            return settings
        }

        let settings = AppSettings.default
        try saveSettings(settings)
        return settings
    }

    func saveSettings(_ settings: AppSettings) throws {
        let payloadData = try JSONEncoder().encode(settings)
        guard let payload = String(data: payloadData, encoding: .utf8) else {
            throw StoreError.insertFailed
        }

        let sql = "INSERT OR REPLACE INTO settings (key, payload) VALUES ('app', ?)"
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }

        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw StoreError.queryFailed
        }

        bindText(stmt, 1, payload)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw StoreError.insertFailed
        }
    }

    func upsertDailyInsightNote(_ note: DailyInsightNoteRecord) throws {
        let sql = """
        INSERT INTO daily_insight_notes (id, plan_id, day_start, note_body, model_name, created_at)
        VALUES (?, ?, ?, ?, ?, ?)
        ON CONFLICT(plan_id, day_start) DO UPDATE SET
            id = excluded.id,
            note_body = excluded.note_body,
            model_name = excluded.model_name,
            created_at = excluded.created_at
        """

        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }

        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw StoreError.queryFailed
        }

        bindText(stmt, 1, note.id.uuidString)
        bindText(stmt, 2, note.planID.uuidString)
        sqlite3_bind_double(stmt, 3, note.dayStart.timeIntervalSince1970)
        bindText(stmt, 4, note.noteBody)
        bindText(stmt, 5, note.modelName)
        sqlite3_bind_double(stmt, 6, note.createdAt.timeIntervalSince1970)

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw StoreError.insertFailed
        }
    }

    func fetchDailyInsightNote(planID: UUID, day: Date) throws -> DailyInsightNoteRecord? {
        let dayStart = Calendar.current.startOfDay(for: day)
        let sql = """
        SELECT id, plan_id, day_start, note_body, model_name, created_at
        FROM daily_insight_notes
        WHERE plan_id = ? AND day_start = ?
        LIMIT 1
        """

        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }

        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw StoreError.queryFailed
        }

        bindText(stmt, 1, planID.uuidString)
        sqlite3_bind_double(stmt, 2, dayStart.timeIntervalSince1970)

        guard sqlite3_step(stmt) == SQLITE_ROW,
              let idText = sqliteText(stmt, 0),
              let planText = sqliteText(stmt, 1),
              let noteBody = sqliteText(stmt, 3),
              let modelName = sqliteText(stmt, 4),
              let id = UUID(uuidString: idText),
              let rowPlanID = UUID(uuidString: planText) else {
            return nil
        }

        return DailyInsightNoteRecord(
            id: id,
            planID: rowPlanID,
            dayStart: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 2)),
            noteBody: noteBody,
            modelName: modelName,
            createdAt: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 5))
        )
    }

    private func exec(_ sql: String) throws {
        var err: UnsafeMutablePointer<Int8>?
        guard sqlite3_exec(db, sql, nil, nil, &err) == SQLITE_OK else {
            let message = err.flatMap { String(cString: $0) } ?? "SQL error"
            sqlite3_free(err)
            throw StoreError.sqlError(message)
        }
    }

    private func bindText(_ stmt: OpaquePointer?, _ index: Int32, _ value: String) {
        sqlite3_bind_text(stmt, index, value, -1, SQLITE_TRANSIENT)
    }

    private func sqliteText(_ stmt: OpaquePointer?, _ index: Int32) -> String? {
        guard let cString = sqlite3_column_text(stmt, index) else { return nil }
        return String(cString: cString)
    }
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

enum StoreError: Error {
    case openFailed
    case queryFailed
    case insertFailed
    case sqlError(String)
}
