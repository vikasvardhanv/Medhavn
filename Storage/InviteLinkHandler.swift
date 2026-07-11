import Foundation

// MARK: - Invitation Models

struct DependentInvitationRecord: Identifiable, Codable {
    let id: UUID
    var inviterId: UUID
    var inviteeContact: String
    var status: String
    var createdAt: Date
    var acceptedAt: Date?
}

// MARK: - Invite Link Handler

/// Orchestrates deep-link handling and invitation actions for connecting dependents.
@MainActor
final class InviteLinkHandler: ObservableObject {
    static let shared = InviteLinkHandler()
    
    @Published var pendingInvitationID: UUID?
    
    private init() {}
    
    /// Parses an incoming URL for deep links (e.g. medhavn://invite?id=...)
    func handle(url: URL) -> Bool {
        guard url.scheme == "medhavn", url.host == "invite" else { return false }
        
        let components = URLComponents(url: url, resolvingAgainstBaseURL: true)
        if let idQuery = components?.queryItems?.first(where: { $0.name == "id" })?.value,
           let uuid = UUID(uuidString: idQuery) {
            self.pendingInvitationID = uuid
            return true
        }
        return false
    }
}
