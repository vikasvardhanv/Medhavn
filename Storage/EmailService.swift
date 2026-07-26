import Foundation

struct EmailService {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func sendEmail(to: String, subject: String, html: String, from: String? = nil) async throws {
        guard let config = SupabaseRuntimeConfig.current else {
            throw EmailServiceError.missingConfiguration
        }

        let url = config.baseURL.appending(path: "functions/v1/send-email")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(config.anonKey)", forHTTPHeaderField: "Authorization")

        let payload = SendEmailRequest(to: to, subject: subject, html: html, from: from)
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw EmailServiceError.badResponse
        }

        guard (200..<300).contains(http.statusCode) else {
            if let err = try? JSONDecoder().decode(EmailErrorEnvelope.self, from: data) {
                throw EmailServiceError.api(err.error)
            }
            throw EmailServiceError.badResponse
        }
    }
}

enum EmailServiceError: LocalizedError {
    case missingConfiguration
    case badResponse
    case api(String)

    var errorDescription: String? {
        switch self {
        case .missingConfiguration:
            return "Email service is not configured. Set SUPABASE_URL and SUPABASE_ANON_KEY."
        case .badResponse:
            return "Email service returned an invalid response."
        case .api(let message):
            return message
        }
    }
}

private struct SendEmailRequest: Encodable {
    let to: String;
    let subject: String;
    let html: String;
    let from: String?;
}

private struct EmailErrorEnvelope: Decodable {
    let error: String
}

private struct SupabaseRuntimeConfig {
    let baseURL: URL
    let anonKey: String

    static var current: SupabaseRuntimeConfig? {
        guard
            let urlText = value(forKeys: ["SUPABASE_URL", "SERVICE_SUPABASE_URL"]),
            let anonKey = value(forKeys: ["SUPABASE_ANON_KEY", "SERVICE_SUPABASEANON_KEY", "ANON_KEY"])
        else {
            return nil
        }

        let trimmedURL = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedKey = anonKey.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedURL.isEmpty, !trimmedKey.isEmpty, let baseURL = URL(string: trimmedURL) else {
            return nil
        }

        return SupabaseRuntimeConfig(baseURL: baseURL, anonKey: trimmedKey)
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
}
