import SwiftUI

// MARK: - Manage Dependents View

struct ManageDependentsView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var showInviteSheet = false
    @State private var showAddLocalSheet = false
    
    var body: some View {
        ZStack {
            MeshBackgroundView()
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Title/Header summary card
                    headerSummaryCard
                    
                    // Action Buttons for adding/inviting
                    actionRow
                    
                    // Offline/Local Dependents list
                    localDependentsSection
                    
                    // Pending Online Invitations list
                    onlineInvitationsSection
                }
                .padding(16)
            }
        }
        .navigationTitle("Add Dependent")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Back") { dismiss() }
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .sheet(isPresented: $showInviteSheet) {
            InviteDependentView().environmentObject(appState)
        }
        .sheet(isPresented: $showAddLocalSheet) {
            NavigationStack {
                AddDependentView().environmentObject(appState)
            }
        }
    }
    
    private var headerSummaryCard: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(AppTheme.primary.opacity(0.15))
                    .frame(width: 54, height: 54)
                Image(systemName: "person.2.fill")
                    .font(.title3)
                    .foregroundStyle(AppTheme.primary)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Dependents & Linking")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                Text("\(appState.dependents.count) profiles linked or created")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
            }
            Spacer()
        }
        .padding(16)
        .glassCard(cornerRadius: 20)
    }
    
    private var actionRow: some View {
        HStack(spacing: 12) {
            Button {
                showAddLocalSheet = true
            } label: {
                HStack {
                    Image(systemName: "person.fill.badge.plus")
                    Text("Add Local (Offline)")
                }
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.white.opacity(0.1))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
            }
            
            Button {
                showInviteSheet = true
            } label: {
                HStack {
                    Image(systemName: "paperplane.fill")
                    Text("Invite Remote (Online)")
                }
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(AppTheme.primary)
                .foregroundStyle(.black)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
    }
    
    private var localDependentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Local Profiles (Offline)")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.primary)
                .padding(.horizontal, 4)
            
            if appState.dependents.isEmpty {
                Text("No local dependents configured.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassCard(cornerRadius: 16)
            } else {
                VStack(spacing: 12) {
                    ForEach(appState.dependents) { dep in
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.12))
                                    .frame(width: 40, height: 40)
                                Image(systemName: "person.fill")
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(dep.firstName) \(dep.lastName)")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                                Text("Born \(String(dep.birthYear)) · \(dep.gender)")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                            Spacer()
                        }
                        .padding(12)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
            }
        }
    }
    
    private var onlineInvitationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pending Online Invites")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.primary)
                .padding(.horizontal, 4)
            
            if appState.sentInvitations.isEmpty {
                Text("No pending invitations sent.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassCard(cornerRadius: 16)
            } else {
                VStack(spacing: 12) {
                    ForEach(appState.sentInvitations) { invite in
                        HStack(spacing: 12) {
                            Image(systemName: "paperplane.fill")
                                .foregroundStyle(AppTheme.warning)
                                .font(.system(size: 14))
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(invite.inviteeContact)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                                Text("Sent \(invite.createdAt.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                            Spacer()
                            
                            Text(invite.status.capitalized)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(AppTheme.warning.opacity(0.16))
                                .foregroundStyle(AppTheme.warning)
                                .clipShape(Capsule())
                        }
                        .padding(12)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
            }
        }
    }
}

// MARK: - Invite Dependent View

struct InviteDependentView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @State private var emailOrPhone = ""
    @State private var isSending = false
    @State private var showConfirmation = false
    
    var body: some View {
        ZStack {
            MeshBackgroundView()
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Text("Invite Online Dependent")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                    Text("Enter their email or phone number. We'll generate a link to safely connect your accounts.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 24)
                
                // Form input
                VStack(spacing: 12) {
                    TextField("Email or Phone Number", text: $emailOrPhone)
                        .padding(14)
                        .background(Color.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)
                        .font(.body)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                .padding(.horizontal, 16)
                
                Button {
                    Task {
                        isSending = true
                        await appState.sendDependentInvite(emailOrPhone: emailOrPhone)
                        isSending = false
                        showConfirmation = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            dismiss()
                        }
                    }
                } label: {
                    HStack {
                        if isSending {
                            ProgressView()
                                .tint(.black)
                                .padding(.trailing, 8)
                        }
                        Text(showConfirmation ? "Link Generated!" : "Send Invite Link")
                    }
                    .font(.headline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AppTheme.primary)
                    .foregroundStyle(.black)
                    .clipShape(Capsule())
                }
                .disabled(emailOrPhone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
                .opacity(emailOrPhone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.6 : 1.0)
                
                Spacer()
            }
            .padding(24)
        }
    }
}
