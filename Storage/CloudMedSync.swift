import Foundation

/// Syncs the pill cabinet and dose ticks with `medhavn.med_cabinet_items` and
/// `medhavn.pill_dose_statuses`, so a companion app on the same Supabase
/// project (AuraPath) sees the same medicines and doses.
///
/// Local storage stays the source of truth for the UI. This type only moves
/// rows over PostgREST and computes merges; AppState applies the result.
final class CloudMedSync {
    struct Session {
        let userId: String
        var token: String
        var refreshToken: String?
    }

    struct CabinetMerge {
        var items: [MedCabinetItem]
        var toPush: [MedCabinetItem]
        var changed: Bool
    }

    struct StatusMerge {
        var statuses: [PillDoseStatusRecord]
        var toPush: [PillDoseStatusRecord]
        var changed: Bool
    }

    enum SyncError: LocalizedError {
        case http(Int, String)
        case invalidResponse

        var errorDescription: String? {
            switch self {
            case .http(let code, let body): return "HTTP \(code): \(body)"
            case .invalidResponse: return "Response was not HTTP."
            }
        }
    }

    private let baseURL: URL
    private let anonKey: String
    /// Called after a token refresh so AppState can persist the new tokens.
    /// May run off the main thread.
    var onSessionRefreshed: ((Session) -> Void)?

    init?() {
        let env = ProcessInfo.processInfo.environment
        func value(_ key: String) -> String? {
            let raw = env[key] ?? (Bundle.main.object(forInfoDictionaryKey: key) as? String)
            let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return trimmed.isEmpty || trimmed.hasPrefix("$(") ? nil : trimmed
        }
        guard let urlText = value("SUPABASE_URL"), let key = value("SUPABASE_ANON_KEY"),
              var components = URLComponents(string: urlText) else {
            appLog("Cloud med sync disabled: SUPABASE_URL / SUPABASE_ANON_KEY missing", level: .warning, category: "CloudSync")
            return nil
        }
        components.path = ""
        components.query = nil
        guard let url = components.url else { return nil }
        baseURL = url
        anonKey = key
    }

    // MARK: - Push

    func push(items: [MedCabinetItem], session: Session) async throws {
        guard !items.isEmpty else { return }
        _ = try await send(method: "POST", table: "med_cabinet_items",
                           query: [URLQueryItem(name: "on_conflict", value: "id")],
                           body: items.map { Self.row(from: $0, userId: session.userId) },
                           prefer: "resolution=merge-duplicates,return=minimal", session: session)
    }

    func push(statuses: [PillDoseStatusRecord], session: Session) async throws {
        guard !statuses.isEmpty else { return }
        let rows: [[String: Any]] = statuses.map {
            ["user_id": session.userId, "key": $0.key, "status": $0.status.rawValue,
             "updated_at": Self.iso.string(from: $0.updatedAt)]
        }
        _ = try await send(method: "POST", table: "pill_dose_statuses",
                           query: [URLQueryItem(name: "on_conflict", value: "user_id,key")],
                           body: rows, prefer: "resolution=merge-duplicates,return=minimal", session: session)
    }

    /// Deletes the cabinet row and its dose rows (local removal drops both too).
    func delete(itemID: UUID, session: Session) async throws {
        _ = try await send(method: "DELETE", table: "pill_dose_statuses",
                           query: [URLQueryItem(name: "user_id", value: "eq.\(session.userId)"),
                                   URLQueryItem(name: "key", value: "like.\(itemID.uuidString)|*")],
                           body: nil, prefer: "return=minimal", session: session)
        _ = try await send(method: "DELETE", table: "med_cabinet_items",
                           query: [URLQueryItem(name: "id", value: "eq.\(itemID.uuidString)")],
                           body: nil, prefer: "return=minimal", session: session)
    }

    // MARK: - Pull

    func pull(session: Session) async throws -> (items: [CabinetRow], statuses: [StatusRow]) {
        let owner = URLQueryItem(name: "user_id", value: "eq.\(session.userId)")
        let itemData = try await send(method: "GET", table: "med_cabinet_items",
                                      query: [owner, URLQueryItem(name: "select", value: "*")],
                                      body: nil, prefer: nil, session: session)
        let statusData = try await send(method: "GET", table: "pill_dose_statuses",
                                        query: [owner, URLQueryItem(name: "select", value: "key,status,updated_at")],
                                        body: nil, prefer: nil, session: session)
        let decoder = JSONDecoder()
        return (try decoder.decode([CabinetRow].self, from: itemData),
                try decoder.decode([StatusRow].self, from: statusData))
    }

    // MARK: - Merge rules (pure)

    /// Cabinet: server rows unknown locally are added (assigned to `profileID`).
    /// For known rows only `remaining_pills` merges: the lower value wins,
    /// because the companion app decrements it on the server. Local rows are
    /// never removed. `toPush` holds local rows the server lacks or holds higher.
    static func mergeCabinet(local: [MedCabinetItem], remote: [CabinetRow], profileID: UUID, syncedProfileID: UUID) -> CabinetMerge {
        var items = local
        var changed = false
        var remoteByID: [UUID: CabinetRow] = [:]
        for row in remote {
            guard let id = UUID(uuidString: row.id) else { continue }
            remoteByID[id] = row
            if let index = items.firstIndex(where: { $0.id == id }) {
                if row.remaining_pills < items[index].remainingPills {
                    items[index].remainingPills = row.remaining_pills
                    changed = true
                }
            } else {
                items.append(row.toItem(id: id, profileID: profileID))
                changed = true
            }
        }
        let toPush = items.filter { item in
            guard item.profileID == syncedProfileID else { return false }
            guard let row = remoteByID[item.id] else { return true }
            return item.remainingPills < row.remaining_pills
        }
        return CabinetMerge(items: items, toPush: toPush, changed: changed)
    }

    /// Statuses: the newer `updated_at` wins (1 s tolerance for timestamp
    /// rounding). Exception: a server `taken` beats a local `skipped`, because
    /// Medhavn writes `skipped` automatically for expired blocks before it has
    /// pulled, and that synthetic skip must not hide a real dose. Local rows are
    /// never removed. `toPush` holds local rows the server lacks or holds older,
    /// limited to keys of `syncedItemIDs`.
    static func mergeStatuses(local: [PillDoseStatusRecord], remote: [StatusRow], syncedItemIDs: Set<UUID>) -> StatusMerge {
        var statuses = local
        var changed = false
        var remoteByKey: [String: (status: DoseStatusKind, date: Date)] = [:]
        for row in remote {
            guard let status = DoseStatusKind(rawValue: row.status), let date = parseDate(row.updated_at) else { continue }
            remoteByKey[row.key] = (status, date)
            if let index = statuses.firstIndex(where: { $0.key == row.key }) {
                let localRecord = statuses[index]
                let remoteNewer = date.timeIntervalSince(localRecord.updatedAt) > 1
                let takenBeatsSkip = status == .taken && localRecord.status == .skipped
                if remoteNewer || takenBeatsSkip {
                    statuses[index].status = status
                    statuses[index].updatedAt = max(date, localRecord.updatedAt)
                    changed = true
                }
            } else {
                statuses.append(PillDoseStatusRecord(id: UUID(), key: row.key, status: status, updatedAt: date))
                changed = true
            }
        }
        let syncedPrefixes = Set(syncedItemIDs.map { "\($0.uuidString)|" })
        let toPush = statuses.filter { record in
            guard let bar = record.key.firstIndex(of: "|"),
                  syncedPrefixes.contains(String(record.key[...bar])) else { return false }
            guard let remoteRecord = remoteByKey[record.key] else { return true }
            if remoteRecord.status == .taken && record.status == .skipped { return false }
            return record.status != remoteRecord.status && record.updatedAt.timeIntervalSince(remoteRecord.date) > 1
        }
        return StatusMerge(statuses: statuses, toPush: toPush, changed: changed)
    }

    // MARK: - Rows

    struct StatusRow: Decodable {
        let key: String
        let status: String
        let updated_at: String
    }

    struct CabinetRow: Decodable {
        let id: String
        let name: String
        let dosage_text: String
        let schedule_blocks: String
        let remaining_pills: Int
        let refill_threshold: Int?
        let pill_shape: String?
        let pill_color_hex: String?
        let contraindication_tags: String?
        let created_at: String?
        let frequency: String?
        let scheduled_times: String?
        let schedule_start_date: String?
        let schedule_end_date: String?
        let specific_days: String?
        let interval_days: Int?
        let rx_number: String?
        let pills_left: Int?
        let refill_reminder_enabled: Bool?

        func toItem(id: UUID, profileID: UUID) -> MedCabinetItem {
            MedCabinetItem(
                id: id,
                profileID: profileID,
                name: name,
                dosageText: dosage_text,
                scheduleBlocks: (CloudMedSync.decodeJSON([String].self, schedule_blocks) ?? []).compactMap(DayTimeBlock.init(rawValue:)),
                remainingPills: remaining_pills,
                refillThreshold: refill_threshold ?? 5,
                pillShape: pill_shape.flatMap(PillShapeStyle.init(rawValue:)) ?? .capsule,
                pillColorHex: pill_color_hex ?? "#2F80ED",
                contraindicationTags: CloudMedSync.decodeJSON([String].self, contraindication_tags) ?? [],
                createdAt: created_at.flatMap(CloudMedSync.parseDate) ?? Date(),
                frequency: CloudMedSync.frequency(from: frequency),
                scheduledTimes: CloudMedSync.decodeJSON([ScheduledTime].self, scheduled_times) ?? [],
                scheduleStartDate: schedule_start_date.flatMap(CloudMedSync.parseDate),
                scheduleEndDate: schedule_end_date.flatMap(CloudMedSync.parseDate),
                specificDays: CloudMedSync.decodeJSON([Int].self, specific_days) ?? [],
                intervalDays: interval_days ?? 1,
                refill: PrescriptionRefill(rxNumber: rx_number ?? "", pillsLeft: pills_left ?? 0,
                                           refillReminderEnabled: refill_reminder_enabled ?? false)
            )
        }
    }

    /// JSON array columns are TEXT in the schema, so they travel as JSON strings.
    /// `profileID` stays local-only (no column).
    static func row(from item: MedCabinetItem, userId: String) -> [String: Any] {
        [
            "id": item.id.uuidString,
            "user_id": userId,
            "name": item.name,
            "dosage_text": item.dosageText,
            "schedule_blocks": encodeJSON(item.scheduleBlocks.map(\.rawValue)),
            "remaining_pills": item.remainingPills,
            "refill_threshold": item.refillThreshold,
            "pill_shape": item.pillShape.rawValue,
            "pill_color_hex": item.pillColorHex,
            "contraindication_tags": encodeJSON(item.contraindicationTags),
            "created_at": iso.string(from: item.createdAt),
            "frequency": frequencyColumn(item.frequency),
            "scheduled_times": encodeJSON(item.scheduledTimes),
            "schedule_start_date": item.scheduleStartDate.map { iso.string(from: $0) } ?? NSNull(),
            "schedule_end_date": item.scheduleEndDate.map { iso.string(from: $0) } ?? NSNull(),
            "specific_days": encodeJSON(item.specificDays),
            "interval_days": item.intervalDays,
            "rx_number": item.refill.rxNumber,
            "pills_left": item.refill.pillsLeft,
            "refill_reminder_enabled": item.refill.refillReminderEnabled
        ]
    }

    /// The schema default is the case name (`everyDay`), not the display raw value.
    static func frequencyColumn(_ frequency: MedFrequency) -> String {
        switch frequency {
        case .asNeeded: return "asNeeded"
        case .everyDay: return "everyDay"
        case .specificDays: return "specificDays"
        case .daysInterval: return "daysInterval"
        }
    }

    static func frequency(from column: String?) -> MedFrequency {
        guard let column else { return .everyDay }
        return MedFrequency.allCases.first { frequencyColumn($0) == column || $0.rawValue == column } ?? .everyDay
    }

    // MARK: - Helpers

    static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let isoPlain = ISO8601DateFormatter()

    /// Postgres returns microseconds and `+00:00`; trim the fraction to 3 digits.
    static func parseDate(_ text: String) -> Date? {
        if let d = iso.date(from: text) ?? isoPlain.date(from: text) { return d }
        let trimmed = text.replacingOccurrences(of: #"(\.\d{3})\d+"#, with: "$1", options: .regularExpression)
        return iso.date(from: trimmed) ?? isoPlain.date(from: trimmed.replacingOccurrences(of: #"\.\d+"#, with: "", options: .regularExpression))
    }

    private static func encodeJSON<T: Encodable>(_ value: T) -> String {
        guard let data = try? JSONEncoder().encode(value), let text = String(data: data, encoding: .utf8) else {
            appLog("Cloud sync could not encode \(T.self) as JSON", level: .error, category: "CloudSync")
            return "[]"
        }
        return text
    }

    static func decodeJSON<T: Decodable>(_ type: T.Type, _ text: String?) -> T? {
        guard let text, let data = text.data(using: .utf8) else { return nil }
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            appLog("Cloud sync could not decode \(T.self) from '\(text)': \(error)", level: .warning, category: "CloudSync")
            return nil
        }
    }

    // MARK: - Transport

    private func send(method: String, table: String, query: [URLQueryItem], body: Any?, prefer: String?, session: Session) async throws -> Data {
        var current = session
        for attempt in 0..<2 {
            var components = URLComponents(url: baseURL.appending(path: "rest/v1/\(table)"), resolvingAgainstBaseURL: false)!
            components.queryItems = query
            var request = URLRequest(url: components.url!)
            request.httpMethod = method
            request.setValue(anonKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(current.token)", forHTTPHeaderField: "Authorization")
            request.setValue("medhavn", forHTTPHeaderField: "Accept-Profile")
            request.setValue("medhavn", forHTTPHeaderField: "Content-Profile")
            if let prefer { request.setValue(prefer, forHTTPHeaderField: "Prefer") }
            if let body {
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
            }

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw SyncError.invalidResponse }
            if (200..<300).contains(http.statusCode) { return data }
            if http.statusCode == 401, attempt == 0, let refreshed = try await refresh(current) {
                current = refreshed
                continue
            }
            throw SyncError.http(http.statusCode, String(data: data, encoding: .utf8) ?? "<binary>")
        }
        throw SyncError.invalidResponse
    }

    /// Exchanges the refresh token for a new access token (Supabase tokens expire after ~1 h).
    private func refresh(_ session: Session) async throws -> Session? {
        guard let refreshToken = session.refreshToken, !refreshToken.isEmpty else { return nil }
        var components = URLComponents(url: baseURL.appending(path: "auth/v1/token"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "grant_type", value: "refresh_token")]
        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["refresh_token": refreshToken])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let token = json["access_token"] as? String else {
            appLog("Cloud sync token refresh failed (HTTP \((response as? HTTPURLResponse)?.statusCode ?? -1))", level: .error, category: "CloudSync")
            return nil
        }
        let refreshed = Session(userId: session.userId, token: token, refreshToken: json["refresh_token"] as? String ?? refreshToken)
        appLog("Cloud sync refreshed access token", level: .info, category: "CloudSync")
        onSessionRefreshed?(refreshed)
        return refreshed
    }
}
