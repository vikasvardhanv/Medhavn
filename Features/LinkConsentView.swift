import SwiftUI

// MARK: - Link Consent View

struct LinkConsentView: View {
    @EnvironmentObject private var appState: AppState
    let invitationID: UUID
    let inviterContact: String
    
    var body: some View {
        ZStack {
            MeshBackgroundView()
                .ignoresSafeArea()
            
            VStack(spacing: 28) {
                // Warning / Link Header
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.primary.opacity(0.16))
                            .frame(width: 64, height: 64)
                        Image(systemName: "person.2.circle.fill")
                            .font(.title)
                            .foregroundStyle(AppTheme.primary)
                    }
                    
                    Text("Consent to Link Account")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                    
                    Text("User **\(inviterContact)** is requesting to link your Medhavn account as their dependent.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
                
                // Key sharing items card
                VStack(alignment: .leading, spacing: 16) {
                    Text("BY LINKING, YOU CONSENT TO SHARE:")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(AppTheme.primary)
                    
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "checkmark.shield.fill")
                            .foregroundStyle(AppTheme.primary)
                        Text("Medication schedules, supplement logs, and daily compliance records.")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "checkmark.shield.fill")
                            .foregroundStyle(AppTheme.primary)
                        Text("Adherence reports and trends visible in their Hub dashboard.")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "bell.badge.fill")
                            .foregroundStyle(AppTheme.primary)
                        Text("Permission for them to send missed-dose alerts and buzz notifications to your device.")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.9))
                    }
                }
                .padding(18)
                .glassCard(cornerRadius: 18)
                
                // Consent actions
                VStack(spacing: 12) {
                    Button {
                        Task {
                            await appState.acceptDependentInvitation(inviteID: invitationID)
                            appState.pendingInvitationID = nil
                        }
                    } label: {
                        Text("Confirm & Link Accounts")
                            .font(.headline.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(AppTheme.primary)
                            .foregroundStyle(.black)
                            .clipShape(Capsule())
                    }
                    
                    Button {
                        Task {
                            await appState.declineDependentInvitation(inviteID: invitationID)
                            appState.pendingInvitationID = nil
                        }
                    } label: {
                        Text("Decline Request")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white.opacity(0.6))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                }
                
                Spacer()
            }
            .padding(28)
            .padding(.top, 24)
        }
    }
}
