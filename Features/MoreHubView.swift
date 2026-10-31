import SwiftUI
import MedicationLogicEngine

public struct MoreHubView: View {
    @EnvironmentObject private var appState: AppState
    @State private var referralEmail = ""
    @State private var referralRelationship = "friend"
    @State private var showReferralAlert = false
    @State private var referralAlertMessage = ""

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Health Points Gamification Badge
                pointsBadge
                    .staggeredEntrance(delay: 0.0)

                // Profiles section
                profilesSection
                    .staggeredEntrance(delay: 0.04)

                // Health tools section
                healthToolsSection
                    .staggeredEntrance(delay: 0.08)

                // Safety tools section
                safetySection
                    .staggeredEntrance(delay: 0.12)

                // Apple Watch Section
                appleWatchSection
                    .staggeredEntrance(delay: 0.16)

                // Referral Section
                referralSection
                    .staggeredEntrance(delay: 0.20)

                // Fertility tracking section
                fertilitySection
                    .staggeredEntrance(delay: 0.24)

                // AI Engine & Settings Tools
                toolsSection
                    .staggeredEntrance(delay: 0.28)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 32)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .background { MeshBackgroundView() }
        .navigationTitle(appState.selectedProfile.map { "\($0.name)'s Hub" } ?? "Hub")
        .accessibilityLabel(appState.selectedProfile.map { "\($0.name)'s Hub" } ?? "Hub")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    SettingsView()
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.black)
                }
                .accessibilityLabel("Open Settings")
            }
        }
    }

    private var pointsBadge: some View {
        HStack {
            Image(systemName: "sparkles")
                .foregroundStyle(AppTheme.primary)
                .font(.title3.weight(.bold))
            Text("Your Health Points:")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
            Spacer()
            Text("\(appState.userHealthPoints) PTS")
                .font(.headline.weight(.bold))
                .foregroundStyle(.black)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(AppTheme.primary)
                .clipShape(Capsule())
        }
        .padding(16)
        .glassCard(cornerRadius: 16)
    }

    private var profilesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Profiles")
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 4)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(appState.profiles) { p in
                        let isSelected = appState.selectedProfileID == p.id
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                appState.selectProfile(p.id)
                            }
                        } label: {
                            VStack(spacing: 8) {
                                ZStack {
                                    Circle()
                                        .fill(isSelected ? AppTheme.primary : Color.white.opacity(0.24))
                                        .frame(width: 52, height: 52)
                                    Image(systemName: p.avatarSymbol)
                                        .foregroundStyle(isSelected ? .black : .white.opacity(0.6))
                                        .font(.title3.weight(.semibold))
                                }
                                .overlay(
                                    Circle()
                                        .stroke(isSelected ? Color.clear : Color.white.opacity(0.2), lineWidth: 1.5)
                                )
                                .shadow(color: isSelected ? AppTheme.primary.opacity(0.3) : Color.clear, radius: 6, x: 0, y: 3)
                                
                                Text(p.name)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(isSelected ? .black : .white.opacity(0.7))
                                    .lineLimit(1)
                                    .frame(width: 64)
                            }
                        }
                    }
                    
                    NavigationLink {
                        AddDependentView().environmentObject(appState)
                    } label: {
                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(AppTheme.primary.opacity(0.12))
                                    .frame(width: 52, height: 52)
                                Image(systemName: "person.badge.plus")
                                    .foregroundStyle(.black)
                                    .font(.title3.weight(.bold))
                            }
                            .overlay(
                                Circle()
                                    .stroke(AppTheme.primary.opacity(0.2), lineWidth: 1.5)
                            )
                            
                            Text("Add")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.black)
                        }
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 4)
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 24)
    }

    private var healthToolsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Health Tools")
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 4)

            VStack(spacing: 1) {
                hubRow(icon: "waveform.path.ecg", color: AppTheme.info, title: "Insights",
                       subtitle: "Adherence reports & trends") {
                    ReportsDashboardView().environmentObject(appState)
                }

                Divider().background(Color.white.opacity(0.15)).padding(.leading, 52)

                hubRow(icon: "clock.arrow.circlepath", color: AppTheme.accentBlue, title: "Timeline / Audit Trail",
                       subtitle: "Audit logs of medication activity") {
                    UpdatesFeedView().environmentObject(appState)
                }

                Divider().background(Color.white.opacity(0.15)).padding(.leading, 52)

                hubRow(icon: "waveform.path.ecg.rectangle", color: AppTheme.danger, title: "Measurements",
                       subtitle: "Vitals, biometrics & wellness") {
                    MeasurementsListView().environmentObject(appState)
                }
                
                Divider().background(Color.white.opacity(0.15)).padding(.leading, 52)
                
                hubRow(icon: "book.pages.fill", color: AppTheme.warning, title: "Diary",
                       subtitle: "Personal health notes") {
                    DiaryView().environmentObject(appState)
                }
                
                Divider().background(Color.white.opacity(0.15)).padding(.leading, 52)
                
                hubRow(icon: "calendar.badge.checkmark", color: AppTheme.accentBlue, title: "Appointments",
                       subtitle: "\(appState.appointments.count) upcoming") {
                    AppointmentsView().environmentObject(appState)
                }
                
                Divider().background(Color.white.opacity(0.15)).padding(.leading, 52)
                
                hubRow(icon: "stethoscope", color: AppTheme.accentTeal, title: "Doctors",
                       subtitle: "\(appState.doctors.count) contacts") {
                    DoctorsView().environmentObject(appState)
                }
            }
        }
        .padding(.vertical, 8)
        .glassCard(cornerRadius: 24)
    }

    // MARK: - Fertility Tracking Section
    private var fertilitySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Fertility")
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 4)

            VStack(spacing: 1) {
                hubRow(icon: "heart.circle", color: AppTheme.danger, title: "Fertility Tracker",
                       subtitle: "Cycle, symptoms & treatments") {
                    FertilityTrackerView().environmentObject(appState)
                }

                Divider().background(Color.white.opacity(0.15)).padding(.leading, 52)

                hubRow(icon: "drop.fill", color: AppTheme.danger, title: "Period Tracker",
                       subtitle: appState.currentFertilityCycle?.predictedNextPeriod.map { "Next period \($0.formatted(date: .abbreviated, time: .omitted))" } ?? "Cycle & symptom tracking") {
                    PeriodTrackerView().environmentObject(appState)
                }

                Divider().background(Color.white.opacity(0.15)).padding(.leading, 52)

                hubRow(icon: "pills", color: AppTheme.info, title: "Fertility Treatments",
                       subtitle: "\(appState.fertilityTreatments.count) logged") {
                    TreatmentsTab().environmentObject(appState)
                }

                Divider().background(Color.white.opacity(0.15)).padding(.leading, 52)

                hubRow(icon: "flask", color: AppTheme.accentTeal, title: "Lab Results",
                       subtitle: "\(appState.fertilityLabs.count) recorded") {
                    LabsTab().environmentObject(appState)
                }
            }
        }
        .padding(.vertical, 8)
        .glassCard(cornerRadius: 24)
    }

    private var safetySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Safety")
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 4)

            VStack(spacing: 1) {
                hubRow(icon: "shield.lefthalf.filled.badge.checkmark", color: AppTheme.info, title: "SafeCircle",
                       subtitle: "\(appState.safeCircleContacts.count) trusted contacts") {
                    SafeCircleView().environmentObject(appState)
                }
                
                Divider().background(Color.white.opacity(0.15)).padding(.leading, 52)

                // SafeCircle notification toggle
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(AppTheme.warning.opacity(0.12))
                            .frame(width: 40, height: 40)
                        Image(systemName: "bell.badge.fill")
                            .foregroundStyle(AppTheme.warning)
                            .font(.system(size: 18))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("SafeCircle Pushes")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                        Text("Alert contacts on missed doses")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    Spacer()
                    Toggle("", isOn: $appState.safeCirclePushEnabled)
                        .labelsHidden()
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)

                Divider().background(Color.white.opacity(0.15)).padding(.leading, 52)

                hubRow(icon: "figure.2.and.child.holdinghands", color: AppTheme.accentTeal, title: "Dependent Care",
                       subtitle: "Track linked dependents & lab reports") {
                    ParentCareView().environmentObject(appState)
                }

                Divider().background(Color.white.opacity(0.15)).padding(.leading, 52)

                hubRow(icon: "person.badge.plus", color: AppTheme.accentTeal, title: "Add Dependent",
                       subtitle: "Manage offline & online dependents") {
                    ManageDependentsView().environmentObject(appState)
                }

                Divider().background(Color.white.opacity(0.15)).padding(.leading, 52)
                
                hubRow(icon: "arrow.triangle.2.circlepath.doc.on.clipboard", color: AppTheme.danger, title: "Interactions Checker",
                       subtitle: "Safety check between your meds") {
                    InteractionsCheckerView().environmentObject(appState)
                }
                
                Divider().background(Color.white.opacity(0.15)).padding(.leading, 52)
                
                hubRow(icon: "allergens", color: AppTheme.warning, title: "Allergies",
                       subtitle: "\(appState.allergies.count) recorded") {
                    AllergiesView().environmentObject(appState)
                }
            }
        }
        .padding(.vertical, 8)
        .glassCard(cornerRadius: 24)
    }

    private var appleWatchSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Apple Watch Integration")
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 4)

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.orange.opacity(0.12))
                            .frame(width: 40, height: 40)
                        Image(systemName: "applewatch")
                            .foregroundStyle(.orange)
                            .font(.system(size: 20))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Link Apple Watch")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                        Text("Sync vitals, heart rate & activity")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    Spacer()
                    Toggle("", isOn: $appState.appleWatchLinked)
                        .labelsHidden()
                }

                if appState.appleWatchLinked {
                    Divider().opacity(0.1)

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Last synced: \(appState.lastAppleWatchSyncDate?.formatted(date: .abbreviated, time: .shortened) ?? "Never")")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        Spacer()
                        Button {
                            appState.syncAppleWatch()
                        } label: {
                            Text("Sync Now")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(AppTheme.primary)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            .padding(16)
            .glassCard(cornerRadius: 16)
        }
    }

    private func referralShareText(code: String) -> String {
        let link = appState.referralStoreURL.isEmpty ? "" : "\nDownload: \(appState.referralStoreURL)"
        return "Join me on Medhavn! Use my referral code \(code) when you sign up.\(link)"
    }

    private var referralSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Invite Friends & Family")
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 4)

            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.primary.opacity(0.16))
                            .frame(width: 48, height: 48)
                        Image(systemName: "gift.fill")
                            .font(.title3)
                            .foregroundStyle(AppTheme.primary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Get 1 Month Free Premium")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                        Text("Refer 5 friends to get a free subscription")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.75))
                    }
                }

                VStack(spacing: 8) {
                    HStack {
                        Text("Referral Progress")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white.opacity(0.7))
                        Spacer()
                        Text("\(appState.referralCount)/5 referred")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.primary)
                    }

                    ProgressView(value: Double(appState.referralCount), total: 5.0)
                        .tint(AppTheme.primary)
                        .background(Color.white.opacity(0.12))
                }

                if let code = appState.referralCode {
                    ShareLink(item: referralShareText(code: code)) {
                        Label("Share My Code (\(code))", systemImage: "square.and.arrow.up")
                            .font(.caption.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(AppTheme.primary)
                            .foregroundStyle(.black)
                            .clipShape(Capsule())
                    }
                }

                Divider().overlay(.white.opacity(0.15))
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Or refer via email:")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.8))

                    Picker("They are my", selection: $referralRelationship) {
                        Text("Friend").tag("friend")
                        Text("Parent").tag("parent")
                        Text("Child").tag("child")
                        Text("Spouse").tag("spouse")
                        Text("Sibling").tag("sibling")
                    }
                    .pickerStyle(.menu)
                    .tint(AppTheme.primary)
                    
                    HStack(spacing: 8) {
                        TextField("Friend's email address", text: $referralEmail)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding(10)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .foregroundStyle(.white)
                        
                        Button {
                            let email = referralEmail.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !email.isEmpty else { return }
                            Task {
                                let success = await appState.sendReferralEmail(email: email, relationship: referralRelationship)
                                if success {
                                    referralAlertMessage = "Referral email sent successfully to \(email)!"
                                    referralEmail = ""
                                } else {
                                    referralAlertMessage = "Failed to send referral email. Please try again."
                                }
                                showReferralAlert = true
                            }
                        } label: {
                            Text("Send")
                                .font(.caption.weight(.bold))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(AppTheme.primary)
                                .foregroundStyle(.black)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .disabled(referralEmail.isEmpty || !referralEmail.contains("@"))
                    }
                }
            }
            .padding(16)
            .glassCard(cornerRadius: 16)
            .task { await appState.refreshReferrals() }
            .alert("Referral", isPresented: $showReferralAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(referralAlertMessage)
            }
        }
    }

    private var toolsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Tools & Services")
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 4)

            VStack(spacing: 12) {
                // AI Model Indicator
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(AppTheme.info.opacity(0.12))
                            .frame(width: 40, height: 40)
                        Image(systemName: "cpu.fill")
                            .foregroundStyle(AppTheme.info)
                            .font(.system(size: 18, weight: .bold))
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Intuio AI Engine")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                        
                        if appState.isModelPrewarming {
                            HStack(spacing: 6) {
                                ProgressView().controlSize(.small)
                                Text("Downloading models…")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                        } else if appState.isModelWarmedUp {
                            Text("Ready · fully on-device")
                                .font(.caption)
                                .foregroundStyle(AppTheme.success)
                        } else if appState.modelPrewarmFailed {
                            Text("Offline · Tap to retry setup")
                                .font(.caption)
                                .foregroundStyle(AppTheme.warning)
                        } else {
                            Text("Offline")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                    Spacer()
                }
                .padding(12)
                .background(Color.white.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )

                // Navigation tools
                VStack(spacing: 1) {
                    NavigationLink {
                        AddPlanView()
                    } label: {
                        HStack {
                            Image(systemName: "doc.text.magnifyingglass")
                                .foregroundStyle(.black)
                                .font(.system(size: 16, weight: .bold))
                                .frame(width: 24)
                            Text("Medication Plan Parser")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                        .padding(.vertical, 14)
                        .padding(.horizontal, 16)
                    }

                    Divider().background(Color.white.opacity(0.15))

                    NavigationLink {
                        SettingsView()
                    } label: {
                        HStack {
                            Image(systemName: "gearshape")
                                .foregroundStyle(.black)
                                .font(.system(size: 16, weight: .bold))
                                .frame(width: 24)
                            Text("App Settings")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                        .padding(.vertical, 14)
                        .padding(.horizontal, 16)
                    }
                }
                .background(Color.white.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 24)
    }

    @ViewBuilder
    private func hubRow<Dest: View>(icon: String, color: Color, title: String, subtitle: String,
                                    @ViewBuilder destination: () -> Dest) -> some View {
        NavigationLink(destination: destination()) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [color, color.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: icon)
                        .foregroundStyle(.white)
                        .font(.system(size: 18))
                }
                .shadow(color: color.opacity(0.2), radius: 4, x: 0, y: 2)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.7))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
        }
    }
}
