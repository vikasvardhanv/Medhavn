import SwiftUI
import AVFoundation
import UniformTypeIdentifiers
import PDFKit
import Vision
import UIKit

struct AddMedicationWizardView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState

    @State private var step = 1
    // Step 1
    @State private var name = ""
    @State private var dosageText = "1 pill"
    @State private var tags = ""
    // Step 2 – schedule
    @State private var frequency: MedFrequency = .everyDay
    @State private var timesPerDay: Int = 1
    @State private var scheduledTimes: [ScheduledTime] = [ScheduledTime(hour: 8, minute: 0)]
    @State private var scheduleStartDate = Date()
    @State private var hasEndDate = false
    @State private var scheduleEndDate = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
    @State private var specificDays: Set<Int> = [1,2,3,4,5]
    @State private var intervalDays = 1
    // Step 3 – look
    @State private var shape: PillShapeStyle = .capsule
    @State private var colorHex = "#FF6B35"
    // Step 4 – refill
    @State private var remaining = "30"
    @State private var threshold = "5"
    @State private var rxNumber = ""
    @State private var refillReminder = false
    @State private var warnings: [String] = []
    // Scan state
    @State private var showScanOptions = false
    @State private var showScanner = false
    @State private var showFileImporter = false

    private let pillColors = [
        "#FFD700","#FF9500","#FF6B35","#E8503A","#FF8FAB",
        "#C0C0C0","#2F80ED","#5AC8FA","#4CD964","#34C759",
        "#AF52DE","#FF3B30","#A0522D","#1C1C1E"
    ]
    private let dayLabels = ["Mo","Tu","We","Th","Fr","Sa","Su"]
    private let suggestions = ["Metformin","Lisinopril","Ibuprofen","Warfarin","Prednisone","Amoxicillin","Aspirin","Atorvastatin","Omeprazole","Amlodipine"]

    var body: some View {
        ZStack(alignment: .bottom) {
            MeshBackgroundView()
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Progress indicator
                    VStack(spacing: 10) {
                        HStack {
                            Text("Step \(step) of 4")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(["Details", "Schedule", "Appearance", "Refill & Safety"][step - 1])
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 4)

                        HStack(spacing: 8) {
                            ForEach(1...4, id: \.self) { i in
                                Capsule()
                                    .fill(i <= step ? AppTheme.primary : Color.primary.opacity(0.12))
                                    .frame(height: 6)
                                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: step)
                            }
                        }
                    }
                    .padding(16)
                    .glassCard(cornerRadius: 16)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                    // Step View Container
                    Group {
                        switch step {
                        case 1: step1
                        case 2: step2
                        case 3: step3
                        default: step4
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 120) // spacing for bottom action bar
                }
            }
            
            // Floating navigation panel
            VStack(spacing: 0) {
                Divider()
                    .opacity(0.1)
                
                HStack(spacing: 16) {
                    if step > 1 {
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                step -= 1
                            }
                        } label: {
                            HStack {
                                Image(systemName: "chevron.left")
                                Text("Back")
                            }
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.primary.opacity(0.06))
                            .clipShape(Capsule())
                        }
                        .foregroundStyle(.primary)
                    }
                    
                    Button {
                        if step < 4 {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                step += 1
                            }
                            if step == 4 {
                                previewWarnings()
                            }
                        } else {
                            saveMedication()
                        }
                    } label: {
                        HStack {
                            Text(step < 4 ? "Continue" : "Save to Cabinet")
                            Image(systemName: step < 4 ? "chevron.right" : "checkmark")
                        }
                        .font(.headline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [AppTheme.primary, AppTheme.secondary],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                        .shadow(color: AppTheme.primary.opacity(0.35), radius: 8, x: 0, y: 4)
                    }
                    .disabled(step == 1 && name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .background(.ultraThinMaterial)
            }
        }
        .navigationTitle(["Add Medication", "Medication Schedule", "Choose Look", "Refills & Alerts"][step - 1])
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: timesPerDay) { _, n in syncTimes(count: n) }
        .confirmationDialog("Add from Label", isPresented: $showScanOptions, titleVisibility: .visible) {
            Button("Take Photo") {
                startScanFlow()
            }
            Button("Choose from Files") {
                showFileImporter = true
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Capture your prescription label to auto-fill medication details.")
        }
        .sheet(isPresented: $showScanner) {
            ScannerSheetView(scannedText: Binding(
                get: { "" },
                set: { text in
                    if !text.isEmpty {
                        processScannedText(text)
                    }
                }
            ))
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.plainText, .text, .utf8PlainText, .pdf, .image],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
    }

    // MARK: Step 1 – Name & Dose
    private var step1: some View {
        VStack(alignment: .leading, spacing: 18) {
            formCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 0) {
                        fieldLabel("Medication Name", symbol: "pills.fill")
                        Spacer()
                        Button {
                            showScanOptions = true
                        } label: {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.primary)
                                .padding(8)
                                .background(AppTheme.primary.opacity(0.12), in: Circle())
                        }
                        .accessibilityLabel("Scan prescription label")
                    }

                    TextField("e.g. Ibuprofen 200mg", text: $name)
                        .padding(14)
                        .background(Color.primary.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                        )
                    
                    if !name.isEmpty {
                        let hits = suggestions.filter { $0.localizedCaseInsensitiveContains(name) }.prefix(4)
                        if !hits.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(Array(hits), id: \.self) { s in
                                        Button {
                                            name = s
                                        } label: {
                                            Text(s)
                                                .font(.caption.weight(.semibold))
                                                .padding(.horizontal, 14)
                                                .padding(.vertical, 8)
                                                .background(AppTheme.primary.opacity(0.12))
                                                .foregroundStyle(.primary)
                                                .clipShape(Capsule())
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
            }
            .staggeredEntrance(delay: 0.0)
            
            formCard {
                VStack(alignment: .leading, spacing: 12) {
                    fieldLabel("Dosage / Strength", symbol: "cross.circle.fill")
                    
                    TextField("e.g. 1 pill, 200 mg, 5 ml", text: $dosageText)
                        .padding(14)
                        .background(Color.primary.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                        )
                }
            }
            .staggeredEntrance(delay: 0.1)
            
            formCard {
                VStack(alignment: .leading, spacing: 8) {
                    fieldLabel("Active Ingredients (for interaction checking)", symbol: "exclamationmark.triangle.fill")
                    Text("Enter comma-separated ingredients to enable drug-drug safety screening.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 4)
                    
                    TextField("e.g. ibuprofen, aspirin", text: $tags)
                        .padding(14)
                        .background(Color.primary.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                        )
                }
            }
            .staggeredEntrance(delay: 0.2)
        }
    }

    // MARK: Step 2 – Schedule
    private var step2: some View {
        VStack(alignment: .leading, spacing: 18) {
            formCard {
                VStack(alignment: .leading, spacing: 12) {
                    fieldLabel("Frequency", symbol: "calendar")
                    
                    Picker("Frequency", selection: $frequency) {
                        ForEach(MedFrequency.allCases) { f in
                            Text(f.rawValue).tag(f)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .tint(AppTheme.primary)
                }
            }
            .staggeredEntrance(delay: 0.0)
            
            if frequency == .specificDays {
                formCard {
                    VStack(alignment: .leading, spacing: 12) {
                        fieldLabel("Days of the Week", symbol: "calendar.day.timeline.right")
                        
                        HStack(spacing: 8) {
                            ForEach(Array(dayLabels.enumerated()), id: \.offset) { idx, d in
                                let num = idx + 1
                                let isSelected = specificDays.contains(num)
                                Button {
                                    if isSelected {
                                        specificDays.remove(num)
                                    } else {
                                        specificDays.insert(num)
                                    }
                                } label: {
                                    Text(d)
                                        .font(.subheadline.weight(.bold))
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 40)
                                        .background(isSelected ? AppTheme.primary : Color.primary.opacity(0.05))
                                        .foregroundStyle(isSelected ? .white : .primary)
                                        .clipShape(Circle())
                                }
                            }
                        }
                    }
                }
                .staggeredEntrance(delay: 0.1)
            }
            
            if frequency == .daysInterval {
                formCard {
                    VStack(alignment: .leading, spacing: 12) {
                        fieldLabel("Interval (Every N days)", symbol: "arrow.clockwise")
                        
                        Stepper("Every \(intervalDays) day\(intervalDays > 1 ? "s" : "")", value: $intervalDays, in: 1...90)
                            .font(.body.weight(.semibold))
                    }
                }
                .staggeredEntrance(delay: 0.1)
            }
            
            if frequency != .asNeeded {
                formCard {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            fieldLabel("Times Per Day", symbol: "number")
                            Spacer()
                            Stepper("\(timesPerDay)×", value: $timesPerDay, in: 1...8)
                                .fixedSize()
                        }
                        
                        Divider()
                            .opacity(0.1)
                        
                        fieldLabel("Scheduled Times", symbol: "clock.fill")
                        
                        ForEach($scheduledTimes) { $t in
                            HStack {
                                DatePicker("", selection: Binding(
                                    get: { Calendar.current.date(bySettingHour: t.hour, minute: t.minute, second: 0, of: Date()) ?? Date() },
                                    set: { d in
                                        t.hour = Calendar.current.component(.hour, from: d)
                                        t.minute = Calendar.current.component(.minute, from: d)
                                    }
                                ), displayedComponents: .hourAndMinute)
                                .labelsHidden()
                                .datePickerStyle(.compact)
                                
                                Spacer()
                                
                                Text(t.displayString)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                            }
                            .padding(.vertical, 6)
                        }
                    }
                }
                .staggeredEntrance(delay: 0.15)
            }
            
            formCard {
                VStack(alignment: .leading, spacing: 14) {
                    fieldLabel("Duration", symbol: "calendar.badge.clock")
                    
                    HStack {
                        Text("Starts")
                            .foregroundStyle(.secondary)
                        Spacer()
                        DatePicker("", selection: $scheduleStartDate, displayedComponents: .date)
                            .labelsHidden()
                    }
                    
                    Toggle("Set End Date", isOn: $hasEndDate)
                        .tint(AppTheme.primary)
                    
                    if hasEndDate {
                        HStack {
                            Text("Ends")
                                .foregroundStyle(.secondary)
                            Spacer()
                            DatePicker("", selection: $scheduleEndDate, in: scheduleStartDate..., displayedComponents: .date)
                                .labelsHidden()
                        }
                    }
                }
            }
            .staggeredEntrance(delay: 0.2)
        }
    }

    // MARK: Step 3 – Appearance
    private var step3: some View {
        VStack(alignment: .leading, spacing: 18) {
            formCard {
                HStack(spacing: 20) {
                    PillVisual(shape: shape, colorHex: colorHex)
                        .frame(width: 64, height: 48)
                        .shadow(color: (Color(hex: colorHex) ?? AppTheme.primary).opacity(0.4), radius: 10, y: 4)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(name.isEmpty ? "Medication Name" : name)
                            .font(.title3.weight(.bold))
                        Text(dosageText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 8)
            }
            .staggeredEntrance(delay: 0.0)
            
            formCard {
                VStack(alignment: .leading, spacing: 16) {
                    fieldLabel("Pill Shape", symbol: "capsule.portrait.fill")
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(PillShapeStyle.allCases) { s in
                                Button {
                                    shape = s
                                } label: {
                                    ZStack {
                                        if shape == s {
                                            Circle()
                                                .fill(AppTheme.primary.opacity(0.12))
                                                .frame(width: 58, height: 58)
                                        }
                                        pillShapeView(s, hex: colorHex)
                                            .frame(width: 38, height: 26)
                                    }
                                }
                                .frame(width: 58, height: 58)
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                    
                    Divider()
                        .opacity(0.1)
                    
                    fieldLabel("Pill Color", symbol: "paintpalette.fill")
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 14) {
                        ForEach(pillColors, id: \.self) { hex in
                            Button {
                                colorHex = hex
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(Color(hex: hex) ?? AppTheme.primary)
                                        .frame(width: 34, height: 34)
                                        .shadow(color: (Color(hex: hex) ?? AppTheme.primary).opacity(0.2), radius: 4, y: 2)
                                    
                                    if colorHex == hex {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundStyle(hex == "#FFFFFF" || hex == "#FFD700" ? Color.black : Color.white)
                                    }
                                }
                            }
                            .frame(width: 36, height: 36)
                        }
                    }
                }
            }
            .staggeredEntrance(delay: 0.1)
        }
    }

    // MARK: Step 4 – Refill & Warnings
    private var step4: some View {
        VStack(alignment: .leading, spacing: 18) {
            formCard {
                VStack(alignment: .leading, spacing: 14) {
                    fieldLabel("Prescription Refill", symbol: "doc.text.fill")
                    
                    HStack {
                        Text("Rx Number")
                        Spacer()
                        TextField("e.g. 123456", text: $rxNumber)
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(.secondary)
                    }
                    
                    Divider()
                        .opacity(0.1)
                    
                    HStack {
                        Text("Pills Left in Cabinet")
                        Spacer()
                        TextField("30", text: $remaining)
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(.secondary)
                            .keyboardType(.numberPad)
                    }
                    
                    Divider()
                        .opacity(0.1)
                    
                    HStack {
                        Text("Low Pill Warning Limit")
                        Spacer()
                        TextField("5", text: $threshold)
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(.secondary)
                            .keyboardType(.numberPad)
                    }
                    
                    Divider()
                        .opacity(0.1)
                    
                    Toggle("Enable Refill Reminder", isOn: $refillReminder)
                        .tint(AppTheme.primary)
                }
            }
            .staggeredEntrance(delay: 0.0)
            
            if !warnings.isEmpty {
                formCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Safety Contraindications Detected", systemImage: "exclamationmark.shield.fill")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(AppTheme.warning)
                        
                        ForEach(warnings, id: \.self) { w in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(AppTheme.warning)
                                    .font(.caption)
                                    .padding(.top, 2)
                                Text(w)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .staggeredEntrance(delay: 0.1)
            }
        }
    }

    // MARK: Helpers
    @ViewBuilder
    private func formCard<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        content()
            .padding(18)
            .glassCard(cornerRadius: 16)
    }

    private func fieldLabel(_ text: String, symbol: String) -> some View {
        Label(text, systemImage: symbol)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.primary)
    }

    @ViewBuilder
    private func pillShapeView(_ s: PillShapeStyle, hex: String) -> some View {
        let c = Color(hex: hex) ?? AppTheme.primary
        switch s {
        case .capsule: Capsule().fill(c)
        case .round: Circle().fill(c)
        case .oval: RoundedRectangle(cornerRadius: 16).fill(c)
        case .tablet: RoundedRectangle(cornerRadius: 6).fill(c)
        }
    }

    private func syncTimes(count: Int) {
        let defaultHours = [8, 12, 16, 20, 6, 10, 14, 22]
        while scheduledTimes.count < count {
            let h = defaultHours[min(scheduledTimes.count, defaultHours.count - 1)]
            scheduledTimes.append(ScheduledTime(hour: h, minute: 0))
        }
        if scheduledTimes.count > count {
            scheduledTimes = Array(scheduledTimes.prefix(count))
        }
    }

    private func previewWarnings() {
        guard let profileID = appState.selectedProfile?.id else { return }
        let tagList = tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        let draft = MedCabinetItem(profileID: profileID, name: name.isEmpty ? "Medication" : name,
                                   dosageText: dosageText, scheduleBlocks: computedBlocks,
                                   contraindicationTags: tagList)
        warnings = appState.interactionWarnings(for: draft)
    }

    private var computedBlocks: [DayTimeBlock] {
        scheduledTimes.compactMap { t -> DayTimeBlock? in
            switch t.hour {
            case 5..<12: return .morning
            case 12..<17: return .afternoon
            case 17..<21: return .evening
            default: return .night
            }
        }
    }

    private func saveMedication() {
        guard let profileID = appState.selectedProfile?.id else { return }
        let tagList = tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        let item = MedCabinetItem(
            profileID: profileID,
            name: name.isEmpty ? "Medication" : name,
            dosageText: dosageText,
            scheduleBlocks: computedBlocks,
            remainingPills: Int(remaining) ?? 30,
            refillThreshold: Int(threshold) ?? 5,
            pillShape: shape,
            pillColorHex: colorHex,
            contraindicationTags: tagList,
            frequency: frequency,
            scheduledTimes: scheduledTimes,
            scheduleStartDate: scheduleStartDate,
            scheduleEndDate: hasEndDate ? scheduleEndDate : nil,
            specificDays: Array(specificDays).sorted(),
            intervalDays: intervalDays,
            refill: PrescriptionRefill(rxNumber: rxNumber, pillsLeft: Int(remaining) ?? 30, refillReminderEnabled: refillReminder)
        )
        warnings = appState.addMedCabinetItem(item)
        if warnings.isEmpty { dismiss() }
    }

    // MARK: - Scan & Auto-fill

    private func startScanFlow() {
        guard ScannerSheetView.canScanDocument else { return }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            showScanner = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted { showScanner = true }
                }
            }
        default: break
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let didAccess = url.startAccessingSecurityScopedResource()
            defer { if didAccess { url.stopAccessingSecurityScopedResource() } }

            Task {
                let text = await extractText(from: url)
                await MainActor.run {
                    if let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        processScannedText(text)
                    }
                }
            }
        case .failure: break
        }
    }

    private func extractText(from url: URL) async -> String? {
        let type = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType

        if type?.conforms(to: .pdf) == true || url.pathExtension.lowercased() == "pdf" {
            guard let document = PDFDocument(url: url) else { return nil }
            let native = document.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !native.isEmpty { return native }
            for i in 0..<document.pageCount {
                guard let page = document.page(at: i) else { continue }
                let img = page.thumbnail(of: CGSize(width: 600, height: 800), for: .mediaBox)
                if let cg = img.cgImage, let t = try? await ocr(cgImage: cg), !t.isEmpty { return t }
            }
            return nil
        }
        if type?.conforms(to: .image) == true {
            if let data = try? Data(contentsOf: url), let img = UIImage(data: data), let cg = img.cgImage {
                return try? await ocr(cgImage: cg)
            }
            return nil
        }
        return try? String(contentsOf: url, encoding: .utf8)
    }

    private func ocr(cgImage: CGImage) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error { continuation.resume(throwing: error); return }
                let text = (request.results as? [VNRecognizedTextObservation])?
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n") ?? ""
                continuation.resume(returning: text)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            try? VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
        }
    }

    private func processScannedText(_ text: String) {
        // Clear previous state first
        name = ""
        dosageText = "1 pill"
        tags = ""

        // Use the same NLP engine that AddPlanView uses
        let output = appState.engine.process(text: text, projectionDays: 60)
        let parsed = output.parsed

        // Medication name
        if let drugName = parsed.drugName {
            name = drugName
        } else {
            // Regex fallback for name (often first line or near "Rx" / "Take")
            let lines = text.components(separatedBy: "\n")
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.contains("Rx") || trimmed.contains("Take") || trimmed.contains("Supplement") {
                    let cleaned = trimmed.replacingOccurrences(of: "Rx", with: "").replacingOccurrences(of: "Take", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                    if !cleaned.isEmpty {
                        name = cleaned
                        break
                    }
                }
            }
        }

        // Dosage: combine numeric dose with units
        if let dose = parsed.dose, let units = parsed.units {
            let formattedDose = dose.truncatingRemainder(dividingBy: 1) == 0
                ? String(format: "%.0f", dose)
                : String(format: "%.1f", dose)
            dosageText = "\(formattedDose) \(units)"
        } else if let dose = parsed.dose {
            dosageText = "\(dose) pill"
        } else {
            // Regex fallback for dose/strength (e.g. "500mg" or "10 mg" or "2 tablets")
            let pattern = "(\\d+(?:\\.\\d+)?)\\s*(mg|mcg|ml|g|tabs?|caps?|tablets?|pills?|capsules?)"
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)) {
                if let doseRange = Range(match.range(at: 1), in: text),
                   let unitRange = Range(match.range(at: 2), in: text) {
                    let doseVal = String(text[doseRange])
                    let unitVal = String(text[unitRange])
                    dosageText = "\(doseVal) \(unitVal)"
                }
            }
        }

        // Frequency mapping from engine's Frequency to wizard's MedFrequency + timesPerDay
        if let engineFreq = parsed.frequency {
            switch engineFreq {
            case .onceDaily:
                frequency = .everyDay; timesPerDay = 1
            case .twiceDaily:
                frequency = .everyDay; timesPerDay = 2
            case .threeTimesDaily:
                frequency = .everyDay; timesPerDay = 3
            case .fourTimesDaily:
                frequency = .everyDay; timesPerDay = 4
            case .customPerDay(let n):
                frequency = .everyDay; timesPerDay = n
            case .everyHours(let h):
                frequency = .everyDay
                timesPerDay = max(1, min(8, 24 / max(1, h)))
            case .asNeeded:
                frequency = .asNeeded
            @unknown default:
                frequency = .everyDay; timesPerDay = 1
            }
        }

        // Duration
        if let days = parsed.durationDays {
            // The wizard doesn't have a direct duration field, but we store this info
            // The schedule start/end date picks this up in step 2
            hasEndDate = true
            scheduleEndDate = Calendar.current.date(byAdding: .day, value: days, to: scheduleStartDate) ?? scheduleEndDate
        }

        // PRN details
        if let prn = parsed.prnRule {
            if let maxDoses = prn.maxPerDayDoses {
                // Store in step 2's PRN fields — wizard doesn't have direct PRN vars
                // but the schedule step handles PRN via frequency == .asNeeded
                frequency = .asNeeded
            }
        }

        // Extract ingredients from text for interaction checking
        // Use the engine-parsed source text which is cleaned
        let fullText = text.lowercased()
        let ingredientPatterns = ["ibuprofen", "aspirin", "acetaminophen", "warfarin", "metformin",
                                  "lisinopril", "atorvastatin", "omeprazole", "amlodipine", "sertraline",
                                  "gabapentin", "losartan", "hydrochlorothiazide", "albuterol",
                                  "prednisone", "amoxicillin", "doxycycline", "levothyroxine"]
        var found: [String] = []
        for ing in ingredientPatterns {
            if fullText.contains(ing), !found.contains(ing) {
                found.append(ing)
            }
        }
        if !found.isEmpty { tags = found.joined(separator: ", ") }

        // Auto-fill scheduled times based on parsed frequency
        syncTimes(count: timesPerDay)

        // Auto-advance: jump to step 2 if we got a name, or show the parsed data on step 1
        if !name.isEmpty && step == 1 {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                step = 2
            }
        }
    }
}
