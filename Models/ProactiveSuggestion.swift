import Foundation

enum ProactiveSuggestionPriority: String {
    case critical
    case warning
    case info
}

enum ProactiveSuggestionAction: String {
    case enableReminders
    case grantNotificationAccess
    case scheduleReminders
    case reviewSafety
    case none
}

struct ProactiveSuggestion: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let priority: ProactiveSuggestionPriority
    let action: ProactiveSuggestionAction
    let actionTitle: String?
}
