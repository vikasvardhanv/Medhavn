import SwiftUI
import MedicationLogicEngine

struct AdherenceSummary {
    let taken: Int
    let missed: Int
    let compliance: Int
}

struct DailyAdherenceRecord {
    let date: Date
    let taken: Int
    let missed: Int
}

struct ReportsDashboardView: View {
    @EnvironmentObject private var appState: AppState

    init() {}

    var body: some View {
        let rawSummary = appState.weeklyAdherenceSummary()
        let summary = AdherenceSummary(
            taken: rawSummary.taken,
            missed: rawSummary.missed,
            compliance: rawSummary.compliance
        )
        
        let rawHistory = appState.dailyAdherenceHistory(days: 7)
        let history = rawHistory.map {
            DailyAdherenceRecord(date: $0.date, taken: $0.taken, missed: $0.missed)
        }

        ScrollView {
            VStack(spacing: 24) {
                // Adherence ring dashboard card
                adherenceSummaryCard(summary: summary)
                    .staggeredEntrance(delay: 0.0)

                // Day-by-day breakdown
                doseHistoryList(history: history)
                    .staggeredEntrance(delay: 0.1)

                // Export button
                exportButtonSection
                    .staggeredEntrance(delay: 0.2)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 32)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .background { MeshBackgroundView() }
        .navigationTitle("Insights")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
    }

    @ViewBuilder
    private func adherenceSummaryCard(summary: AdherenceSummary) -> some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.24), lineWidth: 14)
                
                Circle()
                    .trim(from: 0, to: min(CGFloat(summary.compliance) / 100.0, 1.0))
                    .stroke(
                        LinearGradient(
                            colors: [AppTheme.primary, AppTheme.secondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 14, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.9, dampingFraction: 0.8), value: summary.compliance)
                
                VStack(spacing: 4) {
                    Text("\(summary.compliance)%")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    
                    Text("Compliance")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .frame(width: 148, height: 148)
            .padding(.top, 8)

            HStack(spacing: 40) {
                VStack(spacing: 4) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(AppTheme.success)
                            .frame(width: 8, height: 8)
                        Text("\(summary.taken)")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    Text("Doses Taken")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.7))
                }
                
                VStack(spacing: 4) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(AppTheme.danger)
                            .frame(width: 8, height: 8)
                        Text("\(summary.missed)")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    Text("Doses Missed")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .glassCard(cornerRadius: 24)
    }

    @ViewBuilder
    private func doseHistoryList(history: [DailyAdherenceRecord]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Dose History")
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 4)

            VStack(spacing: 12) {
                ForEach(history.reversed(), id: \.date) { day in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(day.date.formatted(.dateTime.weekday(.wide).month().day()))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                            
                            if day.taken == 0 && day.missed == 0 {
                                Text("No doses logged")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.6))
                            } else {
                                HStack(spacing: 12) {
                                    if day.taken > 0 {
                                        Label("\(day.taken) Taken", systemImage: "checkmark.circle.fill")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(AppTheme.success)
                                    }
                                    if day.missed > 0 {
                                        Label("\(day.missed) Missed", systemImage: "xmark.circle.fill")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(AppTheme.danger)
                                    }
                                }
                            }
                        }
                        
                        Spacer()
                        
                        // Small indicator ring for the day
                        let total = day.taken + day.missed
                        let compliance = total > 0 ? Double(day.taken) / Double(total) : 0.0
                        
                        ZStack {
                            Circle()
                                .stroke(Color.white.opacity(0.2), lineWidth: 4)
                            
                            if total > 0 {
                                Circle()
                                    .trim(from: 0, to: CGFloat(compliance))
                                    .stroke(
                                        compliance > 0.79 ? AppTheme.success : (compliance > 0.49 ? AppTheme.warning : AppTheme.danger),
                                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                                    )
                                    .rotationEffect(.degrees(-90))
                            }
                        }
                        .frame(width: 28, height: 28)
                    }
                    .padding(14)
                    .background(Color.white.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
                }
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 24)
    }

    private var exportButtonSection: some View {
        Group {
            if let plan = appState.selectedPlan {
                ShareLink(
                    item: PDFExporter.adherenceSummary(plan: plan, logs: appState.todayLog),
                    preview: SharePreview(
                        "Medhavn Adherence Summary",
                        image: Image(systemName: "doc.richtext")
                    )
                ) {
                    Label("Export Report for Clinician", systemImage: "square.and.arrow.up")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [AppTheme.primary, AppTheme.primary.opacity(0.85)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: AppTheme.primary.opacity(0.3), radius: 8, x: 0, y: 4)
                }
            } else {
                VStack(spacing: 8) {
                    Label("Export Report for Clinician", systemImage: "square.and.arrow.up")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.white.opacity(0.12))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                    
                    Text("Add a medication plan to enable export")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
        }
    }
}
