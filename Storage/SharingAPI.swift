import Foundation

// MARK: - Models

struct SharingPerson: Decodable, Hashable {
    let id: String
    let name: String
    let email: String
}

struct ConnectionItem: Decodable, Identifiable {
    let id: String
    let status: String        // pending | accepted | declined
    let direction: String     // outgoing | incoming
    let relationship: String  // what the other person is to me
    let other: SharingPerson
}

struct ShareItem: Decodable, Identifiable {
    let id: String
    let status: String        // pending | active | declined
    let scopes: [String]
    let initiatedByMe: Bool
    let other: SharingPerson
}

struct SharesResponse: Decodable {
    let owned: [ShareItem]
    let viewing: [ShareItem]
}

struct AdherenceDay: Decodable, Identifiable {
    let date: String
    let taken: Int
    let missed: Int
    var id: String { date }
}

struct AdherenceReport: Decodable {
    let periodDays: Int
    let taken: Int
    let missed: Int
    let rate: Int?
    let byDay: [AdherenceDay]
}

struct SharedMedication: Decodable, Identifiable {
    let id: String
    let name: String
    let dosage_text: String
    let remaining_pills: Int
}

enum ShareScope: String, CaseIterable, Identifiable {
    case alerts, adherence, medications
    var id: String { rawValue }

    var title: String {
        switch self {
        case .alerts: return "Missed-dose alerts"
        case .adherence: return "Adherence summary"
        case .medications: return "Medications"
        }
    }

    var detail: String {
        switch self {
        case .alerts: return "Email when a dose is missed. No medicine names."
        case .adherence: return "How many doses were taken or missed. No medicine names."
        case .medications: return "Medicine names, doses and schedules. Also adds names to alerts."
        }
    }
}

enum ConnectResult { case sent, notAUser, alreadyConnected }

// MARK: - Calls

extension BackendAPI {
    private struct StatusBody: Decodable { let status: String? }

    func connections(token: String) async throws -> [ConnectionItem] {
        struct Wrapper: Decodable { let connections: [ConnectionItem] }
        let (_, data) = try await request("GET", "v1/connections", body: nil, token: token, accept: [200])
        return try JSONDecoder().decode(Wrapper.self, from: data).connections
    }

    func connect(email: String, relationship: String, token: String) async throws -> ConnectResult {
        let (status, _) = try await request("POST", "v1/connections", body: ["email": email, "relationship": relationship],
                                            token: token, accept: [200, 404, 409])
        switch status {
        case 200: return .sent
        case 404: return .notAUser
        default: return .alreadyConnected
        }
    }

    func respondToConnection(id: String, accept: Bool, token: String) async throws {
        _ = try await request("POST", "v1/connections/\(id)/respond", body: ["accept": accept], token: token, accept: [200])
    }

    func removeConnection(id: String, token: String) async throws {
        _ = try await request("DELETE", "v1/connections/\(id)", body: nil, token: token, accept: [200])
    }

    func shares(token: String) async throws -> SharesResponse {
        let (_, data) = try await request("GET", "v1/shares", body: nil, token: token, accept: [200])
        return try JSONDecoder().decode(SharesResponse.self, from: data)
    }

    /// `direction`: "offer" shares my data, "request" asks to see theirs.
    func proposeShare(connectionId: String, direction: String, scopes: [String], token: String) async throws {
        _ = try await request("POST", "v1/shares", body: ["connectionId": connectionId, "direction": direction, "scopes": scopes],
                              token: token, accept: [200])
    }

    func respondToShare(id: String, accept: Bool, scopes: [String]?, token: String) async throws {
        var body: [String: Any] = ["accept": accept]
        if let scopes { body["scopes"] = scopes }
        _ = try await request("POST", "v1/shares/\(id)/respond", body: body, token: token, accept: [200])
    }

    func updateShare(id: String, scopes: [String], token: String) async throws {
        _ = try await request("PATCH", "v1/shares/\(id)", body: ["scopes": scopes], token: token, accept: [200])
    }

    func revokeShare(id: String, token: String) async throws {
        _ = try await request("DELETE", "v1/shares/\(id)", body: nil, token: token, accept: [200])
    }

    func adherence(shareId: String, days: Int = 7, token: String) async throws -> AdherenceReport {
        let (_, data) = try await request("GET", "v1/shares/\(shareId)/adherence?days=\(days)", body: nil, token: token, accept: [200])
        return try JSONDecoder().decode(AdherenceReport.self, from: data)
    }

    func sharedMedications(shareId: String, token: String) async throws -> [SharedMedication] {
        struct Wrapper: Decodable { let medications: [SharedMedication] }
        let (_, data) = try await request("GET", "v1/shares/\(shareId)/medications", body: nil, token: token, accept: [200])
        return try JSONDecoder().decode(Wrapper.self, from: data).medications
    }
}
