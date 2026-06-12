import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject private var logger = AppLogger.shared
    @State private var showPINSetup = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                securitySection
                    .staggeredEntrance(delay: 0.0)
                accountSection
                    .staggeredEntrance(delay: 0.06)
                trialSection
                    .staggeredEntrance(delay: 0.12)
                privacySection
                    .staggeredEntrance(delay: 0.18)
                remindersSection
                    .staggeredEntrance(delay: 0.24)
                medicalSourcesSection
                    .staggeredEntrance(delay: 0.30)
                safetyDisclaimerSection
                    .staggeredEntrance(delay: 0.36)
                if appState.isLoggedIn {
                    logoutSection
                        .staggeredEntrance(delay: 0.42)
                }
                diagnosticsSection
                    .staggeredEntrance(delay: 0.48)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .background { MeshBackgroundView() }
        .navigationTitle("Settings")
        .sheet(isPresented: $showPINSetup) {
            PINSetupView().environmentObject(appState)
        }
        .onAppear {
            Task {
                await appState.refreshNotificationAuthorization()
                appState.refreshProactiveSuggestions()
            }
        }
    }

    // MARK: - Section Views

    private var securitySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("Security", icon: "lock.shield.fill")

            VStack(spacing: 1) {
                settingToggle("Enable PIN Lock", isOn: Binding(
                    get: { appState.pinLockEnabled },
                    set: { newVal in
                        if newVal { showPINSetup = true }
                        else { appState.disablePIN() }
                    }
                ))
                if appState.pinLockEnabled {
                    Divider().background(Color.white.opacity(0.15)).padding(.leading, 16)
                    settingToggle("Use Face ID / Touch ID", isOn: Binding(
                        get: { appState.biometricLockEnabled },
                        set: { val in
                            appState.biometricLockEnabled = val
                            appState.saveSettings()
                        }
                    ))
                    Divider().background(Color.white.opacity(0.15)).padding(.leading, 16)
                    settingButton("Change PIN", icon: "key.fill") {
                        showPINSetup = true
                    }
                }
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 24)
    }

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("Account", icon: "person.circle.fill")

            VStack(spacing: 1) {
                settingRow(label: "Login Status", value: appState.isLoggedIn ? "Signed in" : "Signed out")
                Divider().background(Color.white.opacity(0.15)).padding(.leading, 16)
                settingRow(label: "Consent Checklist", value: appState.consentChecklistCompleted ? "Completed" : "Pending")
                if !appState.authEmail.isEmpty {
                    Divider().background(Color.white.opacity(0.15)).padding(.leading, 16)
                    settingRow(label: "Email", value: appState.authEmail)
                }
                if let userId = appState.authUserId {
                    Divider().background(Color.white.opacity(0.15)).padding(.leading, 16)
                    settingRow(label: "User ID", value: userId)
                }
                if appState.isLoggedIn {
                    Divider().background(Color.white.opacity(0.15)).padding(.leading, 16)
                    settingButton("Logout", icon: "arrowshape.left.circle.fill", isDestructive: true) {
                        appState.logout()
                    }
                }
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 24)
    }

    private var trialSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("Trial", icon: "clock.badge.checkmark.fill")

            VStack(spacing: 1) {
                settingRow(label: "Days remaining", value: "\(appState.trialDaysRemaining)")
                Divider().background(Color.white.opacity(0.15)).padding(.leading, 16)
                settingButton("Upgrade Later", icon: "arrow.forward.circle.fill") {
                    appState.showUpgradeSheet = false
                }
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 24)
    }

    private var privacySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("Privacy", icon: "hand.raised.fill")

            VStack(spacing: 1) {
                settingToggle("Allow cloud processing (explicit consent)", isOn: $appState.userCloudConsent)
                    .onChange(of: appState.userCloudConsent) { _, _ in appState.saveSettings() }
                Divider().background(Color.white.opacity(0.15)).padding(.leading, 16)
                settingInfoRow("By default, processing stays on-device when possible.")
                Divider().background(Color.white.opacity(0.15)).padding(.leading, 16)
                settingLink("Privacy Policy", url: AppWebLinks.privacyPolicy)
                Divider().background(Color.white.opacity(0.15)).padding(.leading, 16)
                settingLink("Support", url: AppWebLinks.support)
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 24)
    }

    private var remindersSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("Reminders", icon: "bell.badge.fill")

            VStack(spacing: 1) {
                settingToggle("Enable proactive dose reminders", isOn: $appState.remindersEnabled)
                    .onChange(of: appState.remindersEnabled) { _, enabled in appState.setRemindersEnabled(enabled) }
                Divider().background(Color.white.opacity(0.15)).padding(.leading, 16)
                settingRow(label: "Notification Access", value: appState.notificationPermissionGranted ? "Granted" : "Not granted")
                Divider().background(Color.white.opacity(0.15)).padding(.leading, 16)
                settingButton("Request Notification Access", icon: "bell.badge.waveform.fill") {
                    appState.requestNotificationAccess()
                }
                Divider().background(Color.white.opacity(0.15)).padding(.leading, 16)
                settingButton("Refresh Reminder Schedule", icon: "arrow.triangle.2.circlepath") {
                    Task { await appState.scheduleDoseReminders() }
                }
                if let status = appState.reminderStatusMessage, !status.isEmpty {
                    Divider().background(Color.white.opacity(0.15)).padding(.leading, 16)
                    settingInfoRow(status)
                }
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 24)
    }

    private var medicalSourcesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("Medical Sources", icon: "book.closed.fill")

            VStack(spacing: 1) {
                NavigationLink {
                    MedicalSourcesView()
                } label: {
                    settingNavigationRow("View all medical data sources", icon: "book.closed")
                }
                Divider().background(Color.white.opacity(0.15)).padding(.leading, 16)
                settingInfoRow("Medhavn uses authoritative medical references for drug interactions, health metrics, and medication information.")
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 24)
    }

    private var safetyDisclaimerSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("Safety Disclaimer", icon: "exclamationmark.shield.fill")

            VStack(spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    Text("I understand this app does not prescribe or recommend any dose — all dosing information comes from my own prescription")
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Toggle("", isOn: $appState.disclaimerAccepted)
                        .labelsHidden()
                        .fixedSize()
                        .tint(AppTheme.primary)
                        .onChange(of: appState.disclaimerAccepted) { _, _ in appState.saveSettings() }
                }
                settingInfoRow("Medhavn reads and schedules your existing prescription instructions. For unclear instructions, confirm with your pharmacist or clinician before following them.")
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 24)
    }

    private var logoutSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("Session", icon: "arrowshape.left.circle.fill")

            VStack(spacing: 1) {
                settingButton("Logout", icon: "arrowshape.left.circle.fill", isDestructive: true) {
                    appState.logout()
                }
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 24)
    }

    private var diagnosticsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("Diagnostics", icon: "wrench.and.screwdriver.fill")

            VStack(spacing: 1) {
                settingToggle("Automatically upload logs to backend", isOn: $logger.autoUploadEnabled)
                    .onChange(of: logger.autoUploadEnabled) { _, enabled in
                        if enabled {
                            appLog("Enabled automatic log upload to backend", level: .info, category: "Settings")
                        } else {
                            appLog("Disabled automatic log upload to backend", level: .info, category: "Settings")
                        }
                    }
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 24)
    }

    // MARK: - Reusable Setting Rows

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(AppTheme.primary)
                .font(.system(size: 14, weight: .semibold))
            Text(title)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 4)
    }

    private func settingRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))
            Spacer()
            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppTheme.secondary)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
    }

    private func settingInfoRow(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(AppTheme.secondary)
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func settingToggle(_ title: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))
        }
        .tint(AppTheme.primary)
        .padding(.vertical, 4)
        .padding(.horizontal, 16)
    }

    private func settingButton(_ title: String, icon: String, isDestructive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 20)
                Text(title)
                    .font(.subheadline.weight(.medium))
                Spacer()
            }
            .foregroundStyle(isDestructive ? AppTheme.danger : AppTheme.primary)
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
        }
    }

    private func settingLink(_ title: String, url: URL) -> some View {
        Link(destination: url) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.medium))
                Spacer()
                Image(systemName: "arrow.up.forward.app.fill")
                    .font(.system(size: 12))
            }
            .foregroundStyle(AppTheme.primary)
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
        }
    }

    private func settingNavigationRow(_ title: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .frame(width: 20)
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.8))
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(AppTheme.secondary)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
    }
}

// MARK: - Medical Sources

struct MedicalSourcesView: View {
    var body: some View {
        List {
            Section("Drug Interactions") {
                sourceRow(
                    title: "DrugBank Open Data",
                    description: "Drug interaction severity classifications and clinical details.",
                    url: URL(string: "https://go.drugbank.com/drugs")!,
                    domain: "drugbank.ca"
                )
                sourceRow(
                    title: "FDA Drug Interactions & Labeling",
                    description: "U.S. Food and Drug Administration official drug interaction guidance.",
                    url: URL(string: "https://www.fda.gov/drugs/drug-interactions-labeling/drug-interactions-what-you-should-know")!,
                    domain: "fda.gov"
                )
                sourceRow(
                    title: "NIH DailyMed",
                    description: "Official FDA-approved drug labeling from the National Library of Medicine.",
                    url: URL(string: "https://dailymed.nlm.nih.gov/dailymed/")!,
                    domain: "dailymed.nlm.nih.gov"
                )
            }
            Section("Health Metrics & Reference Ranges") {
                sourceRow(
                    title: "WHO BMI Classification",
                    description: "World Health Organization reference classifications for BMI and weight status.",
                    url: URL(string: "https://www.who.int/news-room/fact-sheets/detail/obesity-and-overweight")!,
                    domain: "who.int"
                )
                sourceRow(
                    title: "NIH Blood Pressure Guidelines",
                    description: "Reference ranges for blood pressure categories from the National Heart, Lung, and Blood Institute.",
                    url: URL(string: "https://www.nhlbi.nih.gov/health/high-blood-pressure")!,
                    domain: "nhlbi.nih.gov"
                )
                sourceRow(
                    title: "ADA Blood Glucose Standards",
                    description: "American Diabetes Association standards for blood glucose measurement and diagnosis.",
                    url: URL(string: "https://www.diabetes.org/diabetes/diagnosis")!,
                    domain: "diabetes.org"
                )
                sourceRow(
                    title: "CDC Body Measurement References",
                    description: "Centers for Disease Control and Prevention reference values for vital signs and body measurements.",
                    url: URL(string: "https://www.cdc.gov/nchs/fastats/body-measurements.htm")!,
                    domain: "cdc.gov"
                )
                sourceRow(
                    title: "NIH MedlinePlus Lab Tests",
                    description: "Comprehensive health metric definitions and normal ranges from the National Library of Medicine.",
                    url: URL(string: "https://medlineplus.gov/lab-tests/")!,
                    domain: "medlineplus.gov"
                )
            }
            Section("Medication Information") {
                sourceRow(
                    title: "MedlinePlus Drug Information",
                    description: "Comprehensive medication guides from the U.S. National Library of Medicine.",
                    url: URL(string: "https://medlineplus.gov/druginformation.html")!,
                    domain: "medlineplus.gov"
                )
                sourceRow(
                    title: "FDA Drug Database",
                    description: "Official FDA database of approved drug products with therapeutic equivalence evaluations.",
                    url: URL(string: "https://www.accessdata.fda.gov/scripts/cder/daf/")!,
                    domain: "accessdata.fda.gov"
                )
            }
            Section {
                Text("Medhavn provides health and medication information for reference purposes only. This app does not provide medical advice, diagnosis, or treatment. Always consult a qualified healthcare professional for medical decisions.")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.secondary)
            }
        }
        .navigationTitle("Medical Sources")
        .navigationBarTitleDisplayMode(.large)
        .scrollContentBackground(.hidden)
        .background(MeshBackgroundView().ignoresSafeArea())
        .tint(AppTheme.primary)
    }

    private func sourceRow(title: String, description: String, url: URL, domain: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
            Text(description).font(.caption).foregroundStyle(AppTheme.secondary)
            Link(domain, destination: url)
                .font(.caption).foregroundStyle(AppTheme.primary)
        }
        .padding(.vertical, 4)
        .listRowBackground(AppTheme.cardBackground)
    }
}

private enum AppWebLinks {
    static let privacyPolicy = URL(string: "https://medhavn.viktron.ai/privacy")!
    static let support = URL(string: "https://medhavn.viktron.ai/support")!
}

// MARK: - Diagnostics Log Viewer

struct DiagnosticsLogView: View {
    @ObservedObject private var logger = AppLogger.shared
    @Environment(\.dismiss) private var dismiss
    @State private var filterLevel: DiagLogEntry.Level? = nil

    private var filtered: [DiagLogEntry] {
        guard let level = filterLevel else { return logger.entries }
        return logger.entries.filter { $0.level == level }
    }

    var body: some View {
        NavigationStack {
            List {
                if logger.entries.isEmpty {
                    ContentUnavailableView("No Logs Yet", systemImage: "doc.text", description: Text("Logs will appear here as the app runs."))
                        .listRowBackground(AppTheme.cardBackground)
                } else {
                    ForEach(filtered) { entry in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text(entry.level.emoji)
                                Text(entry.category)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(AppTheme.secondary)
                                Spacer()
                                Text(entry.timestamp, style: .time)
                                    .font(.caption2)
                                    .foregroundStyle(AppTheme.secondary)
                            }
                            Text(entry.message)
                                .font(.caption)
                                .foregroundStyle(levelColor(entry.level))
                        }
                        .listRowBackground(entry.level == .error ? AppTheme.danger.opacity(0.12) : AppTheme.cardBackground)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(MeshBackgroundView().ignoresSafeArea())
            .navigationTitle("Diagnostics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(AppTheme.primary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("All") { filterLevel = nil }
                        ForEach(DiagLogEntry.Level.allCases, id: \.self) { lvl in
                            Button("\(lvl.emoji) \(lvl.rawValue)") { filterLevel = lvl }
                        }
                    } label: {
                        Label(filterLevel.map { "\($0.emoji) \($0.rawValue)" } ?? "Filter", systemImage: "line.3.horizontal.decrease.circle")
                            .foregroundStyle(AppTheme.primary)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(
                        item: logger.exportText(),
                        preview: SharePreview("Medhavn Diagnostics", image: Image(systemName: "doc.text"))
                    ) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundStyle(AppTheme.primary)
                    }
                }
            }
        }
    }

    private func levelColor(_ level: DiagLogEntry.Level) -> Color {
        switch level {
        case .debug:   return AppTheme.secondary
        case .info:    return .white
        case .warning: return AppTheme.warning
        case .error:   return AppTheme.danger
        }
    }
}

// MARK: -

struct UpgradeSheetView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationStack {
            List {
                Section("Trial Ended") {
                    Text("Your 60-day trial has ended. Safety warnings remain available.")
                        .foregroundStyle(.white)
                }
                Section("Choose Plan") {
                    Button("Subscribe") {
                        appState.saveSettings(hasPaid: true)
                        appState.showUpgradeSheet = false
                    }
                    .foregroundStyle(AppTheme.primary)
                    Button("One-Time Purchase") {
                        appState.saveSettings(hasPaid: true)
                        appState.showUpgradeSheet = false
                    }
                    .foregroundStyle(AppTheme.primary)
                }
                Section {
                    Button("Upgrade Later") {
                        appState.showUpgradeSheet = false
                    }
                    .foregroundStyle(AppTheme.secondary)
                }
            }
            .navigationTitle("Upgrade")
            .scrollContentBackground(.hidden)
            .background(MeshBackgroundView().ignoresSafeArea())
            .tint(AppTheme.primary)
        }
    }
}

// MARK: - PIN Setup

struct PINSetupView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var step: Step = .enter
    @State private var firstPIN = ""
    @State private var entered = ""
    @State private var error = ""
    private let length = 4

    enum Step { case enter, confirm }

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()
                Text(step == .enter ? "Set a 4-Digit PIN" : "Confirm PIN")
                    .font(.title2.bold())
                    .foregroundStyle(.white)

                Text(step == .enter
                     ? "You'll use this PIN to unlock Intuio."
                     : "Enter the same PIN again to confirm.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                // Dots
                HStack(spacing: 20) {
                    ForEach(0..<length, id: \.self) { i in
                        Circle()
                            .fill(i < entered.count ? AppTheme.primary : Color.white.opacity(0.15))
                            .frame(width: 16, height: 16)
                    }
                }

                if !error.isEmpty {
                    Text(error).foregroundStyle(AppTheme.danger).font(.caption)
                }

                // Keypad
                VStack(spacing: 14) {
                    ForEach([[1,2,3],[4,5,6],[7,8,9]], id: \.self) { row in
                        HStack(spacing: 20) {
                            ForEach(row, id: \.self) { num in
                                numberKey("\(num)") { tap("\(num)") }
                            }
                        }
                    }
                    HStack(spacing: 20) {
                        Spacer().frame(width: 72)
                        numberKey("0") { tap("0") }
                        Button { if !entered.isEmpty { entered.removeLast(); error = "" } } label: {
                            Image(systemName: "delete.left")
                                .font(.title2)
                                .frame(width: 72, height: 72)
                        }
                        .foregroundStyle(.white)
                    }
                }

                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .background(MeshBackgroundView().ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(AppTheme.primary)
                }
            }
        }
    }

    @ViewBuilder
    private func numberKey(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.title.weight(.regular))
                .frame(width: 72, height: 72)
                .background(Circle().fill(AppTheme.cardBackground))
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        }
        .foregroundStyle(.white)
    }

    private func tap(_ digit: String) {
        guard entered.count < length else { return }
        entered += digit
        error = ""
        if entered.count == length {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { advance() }
        }
    }

    private func advance() {
        switch step {
        case .enter:
            firstPIN = entered
            entered = ""
            step = .confirm
        case .confirm:
            if entered == firstPIN {
                appState.setPIN(entered)
                dismiss()
            } else {
                error = "PINs don't match – try again"
                entered = ""
                step = .enter
                firstPIN = ""
            }
        }
    }
}
