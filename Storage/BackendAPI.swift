import Foundation

/// Client for the Medhavn backend service (signup OTP and transactional email).
/// The base URL comes from BACKEND_URL (Info.plist or environment).
struct BackendAPI {
    enum BackendError: LocalizedError {
        case unauthorized
        case rateLimited
        case server(Int)

        var errorDescription: String? {
            switch self {
            case .unauthorized: return "Backend rejected the session token."
            case .rateLimited: return "Too many requests. Try again later."
            case .server(let code): return "Backend returned HTTP \(code)."
            }
        }
    }

    let baseURL: URL
    private let session: URLSession

    init?(session: URLSession = .shared) {
        let env = ProcessInfo.processInfo.environment
        let raw = env["BACKEND_URL"] ?? (Bundle.main.object(forInfoDictionaryKey: "BACKEND_URL") as? String)
        let text = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !text.isEmpty, !text.hasPrefix("$("), let url = URL(string: text) else {
            appLog("Backend disabled: BACKEND_URL missing", level: .warning, category: "Backend")
            return nil
        }
        baseURL = url
        self.session = session
    }

    // MARK: - Signup OTP (no account yet, so no token)

    func sendOTP(email: String) async throws {
        _ = try await post("v1/otp/send", body: ["email": email], token: nil, accept: [200])
    }

    /// True when the code matches. A wrong or expired code is `false`, not an error.
    func verifyOTP(email: String, code: String) async throws -> Bool {
        let status = try await post("v1/otp/verify", body: ["email": email, "code": code], token: nil, accept: [200, 400])
        return status == 200
    }

    // MARK: - Signed-in email

    func sendSafeCircleInvite(name: String, email: String, token: String) async throws {
        _ = try await post("v1/email/safecircle-invite", body: ["name": name, "email": email], token: token, accept: [200])
    }

    // MARK: - Referrals

    struct ReferralSummary: Decodable {
        let code: String
        let appStoreUrl: String
        let signedUpCount: Int
    }

    private struct InviteResponse: Decodable { let code: String }
    private struct ClaimResponse: Decodable { let claimed: Bool }

    func fetchReferrals(token: String) async throws -> ReferralSummary {
        let (_, data) = try await request("GET", "v1/referrals", body: nil, token: token, accept: [200])
        return try JSONDecoder().decode(ReferralSummary.self, from: data)
    }

    /// Stores the invite and emails it. `relationship` is what the invitee is to the user.
    func sendReferral(email: String, relationship: String, token: String) async throws {
        _ = try await request("POST", "v1/referrals", body: ["email": email, "relationship": relationship], token: token, accept: [200])
    }

    /// Links this new account to whoever invited it. Matches by email, or by `code` when given.
    func claimReferral(code: String?, token: String) async throws -> Bool {
        var body: [String: Any] = [:]
        if let code, !code.isEmpty { body["code"] = code }
        let (_, data) = try await request("POST", "v1/referrals/claim", body: body, token: token, accept: [200])
        return (try? JSONDecoder().decode(ClaimResponse.self, from: data))?.claimed ?? false
    }

    // MARK: - Transport

    private func post(_ path: String, body: [String: Any], token: String?, accept: Set<Int>) async throws -> Int {
        try await request("POST", path, body: body, token: token, accept: accept).status
    }

    func request(_ method: String, _ path: String, body: [String: Any]?, token: String?, accept: Set<Int>) async throws -> (status: Int, data: Data) {
        // appending(path:) would percent-encode a "?", so split off the query first.
        let parts = path.split(separator: "?", maxSplits: 1).map(String.init)
        var components = URLComponents(url: baseURL.appending(path: parts[0]), resolvingAgainstBaseURL: false)!
        if parts.count > 1 { components.query = parts[1] }
        var request = URLRequest(url: components.url!)
        request.httpMethod = method
        request.timeoutInterval = 30
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if accept.contains(status) { return (status, data) }
        if status == 401 { throw BackendError.unauthorized }
        if status == 429 { throw BackendError.rateLimited }
        throw BackendError.server(status)
    }
}
