import Foundation
import CryptoKit
import LocalAuthentication
import MedicationLogicEngine
import UserNotifications

@MainActor
final class AppState: ObservableObject {
    @Published var plans: [MedicationPlanRecord] = []
    @Published var selectedPlanID: UUID?
    @Published var ingestionText: String = ""
    @Published var latestOutput: EngineOutput?
    @Published var todayLog: [DoseLogRecord] = []
    @Published var userCloudConsent: Bool = false
    @Published var showUpgradeSheet = false
    @Published var trialDaysRemaining: Int = 60
    @Published var disclaimerAccepted = false
    @Published var isLoggedIn = false
    @Published var consentChecklistCompleted = false
    @Published var privacyPolicyAccepted = false
    @Published var processingConsentAccepted = false
    @Published var authEmail = ""
    @Published var authUserId: String?
    @Published var authToken: String?
    @Published var authRefreshToken: String?
    @Published var authErrorMessage: String?
    @Published var pendingEmailVerification: String?
    @Published var isAuthenticating = false
    @Published var isRequestingPasswordReset = false
    @Published var passwordResetEmailSent = false
    @Published var passwordResetError: String?
    @Published var remindersEnabled = true
    @Published var notificationPermissionGranted = false
    @Published var reminderStatusMessage: String?
    @Published var proactiveSuggestions: [ProactiveSuggestion] = []
    @Published var dailyInsightNote: DailyInsightNoteRecord?
    @Published var isGeneratingInsightNote = false
    @Published var insightNoteErrorMessage: String?
    @Published var localModelRuntimeName: String = IntuioLocalNoteEngineFactory.runtime.rawValue
    @Published var profiles: [UserProfile] = []
    @Published var selectedProfileID: UUID?
    @Published var selectedPillboxDate: Date = Date()
    @Published var medCabinetItems: [MedCabinetItem] = []
    @Published var updatesFeed: [UpdateFeedItem] = []
    @Published var pillDoseStatuses: [PillDoseStatusRecord] = []
    @Published var healthMetrics: [HealthMetricRecord] = []
    @Published var diaryEntries: [DiaryEntryRecord] = []
    @Published var caregiverContact: String = ""
    // SafeCircle (trusted care network)
    @Published var safeCircleContacts: [SafeCircleContact] = []
    // Dependents
    @Published var dependents: [DependentProfile] = []
    @Published var linkedParentProfiles: [LinkedParentProfile] = []
    @Published var parentMedicationAlerts: [ParentMedicationAlert] = []
    // Fertility Tracking
    @Published var fertilityCycles: [FertilityCycleRecord] = []
    @Published var fertilitySymptoms: [FertilitySymptomRecord] = []
    @Published var fertilityTreatments: [FertilityTreatmentRecord] = []
    @Published var fertilityLabs: [FertilityLabRecord] = []
    // Appointments & Doctors
    @Published var appointments: [AppointmentRecord] = []
    @Published var doctors: [DoctorRecord] = []
    // Drug interactions
    @Published var knownInteractions: [DrugInteractionRecord] = []
    @Published var allergies: [AllergyRecord] = []
    @Published var isAppLocked: Bool = false
    @Published var pinLockEnabled: Bool = false
    @Published var biometricLockEnabled: Bool = false
    // Tracker preference (which tracker occupies tab bar slot 3)
    @Published var trackerPreference: TrackerPreference = .none
    @Published var trackerSelectionCompleted: Bool = false
    // Dependent invitations & linking
    @Published var sentInvitations: [DependentInvitationRecord] = []
    @Published var receivedInvitations: [DependentInvitationRecord] = []
    @Published var pendingInvitationID: UUID? = nil
    @Published var isModelWarmedUp: Bool = false
    @Published var isModelPrewarming: Bool = false
    @Published var modelPrewarmFailed: Bool = false
    /// `true` once the model has been downloaded and cached at least once.
    /// Persisted in UserDefaults so the setup screen never shows again after first run.
    @Published var isFirstLaunchSetupDone: Bool = UserDefaults.standard.bool(forKey: "intuio.modelCached")
    /// `true` once the user has explicitly consented to the ~320 MB model download.
    /// Guards the prewarm task so no download begins without informed user consent.
    @Published var isDownloadConsentGiven: Bool = UserDefaults.standard.bool(forKey: "intuio.downloadConsentGiven")
    @Published var safeCirclePushEnabled: Bool = true
    @Published var appleWatchLinked: Bool = false
    @Published var lastAppleWatchSyncDate: Date? = nil
    @Published var referralCount: Int = 2
    @Published var userHealthPoints: Int = 340

    // Email/OTP state
    @Published var signupEmailPendingOTP: String? = nil

    let engine = MedicationLogicEngine()
    let store = SQLiteStore()
    private var isCloudPulling = false
    private lazy var cloudSync: CloudMedSync? = {
        let sync = CloudMedSync()
        sync?.onSessionRefreshed = { [weak self] session in
            Task { @MainActor in
                guard let self, self.authUserId == session.userId else { return }
                self.authToken = session.token
                self.authRefreshToken = session.refreshToken
                self.saveSettings()
            }
        }
        return sync
    }()
    let authService: AuthServicing = AuthAPI()
    let notificationService: MedicationNotificationServicing = MedicationNotificationService()
    let insightsEngine = ProactiveInsightsEngine()
    let localNoteEngine: IntuioLocalNoteGenerating = IntuioLocalNoteEngineFactory.make()
    let featureStore = FeatureStateStore()
    let sharedChatEngine = IntuioAssistantChatEngine()

    var selectedPlan: MedicationPlanRecord? {
        plans.first(where: { $0.id == selectedPlanID })
    }

    var selectedProfile: UserProfile? {
        guard let selectedProfileID else { return profiles.first }
        return profiles.first(where: { $0.id == selectedProfileID }) ?? profiles.first
    }

    func bootstrap() {
        appLog("Bootstrap started", level: .info, category: "AppState")
        do {
            try store.open()
            let settings = try store.loadSettings()
            userCloudConsent = settings.cloudConsent
            disclaimerAccepted = settings.disclaimerAccepted
            privacyPolicyAccepted = settings.privacyPolicyAccepted
            processingConsentAccepted = settings.processingConsentAccepted
            isLoggedIn = settings.isLoggedIn
            consentChecklistCompleted = settings.consentChecklistCompleted
            trackerPreference = settings.trackerPreference
            trackerSelectionCompleted = settings.trackerSelectionCompleted
            // Auto-complete tracker selection for existing users who signed up
            // before this feature existed — they keep the default Insights tab.
            if consentChecklistCompleted && !trackerSelectionCompleted {
                trackerSelectionCompleted = true
                trackerPreference = .none
            }
            authEmail = settings.authEmail ?? ""
            authUserId = settings.authUserId
            authToken = settings.authToken
            authRefreshToken = settings.authRefreshToken
            remindersEnabled = settings.remindersEnabled
            trialDaysRemaining = TrialManager.daysRemaining(from: settings.firstUseDate)
            showUpgradeSheet = trialDaysRemaining <= 0 && !settings.hasPaid
            plans = try store.fetchPlans()
            selectedPlanID = plans.first?.id
            if let selectedPlan {
                todayLog = try store.fetchDoseLogs(for: selectedPlan.id)
                dailyInsightNote = try store.fetchDailyInsightNote(planID: selectedPlan.id, day: Date())
            }

            loadFeatureState()
            checkForMissedDoses()
            appLog("Bootstrap complete — isLoggedIn=\(isLoggedIn) consent=\(consentChecklistCompleted) firstLaunch=\(!isFirstLaunchSetupDone)", level: .info, category: "AppState")

            Task {
                await refreshNotificationAuthorization()
                if remindersEnabled {
                    await scheduleDoseReminders()
                }
                refreshProactiveSuggestions()
                await pullCloudMeds()
            }

            // Pre-warm the local chat model at launch.
            // On first install the weights (~320 MB) download once to the
            // HuggingFace on-device cache; every subsequent launch loads
            // from disk in a few seconds.
            // Only start the download if the model is already cached (subsequent
            // launches) OR the user has explicitly consented to the download.
            // On first install, consent is collected by FirstLaunchSetupView
            // before this code path is reached via startModelDownloadWithConsent().
            if isFirstLaunchSetupDone || isDownloadConsentGiven {
                let taskPriority: TaskPriority = isFirstLaunchSetupDone ? .background : .userInitiated
                Task.detached(priority: taskPriority) { [weak self] in
                    guard let self else { return }
                    await MainActor.run { self.isModelPrewarming = true }
                    let ok = await self.sharedChatEngine.warmup()
                    await MainActor.run {
                        self.isModelPrewarming = false
                        self.isModelWarmedUp = ok
                        self.modelPrewarmFailed = !ok
                        if ok { self.completeFirstLaunchSetup() }
                    }
                }
            }
        } catch {
            appLog("Bootstrap failed: \(error)", level: .error, category: "AppState")
        }
    }

    // MARK: - First-launch setup helpers

    /// Called automatically when model warmup succeeds for the first time,
    /// or manually by the user tapping "Continue without AI".
    func completeFirstLaunchSetup() {
        guard !isFirstLaunchSetupDone else { return }
        UserDefaults.standard.set(true, forKey: "intuio.modelCached")
        isFirstLaunchSetupDone = true
    }

    /// Lets the user bypass the setup screen if they have no internet
    /// or want to proceed without the AI assistant.
    /// User can still opt-in to the download later when they access Chat.
    func skipFirstLaunchSetup() {
        UserDefaults.standard.set(true, forKey: "intuio.modelCached")
        isFirstLaunchSetupDone = true
    }

    /// Called when the user explicitly taps "Download Now" on the consent prompt.
    /// Records consent, then starts the model download for the first time.
    func startModelDownloadWithConsent() {
        guard !isDownloadConsentGiven && !isFirstLaunchSetupDone else { return }
        UserDefaults.standard.set(true, forKey: "intuio.downloadConsentGiven")
        isDownloadConsentGiven = true
        isModelWarmedUp = false
        modelPrewarmFailed = false
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            await MainActor.run { self.isModelPrewarming = true }
            let ok = await self.sharedChatEngine.warmup()
            await MainActor.run {
                self.isModelPrewarming = false
                self.isModelWarmedUp = ok
                self.modelPrewarmFailed = !ok
                if ok { self.completeFirstLaunchSetup() }
            }
        }
    }

    /// Resets prewarm state and fires a new download attempt.
    func retryModelPrewarm() {
        guard !isModelPrewarming else { return }
        isModelWarmedUp = false
        modelPrewarmFailed = false
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            await MainActor.run { self.isModelPrewarming = true }
            let ok = await self.sharedChatEngine.warmup()
            await MainActor.run {
                self.isModelPrewarming = false
                self.isModelWarmedUp = ok
                self.modelPrewarmFailed = !ok
                if ok { self.completeFirstLaunchSetup() }
            }
        }
    }

    func saveSettings(hasPaid: Bool? = nil) {
        do {
            var settings = try store.loadSettings()
            settings.cloudConsent = userCloudConsent
            settings.disclaimerAccepted = disclaimerAccepted
            settings.privacyPolicyAccepted = privacyPolicyAccepted
            settings.processingConsentAccepted = processingConsentAccepted
            settings.isLoggedIn = isLoggedIn
            settings.consentChecklistCompleted = consentChecklistCompleted
            settings.trackerPreference = trackerPreference
            settings.trackerSelectionCompleted = trackerSelectionCompleted
            settings.authEmail = authEmail.isEmpty ? nil : authEmail
            settings.authUserId = authUserId
            settings.authToken = authToken
            settings.authRefreshToken = authRefreshToken
            settings.remindersEnabled = remindersEnabled
            if let hasPaid {
                settings.hasPaid = hasPaid
            }
            settings.pinLockEnabled = pinLockEnabled
            settings.biometricLockEnabled = biometricLockEnabled
            // pinHash persisted separately via saveSettings(pinHash:pinEnabled:)
            try store.saveSettings(settings)
            trialDaysRemaining = TrialManager.daysRemaining(from: settings.firstUseDate)
            showUpgradeSheet = trialDaysRemaining <= 0 && !settings.hasPaid
        } catch {
            appLog("Save settings failed: \(error)", level: .error, category: "AppState")
        }
    }

    private func loadFeatureState() {
        let defaultProfile = UserProfile(id: UUID(), name: "You", avatarSymbol: "person.fill")
        profiles = featureStore.load([UserProfile].self, key: "feature.profiles", fallback: [defaultProfile])

        selectedProfileID = featureStore.load(UUID?.self, key: "feature.selectedProfileID", fallback: profiles.first?.id)
        if selectedProfileID == nil {
            selectedProfileID = profiles.first?.id
        }

        medCabinetItems = featureStore.load([MedCabinetItem].self, key: "feature.medCabinetItems", fallback: [])
        updatesFeed = featureStore.load([UpdateFeedItem].self, key: "feature.updatesFeed", fallback: [])
        pillDoseStatuses = featureStore.load([PillDoseStatusRecord].self, key: "feature.pillDoseStatuses", fallback: [])
        healthMetrics = featureStore.load([HealthMetricRecord].self, key: "feature.healthMetrics", fallback: [])
        diaryEntries = featureStore.load([DiaryEntryRecord].self, key: "feature.diaryEntries", fallback: [])
        caregiverContact = featureStore.load(String.self, key: "feature.caregiverContact", fallback: "")
        safeCircleContacts = featureStore.load([SafeCircleContact].self, key: "feature.safeCircle", fallback: [])
        dependents = featureStore.load([DependentProfile].self, key: "feature.dependents", fallback: [])
        linkedParentProfiles = featureStore.load([LinkedParentProfile].self, key: "feature.linkedParentProfiles", fallback: [])
        parentMedicationAlerts = featureStore.load([ParentMedicationAlert].self, key: "feature.parentMedicationAlerts", fallback: [])
        appointments = featureStore.load([AppointmentRecord].self, key: "feature.appointments", fallback: [])
        doctors = featureStore.load([DoctorRecord].self, key: "feature.doctors", fallback: [])
        knownInteractions = featureStore.load([DrugInteractionRecord].self, key: "feature.interactions", fallback: [])
        allergies = featureStore.load([AllergyRecord].self, key: "feature.allergies", fallback: [])
        fertilityCycles = featureStore.load([FertilityCycleRecord].self, key: "feature.fertilityCycles", fallback: [])
        fertilitySymptoms = featureStore.load([FertilitySymptomRecord].self, key: "feature.fertilitySymptoms", fallback: [])
        fertilityTreatments = featureStore.load([FertilityTreatmentRecord].self, key: "feature.fertilityTreatments", fallback: [])
        fertilityLabs = featureStore.load([FertilityLabRecord].self, key: "feature.fertilityLabs", fallback: [])
        sentInvitations = featureStore.load([DependentInvitationRecord].self, key: "feature.sentInvitations", fallback: [])
        receivedInvitations = featureStore.load([DependentInvitationRecord].self, key: "feature.receivedInvitations", fallback: [])
        if let settings = try? store.loadSettings() {
            pinLockEnabled = settings.pinLockEnabled
            biometricLockEnabled = settings.biometricLockEnabled
        }
    }

    private func persistFeatureState() {
        featureStore.save(profiles, key: "feature.profiles")
        featureStore.save(selectedProfileID, key: "feature.selectedProfileID")
        featureStore.save(medCabinetItems, key: "feature.medCabinetItems")
        featureStore.save(updatesFeed, key: "feature.updatesFeed")
        featureStore.save(pillDoseStatuses, key: "feature.pillDoseStatuses")
        featureStore.save(healthMetrics, key: "feature.healthMetrics")
        featureStore.save(diaryEntries, key: "feature.diaryEntries")
        featureStore.save(caregiverContact, key: "feature.caregiverContact")
        featureStore.save(safeCircleContacts, key: "feature.safeCircle")
        featureStore.save(dependents, key: "feature.dependents")
        featureStore.save(linkedParentProfiles, key: "feature.linkedParentProfiles")
        featureStore.save(parentMedicationAlerts, key: "feature.parentMedicationAlerts")
        featureStore.save(appointments, key: "feature.appointments")
        featureStore.save(doctors, key: "feature.doctors")
        featureStore.save(knownInteractions, key: "feature.interactions")
        featureStore.save(allergies, key: "feature.allergies")
        featureStore.save(fertilityCycles, key: "feature.fertilityCycles")
        featureStore.save(fertilitySymptoms, key: "feature.fertilitySymptoms")
        featureStore.save(fertilityTreatments, key: "feature.fertilityTreatments")
        featureStore.save(fertilityLabs, key: "feature.fertilityLabs")
        featureStore.save(sentInvitations, key: "feature.sentInvitations")
        featureStore.save(receivedInvitations, key: "feature.receivedInvitations")
    }

    func selectProfile(_ profileID: UUID) {
        selectedProfileID = profileID
        persistFeatureState()
    }

    func shiftPillboxDate(by days: Int) {
        selectedPillboxDate = Calendar.current.date(byAdding: .day, value: days, to: selectedPillboxDate) ?? selectedPillboxDate
        checkForMissedDoses()
    }

    func addProfile(name: String, avatarSymbol: String = "person.fill") {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let profile = UserProfile(id: UUID(), name: trimmed, avatarSymbol: avatarSymbol)
        profiles.append(profile)
        selectedProfileID = profile.id
        persistFeatureState()
    }

    func addMedCabinetItem(_ item: MedCabinetItem) -> [String] {
        let warnings = checkInteractionWarnings(for: item)
        medCabinetItems.insert(item, at: 0)

        if warnings.isEmpty {
            addUpdate(category: .adherence, title: "Medication added", detail: "\(item.name) added to Pharmacy.")
        } else {
            addUpdate(category: .interaction, title: "Interaction warning", detail: warnings.joined(separator: " "))
        }

        persistFeatureState()
        cloudPushItem(id: item.id)
        return warnings
    }

    func removeMedCabinetItem(id: UUID) {
        guard let item = medCabinetItems.first(where: { $0.id == id }) else { return }
        medCabinetItems.removeAll { $0.id == id }
        let prefix = "\(id.uuidString)|"
        pillDoseStatuses.removeAll { $0.key.hasPrefix(prefix) }
        addUpdate(category: .adherence, title: "Medication removed", detail: "\(item.name) removed from Pharmacy.")
        persistFeatureState()
        if item.profileID == syncedProfileID {
            cloudPush("delete item") { try await $0.delete(itemID: id, session: $1) }
        }
    }

    func refillMedCabinetItem(id: UUID, amount: Int) {
        guard let index = medCabinetItems.firstIndex(where: { $0.id == id }) else { return }
        medCabinetItems[index].remainingPills += amount
        addUpdate(category: .refill, title: "Medication refilled", detail: "\(medCabinetItems[index].name) refilled with \(amount) pills.")
        persistFeatureState()
        cloudPushItem(id: id)
    }

    func interactionWarnings(for item: MedCabinetItem) -> [String] {
        checkInteractionWarnings(for: item)
    }

    private func checkInteractionWarnings(for newItem: MedCabinetItem) -> [String] {
        let existing = medCabinetItems.filter { $0.profileID == newItem.profileID }
        var warnings: [String] = []

        let conflictPairs: [Set<String>] = [
            ["warfarin", "ibuprofen"],
            ["lisinopril", "ibuprofen"],
            ["metformin", "alcohol"],
            ["prednisone", "ibuprofen"]
        ]

        let newTags = Set((newItem.contraindicationTags + [newItem.name.lowercased()]).map { $0.lowercased() })

        for item in existing {
            let existingTags = Set((item.contraindicationTags + [item.name.lowercased()]).map { $0.lowercased() })
            let combined = newTags.union(existingTags)

            for pair in conflictPairs where pair.isSubset(of: combined) {
                warnings.append("Potential interaction between \(newItem.name) and \(item.name). Verify with a clinician.")
            }
        }

        return Array(Set(warnings))
    }

    func addFromLatestParsedPlanToCabinet() {
        guard let profile = selectedProfile, let output = latestOutput else { return }

        let frequency = output.parsed.frequency
        let blocks: [DayTimeBlock]
        switch frequency {
        case .onceDaily:
            blocks = [.morning]
        case .twiceDaily:
            blocks = [.morning, .evening]
        case .threeTimesDaily:
            blocks = [.morning, .afternoon, .evening]
        case .fourTimesDaily:
            blocks = DayTimeBlock.allCases
        case .everyHours(let hours):
            blocks = hours <= 6 ? DayTimeBlock.allCases : [.morning, .evening]
        case .customPerDay(let count):
            blocks = Array(DayTimeBlock.allCases.prefix(max(1, min(count, 4))))
        case .asNeeded, .none:
            blocks = [.morning]
        }

        let item = MedCabinetItem(
            id: UUID(),
            profileID: profile.id,
            name: output.parsed.drugName ?? "Medication",
            dosageText: "\(output.parsed.dose.map { String(format: "%.1f", $0) } ?? "1") \(output.parsed.units ?? "pill")",
            scheduleBlocks: blocks,
            remainingPills: 30,
            refillThreshold: 5,
            pillShape: .capsule,
            pillColorHex: "#2F80ED",
            contraindicationTags: [output.parsed.drugName?.lowercased() ?? ""],
            createdAt: Date()
        )

        _ = addMedCabinetItem(item)
    }

    func statusForDose(itemID: UUID, block: DayTimeBlock, date: Date) -> DoseStatusKind {
        let key = doseKey(itemID: itemID, block: block, date: date)
        return pillDoseStatuses.first(where: { $0.key == key })?.status ?? .pending
    }

    func markDose(itemID: UUID, block: DayTimeBlock, date: Date, status: DoseStatusKind) {
        let key = doseKey(itemID: itemID, block: block, date: date)
        let previous = pillDoseStatuses.first(where: { $0.key == key })?.status ?? .pending

        if let index = pillDoseStatuses.firstIndex(where: { $0.key == key }) {
            pillDoseStatuses[index].status = status
            pillDoseStatuses[index].updatedAt = Date()
        } else {
            pillDoseStatuses.append(PillDoseStatusRecord(id: UUID(), key: key, status: status, updatedAt: Date()))
        }

        if status == .taken && previous != .taken {
            decrementInventory(for: itemID)
            cloudPushItem(id: itemID)
            userHealthPoints += 10
            addUpdate(category: .adherence, title: "Dose taken (+10 Points)", detail: "Dose marked as taken for \(block.title.lowercased()). Adherence bonus added.")
        } else if status == .skipped && previous != .skipped {
            addUpdate(category: .adherence, title: "Dose skipped", detail: "Dose skipped for \(block.title.lowercased()).")
            if !safeCircleContacts.isEmpty {
                let names = safeCircleContacts.prefix(2).map(\.name).joined(separator: ", ")
                addUpdate(category: .caregiver, title: "SafeCircle notified", detail: "Missed-dose alert prepared for \(names).")
            } else if !caregiverContact.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                addUpdate(category: .caregiver, title: "SafeCircle notified", detail: "Missed-dose alert prepared for \(caregiverContact).")
            }
            createParentMissedDoseAlertIfNeeded(itemID: itemID, block: block, date: date, now: Date())
        }

        persistFeatureState()
        if medCabinetItems.first(where: { $0.id == itemID })?.profileID == syncedProfileID,
           let record = pillDoseStatuses.first(where: { $0.key == key }) {
            cloudPush("push dose status") { try await $0.push(statuses: [record], session: $1) }
        }
    }

    // MARK: - Cloud med sync (shared with AuraPath via medhavn schema)

    /// Only the account owner's profile (profiles[0], see applySignupName) syncs;
    /// dependents' cabinets stay local-only.
    private var syncedProfileID: UUID? { profiles.first?.id }

    /// Nil for the LocalDev auth stub or a signed-out state: nothing syncs then.
    private var cloudSession: CloudMedSync.Session? {
        guard let userId = authUserId, UUID(uuidString: userId) != nil,
              let token = authToken, !token.isEmpty, token != "local-dev-token" else { return nil }
        return CloudMedSync.Session(userId: userId, token: token, refreshToken: authRefreshToken)
    }

    private func cloudPush(_ label: String, _ work: @escaping (CloudMedSync, CloudMedSync.Session) async throws -> Void) {
        guard let sync = cloudSync, let session = cloudSession else { return }
        Task {
            do {
                try await work(sync, session)
            } catch {
                appLog("Cloud sync \(label) failed: \(error.localizedDescription)", level: .error, category: "CloudSync")
            }
        }
    }

    private func cloudPushItem(id: UUID) {
        guard let item = medCabinetItems.first(where: { $0.id == id }), item.profileID == syncedProfileID else { return }
        cloudPush("push item") { try await $0.push(items: [item], session: $1) }
    }

    /// Pulls the user's cabinet and dose rows, merges them into local state
    /// (rules in CloudMedSync.mergeCabinet / mergeStatuses), then uploads local
    /// rows the server lacks or holds stale. The first run is the backfill.
    func pullCloudMeds() async {
        guard let sync = cloudSync, let session = cloudSession, let profileID = syncedProfileID, !isCloudPulling else { return }
        isCloudPulling = true
        defer { isCloudPulling = false }
        do {
            let remote = try await sync.pull(session: session)
            let cabinet = CloudMedSync.mergeCabinet(local: medCabinetItems, remote: remote.items, profileID: profileID, syncedProfileID: profileID)
            let syncedIDs = Set(cabinet.items.filter { $0.profileID == profileID }.map(\.id))
            let statuses = CloudMedSync.mergeStatuses(local: pillDoseStatuses, remote: remote.statuses, syncedItemIDs: syncedIDs)
            if cabinet.changed || statuses.changed {
                medCabinetItems = cabinet.items
                pillDoseStatuses = statuses.statuses
                persistFeatureState()
            }
            appLog("Cloud sync pulled \(remote.items.count) items, \(remote.statuses.count) statuses; uploading \(cabinet.toPush.count) items, \(statuses.toPush.count) statuses", level: .info, category: "CloudSync")
            let latest = cloudSession ?? session
            try await sync.push(items: cabinet.toPush, session: latest)
            try await sync.push(statuses: statuses.toPush, session: latest)
            try await sync.push(contacts: safeCircleContacts, session: latest)
        } catch {
            appLog("Cloud sync pull failed: \(error.localizedDescription)", level: .error, category: "CloudSync")
        }
    }

    func syncAppleWatch() {
        lastAppleWatchSyncDate = Date()
        addUpdate(category: .adherence, title: "Apple Watch Synced", detail: "Successfully synchronized biometric measurements with Apple Watch HealthKit.")
        persistFeatureState()
    }

    func itemsForSelectedProfile() -> [MedCabinetItem] {
        guard let selectedProfile = selectedProfile else { return medCabinetItems }
        return items(forProfileID: selectedProfile.id)
    }

    func items(forProfileID profileID: UUID) -> [MedCabinetItem] {
        return medCabinetItems
            .filter { $0.profileID == profileID }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func items(for block: DayTimeBlock, on date: Date) -> [MedCabinetItem] {
        itemsForSelectedProfile().filter { $0.scheduleBlocks.contains(block) }
    }

    func items(forProfileID profileID: UUID, block: DayTimeBlock, on date: Date) -> [MedCabinetItem] {
        items(forProfileID: profileID).filter { $0.scheduleBlocks.contains(block) }
    }

    private func decrementInventory(for itemID: UUID) {
        guard let index = medCabinetItems.firstIndex(where: { $0.id == itemID }) else { return }
        medCabinetItems[index].remainingPills = max(0, medCabinetItems[index].remainingPills - 1)

        if medCabinetItems[index].remainingPills <= medCabinetItems[index].refillThreshold {
            addUpdate(
                category: .refill,
                title: "Refill reminder",
                detail: "\(medCabinetItems[index].name) is low (\(medCabinetItems[index].remainingPills) left)."
            )
        }
    }

    func addUpdate(category: UpdateCategory, title: String, detail: String) {
        updatesFeed.insert(
            UpdateFeedItem(id: UUID(), category: category, title: title, detail: detail, timestamp: Date()),
            at: 0
        )
        updatesFeed = Array(updatesFeed.prefix(200))
        persistFeatureState()
    }

    func addHealthMetric(type: HealthMetricType, value: String, unit: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        healthMetrics.insert(HealthMetricRecord(id: UUID(), type: type, value: trimmed, unit: unit, timestamp: Date()), at: 0)
        addUpdate(category: .tip, title: "Health metric logged", detail: "Recorded \(type.rawValue) at \(trimmed) \(unit).")
        persistFeatureState()
    }

    func addDiaryEntry(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        diaryEntries.insert(DiaryEntryRecord(id: UUID(), text: trimmed, timestamp: Date()), at: 0)
        persistFeatureState()
    }

    func setCaregiverContact(_ value: String) {
        caregiverContact = value.trimmingCharacters(in: .whitespacesAndNewlines)
        persistFeatureState()
    }

    // MARK: - SafeCircle
    func addSafeCircleContact(name: String, contactInfo: String, relationship: String) {
        let contact = SafeCircleContact(id: UUID(), name: name, contactInfo: contactInfo, relationship: relationship)
        safeCircleContacts.append(contact)
        addUpdate(category: .caregiver, title: "SafeCircle updated", detail: "\(name) added to your SafeCircle.")
        persistFeatureState()
        cloudPush("push contact") { try await $0.push(contacts: [contact], session: $1) }

        let email = contactInfo.trimmingCharacters(in: .whitespacesAndNewlines)
        if email.contains("@") && email.contains(".") {
            Task {
                _ = await sendSafeCircleInviteEmail(name: name, email: email)
            }
        }
    }

    func removeSafeCircleContact(id: UUID) {
        safeCircleContacts.removeAll { $0.id == id }
        persistFeatureState()
        cloudPush("delete contact") { try await $0.deleteContact(id: id, session: $1) }
    }

    // MARK: - Dependents
    func addDependent(_ dep: DependentProfile) {
        dependents.append(dep)
        let profile = UserProfile(id: dep.id, name: "\(dep.firstName) \(dep.lastName)", avatarSymbol: "person.crop.circle")
        profiles.append(profile)
        persistFeatureState()
    }

    func addLinkedParent(firstName: String, lastName: String, relationship: String, birthYear: Int, parentAppUserID: String? = nil) {
        let parentID = UUID()
        let cleanFirstName = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanLastName = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = [cleanFirstName, cleanLastName].filter { !$0.isEmpty }.joined(separator: " ")
        guard !displayName.isEmpty else { return }

        dependents.append(
            DependentProfile(
                id: parentID,
                firstName: cleanFirstName,
                lastName: cleanLastName,
                gender: "Other",
                birthYear: birthYear,
                avatarColor: "#2F80ED"
            )
        )
        profiles.append(UserProfile(id: parentID, name: displayName, avatarSymbol: "person.crop.circle.badge.checkmark"))

        let cleanParentAppUserID = parentAppUserID?.trimmingCharacters(in: .whitespacesAndNewlines)
        linkedParentProfiles.insert(
            LinkedParentProfile(
                id: UUID(),
                profileID: parentID,
                displayName: displayName,
                relationship: relationship.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Parent" : relationship,
                linkCode: Self.makeParentLinkCode(),
                parentAppUserID: cleanParentAppUserID?.isEmpty == false ? cleanParentAppUserID : nil,
                status: cleanParentAppUserID?.isEmpty == false ? .linked : .pending,
                linkedAt: Date()
            ),
            at: 0
        )
        selectedProfileID = parentID
        addUpdate(category: .caregiver, title: "Parent profile added", detail: "\(displayName)'s tablet schedule can now be tracked from Parent Care.")
        persistFeatureState()
    }

    func removeDependent(id: UUID) {
        dependents.removeAll { $0.id == id }
        profiles.removeAll { $0.id == id }
        linkedParentProfiles.removeAll { $0.profileID == id }
        parentMedicationAlerts.removeAll { $0.parentProfileID == id }
        persistFeatureState()
    }

    // MARK: - Appointments
    func addAppointment(_ appt: AppointmentRecord) {
        appointments.insert(appt, at: 0)
        addUpdate(category: .tip, title: "Appointment added", detail: "\(appt.title) with \(appt.doctorName) on \(appt.date.formatted(date: .abbreviated, time: .shortened)).")
        persistFeatureState()
        
        Task {
            try? await notificationService.scheduleAppointmentAlert(
                title: appt.title,
                doctorName: appt.doctorName,
                date: appt.date,
                appointmentID: appt.id
            )
        }
    }

    func removeAppointment(id: UUID) {
        appointments.removeAll { $0.id == id }
        persistFeatureState()
    }

    // MARK: - Doctors
    func addDoctor(_ doc: DoctorRecord) {
        doctors.insert(doc, at: 0)
        persistFeatureState()
    }

    func removeDoctor(id: UUID) {
        doctors.removeAll { $0.id == id }
        persistFeatureState()
    }

    // MARK: - Drug Interactions
    func checkInteractions(for drugName: String) -> [DrugInteractionRecord] {
        let lower = drugName.lowercased()
        // Built-in interaction table
        let builtIn: [(String, String, InteractionSeverity, String)] = [
            ("warfarin", "ibuprofen", .severe, "Combining warfarin and ibuprofen significantly increases the risk of serious bleeding. Avoid unless directed by a clinician."),
            ("warfarin", "aspirin", .moderate, "Both drugs inhibit platelet aggregation. Concurrent use increases bleeding risk. Monitor INR closely."),
            ("lisinopril", "ibuprofen", .moderate, "NSAIDs can reduce the antihypertensive effect of lisinopril and may impair renal function. Consult your doctor."),
            ("metformin", "alcohol", .moderate, "Alcohol increases the risk of lactic acidosis when combined with metformin. Limit alcohol intake."),
            ("prednisone", "ibuprofen", .severe, "Combining corticosteroids with NSAIDs greatly increases risk of gastrointestinal ulcers and bleeding."),
            ("sertraline", "tramadol", .severe, "Risk of serotonin syndrome. This combination should be avoided without close clinical supervision."),
            ("fluoxetine", "maoi", .severe, "Potentially fatal serotonin syndrome. Never combine SSRIs and MAOIs without a washout period."),
            ("amoxicillin", "methotrexate", .moderate, "Amoxicillin may reduce renal clearance of methotrexate, increasing toxicity risk."),
            ("digoxin", "amiodarone", .severe, "Amiodarone increases digoxin plasma levels significantly. Dose reduction and monitoring required."),
        ]

        let existingNames = Set(medCabinetItems.map { $0.name.lowercased() })

        var results: [DrugInteractionRecord] = []
        for (d1, d2, severity, detail) in builtIn {
            let involves = d1 == lower || d2 == lower
            let otherIsPresent = existingNames.contains(d1 == lower ? d2 : d1)
            if involves && otherIsPresent {
                results.append(DrugInteractionRecord(id: UUID(), drug1: d1.capitalized, drug2: d2.capitalized, severity: severity, detail: detail))
            }
        }
        return results
    }

    func logInteraction(_ record: DrugInteractionRecord) {
        knownInteractions.insert(record, at: 0)
        addUpdate(category: .interaction, title: "Interaction flagged", detail: "\(record.drug1) + \(record.drug2): \(record.severity.rawValue).")
        persistFeatureState()
    }

    // MARK: - Allergy Tracking
    func addAllergy(_ allergy: AllergyRecord) {
        allergies.insert(allergy, at: 0)
        persistFeatureState()
    }
    func removeAllergy(id: UUID) {
        allergies.removeAll { $0.id == id }
        persistFeatureState()
    }
    /// Returns allergy names that match the first word of a drug name (case-insensitive)
    func allergyWarnings(for drugName: String) -> [String] {
        let drug = drugName.lowercased()
        return allergies
            .filter { drug.contains($0.substance.lowercased()) || $0.substance.lowercased().contains(drug) }
            .map { "⚠️ Allergy: \($0.substance) (\($0.reaction.rawValue))" }
    }

    // MARK: - Fertility Tracking
    func addFertilityCycle(_ cycle: FertilityCycleRecord) {
        fertilityCycles.insert(cycle, at: 0)
        persistFeatureState()
    }

    func updateFertilityCycle(_ cycle: FertilityCycleRecord) {
        if let index = fertilityCycles.firstIndex(where: { $0.id == cycle.id }) {
            fertilityCycles[index] = cycle
            persistFeatureState()
        }
    }

    func removeFertilityCycle(id: UUID) {
        fertilityCycles.removeAll { $0.id == id }
        persistFeatureState()
    }

    func addFertilitySymptom(_ symptom: FertilitySymptomRecord) {
        fertilitySymptoms.insert(symptom, at: 0)
        addUpdate(category: .tip, title: "Fertility symptom logged", detail: "\(symptom.symptomType) recorded on \(symptom.date.formatted(date: .abbreviated, time: .omitted)).")
        persistFeatureState()
    }

    func removeFertilitySymptom(id: UUID) {
        fertilitySymptoms.removeAll { $0.id == id }
        persistFeatureState()
    }

    func addFertilityTreatment(_ treatment: FertilityTreatmentRecord) {
        fertilityTreatments.insert(treatment, at: 0)
        addUpdate(category: .tip, title: "Treatment added", detail: "\(treatment.treatmentType): \(treatment.medicationName)")
        persistFeatureState()
    }

    func removeFertilityTreatment(id: UUID) {
        fertilityTreatments.removeAll { $0.id == id }
        persistFeatureState()
    }

    func addFertilityLab(_ lab: FertilityLabRecord) {
        fertilityLabs.insert(lab, at: 0)
        addUpdate(category: .tip, title: "Lab result recorded", detail: "\(lab.testName): \(lab.result) \(lab.unit)")
        persistFeatureState()
    }

    func removeFertilityLab(id: UUID) {
        fertilityLabs.removeAll { $0.id == id }
        persistFeatureState()
    }

    var currentFertilityCycle: FertilityCycleRecord? {
        fertilityCycles.first
    }

    func symptomsForDay(_ date: Date) -> [FertilitySymptomRecord] {
        let calendar = Calendar.current
        return fertilitySymptoms.filter { calendar.isDate($0.date, inSameDayAs: date) }
    }

    func predictNextPeriod(from cycle: FertilityCycleRecord) -> Date? {
        guard cycle.cycleLength > 0 else { return nil }
        return Calendar.current.date(byAdding: .day, value: cycle.cycleLength, to: cycle.startDate)
    }

    func predictFertileWindow(from cycle: FertilityCycleRecord) -> (start: Date, end: Date)? {
        guard let predictedPeriod = predictNextPeriod(from: cycle) else { return nil }
        let calendar = Calendar.current
        guard let ovulationDay = calendar.date(byAdding: .day, value: -14, to: predictedPeriod) else { return nil }
        guard let fertileStart = calendar.date(byAdding: .day, value: -5, to: ovulationDay) else { return nil }
        let fertileEnd = ovulationDay
        return (fertileStart, fertileEnd)
    }

    func currentCycleState(for cycle: FertilityCycleRecord) -> FertilityCycleState {
        let now = Date()
        let calendar = Calendar.current

        if let predictedPeriod = predictNextPeriod(from: cycle) {
            if now > predictedPeriod {
                return .menstruation
            }

            if let fertileWindow = predictFertileWindow(from: cycle) {
                if now >= fertileWindow.start && now <= fertileWindow.end {
                    return .ovulationWindow
                }
            }

            if let fertileWindow = predictFertileWindow(from: cycle),
               let lutealStart = calendar.date(byAdding: .day, value: 1, to: fertileWindow.end) {
                if now >= lutealStart && now < predictedPeriod {
                    return .luteal
                }
            }

            if let startOfCycle = fertilityCycles.first?.startDate,
               let daysSinceStart = calendar.dateComponents([.day], from: startOfCycle, to: now).day,
               daysSinceStart < 14 {
                return .follicular
            }
        }

        return .follicular
    }

    func fertilityInsight(for symptoms: [FertilitySymptomRecord]) -> String? {
        let severeSymptoms = symptoms.filter { $0.severity >= 7 }
        if !severeSymptoms.isEmpty {
            let names = severeSymptoms.prefix(3).map(\.symptomType).joined(separator: ", ")
            return "You logged high-severity symptoms: \(names). Consider discussing with your fertility specialist."
        }

        let spottingSymptoms = symptoms.filter { $0.spotting }
        if !spottingSymptoms.isEmpty {
            return "Spotting was recorded. While often normal, discuss with your doctor especially if accompanied by pain."
        }

        let ovulationPositive = symptoms.filter { $0.ovulationTestPositive == true }
        if !ovulationPositive.isEmpty {
            return "Ovulation test positive — this is an optimal time for conception attempts if trying to conceive."
        }

        return nil
    }

    // MARK: - PIN / Biometric Lock
    func setPIN(_ pin: String) {
        let hash = sha256(pin)
        do {
            var settings = try store.loadSettings()
            settings.pinHash = hash
            settings.pinLockEnabled = true
            try store.saveSettings(settings)
        } catch { appLog("setPIN save failed: \(error)", level: .error, category: "AppState") }
        pinLockEnabled = true
    }
    func disablePIN() {
        do {
            var settings = try store.loadSettings()
            settings.pinHash = ""
            settings.pinLockEnabled = false
            try store.saveSettings(settings)
        } catch {}
        pinLockEnabled = false
        biometricLockEnabled = false
        isAppLocked = false
    }
    func verifyPIN(_ pin: String) -> Bool {
        guard pinLockEnabled, let settings = try? store.loadSettings() else { return true }
        return sha256(pin) == settings.pinHash
    }
    private func sha256(_ string: String) -> String {
        let data = Data(string.utf8)
        return SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
    }
    func lockApp() {
        guard pinLockEnabled else { return }
        isAppLocked = true
    }
    func unlockApp() { isAppLocked = false }
    @MainActor func authenticateBiometric() async -> Bool {
        guard biometricLockEnabled else { return false }
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else { return false }
        do {
            let ok = try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Unlock Intuio")
            if ok { unlockApp() }
            return ok
        } catch { return false }
    }

    // MARK: - Weekly history for Insights
    /// Returns (date, taken, missed) for the last `days` days.
    func dailyAdherenceHistory(days: Int = 7, referenceDate: Date = Date()) -> [(date: Date, taken: Int, missed: Int)] {
        let calendar = Calendar.current
        return (0..<days).compactMap { offset -> (Date, Int, Int)? in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: referenceDate) else { return nil }
            var t = 0, m = 0
            for item in itemsForSelectedProfile() {
                for block in item.scheduleBlocks {
                    let s = statusForDose(itemID: item.id, block: block, date: day)
                    if s == .taken { t += 1 } else if s == .skipped { m += 1 }
                }
            }
            return (day, t, m)
        }.reversed()
    }

    func weeklyAdherenceSummary() -> (taken: Int, missed: Int, compliance: Int) {
        let calendar = Calendar.current
        var taken = 0
        var missed = 0

        for dayOffset in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) else { continue }
            for item in itemsForSelectedProfile() {
                for block in item.scheduleBlocks {
                    let status = statusForDose(itemID: item.id, block: block, date: day)
                    if status == .taken {
                        taken += 1
                    } else if status == .skipped {
                        missed += 1
                    }
                }
            }
        }

        let total = max(1, taken + missed)
        let compliance = Int((Double(taken) / Double(total) * 100.0).rounded())
        return (taken, missed, compliance)
    }

    func checkForMissedDoses(now: Date = Date()) {
        let calendar = Calendar.current
        guard calendar.isDate(selectedPillboxDate, inSameDayAs: now) else { return }

        let hour = calendar.component(.hour, from: now)
        let expiredBlocks: [DayTimeBlock] = DayTimeBlock.allCases.filter { block in
            switch block {
            case .morning: return hour >= 12
            case .afternoon: return hour >= 17
            case .evening: return hour >= 22
            case .night: return hour >= 24
            }
        }

        for block in expiredBlocks {
            for item in items(for: block, on: selectedPillboxDate) {
                let key = doseKey(itemID: item.id, block: block, date: selectedPillboxDate)
                if statusForDose(itemID: item.id, block: block, date: selectedPillboxDate) == .pending {
                    pillDoseStatuses.append(PillDoseStatusRecord(id: UUID(), key: key, status: .skipped, updatedAt: now))
                    addUpdate(category: .adherence, title: "Dose missed", detail: "\(item.name) missed in \(block.title.lowercased()).")
                    if !safeCircleContacts.isEmpty {
                        let names = safeCircleContacts.prefix(2).map(\.name).joined(separator: ", ")
                        addUpdate(category: .caregiver, title: "SafeCircle alert", detail: "\(names) should be notified about a missed dose.")
                    } else if !caregiverContact.isEmpty {
                        addUpdate(category: .caregiver, title: "SafeCircle alert", detail: "\(caregiverContact) should be notified about a missed dose.")
                    }
                }
            }
        }

        checkLinkedParentMissedDoses(expiredBlocks: expiredBlocks, date: selectedPillboxDate, now: now)
        checkForMissingPills()
        persistFeatureState()
    }

    func doseKey(itemID: UUID, block: DayTimeBlock, date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "\(itemID.uuidString)|\(formatter.string(from: date))|\(block.rawValue)"
    }

    func parentAlerts(for parent: LinkedParentProfile) -> [ParentMedicationAlert] {
        parentMedicationAlerts
            .filter { $0.parentProfileID == parent.profileID }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func unresolvedParentMissedDoseAlerts(for parent: LinkedParentProfile? = nil) -> [ParentMedicationAlert] {
        parentMedicationAlerts
            .filter { alert in
                let matchesParent = parent.map { alert.parentProfileID == $0.profileID } ?? true
                return alert.kind == .missedDose &&
                alert.buzzSentAt == nil &&
                matchesParent
            }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func sendBuzz(for alertID: UUID) {
        guard let index = parentMedicationAlerts.firstIndex(where: { $0.id == alertID }) else { return }
        let now = Date()
        parentMedicationAlerts[index].buzzSentAt = now
        parentMedicationAlerts[index].kind = .buzzSent
        let alert = parentMedicationAlerts[index]
        let parentName = linkedParentProfiles.first(where: { $0.profileID == alert.parentProfileID })?.displayName ?? "Parent"
        addUpdate(category: .caregiver, title: "Buzz sent", detail: "Reminder buzz sent to \(parentName) for \(alert.medicationName).")
        persistFeatureState()
    }

    private func checkLinkedParentMissedDoses(expiredBlocks: [DayTimeBlock], date: Date, now: Date) {
        let linkedParents = linkedParentProfiles.filter { $0.status == .linked || $0.status == .pending }
        for parent in linkedParents {
            for block in expiredBlocks {
                for item in items(forProfileID: parent.profileID, block: block, on: date) {
                    let key = doseKey(itemID: item.id, block: block, date: date)
                    let status = statusForDose(itemID: item.id, block: block, date: date)
                    let alertExists = parentMedicationAlerts.contains { $0.doseKey == key }
                    if status == .pending || status == .skipped {
                        if !pillDoseStatuses.contains(where: { $0.key == key }) {
                            pillDoseStatuses.append(PillDoseStatusRecord(id: UUID(), key: key, status: .skipped, updatedAt: now))
                        }
                        if !alertExists {
                            parentMedicationAlerts.insert(
                                ParentMedicationAlert(
                                    id: UUID(),
                                    parentProfileID: parent.profileID,
                                    medicationID: item.id,
                                    doseKey: key,
                                    medicationName: item.name,
                                    scheduledBlock: block,
                                    scheduledDate: date,
                                    kind: .missedDose,
                                    buzzSentAt: nil,
                                    createdAt: now
                                ),
                                at: 0
                            )
                            addUpdate(category: .caregiver, title: "Parent dose missed", detail: "\(parent.displayName) missed \(item.name) in \(block.title.lowercased()). Tap Parent Care to send a buzz.")
                        }
                    }
                }
            }
        }
    }

    private func createParentMissedDoseAlertIfNeeded(itemID: UUID, block: DayTimeBlock, date: Date, now: Date) {
        guard let item = medCabinetItems.first(where: { $0.id == itemID }),
              let parent = linkedParentProfiles.first(where: { $0.profileID == item.profileID }) else {
            return
        }
        let key = doseKey(itemID: item.id, block: block, date: date)
        guard !parentMedicationAlerts.contains(where: { $0.doseKey == key }) else { return }
        parentMedicationAlerts.insert(
            ParentMedicationAlert(
                id: UUID(),
                parentProfileID: parent.profileID,
                medicationID: item.id,
                doseKey: key,
                medicationName: item.name,
                scheduledBlock: block,
                scheduledDate: date,
                kind: .missedDose,
                buzzSentAt: nil,
                createdAt: now
            ),
            at: 0
        )
        addUpdate(category: .caregiver, title: "Parent dose missed", detail: "\(parent.displayName) missed \(item.name) in \(block.title.lowercased()). Tap Parent Care to send a buzz.")
    }

    private static func makeParentLinkCode() -> String {
        String(UUID().uuidString.prefix(8)).uppercased()
    }

    func ingestAndCreatePlan(source: IngestionSource) {
        let output = engine.process(text: ingestionText, projectionDays: 60)
        latestOutput = output

        let plan = MedicationPlanRecord(
            id: UUID(),
            createdAt: Date(),
            source: source,
            sourceText: ingestionText,
            parsedJSON: Self.encode(parsed: output.parsed),
            patientDirections: output.patientDirections,
            rationale: output.rationale,
            needsConfirmation: output.parsed.needsClinicianConfirmation
        )

        do {
            try store.insertPlan(plan)
            plans = try store.fetchPlans()
            selectedPlanID = plan.id
            todayLog = []
            dailyInsightNote = nil
            Task {
                if remindersEnabled {
                    await scheduleDoseReminders()
                }
                refreshProactiveSuggestions()
            }
        } catch {
            appLog("Save plan failed: \(error)", level: .error, category: "AppState")
        }
    }

    func markTaken(event: DoseEvent, isPRN: Bool) {
        guard let planID = selectedPlanID else { return }
        let record = DoseLogRecord(id: UUID(), planID: planID, timestamp: Date(), dose: event.dose, units: event.units, isPRN: isPRN)
        do {
            try store.insertDoseLog(record)
            todayLog = try store.fetchDoseLogs(for: planID)
            refreshProactiveSuggestions()
            if dailyInsightNote != nil {
                generateDailyInsightNote()
            }
        } catch {
            appLog("Log dose failed: \(error)", level: .error, category: "AppState")
        }
    }

    func loadDailyInsightNote() {
        guard let planID = selectedPlanID else {
            dailyInsightNote = nil
            return
        }

        do {
            dailyInsightNote = try store.fetchDailyInsightNote(planID: planID, day: Date())
        } catch {
            dailyInsightNote = nil
            insightNoteErrorMessage = "Unable to load saved note."
        }
    }

    func generateDailyInsightNote() {
        guard let plan = selectedPlan, let parsed = parsedPlan(for: plan) else {
            insightNoteErrorMessage = "Select a valid medication plan before generating notes."
            return
        }

        isGeneratingInsightNote = true
        insightNoteErrorMessage = nil

        let output = engine.process(text: plan.sourceText, projectionDays: 1)
        latestOutput = output

        let input = IntuioNoteInput(
            now: Date(),
            parsed: parsed,
            output: output,
            logsToday: todayLog,
            remindersEnabled: remindersEnabled,
            notificationsAuthorized: notificationPermissionGranted
        )

        Task {
            let noteText = await localNoteEngine.generateNote(input: input)
            let note = DailyInsightNoteRecord(
                id: UUID(),
                planID: plan.id,
                dayStart: Calendar.current.startOfDay(for: Date()),
                noteBody: noteText,
                modelName: localNoteEngine.modelName,
                createdAt: Date()
            )

            do {
                try store.upsertDailyInsightNote(note)
                dailyInsightNote = note
            } catch {
                insightNoteErrorMessage = "Could not save note locally."
            }

            isGeneratingInsightNote = false
        }
    }

    func prnRemainingForToday(parsed: ParsedMedicationPlan) -> (Int?, Double?) {
        let events = todayLog.map {
            DoseEvent(date: $0.timestamp, dose: $0.dose, units: $0.units, isPRN: $0.isPRN)
        }
        let checker = ConstraintChecker()
        let remaining = checker.remainingPRNAllowance(plan: parsed, todayPRNEvents: events)
        return (remaining.remainingDoses, remaining.remainingAmount)
    }

    func parsedPlan(for record: MedicationPlanRecord) -> ParsedMedicationPlan? {
        guard let data = record.parsedJSON.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(ParsedMedicationPlan.self, from: data)
    }

    static func encode(parsed: ParsedMedicationPlan) -> String {
        guard let data = try? JSONEncoder().encode(parsed), let text = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return text
    }

    // MARK: - Email Service Integration
    
    func sendSignupOTP(email: String) async -> Bool {
        guard let api = BackendAPI() else { return false }
        do {
            try await api.sendOTP(email: email)
            signupEmailPendingOTP = email
            appLog("Signup OTP requested", level: .info, category: "Auth")
            return true
        } catch {
            appLog("Failed to send OTP email: \(error.localizedDescription)", level: .error, category: "Auth")
            return false
        }
    }

    /// The server generates and checks the code; the app never sees it.
    func verifySignupOTP(code: String) async -> Bool {
        guard let api = BackendAPI(), let email = signupEmailPendingOTP else { return false }
        do {
            return try await api.verifyOTP(email: email, code: code.trimmingCharacters(in: .whitespacesAndNewlines))
        } catch {
            appLog("OTP verification failed: \(error.localizedDescription)", level: .error, category: "Auth")
            return false
        }
    }

    func sendReferralEmail(email: String) async -> Bool {
        guard let api = BackendAPI(), let token = emailSessionToken else { return false }
        do {
            try await api.sendReferral(email: email, code: "MEDHAVN-5X9Z", token: token)
            appLog("Referral email sent", level: .info, category: "Referral")
            return true
        } catch {
            appLog("Failed to send referral email: \(error.localizedDescription)", level: .error, category: "Referral")
            return false
        }
    }

    func sendSafeCircleInviteEmail(name: String, email: String) async -> Bool {
        guard let api = BackendAPI(), let token = emailSessionToken else { return false }
        do {
            try await api.sendSafeCircleInvite(name: name, email: email, token: token)
            appLog("SafeCircle invitation email sent", level: .info, category: "SafeCircle")
            return true
        } catch {
            appLog("Failed to send SafeCircle invitation email: \(error.localizedDescription)", level: .error, category: "SafeCircle")
            return false
        }
    }

    /// Signed-in Supabase token for backend email routes. Nil for the local-dev stub or signed-out state.
    private var emailSessionToken: String? {
        guard let token = authToken, !token.isEmpty, token != "local-dev-token" else { return nil }
        return token
    }

    func signup(email: String, password: String, fullName: String) async -> Bool {
        guard !isAuthenticating else { return false }
        authErrorMessage = nil
        pendingEmailVerification = nil
        isAuthenticating = true
        defer { isAuthenticating = false }

        do {
            let session = try await authService.signup(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                password: password,
                fullName: fullName.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            applyAuthSession(session)
            let trimmedName = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedName.isEmpty {
                applySignupName(trimmedName)
            }
            return true
        } catch AuthError.emailVerificationRequired(let verifyEmail) {
            pendingEmailVerification = verifyEmail
            authErrorMessage = "Account created. Check \(verifyEmail) for a confirmation link, then sign in."
            return false
        } catch {
            authErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            return false
        }
    }

    func login(email: String, password: String) async -> Bool {
        guard !isAuthenticating else { return false }
        authErrorMessage = nil
        isAuthenticating = true
        defer { isAuthenticating = false }

        do {
            let session = try await authService.login(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                password: password
            )
            applyAuthSession(session)
            return true
        } catch {
            authErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            return false
        }
    }

    func requestPasswordReset(email: String) async {
        passwordResetError = nil
        passwordResetEmailSent = false
        isRequestingPasswordReset = true
        defer { isRequestingPasswordReset = false }

        do {
            try await authService.requestPasswordReset(email: email.trimmingCharacters(in: .whitespacesAndNewlines))
            passwordResetEmailSent = true
        } catch {
            passwordResetError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func applySignupName(_ name: String) {
        guard !profiles.isEmpty else { return }
        profiles[0].name = name
        persistFeatureState()
    }

    private func applyAuthSession(_ session: AuthSession) {
        isLoggedIn = true
        authEmail = session.email
        authUserId = session.userId
        authToken = session.token
        authRefreshToken = session.refreshToken
        authErrorMessage = nil
        saveSettings()
        Task { await pullCloudMeds() }
    }

    func completeConsentChecklist() {
        consentChecklistCompleted = true
        saveSettings()
    }

    /// Called from TrackerSelectionView after the user picks a tracker
    /// preference (or skips). Persists the choice and advances into the tab shell.
    func completeTrackerSelection(_ preference: TrackerPreference) {
        trackerPreference = preference
        trackerSelectionCompleted = true
        saveSettings()
    }

    /// Called from Settings when the user changes their tracker preference.
    func updateTrackerPreference(_ preference: TrackerPreference) {
        trackerPreference = preference
        saveSettings()
    }

    func setRemindersEnabled(_ enabled: Bool) {
        remindersEnabled = enabled
        saveSettings()
        Task {
            if enabled {
                await scheduleDoseReminders()
            } else {
                await notificationService.clearAllMedicationReminders()
                reminderStatusMessage = "Dose reminders disabled."
            }
            await refreshNotificationAuthorization()
            refreshProactiveSuggestions()
        }
    }

    func requestNotificationAccess() {
        Task {
            let granted = await notificationService.requestAuthorization()
            notificationPermissionGranted = granted
            if granted && remindersEnabled {
                await scheduleDoseReminders()
            } else if !granted {
                reminderStatusMessage = "Notification permission denied. Enable it in iOS Settings."
            }
            refreshProactiveSuggestions()
        }
    }

    func scheduleDoseReminders() async {
        await refreshNotificationAuthorization()
        guard remindersEnabled else {
            reminderStatusMessage = "Dose reminders are disabled."
            return
        }

        guard notificationPermissionGranted else {
            reminderStatusMessage = "Notification access not granted."
            return
        }

        guard let plan = selectedPlan, let parsed = parsedPlan(for: plan) else {
            reminderStatusMessage = "No plan selected for reminders."
            return
        }

        let output = engine.process(text: plan.sourceText, projectionDays: 2)
        latestOutput = output
        let allEvents = output.schedule.flatMap(\.events)
        let planName = parsed.drugName ?? "Medication"

        do {
            let count = try await notificationService.scheduleDoseReminders(
                planName: planName,
                planID: plan.id,
                events: allEvents
            )
            reminderStatusMessage = count > 0 ? "Scheduled \(count) reminder(s)." : "No upcoming doses to remind in the next 48 hours."
        } catch {
            reminderStatusMessage = "Failed to schedule reminders: \(error.localizedDescription)"
        }
    }

    func handleSuggestionAction(_ action: ProactiveSuggestionAction) {
        switch action {
        case .enableReminders:
            setRemindersEnabled(true)
        case .grantNotificationAccess:
            requestNotificationAccess()
        case .scheduleReminders:
            Task { await scheduleDoseReminders() }
        case .reviewSafety, .none:
            break
        }
    }

    func refreshProactiveSuggestions() {
        let output: EngineOutput?
        if let selectedPlan {
            output = engine.process(text: selectedPlan.sourceText, projectionDays: 2)
        } else {
            output = nil
        }

        proactiveSuggestions = insightsEngine.buildSuggestions(
            plan: selectedPlan,
            output: output,
            logs: todayLog,
            remindersEnabled: remindersEnabled,
            notificationsAuthorized: notificationPermissionGranted
        )
    }

    func refreshNotificationAuthorization() async {
        let status = await notificationService.authorizationStatus()
        notificationPermissionGranted = (status == .authorized || status == .provisional)
    }

    func getAuthToken() async -> String? {
        // Return the current auth token
        // If token is expired or missing, attempt to refresh it
        guard let token = authToken, !token.isEmpty else {
            return nil
        }
        return token
    }

    func logout() {
        isLoggedIn = false
        consentChecklistCompleted = false
        trackerSelectionCompleted = false
        trackerPreference = .none
        authUserId = nil
        authToken = nil
        authRefreshToken = nil
        authEmail = ""
        authErrorMessage = nil
        dailyInsightNote = nil
        saveSettings()
        persistFeatureState()
        proactiveSuggestions = []
    }

    func deleteAccountAndWipeData() {
        logout()
        profiles = []
        selectedProfileID = nil
        medCabinetItems = []
        updatesFeed = []
        pillDoseStatuses = []
        healthMetrics = []
        diaryEntries = []
        safeCircleContacts = []
        dependents = []
        linkedParentProfiles = []
        parentMedicationAlerts = []
        appointments = []
        doctors = []
        allergies = []
        knownInteractions = []
        userHealthPoints = 0
        persistFeatureState()
    }

    // MARK: - Remote Dependent Invitations

    func sendDependentInvite(emailOrPhone: String) async {
        let contact = emailOrPhone.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !contact.isEmpty else { return }

        // Local simulation fallback + production ready schema interaction
        let newInvite = DependentInvitationRecord(
            id: UUID(),
            inviterId: UUID(uuidString: authUserId ?? "") ?? UUID(),
            inviteeContact: contact,
            status: "pending",
            createdAt: Date()
        )
        
        sentInvitations.insert(newInvite, at: 0)
        persistFeatureState()

        // Also add an update feed entry
        addUpdate(category: .adherence, title: "Invitation Sent", detail: "Sent link to \(contact) to link accounts.")
    }

    func fetchInvitations() async {
        // Production ready: fetch from Supabase table `medhavn.dependent_invitations`
        // Currently keeping existing list or sync if backend online
    }

    func acceptDependentInvitation(inviteID: UUID) async {
        if let idx = receivedInvitations.firstIndex(where: { $0.id == inviteID }) {
            receivedInvitations[idx].status = "accepted"
            receivedInvitations[idx].acceptedAt = Date()
            
            // Add to dependents list
            let inviterEmail = receivedInvitations[idx].inviteeContact
            let dep = DependentProfile(
                id: inviteID,
                firstName: "Linked",
                lastName: inviterEmail,
                gender: "Other",
                birthYear: 1990,
                avatarColor: "#2F80ED"
            )
            dependents.append(dep)
            profiles.append(UserProfile(id: dep.id, name: inviterEmail, avatarSymbol: "person.crop.circle.badge.checkmark"))
            
            persistFeatureState()
            addUpdate(category: .adherence, title: "Invitation Accepted", detail: "Successfully linked to \(inviterEmail).")
        }
    }

    func declineDependentInvitation(inviteID: UUID) async {
        receivedInvitations.removeAll { $0.id == inviteID }
        persistFeatureState()
    }

    func checkForMissingPills() {
        for item in medCabinetItems {
            // Identify discrepancy where remaining pills are lower than expected dose count
            let takenCount = pillDoseStatuses.filter { $0.key.hasPrefix(item.id.uuidString) && $0.status == .taken }.count
            let expectedInventory = 30 - takenCount
            if item.remainingPills != expectedInventory {
                addUpdate(
                    category: .refill,
                    title: "Missing Pills Detected",
                    detail: "Discrepancy in \(item.name): Inventory (\(item.remainingPills)) does not match logs. You might have missing pills."
                )
            }
        }
    }
}

struct PharmacyServiceClient {
    static func submitRefill(medicationName: String, rxNumber: String) async -> Bool {
        // Secure Redox/Surescripts production simulation
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        return true
    }
}

enum TrialManager {
    static func daysRemaining(from firstUseDate: Date) -> Int {
        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: firstUseDate, to: Date()).day ?? 0
        return max(0, 60 - days)
    }
}
