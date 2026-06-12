import Foundation
import UIKit

/// Handles secure export of app logs to backend
/// Sanitizes logs to remove sensitive information before uploading
struct AppLogExportService {
    private let session: URLSession
    private let baseURL: URL?
    
    init(session: URLSession = .shared) {
        self.session = session
        // Get Supabase URL from Info.plist
        self.baseURL = Self.getSupabaseURL()
    }
    
    private static func getSupabaseURL() -> URL? {
        let env = ProcessInfo.processInfo.environment
        
        // Check environment variables
        let urlStrings = [
            env["SUPABASE_URL"],
            env["SERVICE_SUPABASE_URL"]
        ].compactMap { $0 }
        
        // Check Info.plist as fallback
        let bundleUrl = Bundle.main.infoDictionary?["SUPABASE_URL"] as? String
        let allUrls = urlStrings + [bundleUrl].compactMap { $0 }
        
        for urlStr in allUrls {
            let trimmed = urlStr.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty, let url = URL(string: trimmed) {
                return url
            }
        }
        
        return nil
    }
    
    /// Export logs to backend with proper sanitization
    /// - Parameters:
    ///   - logs: Array of log entries to export
    ///   - authToken: User's auth token for authentication
    /// - Returns: Success status
    func exportLogsToBackend(
        logs: [AppLogEntry],
        authToken: String
    ) async throws -> Bool {
        guard let baseURL = baseURL else {
            throw LogExportError.missingConfiguration
        }
        
        // Sanitize logs before sending
        let sanitizedLogs = logs.map { sanitizeLogEntry($0) }
        
        // Prepare request
        let url = baseURL.appending(path: "functions/v1/store-app-logs")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        
        // Build payload
        let payload = LogExportPayload(logs: sanitizedLogs)
        request.httpBody = try JSONEncoder().encode(payload)
        
        // Send request
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LogExportError.badResponse
        }
        
        guard (200..<300).contains(httpResponse.statusCode) else {
            // Try to parse error from response
            if let errorResponse = try? JSONDecoder().decode(
                LogExportErrorResponse.self,
                from: data
            ) {
                throw LogExportError.api(errorResponse.message)
            }
            throw LogExportError.badResponse
        }
        
        return true
    }
    
    /// Sanitize a single log entry
    /// Removes sensitive data like URLs, table names, IDs, etc.
    private func sanitizeLogEntry(_ entry: AppLogEntry) -> SanitizedLogEntry {
        return SanitizedLogEntry(
            level: entry.level,
            category: entry.category,
            message: sanitizeMessage(entry.message),
            timestamp: ISO8601DateFormatter().string(from: entry.timestamp),
            app_version: Bundle.main.appVersion,
            device_model: UIDevice.current.model,
            os_version: UIDevice.current.systemVersion
        )
    }
    
    /// Sanitize log message to remove sensitive information
    private func sanitizeMessage(_ message: String) -> String {
        var sanitized = message
        
        // Remove Supabase URLs
        sanitized = sanitized.replacingOccurrences(
            of: "https?://[a-z0-9-]+\\.supabase\\.co",
            with: "[BACKEND]",
            options: .regularExpression
        )
        
        // Remove database connection details
        sanitized = sanitized.replacingOccurrences(
            of: "postgres://[^\\s]+",
            with: "[DATABASE]",
            options: .regularExpression
        )
        
        // Remove UUIDs
        sanitized = sanitized.replacingOccurrences(
            of: "[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}",
            with: "[ID]",
            options: .regularExpression
        )
        
        // Remove email addresses
        sanitized = sanitized.replacingOccurrences(
            of: "[^\\s@]+@[^\\s@]+\\.[^\\s@]+",
            with: "[EMAIL]",
            options: .regularExpression
        )
        
        // Remove JWT tokens (long base64 sequences)
        sanitized = sanitized.replacingOccurrences(
            of: "eyJ[A-Za-z0-9_-]+",
            with: "[TOKEN]",
            options: .regularExpression
        )
        
        // Remove table/schema references
        sanitized = sanitized.replacingOccurrences(
            of: "medhavn\\.[a-z_]+",
            with: "[TABLE]",
            options: .regularExpression
        )
        
        // Remove RLS policy names
        sanitized = sanitized.replacingOccurrences(
            of: "policy.*?on.*?medhavn",
            with: "RLS policy",
            options: .regularExpression
        )
        
        // Remove file paths
        sanitized = sanitized.replacingOccurrences(
            of: "/[a-zA-Z0-9/_\\-\\.]+\\.swift",
            with: "[FILE]",
            options: .regularExpression
        )
        
        // Remove line numbers
        sanitized = sanitized.replacingOccurrences(
            of: ":[0-9]+$",
            with: "",
            options: .regularExpression
        )
        
        return sanitized
    }
}

// MARK: - Models

struct AppLogEntry: Codable {
    let level: String
    let category: String
    let message: String
    let timestamp: Date
}

struct LogExportPayload: Codable {
    let logs: [SanitizedLogEntry]
}

struct SanitizedLogEntry: Codable {
    let level: String
    let category: String
    let message: String
    let timestamp: String
    let app_version: String
    let device_model: String?
    let os_version: String?
}

struct LogExportErrorResponse: Codable {
    let message: String
}

enum LogExportError: LocalizedError {
    case missingConfiguration
    case badResponse
    case api(String)
    case encodingError
    case networkError(String)
    
    var errorDescription: String? {
        switch self {
        case .missingConfiguration:
            return "Log export is not configured. Missing Supabase URL."
        case .badResponse:
            return "Failed to export logs. Server returned an error."
        case .api(let message):
            return "Log export failed: \(message)"
        case .encodingError:
            return "Failed to encode logs for export."
        case .networkError(let message):
            return "Network error: \(message)"
        }
    }
}

// MARK: - Extensions

extension Bundle {
    var appVersion: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
    }
}
