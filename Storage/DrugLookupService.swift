import Foundation

/// Medication name suggestions from the Medhavn backend (which proxies OpenFDA).
struct DrugLookupService {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Returns [] when the user is signed out or on the local-dev stub, because the backend needs a real token.
    func searchMedicationNames(query: String, limit: Int = 12, token: String?) async throws -> [String] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2, let token, !token.isEmpty, token != "local-dev-token" else { return [] }
        guard let api = BackendAPI() else { throw DrugLookupError.missingConfiguration }

        var components = URLComponents(url: api.baseURL.appending(path: "v1/drugs/suggest"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "q", value: trimmed),
            URLQueryItem(name: "limit", value: String(max(1, min(limit, 20)))),
        ]
        guard let url = components?.url else { throw DrugLookupError.invalidRequest }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw DrugLookupError.badResponse
        }
        return try JSONDecoder().decode(DrugLookupResponse.self, from: data).suggestions
    }
}

enum DrugLookupError: LocalizedError {
    case missingConfiguration
    case invalidRequest
    case badResponse

    var errorDescription: String? {
        switch self {
        case .missingConfiguration: return "Drug lookup is not configured. Set BACKEND_URL."
        case .invalidRequest: return "Could not build drug lookup request."
        case .badResponse: return "Drug lookup service returned an invalid response."
        }
    }
}

private struct DrugLookupResponse: Decodable {
    let suggestions: [String]
}
