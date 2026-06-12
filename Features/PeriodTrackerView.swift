import SwiftUI

struct PeriodTrackerView: View {
    @EnvironmentObject private var appState: AppState
    @State private var showLogPeriod = false
    @State private var showLogSymptom = false

    private var currentCycle: FertilityCycleRecord? {
        appState.currentFertilityCycle
    }

    var body: some View {
        ZStack {
            MeshBackgroundView()
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    summaryCard
                    quickActions
                    upcomingCard
                    recentSymptoms
                }
                .padding(16)
            }
        }
        .navigationTitle("Period Tracker")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showLogPeriod = true
                    } label: {
                        Label("Log Period", systemImage: "drop.fill")
                    }
                    Button {
                        showLogSymptom = true
                    } label: {
                        Label("Log Symptom", systemImage: "heart.text.square")
                    }
                } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(AppTheme.primary)
                }
            }
        }
        .sheet(isPresented: $showLogPeriod) {
            AddFertilityCycleView()
                .environmentObject(appState)
        }
        .sheet(isPresented: $showLogSymptom) {
            LogFertilitySymptomView()
                .environmentObject(appState)
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(AppTheme.danger.opacity(0.16))
                        .frame(width: 52, height: 52)
                    Image(systemName: "drop.fill")
                        .font(.title2)
                        .foregroundStyle(AppTheme.danger)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(currentCycle == nil ? "Start period tracking" : cyclePhaseTitle)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)

                    Text(summarySubtitle)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }

                Spacer()
            }

            if let cycle = currentCycle {
                HStack(spacing: 12) {
                    periodStat("Cycle Day", "\(cycleDay(for: cycle))")
                    periodStat("Cycle", "\(cycle.cycleLength)d")
                    periodStat("Period", "\(cycle.periodLength)d")
                }
            }
        }
        .padding(18)
        .glassCard(cornerRadius: 18)
    }

    private var quickActions: some View {
        HStack(spacing: 12) {
            Button {
                showLogPeriod = true
            } label: {
                Label("Period", systemImage: "drop.fill")
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AppTheme.danger)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }

            Button {
                showLogSymptom = true
            } label: {
                Label("Symptom", systemImage: "heart.text.square")
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AppTheme.primary)
                    .foregroundStyle(.black)
                    .clipShape(Capsule())
            }
        }
    }

    private var upcomingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Upcoming")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.primary)

            if let cycle = currentCycle {
                timelineRow(
                    icon: "calendar",
                    title: "Next period",
                    detail: (appState.predictNextPeriod(from: cycle) ?? cycle.predictedNextPeriod)?
                        .formatted(date: .abbreviated, time: .omitted) ?? "Not enough data"
                )

                if let window = appState.predictFertileWindow(from: cycle) ?? cycle.predictedFertileWindow {
                    Divider().opacity(0.1)
                    timelineRow(
                        icon: "sparkles",
                        title: "Fertile window",
                        detail: "\(window.start.formatted(date: .abbreviated, time: .omitted)) - \(window.end.formatted(date: .abbreviated, time: .omitted))"
                    )
                }
            } else {
                Text("Log the first day of your latest period to calculate cycle day and upcoming dates.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 16)
    }

    private var recentSymptoms: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Logs")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.primary)

            if appState.fertilitySymptoms.isEmpty {
                Text("No symptoms logged yet.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)
            } else {
                ForEach(appState.fertilitySymptoms.prefix(6)) { symptom in
                    HStack(spacing: 12) {
                        Image(systemName: symptom.spotting ? "drop" : "heart.text.square")
                            .foregroundStyle(symptom.spotting ? AppTheme.danger : AppTheme.primary)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(symptom.symptomType)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                            Text("\(symptom.date.formatted(date: .abbreviated, time: .omitted)) · severity \(symptom.severity)/10")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.65))
                        }

                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 16)
    }

    private var cyclePhaseTitle: String {
        guard let cycle = currentCycle else { return "Period" }
        return appState.currentCycleState(for: cycle).rawValue
    }

    private var summarySubtitle: String {
        guard let cycle = currentCycle else {
            return "Track bleeding days, symptoms, and cycle predictions."
        }
        if isInPeriod(cycle) {
            return "Period day \(cycleDay(for: cycle))"
        }
        return "Last period started \(cycle.startDate.formatted(date: .abbreviated, time: .omitted))"
    }

    private func periodStat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.55))
            Text(value)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func timelineRow(icon: String, title: String, detail: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(AppTheme.primary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
            Spacer()
        }
    }

    private func cycleDay(for cycle: FertilityCycleRecord) -> Int {
        (Calendar.current.dateComponents([.day], from: cycle.startDate, to: Date()).day ?? 0) + 1
    }

    private func isInPeriod(_ cycle: FertilityCycleRecord) -> Bool {
        cycleDay(for: cycle) <= cycle.periodLength
    }
}
