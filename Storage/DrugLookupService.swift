import Foundation

struct DrugLookupService {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func searchMedicationNames(query: String, limit: Int = 12) async throws -> [String] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return [] }

        guard let config = SupabaseRuntimeConfig.current else {
            throw DrugLookupError.missingConfiguration
        }

        var components = URLComponents(
            url: config.baseURL.appending(path: "functions/v1/drug-lookup"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "q", value: trimmed),
            URLQueryItem(name: "limit", value: String(max(1, min(limit, 20))))
        ]

        guard let url = components?.url else {
            throw DrugLookupError.invalidRequest
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(config.anonKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw DrugLookupError.badResponse
        }

        guard (200..<300).contains(http.statusCode) else {
            if let err = try? JSONDecoder().decode(DrugLookupErrorEnvelope.self, from: data) {
                throw DrugLookupError.api(err.error)
            }
            throw DrugLookupError.badResponse
        }

        let payload = try JSONDecoder().decode(DrugLookupResponse.self, from: data)
        return payload.suggestions
    }
}

enum DrugLookupError: LocalizedError {
    case missingConfiguration
    case invalidRequest
    case badResponse
    case api(String)

    var errorDescription: String? {
        switch self {
        case .missingConfiguration:
            return "Drug lookup is not configured. Set SUPABASE_URL and SUPABASE_ANON_KEY."
        case .invalidRequest:
            return "Could not build drug lookup request."
        case .badResponse:
            return "Drug lookup service returned an invalid response."
        case .api(let message):
            return message
        }
    }
}

private struct DrugLookupResponse: Decodable {
    let suggestions: [String]
}

private struct DrugLookupErrorEnvelope: Decodable {
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
