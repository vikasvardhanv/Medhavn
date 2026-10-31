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

    func sendReferral(email: String, code: String, token: String) async throws {
        _ = try await post("v1/email/referral", body: ["email": email, "code": code], token: token, accept: [200])
    }

    // MARK: - Transport

    private func post(_ path: String, body: [String: Any], token: String?, accept: Set<Int>) async throws -> Int {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if accept.contains(status) { return status }
        if status == 401 { throw BackendError.unauthorized }
        if status == 429 { throw BackendError.rateLimited }
        throw BackendError.server(status)
    }
}
