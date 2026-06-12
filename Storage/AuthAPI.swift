import Foundation

struct AuthSession: Sendable {
    let userId: String
    let email: String
    let token: String
    let refreshToken: String?
}

enum AuthError: LocalizedError {
    case invalidInput(String)
    case server(String)
    case invalidResponse
    case missingConfiguration
    case emailVerificationRequired(email: String)

    var errorDescription: String? {
        switch self {
        case .invalidInput(let message): return message
        case .server(let message): return message
        case .invalidResponse: return "Invalid authentication server response."
        case .missingConfiguration:
            return "Authentication is not configured. Set SUPABASE_URL and SUPABASE_ANON_KEY in Info.plist build settings or environment variables."
        case .emailVerificationRequired:
            return "A confirmation email has been sent. Please check your inbox and click the link to activate your account."
        }
    }
}

protocol AuthServicing: Sendable {
    func signup(email: String, password: String, fullName: String) async throws -> AuthSession
    func login(email: String, password: String) async throws -> AuthSession
    func requestPasswordReset(email: String) async throws
}

struct AuthAPI: AuthServicing {
    private let client: AuthServicing

    init() {
        if let config = AuthConfiguration.supabase {
            self.client = SupabaseAuthAPI(config: config)
            appLog("Using Supabase auth → \(config.baseURL.absoluteString)", level: .info, category: "Auth")
            return
        }

        if let legacyBaseURL = AuthConfiguration.legacyBaseURL {
            self.client = LegacyAuthAPI(baseURL: legacyBaseURL)
            appLog("Using legacy auth → \(legacyBaseURL.absoluteString)", level: .info, category: "Auth")
            return
        }

        self.client = LocalDevAuthAPI()
        appLog("No remote auth endpoint configured — using LocalDevAuthAPI fallback", level: .warning, category: "Auth")
    }

    func signup(email: String, password: String, fullName: String) async throws -> AuthSession {
        try await client.signup(email: email, password: password, fullName: fullName)
    }

    func login(email: String, password: String) async throws -> AuthSession {
        try await client.login(email: email, password: password)
    }

    func requestPasswordReset(email: String) async throws {
        try await client.requestPasswordReset(email: email)
    }
}

private enum AuthConfiguration {
    static var supabase: SupabaseConfig? {
        guard
            let urlText = value(forKeys: [
                "SUPABASE_URL",
                "INFOPLIST_KEY_SUPABASE_URL",
                "SERVICE_SUPABASE_URL",
                "SERVICE_URL_SUPABASEKONG",
                "SERVICE_URL_SUPABASEKONG_8000"
            ]),
            let key = value(forKeys: [
                "SUPABASE_ANON_KEY",
                "INFOPLIST_KEY_SUPABASE_ANON_KEY",
                "SERVICE_SUPABASEANON_KEY",
                "ANON_KEY"
            ])
        else {
            appLog("Supabase config keys not found in environment or Info.plist", level: .warning, category: "Auth")
            return nil
        }

        let trimmedURL = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedURL.isEmpty, !trimmedKey.isEmpty, let rawURL = URL(string: trimmedURL) else {
            appLog("Supabase URL or anon key is empty/invalid (url='\(urlText)')", level: .error, category: "Auth")
            return nil
        }
        let url = normalizedSupabaseBaseURL(rawURL)
        appLog("Normalized Supabase base URL: \(url.absoluteString)", level: .info, category: "Auth")
        return SupabaseConfig(baseURL: url, anonKey: trimmedKey)
    }

    static var legacyBaseURL: URL? {
        guard let configured = value(forKeys: ["AUTH_API_BASE_URL"]) else {
            return nil
        }

        let trimmed = configured.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        return URL(string: trimmed)
    }

    private static func value(forKeys keys: [String]) -> String? {
        let env = ProcessInfo.processInfo.environment

        for key in keys {
            if let value = env[key]?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty {
                return value
            }

            if let value = Bundle.main.object(forInfoDictionaryKey: key) as? String {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    return trimmed
                }
            }
        }

        return nil
    }

    private static func normalizedSupabaseBaseURL(_ url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }
        components.path = ""
        components.query = nil
        components.fragment = nil
        return components.url ?? url
    }
}

private struct SupabaseConfig: Sendable {
    let baseURL: URL
    let anonKey: String
}

private struct LocalDevAuthAPI: AuthServicing {
    func signup(email: String, password: String, fullName: String) async throws -> AuthSession {
        guard !email.isEmpty, !password.isEmpty else {
            appLog("Signup validation failed: empty email or password", level: .warning, category: "Auth")
            throw AuthError.invalidInput("Email and password are required.")
        }
        appLog("LocalDev signup for \(email)", level: .debug, category: "Auth")
        return AuthSession(userId: UUID().uuidString, email: email, token: "local-dev-token", refreshToken: nil)
    }

    func login(email: String, password: String) async throws -> AuthSession {
        guard !email.isEmpty, !password.isEmpty else {
            appLog("Login validation failed: empty email or password", level: .warning, category: "Auth")
            throw AuthError.invalidInput("Email and password are required.")
        }
        appLog("LocalDev login for \(email)", level: .debug, category: "Auth")
        return AuthSession(userId: UUID().uuidString, email: email, token: "local-dev-token", refreshToken: nil)
    }

    func requestPasswordReset(email: String) async throws {
        appLog("LocalDev password reset for \(email) (no-op)", level: .debug, category: "Auth")
    }
}

private struct LegacyAuthAPI: AuthServicing {
    let baseURL: URL

    func signup(email: String, password: String, fullName: String) async throws -> AuthSession {
        guard !email.isEmpty, !password.isEmpty else {
            appLog("Signup validation failed: empty email or password", level: .warning, category: "Auth")
            throw AuthError.invalidInput("Email and password are required.")
        }

        let body = SignupRequest(email: email, password: password, fullName: fullName)
        return try await send(to: baseURL.appendingPathComponent("auth/signup"), body: body, operation: "signup")
    }

    func login(email: String, password: String) async throws -> AuthSession {
        guard !email.isEmpty, !password.isEmpty else {
            appLog("Login validation failed: empty email or password", level: .warning, category: "Auth")
            throw AuthError.invalidInput("Email and password are required.")
        }

        let body = LoginRequest(email: email, password: password)
        return try await send(to: baseURL.appendingPathComponent("auth/login"), body: body, operation: "login")
    }

    func requestPasswordReset(email: String) async throws {
        appLog("Legacy password reset for \(email) (not supported)", level: .warning, category: "Auth")
        throw AuthError.server("Password reset is not supported on this server.")
    }

    private func send<T: Encodable>(to url: URL, body: T, operation: String) async throws -> AuthSession {
        appLog("Legacy \(operation) → \(url.absoluteString)", level: .info, category: "Auth")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            appLog("Legacy \(operation) network error: \(error.localizedDescription)", level: .error, category: "Auth")
            throw error
        }

        guard let http = response as? HTTPURLResponse else {
            appLog("Legacy \(operation) — response was not HTTPURLResponse", level: .error, category: "Auth")
            throw AuthError.invalidResponse
        }

        appLog("Legacy \(operation) ← HTTP \(http.statusCode)", level: http.statusCode < 400 ? .info : .error, category: "Auth")

        if (200..<300).contains(http.statusCode) {
            guard let payload = try? JSONDecoder().decode(LegacyAuthResponse.self, from: data) else {
                appLog("Legacy \(operation) — failed to decode success response body", level: .error, category: "Auth")
                throw AuthError.invalidResponse
            }
            appLog("Legacy \(operation) succeeded for userId=\(payload.user.id)", level: .info, category: "Auth")
            return AuthSession(userId: payload.user.id, email: payload.user.email, token: payload.token, refreshToken: nil)
        }

        if let err = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
            appLog("Legacy \(operation) server error: \(err.message)", level: .error, category: "Auth")
            throw AuthError.server(err.message)
        }

        appLog("Legacy \(operation) failed with HTTP \(http.statusCode), body: \(String(data: data, encoding: .utf8) ?? "<binary>")", level: .error, category: "Auth")
        throw AuthError.server("Authentication failed with status \(http.statusCode).")
    }
}

private struct SupabaseAuthAPI: AuthServicing {
    let config: SupabaseConfig

    func signup(email: String, password: String, fullName: String) async throws -> AuthSession {
        guard !email.isEmpty, !password.isEmpty else {
            appLog("Signup validation failed: empty email or password", level: .warning, category: "Auth")
            throw AuthError.invalidInput("Email and password are required.")
        }

        let url = config.baseURL.appending(path: "auth/v1/signup")
        appLog("Supabase signup → \(url.absoluteString)", level: .info, category: "Auth")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(config.anonKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(SupabaseSignupRequest(email: email, password: password, data: .init(fullName: fullName)))

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            appLog("Supabase signup network error: \(error.localizedDescription)", level: .error, category: "Auth")
            throw error
        }

        guard let http = response as? HTTPURLResponse else {
            appLog("Supabase signup — response was not HTTPURLResponse", level: .error, category: "Auth")
            throw AuthError.invalidResponse
        }

        appLog("Supabase signup ← HTTP \(http.statusCode)", level: http.statusCode < 400 ? .info : .error, category: "Auth")

        guard (200..<300).contains(http.statusCode) else {
            if let err = try? JSONDecoder().decode(SupabaseErrorResponse.self, from: data) {
                let msg = err.msg ?? err.errorDescription ?? err.error ?? "Signup failed."
                appLog("Supabase signup server error: \(msg)", level: .error, category: "Auth")
                throw normalizedSupabaseAuthError(message: msg, operation: "signup", errorCode: err.errorCode)
            }
            let raw = String(data: data, encoding: .utf8) ?? "<binary>"
            appLog("Supabase signup HTTP \(http.statusCode) — raw body: \(raw)", level: .error, category: "Auth")
            throw normalizedSupabaseAuthError(message: raw, operation: "signup", errorCode: nil)
        }

        guard let payload = try? JSONDecoder().decode(SupabaseAuthResponse.self, from: data) else {
            appLog("Supabase signup — failed to decode response body", level: .error, category: "Auth")
            throw AuthError.invalidResponse
        }

        guard
            let accessToken = payload.accessToken,
            let user = payload.user
        else {
            let hasUser = payload.user != nil
            appLog("Supabase signup — no session returned (hasUser=\(hasUser), hasToken=\(payload.accessToken != nil)). Email confirmation may be enabled.", level: .warning, category: "Auth")
            throw AuthError.emailVerificationRequired(email: email)
        }

        appLog("Supabase signup succeeded for userId=\(user.id)", level: .info, category: "Auth")
        return AuthSession(
            userId: user.id,
            email: user.email ?? email,
            token: accessToken,
            refreshToken: payload.refreshToken
        )
    }

    func login(email: String, password: String) async throws -> AuthSession {
        guard !email.isEmpty, !password.isEmpty else {
            appLog("Login validation failed: empty email or password", level: .warning, category: "Auth")
            throw AuthError.invalidInput("Email and password are required.")
        }

        let url = makeSupabaseLoginURL(base: config.baseURL)
        appLog("Supabase login → \(url.absoluteString)", level: .info, category: "Auth")
        let attempt = try await performSupabaseLoginRequest(url: url, email: email, password: password, anonKey: config.anonKey)
        let data = attempt.data
        let http = attempt.http

        guard (200..<300).contains(http.statusCode) else {
            if let err = try? JSONDecoder().decode(SupabaseErrorResponse.self, from: data) {
                let msg = err.msg ?? err.errorDescription ?? err.error ?? "Login failed."
                appLog("Supabase login server error: \(msg)", level: .error, category: "Auth")
                throw normalizedSupabaseAuthError(message: msg, operation: "login", errorCode: err.errorCode)
            }
            let raw = String(data: data, encoding: .utf8) ?? "<binary>"
            appLog("Supabase login HTTP \(http.statusCode) — raw body: \(raw)", level: .error, category: "Auth")
            throw normalizedSupabaseAuthError(message: raw, operation: "login", errorCode: nil)
        }

        guard let payload = try? JSONDecoder().decode(SupabaseAuthResponse.self, from: data),
              let token = payload.accessToken,
              let user = payload.user,
              let userEmail = user.email else {
            appLog("Supabase login — failed to decode success response body", level: .error, category: "Auth")
            throw AuthError.invalidResponse
        }

        appLog("Supabase login succeeded for userId=\(user.id)", level: .info, category: "Auth")
        return AuthSession(
            userId: user.id,
            email: userEmail,
            token: token,
            refreshToken: payload.refreshToken
        )
    }

    private func makeSupabaseLoginURL(base: URL) -> URL {
        var components = URLComponents(url: base.appending(path: "auth/v1/token"), resolvingAgainstBaseURL: true)!
        components.queryItems = [URLQueryItem(name: "grant_type", value: "password")]
        return components.url!
    }

    private func performSupabaseLoginRequest(
        url: URL,
        email: String,
        password: String,
        anonKey: String
    ) async throws -> (data: Data, http: HTTPURLResponse) {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(LoginRequest(email: email, password: password))

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            appLog("Supabase login network error: \(error.localizedDescription)", level: .error, category: "Auth")
            throw error
        }

        guard let http = response as? HTTPURLResponse else {
            appLog("Supabase login — response was not HTTPURLResponse", level: .error, category: "Auth")
            throw AuthError.invalidResponse
        }

        appLog("Supabase login ← HTTP \(http.statusCode)", level: http.statusCode < 400 ? .info : .error, category: "Auth")
        return (data, http)
    }

    func requestPasswordReset(email: String) async throws {
        guard !email.isEmpty else {
            throw AuthError.invalidInput("Email is required.")
        }

        let url = config.baseURL.appending(path: "auth/v1/recover")
        appLog("Supabase password reset → \(url.absoluteString)", level: .info, category: "Auth")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(config.anonKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(["email": email])

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw AuthError.invalidResponse
        }

        appLog("Supabase password reset ← HTTP \(http.statusCode)", level: http.statusCode < 400 ? .info : .error, category: "Auth")

        guard (200..<300).contains(http.statusCode) else {
            if let err = try? JSONDecoder().decode(SupabaseErrorResponse.self, from: data) {
                let msg = err.msg ?? err.errorDescription ?? err.error ?? "Password reset failed."
                throw AuthError.server(msg)
            }
            throw AuthError.server("Password reset failed with status \(http.statusCode).")
        }
    }
}

private func normalizedSupabaseAuthError(message: String, operation: String, errorCode: String?) -> AuthError {
    let normalized = message.lowercased()
    let normalizedCode = errorCode?.lowercased() ?? ""

    if normalizedCode == "over_email_send_rate_limit" || normalized.containsAny([
        "for security purposes, you can only request this after",
        "over_email_send_rate_limit",
        "you can only request this after"
    ]) {
        return .server(makeEmailRateLimitMessage(from: message))
    }

    if operation == "signup", normalized.containsAny([
        "already registered",
        "user already registered",
        "already been registered",
        "duplicate key value violates unique constraint",
        "email exists"
    ]) {
        return .invalidInput("An account with this email already exists. Please log in or reset your password.")
    }

    if operation == "login", normalized.containsAny([
        "invalid login credentials",
        "email not confirmed",
        "invalid email or password"
    ]) {
        return .invalidInput("Incorrect email or password.")
    }

    return .server(message)
}

private func makeEmailRateLimitMessage(from message: String) -> String {
    if let seconds = extractWaitSeconds(from: message) {
        return "Too many attempts. Please try signing up again in about \(seconds) seconds."
    }
    return "Too many attempts. Please try signing up again in a little while."
}

private func extractWaitSeconds(from message: String) -> Int? {
    let pattern = #"after\s+(\d+)\s+seconds"#
    guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
        return nil
    }
    let range = NSRange(message.startIndex..<message.endIndex, in: message)
    guard
        let match = regex.firstMatch(in: message, options: [], range: range),
        match.numberOfRanges > 1,
        let numberRange = Range(match.range(at: 1), in: message)
    else {
        return nil
    }
    return Int(message[numberRange])
}

private extension String {
    func containsAny(_ candidates: [String]) -> Bool {
        candidates.contains(where: { self.contains($0) })
    }
}

private struct SupabaseSignupRequest: Encodable {
    struct Metadata: Encodable {
        let fullName: String

        enum CodingKeys: String, CodingKey {
            case fullName = "full_name"
        }
    }

    let email: String
    let password: String
    let data: Metadata
}

private struct SupabaseAuthResponse: Decodable {
    struct UserPayload: Decodable {
        let id: String
        let email: String?
    }

    let accessToken: String?
    let refreshToken: String?
    let user: UserPayload?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case user
    }
}

private struct SupabaseErrorResponse: Decodable {
    let msg: String?
    let error: String?
    let errorDescription: String?
    let errorCode: String?

    enum CodingKeys: String, CodingKey {
        case msg
        case error
        case errorDescription = "error_description"
        case errorCode = "error_code"
    }
}

private struct LegacyAuthResponse: Decodable {
    struct UserPayload: Decodable {
        let id: String
        let email: String
    }

    let token: String
    let user: UserPayload
}

private struct SignupRequest: Encodable {
    let email: String
    let password: String
    let fullName: String
}

private struct LoginRequest: Encodable {
    let email: String
    let password: String
}

private struct ErrorResponse: Decodable {
    let message: String
}
