import SwiftUI
import MedicationLogicEngine
import AVFoundation
import UniformTypeIdentifiers
import PDFKit
import Vision
import UIKit

struct AddPlanView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    private let drugLookupService = DrugLookupService()
    @State private var source: IngestionSource = .manualEntry
    @State private var showScanner = false
    @State private var showFileImporter = false
    @State private var showScannerAlert = false
    @State private var scannerAlertMessage = ""
    @State private var showImportAlert = false
    @State private var importAlertMessage = ""
    @State private var showMedCabinetConfirm = false
    @State private var justAddedMedName = ""
    @State private var pendingAutoScrollToOutput = false
    @State private var sessionAddedCount = 0

    // Multi-medication batch state
    @State private var pendingMedications: [PendingMedicationEntry] = []
    @State private var showBuildSuccess = false
    @State private var lastBuildFailedCount = 0

    private let parsedOutputAnchorID = "parsed-output-anchor"

    // MARK: - Enums

    private enum ManualDoseForm: String, CaseIterable, Identifiable {
        case tablet = "Tablet"
        case pill = "Pill"
        case capsule = "Capsule"
        case puff = "Puff"
        case ml = "mL"

        var id: String { rawValue }

        var parserUnit: String {
            switch self {
            case .tablet: return "tablet"
            case .pill: return "tablet"
            case .capsule: return "capsule"
            case .puff: return "puff"
            case .ml: return "ml"
            }
        }
    }

    private enum ManualFrequencyOption: String, CaseIterable, Identifiable {
        case onceDaily = "Once daily"
        case twiceDaily = "Twice daily"
        case threeTimesDaily = "Three times daily"
        case fourTimesDaily = "Four times daily"
        case asNeeded = "As needed"

        var id: String { rawValue }

        var parserPhrase: String {
            switch self {
            case .onceDaily: return "once daily"
            case .twiceDaily: return "twice daily"
            case .threeTimesDaily: return "three times daily"
            case .fourTimesDaily: return "four times daily"
            case .asNeeded: return "as needed"
            }
        }

        var expectedTimeCount: Int? {
            switch self {
            case .onceDaily: return 1
            case .twiceDaily: return 2
            case .threeTimesDaily: return 3
            case .fourTimesDaily: return 4
            case .asNeeded: return nil
            }
        }
    }

    private enum ManualRouteOption: String, CaseIterable, Identifiable {
        case oral = "By mouth"
        case inhaled = "Inhaled"
        case topical = "Topical"
        case injection = "Injection"

        var id: String { rawValue }

        var parserPhrase: String {
            switch self {
            case .oral: return "by mouth"
            case .inhaled: return "inhaled"
            case .topical: return "topical"
            case .injection: return "inject"
            }
        }
    }

    private struct ManualDoseTime: Identifiable {
        var id = UUID()
        var time: Date

        init(hour: Int, minute: Int) {
            self.time = Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
        }
    }

    // Represents one queued medication before building the plan
    private struct PendingMedicationEntry: Identifiable {
        let id = UUID()
        let name: String
        let doseAmount: String
        let doseForm: ManualDoseForm
        let strength: String
        let frequency: ManualFrequencyOption
        let instructionText: String

        var summary: String {
            var s = "\(doseAmount) \(doseForm.rawValue)"
            if !strength.isEmpty { s += " \(strength)" }
            s += " · \(frequency.rawValue)"
            return s
        }
    }

    // MARK: - Manual Entry State

    @State private var manualMedicationName = ""
    @State private var manualDoseAmount = "1"
    @State private var manualDoseForm: ManualDoseForm = .tablet
    @State private var manualStrength = ""
    @State private var manualRoute: ManualRouteOption = .oral
    @State private var manualFrequency: ManualFrequencyOption = .onceDaily
    @State private var manualDurationDays = "7"
    @State private var manualTimes: [ManualDoseTime] = [ManualDoseTime(hour: 8, minute: 0)]
    @State private var manualPrnMaxDoses = "3"
    @State private var manualPrnMinHours = "6"
    @State private var remoteMedicationSuggestions: [String] = []
    @State private var isLoadingRemoteSuggestions = false
    @State private var remoteSuggestionsError: String?
    @State private var suggestionLookupTask: Task<Void, Never>?

    private let commonMedicationSuggestions = [
        "Acetaminophen", "Albuterol", "Amoxicillin", "Amlodipine", "Aspirin",
        "Atorvastatin", "Azithromycin", "Cetirizine", "Doxycycline", "Ibuprofen",
        "Levothyroxine", "Lisinopril", "Metformin", "Omeprazole", "Prednisone", "Warfarin"
    ]

    private var filteredMedicationSuggestions: [String] {
        let seed = (commonMedicationSuggestions + appState.medCabinetItems.map(\.name) + remoteMedicationSuggestions)
        let unique = Array(Set(seed)).sorted()
        let query = manualMedicationName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }
        return unique
            .filter { $0.localizedCaseInsensitiveContains(query) }
            .prefix(8)
            .map { $0 }
    }

    private var canAddToPending: Bool {
        !manualMedicationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        manualValidationMessages.isEmpty
    }

    private var canBuildPlan: Bool {
        if source == .manualEntry {
            return !pendingMedications.isEmpty
        }
        return !appState.ingestionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var manualValidationMessages: [String] {
        var messages: [String] = []
        let name = manualMedicationName.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty {
            messages.append("Medication name is required.")
        }
        let amount = manualDoseAmount.trimmingCharacters(in: .whitespacesAndNewlines)
        if Double(amount) == nil || (Double(amount) ?? 0) <= 0 {
            messages.append("Dose quantity must be a number greater than 0.")
        }
        if manualFrequency == .asNeeded {
            let maxDoses = manualPrnMaxDoses.trimmingCharacters(in: .whitespacesAndNewlines)
            let minHours = manualPrnMinHours.trimmingCharacters(in: .whitespacesAndNewlines)
            if Int(maxDoses) == nil || (Int(maxDoses) ?? 0) <= 0 {
                messages.append("PRN max doses/day must be greater than 0.")
            }
            if Int(minHours) == nil || (Int(minHours) ?? 0) <= 0 {
                messages.append("PRN minimum hours between doses must be greater than 0.")
            }
        } else {
            if Int(manualDurationDays) == nil || (Int(manualDurationDays) ?? 0) <= 0 {
                messages.append("Duration must be a whole number of days greater than 0.")
            }
            if manualTimes.isEmpty {
                messages.append("Add at least one dose time.")
            }
        }
        return messages
    }

    // MARK: - Body

var body: some View {
        ZStack {
            MeshBackgroundView()
                .ignoresSafeArea()

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 16) {
                        sourcePicker
                            .padding(.top, 8)
                        if source == .manualEntry {
                            manualEntryFormSection
                            if !pendingMedications.isEmpty {
                                pendingMedicationsSection
                                buildPlanSection
                            }
                            if showBuildSuccess {
                                buildSuccessSection
                            }
                        } else {
                            pasteScanSection
                            if let output = appState.latestOutput {
                                parsedOutputSections(output: output, proxy: proxy)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .padding(.bottom, 32)
                }
                .scrollContentBackground(.hidden)
                .onChange(of: appState.latestOutput != nil) { _, hasOutput in
                    guard hasOutput, pendingAutoScrollToOutput else { return }
                    pendingAutoScrollToOutput = false
                    withAnimation(.easeInOut(duration: 0.35)) {
                        proxy.scrollTo(parsedOutputAnchorID, anchor: .top)
                    }
                }
            }
            .navigationTitle("Add Medication")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(AppTheme.primary)
                        .font(.body.weight(.bold))
                }
            }
        }
    }

    private var sourcePicker: some View {
        Picker("Source", selection: $source) {
            Text("Manual Entry").tag(IngestionSource.manualEntry)
            Text("Paste SIG").tag(IngestionSource.pastedSig)
            Text("Scan Label").tag(IngestionSource.scannedDocument)
        }
        .pickerStyle(.segmented)
        .padding(.bottom, 12)
    }

    // MARK: - Manual Entry Form

    @ViewBuilder
    private var manualEntryFormSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            planSectionHeader("Medication Details", symbol: "pills.fill")

            // Name card
            VStack(alignment: .leading, spacing: 12) {
                planFieldLabel("Medication Name", symbol: "pills.fill")

                TextField("e.g. Amlodipine", text: $manualMedicationName)
                    .textInputAutocapitalization(.words)
                    .foregroundStyle(.white)
                    .planTextField()
                    .onChange(of: manualMedicationName) { _, newValue in
                        requestRemoteDrugSuggestions(for: newValue)
                    }

                if isLoadingRemoteSuggestions {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.mini).tint(AppTheme.primary)
                        Text("Searching registry…")
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }

                if !filteredMedicationSuggestions.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(filteredMedicationSuggestions, id: \.self) { suggestion in
                                Button(suggestion) {
                                    manualMedicationName = suggestion
                                    requestRemoteDrugSuggestions(for: suggestion)
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(AppTheme.primary.opacity(0.12))
                                .foregroundStyle(AppTheme.primary)
                                .font(.caption.weight(.semibold))
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(AppTheme.primary.opacity(0.2), lineWidth: 1))
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .padding(16)
            .glassCard(cornerRadius: 16)

            // Dose card
            VStack(alignment: .leading, spacing: 12) {
                planFieldLabel("Dose & Form", symbol: "cross.circle.fill")

                HStack(spacing: 10) {
                    TextField("Qty", text: $manualDoseAmount)
                        .keyboardType(.decimalPad)
                        .foregroundStyle(.white)
                        .planTextField()
                        .frame(maxWidth: 72)

                    Picker("Form", selection: $manualDoseForm) {
                        ForEach(ManualDoseForm.allCases) { form in
                            Text(form.rawValue).tag(form)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(AppTheme.primary)

                    TextField("Strength (e.g. 5 mg)", text: $manualStrength)
                        .foregroundStyle(.white)
                        .planTextField()
                }

                planFieldLabel("Route & Frequency", symbol: "calendar")

                HStack(spacing: 10) {
                    Picker("Route", selection: $manualRoute) {
                        ForEach(ManualRouteOption.allCases) { route in
                            Text(route.rawValue).tag(route)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(AppTheme.primary)

                    Picker("Frequency", selection: $manualFrequency) {
                        ForEach(ManualFrequencyOption.allCases) { freq in
                            Text(freq.rawValue).tag(freq)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(AppTheme.primary)
                    .onChange(of: manualFrequency) { _, _ in
                        syncManualTimesToFrequency()
                    }
                }
            }
            .padding(16)
            .glassCard(cornerRadius: 16)

            // Schedule card
            VStack(alignment: .leading, spacing: 12) {
                if manualFrequency == .asNeeded {
                    planFieldLabel("PRN Limits", symbol: "clock.badge.exclamationmark")
                    HStack(spacing: 10) {
                        TextField("Max doses/day", text: $manualPrnMaxDoses)
                            .keyboardType(.numberPad)
                            .foregroundStyle(.white)
                            .planTextField()
                        TextField("Min hours between", text: $manualPrnMinHours)
                            .keyboardType(.numberPad)
                            .foregroundStyle(.white)
                            .planTextField()
                    }
                } else {
                    planFieldLabel("Duration", symbol: "calendar.badge.clock")
                    TextField("Duration in days", text: $manualDurationDays)
                        .keyboardType(.numberPad)
                        .foregroundStyle(.white)
                        .planTextField()

                    Divider().opacity(0.1)

                    planFieldLabel("Dose Times", symbol: "clock.fill")

                    ForEach($manualTimes) { $doseTime in
                        HStack {
                            DatePicker("", selection: $doseTime.time, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                                .tint(AppTheme.primary)
                            Spacer()
                            if manualTimes.count > 1 {
                                Button(role: .destructive) {
                                    manualTimes.removeAll { $0.id == doseTime.id }
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundStyle(AppTheme.danger)
                                }
                            }
                        }
                    }
                    Button {
                        manualTimes.append(ManualDoseTime(hour: 20, minute: 0))
                    } label: {
                        Label("Add Time", systemImage: "plus.circle")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(AppTheme.primary)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(AppTheme.primary.opacity(0.12), in: Capsule())
                }
            }
            .padding(16)
            .glassCard(cornerRadius: 16)

            // Preview card
            let preview = buildManualInstructionText()
            if !preview.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    planFieldLabel("Instruction Preview", symbol: "doc.text")
                    Text(preview)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .padding(16)
                .glassCard(cornerRadius: 16)
            }

            // Validation
            if !manualValidationMessages.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(manualValidationMessages, id: \.self) { message in
                        Label(message, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(AppTheme.warning)
                    }
                }
                .padding(14)
                .glassCard(cornerRadius: 12)
            }

            Button {
                addCurrentMedicationToPending()
            } label: {
                Label("Add Medication", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.black)
                    .padding(.vertical, 14)
                    .background(AppTheme.primary, in: Capsule())
                    .shadow(color: AppTheme.primary.opacity(0.35), radius: 8, x: 0, y: 4)
            }
            .disabled(!canAddToPending)
        }
    }

    @ViewBuilder
    private var pendingMedicationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            planSectionHeader("Ready to Add (\(pendingMedications.count))", symbol: "tray.fill")

            VStack(spacing: 8) {
                ForEach(pendingMedications) { med in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(med.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                            Text(med.summary)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        Spacer()
                        Button(role: .destructive) {
                            pendingMedications.removeAll { $0.id == med.id }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(AppTheme.danger.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(14)
                    .glassCard(cornerRadius: 12)
                }
            }
        }
    }

    @ViewBuilder
    private var buildPlanSection: some View {
        Button {
            buildAllPendingMedications()
        } label: {
            Label("Build Medication Plan", systemImage: "wand.and.stars")
                .frame(maxWidth: .infinity)
                .font(.headline.weight(.bold))
                .foregroundStyle(.black)
                .padding(.vertical, 14)
                .background(AppTheme.primary, in: Capsule())
                .shadow(color: AppTheme.primary.opacity(0.35), radius: 8, x: 0, y: 4)
        }
    }

    @ViewBuilder
    private var buildSuccessSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Added to your Vault!", systemImage: "checkmark.circle.fill")
                .foregroundStyle(AppTheme.success)
                .font(.subheadline.weight(.semibold))
            if sessionAddedCount > 0 {
                Text("\(sessionAddedCount) medication\(sessionAddedCount == 1 ? "" : "s") added this session.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
            if lastBuildFailedCount > 0 {
                Text("\(lastBuildFailedCount) medication\(lastBuildFailedCount == 1 ? "" : "s") could not be added and remain in queue.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.warning)
            }
            Button("Add More Medications") {
                showBuildSuccess = false
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppTheme.primary)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(AppTheme.primary.opacity(0.12), in: Capsule())
            .padding(.top, 2)
        }
        .padding(16)
        .glassCard(cornerRadius: 16)
    }

    // MARK: - Paste / Scan Flow

    @ViewBuilder
    private var pasteScanSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            planSectionHeader("Instructions", symbol: "doc.text.fill")

            VStack(alignment: .leading, spacing: 12) {
                if source == .scannedDocument {
                    Button {
                        startScanFlow()
                    } label: {
                        Label("Scan Document", systemImage: "camera.fill")
                            .frame(maxWidth: .infinity)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.black)
                            .padding(.vertical, 12)
                            .background(AppTheme.primary, in: Capsule())
                    }
                    if !ScannerSheetView.canScanDocument {
                        Label("Scanner unavailable. Upload a file or switch to Manual Entry.", systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(AppTheme.warning)
                    }
                }

                Button {
                    showFileImporter = true
                } label: {
                    Label("Upload Text or PDF", systemImage: "doc.badge.plus")
                        .frame(maxWidth: .infinity)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.primary)
                        .padding(.vertical, 12)
                        .background(AppTheme.primary.opacity(0.12), in: Capsule())
                        .overlay(Capsule().stroke(AppTheme.primary.opacity(0.2), lineWidth: 1))
                }

                ZStack(alignment: .topLeading) {
                    TextEditor(text: $appState.ingestionText)
                        .frame(minHeight: 140)
                        .foregroundStyle(.white)
                        .scrollContentBackground(.hidden)
                        .padding(10)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.12), lineWidth: 1))
                    if appState.ingestionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("Paste or type medication instructions here…")
                            .foregroundStyle(.white.opacity(0.35))
                            .padding(.top, 18)
                            .padding(.leading, 14)
                            .allowsHitTesting(false)
                    }
                }

                if appState.ingestionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.white.opacity(0.5))
                        Text("Include drug name, dose, route, and frequency for best results. Medhavn reads existing clinician instructions — it does not change any dose.")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(16)
            .glassCard(cornerRadius: 16)

            HStack(spacing: 12) {
                Button {
                    pendingAutoScrollToOutput = true
                    appState.ingestAndCreatePlan(source: source)
                } label: {
                    Text("Build Medication Plan")
                        .frame(maxWidth: .infinity)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.black)
                        .padding(.vertical, 14)
                        .background(canBuildPlan ? AppTheme.primary : AppTheme.primary.opacity(0.4), in: Capsule())
                }
                .disabled(!canBuildPlan)

                if !appState.ingestionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button {
                        appState.ingestionText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(AppTheme.danger.opacity(0.8))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func parsedOutputSections(output: EngineOutput, proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Parsed summary card
            VStack(alignment: .leading, spacing: 10) {
                planSectionHeader("What We Understood", symbol: "doc.text.magnifyingglass")

                parsedRow("Drug", value: output.parsed.drugName ?? "Not provided")
                parsedRow("Dose", value: doseText(output.parsed))
                parsedRow("Route", value: output.parsed.route?.rawValue ?? "Missing")
                parsedRow("Frequency", value: frequencyText(output.parsed.frequency))
                parsedRow("Duration", value: output.parsed.durationDays.map { "\($0) days" } ?? "Missing")
                parsedRow("PRN", value: output.parsed.prnRule?.indication ?? "No")
            }
            .padding(16)
            .glassCard(cornerRadius: 16)
            .id(parsedOutputAnchorID)

            if !output.parsed.taperSteps.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    planSectionHeader("Taper Steps", symbol: "arrow.down.right")
                    ForEach(Array(output.parsed.taperSteps.enumerated()), id: \.offset) { _, step in
                        Text("Day \(step.startDay)–\(step.endDay): \(formatDose(step.dose)) \(output.parsed.units ?? "unit")")
                            .font(.subheadline)
                            .foregroundStyle(.white)
                    }
                }
                .padding(16)
                .glassCard(cornerRadius: 16)
            }

            if !output.parsed.ambiguityQuestions.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    planSectionHeader("Needs Clarification", symbol: "questionmark.circle.fill")
                    ForEach(output.parsed.ambiguityQuestions, id: \.self) { q in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(AppTheme.warning)
                                .font(.caption)
                            Text(q)
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.warning)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(16)
                .glassCard(cornerRadius: 16)
            }

            if !output.flags.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    planSectionHeader("Prescription Flags", symbol: "flag.fill")
                    ForEach(Array(output.flags.enumerated()), id: \.offset) { _, flag in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: flag.severity == .critical ? "xmark.octagon.fill" : "exclamationmark.circle.fill")
                                    .foregroundStyle(flag.severity == .critical ? AppTheme.danger : AppTheme.warning)
                                    .font(.caption)
                                Text(flag.message)
                                    .font(.subheadline)
                                    .foregroundStyle(flag.severity == .critical ? AppTheme.danger : AppTheme.warning)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Text("Confirm with your pharmacist or clinician before proceeding.")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                }
                .padding(16)
                .glassCard(cornerRadius: 16)
            }

            VStack(alignment: .leading, spacing: 8) {
                planSectionHeader("Patient-Ready Directions", symbol: "heart.text.square.fill")
                Text(output.patientDirections)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
                    .lineSpacing(4)
            }
            .padding(16)
            .glassCard(cornerRadius: 16)

            VStack(alignment: .leading, spacing: 8) {
                planSectionHeader("Audit Rationale", symbol: "checkmark.shield.fill")
                Text(output.rationale)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))
                    .lineSpacing(4)
            }
            .padding(16)
            .glassCard(cornerRadius: 16)

            Button {
                if let name = appState.latestOutput?.parsed.drugName {
                    justAddedMedName = name
                    appState.addFromLatestParsedPlanToCabinet()
                    sessionAddedCount += 1
                    showMedCabinetConfirm = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        showMedCabinetConfirm = false
                        appState.latestOutput = nil
                        appState.ingestionText = ""
                    }
                }
            } label: {
                Label("Add Parsed Medication to Vault", systemImage: "lock.doc.fill")
                    .frame(maxWidth: .infinity)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.black)
                    .padding(.vertical, 14)
                    .background(AppTheme.primary, in: Capsule())
                    .shadow(color: AppTheme.primary.opacity(0.35), radius: 8, x: 0, y: 4)
            }

            if showMedCabinetConfirm {
                VStack(alignment: .leading, spacing: 4) {
                    Label("\(justAddedMedName) added to Vault.", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(AppTheme.success)
                        .font(.subheadline.weight(.semibold))
                    Text("You can add another medication now.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
                .padding(14)
                .glassCard(cornerRadius: 12)
            }

            if sessionAddedCount > 0 && !showMedCabinetConfirm {
                Label("\(sessionAddedCount) medication\(sessionAddedCount == 1 ? "" : "s") added this session.", systemImage: "tray.full.fill")
                    .foregroundStyle(.white.opacity(0.5))
                    .font(.caption)
                    .padding(.horizontal, 4)
            }
        }
    }

    // MARK: - Actions

    private func addCurrentMedicationToPending() {
        let text = buildManualInstructionText()
        guard !text.isEmpty else { return }
        let entry = PendingMedicationEntry(
            name: manualMedicationName,
            doseAmount: manualDoseAmount,
            doseForm: manualDoseForm,
            strength: manualStrength,
            frequency: manualFrequency,
            instructionText: text
        )
        pendingMedications.append(entry)
        resetManualEntry()
        remoteMedicationSuggestions = []
        showBuildSuccess = false
        lastBuildFailedCount = 0
    }

    private func buildAllPendingMedications() {
        let meds = pendingMedications
        var added = 0
        var failed: [PendingMedicationEntry] = []
        for med in meds {
            let beforeCount = appState.itemsForSelectedProfile().count
            appState.ingestionText = med.instructionText
            appState.ingestAndCreatePlan(source: .manualEntry)
            appState.addFromLatestParsedPlanToCabinet()
            let afterCount = appState.itemsForSelectedProfile().count
            if afterCount > beforeCount {
                added += 1
            } else {
                failed.append(med)
            }
        }
        sessionAddedCount += added
        pendingMedications = failed
        lastBuildFailedCount = failed.count
        appState.latestOutput = nil
        appState.ingestionText = ""
        showBuildSuccess = added > 0
    }

    // MARK: - Helpers

    private func requestRemoteDrugSuggestions(for query: String) {
        suggestionLookupTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard source == .manualEntry, trimmed.count >= 2 else {
            isLoadingRemoteSuggestions = false
            remoteSuggestionsError = nil
            remoteMedicationSuggestions = []
            return
        }
        suggestionLookupTask = Task {
            isLoadingRemoteSuggestions = true
            remoteSuggestionsError = nil
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            do {
                let names = try await drugLookupService.searchMedicationNames(query: trimmed, limit: 12)
                guard !Task.isCancelled else { return }
                remoteMedicationSuggestions = names
                isLoadingRemoteSuggestions = false
            } catch {
                guard !Task.isCancelled else { return }
                remoteMedicationSuggestions = []
                isLoadingRemoteSuggestions = false
            }
        }
    }

    private func syncManualTimesToFrequency() {
        guard let target = manualFrequency.expectedTimeCount else { return }
        let defaultHours = [8, 12, 18, 22]
        while manualTimes.count < target {
            let hour = defaultHours[min(manualTimes.count, defaultHours.count - 1)]
            manualTimes.append(ManualDoseTime(hour: hour, minute: 0))
        }
        if manualTimes.count > target {
            manualTimes = Array(manualTimes.prefix(target))
        }
    }

    private func resetManualEntry() {
        manualMedicationName = ""
        manualDoseAmount = "1"
        manualDoseForm = .tablet
        manualStrength = ""
        manualRoute = .oral
        manualFrequency = .onceDaily
        manualDurationDays = "7"
        manualTimes = [ManualDoseTime(hour: 8, minute: 0)]
        manualPrnMaxDoses = "3"
        manualPrnMinHours = "6"
    }

    private func buildManualInstructionText() -> String {
        let name = manualMedicationName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return "" }
        let amountRaw = manualDoseAmount.trimmingCharacters(in: .whitespacesAndNewlines)
        let amount = amountRaw.isEmpty ? "1" : amountRaw
        let unit = manualDoseForm.parserUnit
        let strengthText = manualStrength.trimmingCharacters(in: .whitespacesAndNewlines)
        let route = manualRoute.parserPhrase
        var lines: [String] = []
        var firstLine = "\(name) \(amount) \(unit)"
        if !strengthText.isEmpty { firstLine += " (\(strengthText))" }
        firstLine += " \(route), \(manualFrequency.parserPhrase)"
        if manualFrequency != .asNeeded {
            let times = manualTimes
                .sorted { $0.time < $1.time }
                .map { $0.time.formatted(date: .omitted, time: .shortened) }
            if !times.isEmpty { firstLine += " at \(times.joined(separator: ", "))" }
            if let duration = Int(manualDurationDays), duration > 0 { firstLine += " for \(duration) days" }
        } else {
            firstLine += " for symptoms"
        }
        firstLine += "."
        lines.append(firstLine)
        if manualFrequency == .asNeeded {
            if let maxDoses = Int(manualPrnMaxDoses), maxDoses > 0 { lines.append("Maximum \(maxDoses) doses per day.") }
            if let minHours = Int(manualPrnMinHours), minHours > 0 { lines.append("At least \(minHours) hours between doses.") }
        }
        return lines.joined(separator: "\n")
    }

    private func startScanFlow() {
        guard ScannerSheetView.canScanDocument else {
            scannerAlertMessage = "Document scanning requires a physical device with camera access."
            showScannerAlert = true
            return
        }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            showScanner = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted { showScanner = true }
                    else {
                        scannerAlertMessage = "Camera permission was denied. Enable camera access in Settings to scan documents."
                        showScannerAlert = true
                    }
                }
            }
        case .denied, .restricted:
            scannerAlertMessage = "Camera access is denied. Enable it in Settings or use paste/manual entry."
            showScannerAlert = true
        @unknown default:
            scannerAlertMessage = "Scanner is currently unavailable on this device."
            showScannerAlert = true
        }
    }

    private func doseText(_ p: ParsedMedicationPlan) -> String {
        guard let d = p.dose else { return "Missing" }
        return "\(formatDose(d)) \(p.units ?? "unit")"
    }

    private func formatDose(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    private func frequencyText(_ f: Frequency?) -> String {
        guard let f else { return "Missing" }
        switch f {
        case .onceDaily: return "Once daily"
        case .twiceDaily: return "Twice daily"
        case .threeTimesDaily: return "Three times daily"
        case .fourTimesDaily: return "Four times daily"
        case .everyHours(let hours): return "Every \(hours) hours"
        case .asNeeded: return "As needed"
        case .customPerDay(let count): return "\(count) times/day"
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            importAlertMessage = "Could not import file: \(error.localizedDescription)"
            showImportAlert = true
        case .success(let urls):
            guard let url = urls.first else {
                importAlertMessage = "No file was selected."
                showImportAlert = true
                return
            }
            Task {
                do {
                    let text = try await readImportedText(from: url)
                    await MainActor.run {
                        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                            importAlertMessage = "The selected file did not contain readable text."
                            showImportAlert = true
                            return
                        }
                        appState.ingestionText = text
                        importAlertMessage = "Upload successful. Review the text, then tap Build Medication Plan."
                        showImportAlert = true
                    }
                } catch {
                    await MainActor.run {
                        importAlertMessage = "Could not read selected file. Use text, PDF, or image files with extractable text."
                        showImportAlert = true
                    }
                }
            }
        }
    }

    private func readImportedText(from url: URL) async throws -> String {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }

        let type = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType
        if type?.conforms(to: .pdf) == true || url.pathExtension.lowercased() == "pdf" {
            guard let document = PDFDocument(url: url) else { throw NSError(domain: "AddPlanView", code: 2) }
            let nativeText = document.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !nativeText.isEmpty { return nativeText }
            var ocrPages: [String] = []
            for i in 0..<document.pageCount {
                guard let page = document.page(at: i) else { continue }
                let pageRect = page.bounds(for: .mediaBox)
                let renderer = UIGraphicsImageRenderer(size: pageRect.size)
                let pageImage = renderer.image { ctx in
                    UIColor.white.setFill()
                    ctx.fill(pageRect)
                    ctx.cgContext.translateBy(x: 0, y: pageRect.height)
                    ctx.cgContext.scaleBy(x: 1, y: -1)
                    page.draw(with: .mediaBox, to: ctx.cgContext)
                }
                if let cgImage = pageImage.cgImage {
                    let pageText = try await extractTextFromImage(cgImage)
                    if !pageText.isEmpty { ocrPages.append(pageText) }
                }
            }
            guard !ocrPages.isEmpty else { throw NSError(domain: "AddPlanView", code: 2) }
            return ocrPages.joined(separator: "\n\n")
        }

        if type?.conforms(to: .image) == true {
            let data = try Data(contentsOf: url)
            guard let image = UIImage(data: data), let cgImage = image.cgImage else {
                throw NSError(domain: "AddPlanView", code: 3)
            }
            return try await extractTextFromImage(cgImage)
        }

        if let text = try? String(contentsOf: url, encoding: .utf8) { return text }
        if let text = try? String(contentsOf: url, encoding: .unicode) { return text }
        throw NSError(domain: "AddPlanView", code: 1)
    }

    private func extractTextFromImage(_ cgImage: CGImage) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let lines = (request.results as? [VNRecognizedTextObservation])?
                    .compactMap { $0.topCandidates(1).first?.string } ?? []
                continuation.resume(returning: lines.joined(separator: "\n"))
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            do {
                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    // MARK: - Themed helpers

    private func planSectionHeader(_ title: String, symbol: String) -> some View {
        Label(title, systemImage: symbol)
            .font(.subheadline.weight(.bold))
            .foregroundStyle(AppTheme.primary)
    }

    private func planFieldLabel(_ title: String, symbol: String) -> some View {
        Label(title, systemImage: symbol)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white.opacity(0.7))
    }

    private func parsedRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.7))
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundStyle(.white)
                .multilineTextAlignment(.trailing)
        }
    }
}

private extension View {
    func planTextField() -> some View {
        self
            .padding(12)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.12), lineWidth: 1))
    }
}
