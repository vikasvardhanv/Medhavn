import SwiftUI

// MARK: - Fertility Tracker View
struct FertilityTrackerView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedTab = 0
    @State private var showLogSymptom = false
    @State private var showAddCycle = false
    @State private var showAddTreatment = false
    @State private var showAddLab = false

    var body: some View {
        ZStack {
            MeshBackgroundView()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                if let cycle = appState.currentFertilityCycle {
                    cycleHeaderCard(cycle)
                } else {
                    emptyStateCard
                }

                tabSelector

                TabView(selection: $selectedTab) {
                    CycleOverviewTab()
                        .tag(0)

                    SymptomsLogTab()
                        .tag(1)

                    TreatmentsTab()
                        .tag(2)

                    LabsTab()
                        .tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
        }
        .navigationTitle("Fertility")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showAddCycle = true
                    } label: {
                        Label("Log Cycle", systemImage: "calendar.badge.plus")
                    }
                    Button {
                        showLogSymptom = true
                    } label: {
                        Label("Log Symptom", systemImage: "heart.text.square")
                    }
                    Button {
                        showAddTreatment = true
                    } label: {
                        Label("Add Treatment", systemImage: "pills")
                    }
                    Button {
                        showAddLab = true
                    } label: {
                        Label("Add Lab Result", systemImage: "flask")
                    }
                } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(AppTheme.primary)
                }
            }
        }
        .sheet(isPresented: $showLogSymptom) {
            LogFertilitySymptomView()
                .environmentObject(appState)
        }
        .sheet(isPresented: $showAddCycle) {
            AddFertilityCycleView()
                .environmentObject(appState)
        }
        .sheet(isPresented: $showAddTreatment) {
            AddFertilityTreatmentView()
                .environmentObject(appState)
        }
        .sheet(isPresented: $showAddLab) {
            AddFertilityLabView()
                .environmentObject(appState)
        }
    }

    private var tabSelector: some View {
        HStack(spacing: 0) {
            fertilityTab("Overview", icon: "circle.dotted", index: 0)
            fertilityTab("Symptoms", icon: "heart.text.square", index: 1)
            fertilityTab("Treatments", icon: "pills", index: 2)
            fertilityTab("Labs", icon: "flask", index: 3)
        }
        .padding(.top, 8)
        .padding(.horizontal, 8)
    }

    private func fertilityTab(_ title: String, icon: String, index: Int) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                selectedTab = index
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                Text(title)
                    .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(selectedTab == index ? AppTheme.primary : .white.opacity(0.5))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                selectedTab == index ?
                AppTheme.primary.opacity(0.12) :
                Color.clear
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private func cycleHeaderCard(_ cycle: FertilityCycleRecord) -> some View {
        let state = appState.currentCycleState(for: cycle)
        let stateColor = Color(hex: state.color) ?? AppTheme.primary

        return VStack(spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(stateColor.opacity(0.12))
                        .frame(width: 48, height: 48)
                    Image(systemName: state.sfSymbol)
                        .font(.title2)
                        .foregroundStyle(stateColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(state.rawValue)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)

                    if let predicted = cycle.predictedNextPeriod {
                        Text("Next period: \(predicted.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Day \(dayOfCycle(cycle))")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppTheme.primary)

                    Text("\(cycle.cycleLength)-day cycle")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.5))
                }
            }

            if let fertileWindow = cycle.predictedFertileWindow {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.caption)
                        .foregroundStyle(AppTheme.success)

                    Text("Fertile window: \(fertileWindow.start.formatted(date: .abbreviated, time: .omitted)) - \(fertileWindow.end.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundStyle(AppTheme.success)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(AppTheme.success.opacity(0.1))
                .clipShape(Capsule())
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 16)
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    private var emptyStateCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.circle")
                .font(.system(size: 48))
                .foregroundStyle(AppTheme.primary.opacity(0.6))

            Text("Start Cycle Tracking")
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)

            Text("Log your menstrual cycle to unlock fertility insights, ovulation predictions, and treatment tracking.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .lineSpacing(3)

            Button {
                showAddCycle = true
            } label: {
                Text("Start Tracking")
                    .font(.subheadline.weight(.bold))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(AppTheme.primary)
                    .foregroundStyle(.black)
                    .clipShape(Capsule())
            }
        }
        .padding(24)
        .glassCard(cornerRadius: 16)
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    private func dayOfCycle(_ cycle: FertilityCycleRecord) -> Int {
        let calendar = Calendar.current
        return (calendar.dateComponents([.day], from: cycle.startDate, to: Date()).day ?? 0) + 1
    }
}

// MARK: - Cycle Overview Tab
struct CycleOverviewTab: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let cycle = appState.currentFertilityCycle {
                    cycleInfoCard(cycle)
                    cycleVisualTimeline(cycle)
                    insightsCard(cycle)
                } else {
                    Text("No cycle data. Add a cycle to get started.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(40)
                }
            }
            .padding(16)
        }
    }

    private func cycleInfoCard(_ cycle: FertilityCycleRecord) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cycle Details")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.primary)

            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Started")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.5))
                    Text(cycle.startDate.formatted(date: .abbreviated, time: .omitted))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Length")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.5))
                    Text("\(cycle.cycleLength) days")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Period")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.5))
                    Text("\(cycle.periodLength) days")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                }
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 16)
    }

    private func cycleVisualTimeline(_ cycle: FertilityCycleRecord) -> some View {
        let state = appState.currentCycleState(for: cycle)
        let stateColor = Color(hex: state.color) ?? AppTheme.primary

        return VStack(alignment: .leading, spacing: 12) {
            Text("Cycle Timeline")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.primary)

            GeometryReader { geo in
                let day = dayOfCycle(cycle)
                let progress = min(1.0, CGFloat(day) / CGFloat(cycle.cycleLength))

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 12)

                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [stateColor, stateColor.opacity(0.6)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * progress, height: 12)
                }
            }
            .frame(height: 12)

            HStack {
                ForEach(FertilityCycleState.allCases, id: \.self) { s in
                    VStack(spacing: 4) {
                        Circle()
                            .fill(s == state ? Color(hex: s.color) ?? AppTheme.primary : Color.white.opacity(0.3))
                            .frame(width: 8, height: 8)
                        Text(s.rawValue)
                            .font(.system(size: 9))
                            .foregroundStyle(s == state ? .white : .white.opacity(0.5))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 16)
    }

    private func insightsCard(_ cycle: FertilityCycleRecord) -> some View {
        let symptoms = appState.fertilitySymptoms.filter { symptom in
            let daysDiff = Calendar.current.dateComponents([.day], from: symptom.date, to: Date()).day ?? 0
            return daysDiff <= 14
        }

        let insight = appState.fertilityInsight(for: symptoms)

        return VStack(alignment: .leading, spacing: 12) {
            Label("AI Insights", systemImage: "cpu.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.primary)

            if let insight = insight {
                Text(insight)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .lineSpacing(3)
            } else {
                Text("Keep logging symptoms and treatments for personalized AI-powered insights.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .lineSpacing(3)
            }

            Divider()
                .opacity(0.1)

            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(AppTheme.warning)
                    .font(.caption)
                Text("Medhavn provides informational insights only. Always consult your fertility specialist for medical advice.")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
                    .lineSpacing(2)
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 16)
    }

    private func dayOfCycle(_ cycle: FertilityCycleRecord) -> Int {
        let calendar = Calendar.current
        return (calendar.dateComponents([.day], from: cycle.startDate, to: Date()).day ?? 0) + 1
    }
}

// MARK: - Symptoms Log Tab
struct SymptomsLogTab: View {
    @EnvironmentObject private var appState: AppState
    @State private var showLog = false

    var body: some View {
        ZStack {
            MeshBackgroundView()
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    quickLogSection

                    symptomsHistorySection
                }
                .padding(16)
            }
        }
        .sheet(isPresented: $showLog) {
            LogFertilitySymptomView()
                .environmentObject(appState)
        }
    }

    private var quickLogSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Log")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.primary)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 10) {
                QuickLogButton(icon: "thermometer", title: "BBT", color: AppTheme.accentBlue) {
                    showLog = true
                }
                QuickLogButton(icon: "drop.fill", title: "CM", color: AppTheme.accentTeal) {
                    showLog = true
                }
                QuickLogButton(icon: "circle.dotted", title: "OPK", color: AppTheme.success) {
                    showLog = true
                }
                QuickLogButton(icon: "drop", title: "Spotting", color: AppTheme.danger) {
                    showLog = true
                }
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 16)
    }

    private var symptomsHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Symptoms")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.primary)

            if appState.fertilitySymptoms.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "heart.text.square")
                        .font(.title)
                        .foregroundStyle(.white.opacity(0.5))
                    Text("No symptoms logged yet")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding(30)
                .glassCard(cornerRadius: 16)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(appState.fertilitySymptoms.prefix(20)) { symptom in
                        SymptomRecordRow(symptom: symptom)
                    }
                }
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 16)
    }
}

struct QuickLogButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .foregroundStyle(color)
                        .font(.system(size: 18))
                }
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }
}

struct SymptomRecordRow: View {
    let symptom: FertilitySymptomRecord

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(symptom.symptomType)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)

                HStack(spacing: 8) {
                    Text(symptom.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.5))

                    if let bbt = symptom.basalBodyTemp {
                        Text("BBT: \(String(format: "%.1f", bbt))°F")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.5))
                    }

                    if symptom.ovulationTestPositive == true {
                        Text("OPK+")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(AppTheme.success)
                    }

                    if symptom.spotting {
                        Text("Spotting")
                            .font(.caption2)
                            .foregroundStyle(AppTheme.danger)
                    }
                }
            }

            Spacer()

            Text("★ \(symptom.severity)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(12)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Treatments Tab
struct TreatmentsTab: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ZStack {
            MeshBackgroundView()
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    if appState.fertilityTreatments.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "pills")
                                .font(.system(size: 48))
                                .foregroundStyle(.white.opacity(0.5))
                            Text("No Treatments Logged")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(.white)
                            Text("Track IVF, IUI, or fertility medications with precise dosing schedules.")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                        }
                        .padding(24)
                        .glassCard(cornerRadius: 16)
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(appState.fertilityTreatments) { treatment in
                                TreatmentCard(treatment: treatment)
                            }
                        }
                    }
                }
                .padding(16)
            }
        }
    }
}

struct TreatmentCard: View {
    @EnvironmentObject private var appState: AppState
    let treatment: FertilityTreatmentRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(AppTheme.primary.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: "pills.fill")
                        .foregroundStyle(AppTheme.primary)
                        .font(.system(size: 16))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(treatment.treatmentType)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                    Text(treatment.medicationName)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }

                Spacer()

                if let cycleDay = treatment.cycleDay {
                    Text("Day \(cycleDay)")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(AppTheme.primary.opacity(0.2))
                        .foregroundStyle(AppTheme.primary)
                        .clipShape(Capsule())
                }
            }

            Divider()
                .opacity(0.1)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Dosage")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.5))
                    Text(treatment.dosage)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Started")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.5))
                    Text(treatment.startDate.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                }
            }

            if !treatment.instructions.isEmpty {
                Text(treatment.instructions)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(10)
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(14)
        .glassCard(cornerRadius: 14)
    }
}

// MARK: - Labs Tab
struct LabsTab: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ZStack {
            MeshBackgroundView()
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    if appState.fertilityLabs.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "flask")
                                .font(.system(size: 48))
                                .foregroundStyle(.white.opacity(0.5))
                            Text("No Lab Results")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(.white)
                            Text("Track hormone levels, fertility panels, and other lab results.")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                        }
                        .padding(24)
                        .glassCard(cornerRadius: 16)
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(appState.fertilityLabs) { lab in
                                LabResultCard(lab: lab)
                            }
                        }
                    }
                }
                .padding(16)
            }
        }
    }
}

struct LabResultCard: View {
    let lab: FertilityLabRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(lab.testName)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)

                Spacer()

                Text(lab.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
            }

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Result")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.5))
                    Text(lab.result)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(AppTheme.primary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Unit")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.5))
                    Text(lab.unit)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Reference")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.5))
                    Text(lab.referenceRange)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                }
            }

            if !lab.orderedBy.isEmpty || !lab.notes.isEmpty {
                Divider()
                    .opacity(0.1)

                HStack {
                    if !lab.orderedBy.isEmpty {
                        Label(lab.orderedBy, systemImage: "stethoscope")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    if !lab.notes.isEmpty {
                        Spacer()
                        Text(lab.notes)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
            }
        }
        .padding(14)
        .glassCard(cornerRadius: 14)
    }
}

// MARK: - Add Fertility Cycle View
struct AddFertilityCycleView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @State private var cycleStartDate = Date()
    @State private var cycleLength = 28
    @State private var periodLength = 5

    private let cycleLengths = Array(21...40)
    private let periodLengths = Array(1...10)

    var body: some View {
        NavigationStack {
            ZStack {
                MeshBackgroundView()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Cycle Start")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppTheme.primary)
                                .padding(.horizontal, 4)

                            DatePicker("First day of period", selection: $cycleStartDate, displayedComponents: .date)
                                .font(.subheadline)
                                .tint(AppTheme.primary)
                                .padding(16)
                                .glassCard(cornerRadius: 16)
                        }

                        VStack(alignment: .leading, spacing: 14) {
                            Text("Cycle Configuration")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppTheme.primary)
                                .padding(.horizontal, 4)

                            VStack(spacing: 16) {
                                HStack {
                                    Text("Cycle Length")
                                        .font(.subheadline)
                                        .foregroundStyle(.white)
                                    Spacer()
                                    Picker("Cycle Length", selection: $cycleLength) {
                                        ForEach(cycleLengths, id: \.self) { len in
                                            Text("\(len) days").tag(len)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .tint(AppTheme.primary)
                                }

                                Divider()
                                    .opacity(0.1)

                                HStack {
                                    Text("Period Length")
                                        .font(.subheadline)
                                        .foregroundStyle(.white)
                                    Spacer()
                                    Picker("Period Length", selection: $periodLength) {
                                        ForEach(periodLengths, id: \.self) { len in
                                            Text("\(len) days").tag(len)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .tint(AppTheme.primary)
                                }
                            }
                            .padding(16)
                            .glassCard(cornerRadius: 16)
                        }

                        Button {
                            let predictedNext = Calendar.current.date(byAdding: .day, value: cycleLength, to: cycleStartDate)
                            var cycle = FertilityCycleRecord(
                                startDate: cycleStartDate,
                                cycleLength: cycleLength,
                                periodLength: periodLength,
                                predictedNextPeriod: predictedNext,
                                state: .menstruation
                            )
                            if let predicted = predictedNext {
                                let calendar = Calendar.current
                                if let ovulationDay = calendar.date(byAdding: .day, value: -14, to: predicted),
                                   let fertileStart = calendar.date(byAdding: .day, value: -5, to: ovulationDay) {
                                    cycle.predictedFertileWindow = (fertileStart, ovulationDay)
                                }
                            }
                            appState.addFertilityCycle(cycle)
                            dismiss()
                        } label: {
                            Text("Save Cycle")
                                .font(.headline.weight(.bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(AppTheme.primary)
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                                .shadow(color: AppTheme.primary.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Log Cycle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
    }
}

// MARK: - Log Fertility Symptom View
struct LogFertilitySymptomView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @State private var symptomType = ""
    @State private var severity = 5
    @State private var notes = ""
    @State private var cervicalMucusQuality = ""
    @State private var basalBodyTemp = ""
    @State private var ovulationTestPositive = false
    @State private var spotting = false
    @State private var logDate = Date()

    private let symptomTypes = [
        "Abdominal Cramping", "Bloating", "Breast Tenderness", "Fatigue",
        "Headache", "Mood Swings", "Back Pain", "Acne", "Cervical Position",
        "Libido Changes", "Food Cravings", "Nausea", "Constipation", "Other"
    ]

    private let mucusQualities = ["Dry", "Sticky", "Creamy", "Egg White", "Watery"]

    var body: some View {
        NavigationStack {
            ZStack {
                MeshBackgroundView()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Symptom Details")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppTheme.primary)
                                .padding(.horizontal, 4)

                            VStack(spacing: 12) {
                                Picker("Symptom Type", selection: $symptomType) {
                                    Text("Select type...").tag("")
                                    ForEach(symptomTypes, id: \.self) { type in
                                        Text(type).tag(type)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(AppTheme.primary)

                                DatePicker("Date", selection: $logDate, displayedComponents: .date)
                                    .font(.subheadline)
                                    .tint(AppTheme.primary)

                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Severity: \(severity)/10")
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.7))
                                    Slider(value: .init(get: { Double(severity) }, set: { severity = Int($0) }), in: 1...10, step: 1)
                                        .tint(AppTheme.primary)
                                }
                            }
                            .padding(16)
                            .glassCard(cornerRadius: 16)
                        }

                        VStack(alignment: .leading, spacing: 14) {
                            Text("Fertility Metrics")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppTheme.primary)
                                .padding(.horizontal, 4)

                            VStack(spacing: 12) {
                                HStack {
                                    Text("Cervical Mucus")
                                        .font(.subheadline)
                                        .foregroundStyle(.white)
                                    Spacer()
                                    Picker("CM Quality", selection: $cervicalMucusQuality) {
                                        Text("Select...").tag("")
                                        ForEach(mucusQualities, id: \.self) { q in
                                            Text(q).tag(q)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .tint(AppTheme.primary)
                                }

                                Divider()
                                    .opacity(0.1)

                                HStack {
                                    Text("Basal Body Temp (°F)")
                                        .font(.subheadline)
                                        .foregroundStyle(.white)
                                    Spacer()
                                    TextField("98.6", text: $basalBodyTemp)
                                        .keyboardType(.decimalPad)
                                        .frame(width: 80)
                                        .padding(8)
                                        .background(Color.white.opacity(0.08))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }

                                Divider()
                                    .opacity(0.1)

                                Toggle("Ovulation Test Positive", isOn: $ovulationTestPositive)
                                    .tint(AppTheme.primary)

                                Divider()
                                    .opacity(0.1)

                                Toggle("Spotting", isOn: $spotting)
                                    .tint(AppTheme.primary)
                            }
                            .padding(16)
                            .glassCard(cornerRadius: 16)
                        }

                        VStack(alignment: .leading, spacing: 14) {
                            Text("Notes")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white.opacity(0.7))
                                .padding(.horizontal, 4)

                            TextEditor(text: $notes)
                                .frame(minHeight: 80)
                                .padding(8)
                                .background(Color.white.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                                )
                        }

                        Button {
                            saveSymptom()
                            dismiss()
                        } label: {
                            Text("Log Symptom")
                                .font(.headline.weight(.bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(AppTheme.primary)
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                                .shadow(color: AppTheme.primary.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .disabled(symptomType.isEmpty)
                        .opacity(symptomType.isEmpty ? 0.6 : 1.0)
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Log Symptom")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
    }

    private func saveSymptom() {
        var bbt: Double? = nil
        if let temp = Double(basalBodyTemp), !basalBodyTemp.isEmpty {
            bbt = temp
        }

        let symptom = FertilitySymptomRecord(
            date: logDate,
            symptomType: symptomType,
            severity: severity,
            notes: notes,
            cervicalMucusQuality: cervicalMucusQuality.isEmpty ? nil : cervicalMucusQuality,
            basalBodyTemp: bbt,
            ovulationTestPositive: ovulationTestPositive ? true : nil,
            spotting: spotting
        )
        appState.addFertilitySymptom(symptom)
    }
}

// MARK: - Add Fertility Treatment View
struct AddFertilityTreatmentView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @State private var treatmentType = ""
    @State private var medicationName = ""
    @State private var dosage = ""
    @State private var startDate = Date()
    @State private var cycleDay: Int? = nil
    @State private var instructions = ""

    private let treatmentTypes = ["IVF", "IUI", "Clomid", "Letrozole", "Gonal-F", "Menopur", "Cetrotide", "Lupron", "Prometrium", "Progesterone", "HCG Trigger", "Other"]

    var body: some View {
        NavigationStack {
            ZStack {
                MeshBackgroundView()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Treatment Info")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppTheme.primary)
                                .padding(.horizontal, 4)

                            VStack(spacing: 12) {
                                Picker("Treatment Type", selection: $treatmentType) {
                                    Text("Select type...").tag("")
                                    ForEach(treatmentTypes, id: \.self) { type in
                                        Text(type).tag(type)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(AppTheme.primary)

                                TextField("Medication Name", text: $medicationName)
                                    .padding(12)
                                    .background(Color.white.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))

                                TextField("Dosage (e.g., 150 IU)", text: $dosage)
                                    .padding(12)
                                    .background(Color.white.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .padding(16)
                            .glassCard(cornerRadius: 16)
                        }

                        VStack(alignment: .leading, spacing: 14) {
                            Text("Schedule")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppTheme.primary)
                                .padding(.horizontal, 4)

                            VStack(spacing: 12) {
                                DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                                    .font(.subheadline)
                                    .tint(AppTheme.primary)

                                HStack {
                                    Text("Cycle Day (optional)")
                                        .font(.subheadline)
                                        .foregroundStyle(.white)
                                    Spacer()
                                    TextField("Day", value: $cycleDay, format: .number)
                                        .keyboardType(.numberPad)
                                        .frame(width: 60)
                                        .padding(8)
                                        .background(Color.white.opacity(0.08))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                            .padding(16)
                            .glassCard(cornerRadius: 16)
                        }

                        VStack(alignment: .leading, spacing: 14) {
                            Text("Instructions")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white.opacity(0.7))
                                .padding(.horizontal, 4)

                            TextEditor(text: $instructions)
                                .frame(minHeight: 100)
                                .padding(8)
                                .background(Color.white.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                                )
                        }

                        Button {
                            let treatment = FertilityTreatmentRecord(
                                treatmentType: treatmentType,
                                medicationName: medicationName,
                                dosage: dosage,
                                startDate: startDate,
                                instructions: instructions,
                                cycleDay: cycleDay
                            )
                            appState.addFertilityTreatment(treatment)
                            dismiss()
                        } label: {
                            Text("Save Treatment")
                                .font(.headline.weight(.bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(AppTheme.primary)
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                                .shadow(color: AppTheme.primary.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .disabled(medicationName.isEmpty)
                        .opacity(medicationName.isEmpty ? 0.6 : 1.0)
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Add Treatment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
    }
}

// MARK: - Add Fertility Lab View
struct AddFertilityLabView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @State private var testName = ""
    @State private var result = ""
    @State private var unit = ""
    @State private var referenceRange = ""
    @State private var date = Date()
    @State private var orderedBy = ""
    @State private var notes = ""

    private let commonTests = [
        "FSH", "LH", "Estradiol", "Progesterone", "Testosterone", "Prolactin",
        "AMH", "TSH", "hCG", "Estrogen", "Inhibin B", "Cortisol"
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                MeshBackgroundView()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Test Details")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppTheme.primary)
                                .padding(.horizontal, 4)

                            VStack(spacing: 12) {
                                Picker("Test Name", selection: $testName) {
                                    Text("Select test...").tag("")
                                    ForEach(commonTests, id: \.self) { test in
                                        Text(test).tag(test)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(AppTheme.primary)

                                HStack(spacing: 12) {
                                    TextField("Result", text: $result)
                                        .keyboardType(.decimalPad)
                                        .padding(12)
                                        .background(Color.white.opacity(0.08))
                                        .clipShape(RoundedRectangle(cornerRadius: 10))

                                    TextField("Unit", text: $unit)
                                        .padding(12)
                                        .background(Color.white.opacity(0.08))
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                            }
                            .padding(16)
                            .glassCard(cornerRadius: 16)
                        }

                        VStack(alignment: .leading, spacing: 14) {
                            Text("Reference Range")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppTheme.primary)
                                .padding(.horizontal, 4)

                            TextField("e.g., 2.5-10.2 mIU/mL", text: $referenceRange)
                                .padding(12)
                                .background(Color.white.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .padding(16)
                                .glassCard(cornerRadius: 16)
                        }

                        VStack(alignment: .leading, spacing: 14) {
                            Text("Context")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppTheme.primary)
                                .padding(.horizontal, 4)

                            VStack(spacing: 12) {
                                DatePicker("Test Date", selection: $date, displayedComponents: .date)
                                    .font(.subheadline)
                                    .tint(AppTheme.primary)

                                TextField("Ordered By (e.g., Dr. Smith)", text: $orderedBy)
                                    .padding(12)
                                    .background(Color.white.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .padding(16)
                            .glassCard(cornerRadius: 16)
                        }

                        VStack(alignment: .leading, spacing: 14) {
                            Text("Notes")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white.opacity(0.7))
                                .padding(.horizontal, 4)

                            TextEditor(text: $notes)
                                .frame(minHeight: 80)
                                .padding(8)
                                .background(Color.white.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                                )
                        }

                        Button {
                            let lab = FertilityLabRecord(
                                testName: testName,
                                result: result,
                                unit: unit,
                                referenceRange: referenceRange,
                                date: date,
                                orderedBy: orderedBy,
                                notes: notes
                            )
                            appState.addFertilityLab(lab)
                            dismiss()
                        } label: {
                            Text("Save Lab Result")
                                .font(.headline.weight(.bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(AppTheme.primary)
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                                .shadow(color: AppTheme.primary.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .disabled(testName.isEmpty || result.isEmpty)
                        .opacity(testName.isEmpty || result.isEmpty ? 0.6 : 1.0)
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Add Lab Result")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
    }
}