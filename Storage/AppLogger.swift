import Foundation
import os
import Network
import UIKit

// MARK: - Protocols

protocol AppStateProvider {
    var currentAppState: AppState { get }
}

// MARK: - Log Entry

struct DiagLogEntry: Identifiable, Codable, Sendable {
    let id: UUID
    let timestamp: Date
    let level: Level
    let category: String
    let message: String

    enum Level: String, Codable, CaseIterable, Sendable {
        case debug   = "DEBUG"
        case info    = "INFO"
        case warning = "WARN"
        case error   = "ERROR"

        var emoji: String {
            switch self {
            case .debug:   return "🔍"
            case .info:    return "ℹ️"
            case .warning: return "⚠️"
            case .error:   return "🔴"
            }
        }
    }

    var formatted: String {
        let ts = ISO8601DateFormatter().string(from: timestamp)
        return "[\(ts)] [\(level.rawValue)] [\(category)] \(message)"
    }
}

// MARK: - Logger

@MainActor
final class AppLogger: ObservableObject {
    static let shared = AppLogger()

    @Published private(set) var entries: [DiagLogEntry] = []

    private let maxInMemory = 1000
    private let maxPersisted = 200
    private let defaultsKey = "medhavn.appLogs"
    private let autoUploadKey = "medhavn.autoUploadLogs"
    private let uploadQueueKey = "medhavn.uploadQueue"

    private let osLog = Logger(subsystem: "com.medhavn.app", category: "Medhavn")
    private var uploadTask: Task<Void, Never>?
    private var uploadQueue: [DiagLogEntry] = []

    var autoUploadEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: autoUploadKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: autoUploadKey)
            if newValue {
                startAutoUpload()
            } else {
                stopAutoUpload()
            }
        }
    }

    private init() {
        // Restore persisted entries
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let decoded = try? JSONDecoder().decode([DiagLogEntry].self, from: data) {
            entries = decoded
        }

        if let queueData = UserDefaults.standard.data(forKey: uploadQueueKey),
           let decodedQueue = try? JSONDecoder().decode([DiagLogEntry].self, from: queueData) {
            uploadQueue = decodedQueue
        }

        if autoUploadEnabled {
            startAutoUpload()
        }
    }

    func log(_ message: String, level: DiagLogEntry.Level = .info, category: String = "App") {
        let entry = DiagLogEntry(id: UUID(), timestamp: Date(), level: level, category: category, message: message)

        // In-memory buffer
        entries.insert(entry, at: 0)
        if entries.count > maxInMemory {
            entries = Array(entries.prefix(maxInMemory))
        }
        persistEntries()

        // Append to upload queue if auto-upload enabled.
        if autoUploadEnabled {
            queueForUpload(entry)
        }

        // Emit to system logger for low-overhead debugging.
        switch level {
        case .debug:   osLog.debug("[\(category)] \(message)")
        case .info:    osLog.info("[\(category)] \(message)")
        case .warning: osLog.warning("[\(category)] \(message)")
        case .error:   osLog.error("[\(category)] \(message)")
        }

        // If this is an error, trigger upload regardless of batch size.
        if level == .error {
            triggerUpload()
        }
    }

    func clear() {
        entries = []
        uploadQueue = []
        UserDefaults.standard.removeObject(forKey: defaultsKey)
        UserDefaults.standard.removeObject(forKey: uploadQueueKey)
    }

    func exportText() -> String {
        entries.reversed().map(\.formatted).joined(separator: "\n")
    }

    private func persistEntries() {
        let toSave = Array(entries.prefix(maxPersisted))
        if let data = try? JSONEncoder().encode(toSave) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }

    private func queueForUpload(_ entry: DiagLogEntry) {
        uploadQueue.append(entry)
        persistUploadQueue()

        if uploadQueue.count >= 20 {
            triggerUpload()
        }
    }

    private func persistUploadQueue() {
        if let data = try? JSONEncoder().encode(uploadQueue) {
            UserDefaults.standard.set(data, forKey: uploadQueueKey)
        }
    }

    private func startAutoUpload() {
        uploadTask?.cancel()
        uploadTask = Task {
            await uploadQueuedLogs()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(300))
                await uploadQueuedLogs()
            }
        }
    }

    private func stopAutoUpload() {
        uploadTask?.cancel()
        uploadTask = nil
    }

    private func triggerUpload() {
        Task {
            await uploadQueuedLogs()
        }
    }

    private func uploadQueuedLogs() async {
        do {
            try await uploadQueuedLogsInternal()
        } catch {
            appLog("Log upload failed: \(error.localizedDescription)", level: .warning, category: "AppLogger")
        }
    }

    func exportAndUploadLogs() async throws {
        try await uploadQueuedLogsInternal()
    }

    private func uploadQueuedLogsInternal() async throws {
        guard !uploadQueue.isEmpty else { return }

        if !(await isNetworkAvailable()) {
            return
        }

        guard let appState = await getAppState(),
              appState.isLoggedIn,
              let token = await appState.getAuthToken(),
              !token.isEmpty else {
            return
        }

        // The backend accepts at most 200 entries per request; the rest go on the next pass.
        let queueSnapshot = Array(uploadQueue.prefix(200))
        let uploadEntries = queueSnapshot.map { entry in
            UploadLogEntry(
                level: entry.level.rawValue,
                category: entry.category,
                message: String(sanitizeMessage(entry.message).prefix(4000)),
                timestamp: ISO8601DateFormatter().string(from: entry.timestamp),
                app_version: Bundle.main.appVersion,
                device_model: UIDevice.current.model,
                os_version: UIDevice.current.systemVersion
            )
        }

        uploadQueue.removeFirst(queueSnapshot.count)
        persistUploadQueue()

        let payload = UploadPayload(logs: uploadEntries)
        let encoded = try JSONEncoder().encode(payload)

        guard let backend = BackendAPI() else {
            uploadQueue = queueSnapshot + uploadQueue
            persistUploadQueue()
            throw AppLoggerError.missingConfiguration
        }
        let url = backend.baseURL.appending(path: "v1/logs")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = encoded

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpRes = response as? HTTPURLResponse,
              (200..<300).contains(httpRes.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? ""
            uploadQueue = queueSnapshot + uploadQueue
            persistUploadQueue()
            throw AppLoggerError.uploadFailed(message)
        }

        appLog("Uploaded \(uploadEntries.count) logs to backend", level: .info, category: "AppLogger")
    }

    private func isNetworkAvailable() async -> Bool {
        await withCheckedContinuation { continuation in
            let monitor = NWPathMonitor()
            let queue = DispatchQueue(label: "medhavn.network-monitor")
            monitor.pathUpdateHandler = { path in
                if path.status == .satisfied {
                    continuation.resume(returning: true)
                } else {
                    continuation.resume(returning: false)
                }
                monitor.cancel()
            }
            monitor.start(queue: queue)
        }
    }

    private func sanitizeMessage(_ message: String) -> String {
        var sanitized = message

        sanitized = sanitized.replacingOccurrences(
            of: "https?://[a-z0-9-]+\\.supabase\\.co",
            with: "[BACKEND]",
            options: .regularExpression
        )

        sanitized = sanitized.replacingOccurrences(
            of: "postgres://[^\\s]+",
            with: "[DATABASE]",
            options: .regularExpression
        )

        sanitized = sanitized.replacingOccurrences(
            of: "[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}",
            with: "[ID]",
            options: .regularExpression
        )

        sanitized = sanitized.replacingOccurrences(
            of: "[^\\s@]+@[^\\s@]+\\.[^\\s@]+",
            with: "[EMAIL]",
            options: .regularExpression
        )

        sanitized = sanitized.replacingOccurrences(
            of: "eyJ[A-Za-z0-9_-]+",
            with: "[TOKEN]",
            options: .regularExpression
        )

        sanitized = sanitized.replacingOccurrences(
            of: "medhavn\\.[a-z_]+",
            with: "[TABLE]",
            options: .regularExpression
        )

        sanitized = sanitized.replacingOccurrences(
            of: "policy.*?on.*?medhavn",
            with: "RLS policy",
            options: .regularExpression
        )

        sanitized = sanitized.replacingOccurrences(
            of: "/[a-zA-Z0-9/_\\-\\.]+\\.swift",
            with: "[FILE]",
            options: .regularExpression
        )

        sanitized = sanitized.replacingOccurrences(
            of: ":[0-9]+$",
            with: "",
            options: .regularExpression
        )

        return sanitized
    }

    private func getAppState() async -> AppState? {
        await MainActor.run {
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = scene.windows.first,
               let rootViewController = window.rootViewController,
               let stateProvider = findAppState(in: rootViewController) {
                return stateProvider.currentAppState
            }
            return nil
        }
    }

    private func findAppState(in viewController: UIViewController) -> AppStateProvider? {
        if let provider = viewController as? AppStateProvider {
            return provider
        }

        for child in viewController.children {
            if let provider = findAppState(in: child) {
                return provider
            }
        }

        return nil
    }
}

// MARK: - Local Upload Models

private struct UploadLogEntry: Codable {
    let level: String
    let category: String
    let message: String
    let timestamp: String
    let app_version: String
    let device_model: String?
    let os_version: String?
}

private struct UploadPayload: Codable {
    let logs: [UploadLogEntry]
}

private enum AppLoggerError: Error {
    case missingConfiguration
    case uploadFailed(String)
}

// MARK: - Free function (callable from any concurrency context)

/// Call this from anywhere — including non-isolated async code.
/// The actual write always happens on the MainActor.
func appLog(_ message: String, level: DiagLogEntry.Level = .info, category: String = "App") {
    Task { @MainActor in
        AppLogger.shared.log(message, level: level, category: category)
    }
}
