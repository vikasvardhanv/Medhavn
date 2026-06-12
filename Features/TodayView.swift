import SwiftUI
import MedicationLogicEngine

struct TodayView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ZStack {
            MeshBackgroundView()
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    if let plan = appState.selectedPlan, let parsed = appState.parsedPlan(for: plan) {
                        let output = appState.engine.process(text: plan.sourceText, projectionDays: 1)
                        let today = output.schedule.first
                        let next = today?.events.first(where: { $0.date > Date() })
                        let remaining = today?.events.filter { $0.date >= Date() }.count ?? 0
                        let prn = appState.prnRemainingForToday(parsed: parsed)
                        let hasPRN = parsed.prnRule != nil
                        let hasPRNLimits = prn.0 != nil || prn.1 != nil
                        let hasReachedPRNCap = (prn.0 == 0) || (prn.1 == 0)
                        let canLogPRN = hasPRN && hasPRNLimits && (prn.0.map { $0 > 0 } ?? true) && (prn.1.map { $0 > 0 } ?? true)

                        // 1. Next Action / Adherence Prompt
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Label("NEXT ACTION", systemImage: "clock.badge.checkmark.fill")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(AppTheme.primary)
                                Spacer()
                            }
                            
                                if let next {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("Take \(formatDose(next.dose)) \(next.units)")
                                        .font(.title2.weight(.bold))
                                        .foregroundStyle(.white)
                                    
                                    HStack {
                                        Image(systemName: "clock")
                                            .font(.caption)
                                        Text("Scheduled: \(next.date.formatted(date: .omitted, time: .shortened))")
                                            .font(.subheadline)
                                    }
                                    .foregroundStyle(.white.opacity(0.7))
                                    
                                    Text("As directed by your active prescription plan.")
                                        .font(.caption2)
                                        .foregroundStyle(.white.opacity(0.6))
                                        .padding(.bottom, 6)
                                    
                                    Button {
                                        appState.markTaken(event: next, isPRN: false)
                                    } label: {
                                        HStack(spacing: 8) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.system(size: 15, weight: .bold))
                                            Text("Mark as Taken")
                                                .font(.subheadline.weight(.bold))
                                        }
                                        .foregroundStyle(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(
                                            LinearGradient(
                                                colors: [AppTheme.primary, AppTheme.secondary],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .clipShape(Capsule())
                                        .shadow(color: AppTheme.primary.opacity(0.4), radius: 8, x: 0, y: 4)
                                    }
                                    .buttonStyle(.plain)
                                }
                            } else {
                                HStack(spacing: 10) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.title2)
                                        .foregroundStyle(AppTheme.success)
                                    Text("You’re all set — no scheduled doses left today.")
                                        .font(.subheadline.weight(.semibold))
                                }
                                .padding(.vertical, 8)
                            }
                        }
                        .padding(18)
                        .glassCard(cornerRadius: 16)
                        .staggeredEntrance(delay: 0.0)

                        // 2. Scheduled Doses Left Summary
                        HStack {
                            Text("Scheduled doses left today")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text("\(remaining)")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(remaining > 0 ? AppTheme.primary : AppTheme.success)
                        }
                        .padding(16)
                        .glassCard(cornerRadius: 14)
                        .staggeredEntrance(delay: 0.05)

                        // 3. PRN Allowance
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Label("PRN ALLOWANCE", systemImage: "questionmark.circle.fill")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(AppTheme.info)
                                Spacer()
                            }
                            
                            if !hasPRN {
                                Text("No PRN (as-needed) regimen detected in this plan.")
                                    .font(.footnote)
                                    .foregroundStyle(.white.opacity(0.7))
                            } else {
                                VStack(spacing: 12) {
                                    HStack {
                                        Text("Remaining PRN doses")
                                            .font(.footnote)
                                            .foregroundStyle(.white.opacity(0.7))
                                        Spacer()
                                        Text(prn.0.map(String.init) ?? "Not specified")
                                            .font(.subheadline.weight(.bold))
                                            .foregroundStyle(.white)
                                    }
                                    
                                    HStack {
                                        Text("Remaining PRN amount")
                                            .font(.footnote)
                                            .foregroundStyle(.white.opacity(0.7))
                                        Spacer()
                                        Text("\(prn.1.map { String(format: "%.1f", $0) } ?? "Not specified") \(parsed.units ?? "unit")")
                                            .font(.subheadline.weight(.bold))
                                            .foregroundStyle(.white)
                                    }
                                    
                                    if !hasPRNLimits {
                                        Label("PRN limits not specified. Add limits before logging.", systemImage: "exclamationmark.triangle.fill")
                                            .font(.caption)
                                            .foregroundStyle(AppTheme.warning)
                                    } else if hasReachedPRNCap {
                                        Label("PRN limits fully reached for today.", systemImage: "xmark.octagon.fill")
                                            .font(.caption)
                                            .foregroundStyle(AppTheme.danger)
                                    }
                                    
                                    if canLogPRN {
                                        Button {
                                            let event = DoseEvent(date: Date(), dose: parsed.dose ?? 0, units: parsed.units ?? "unit", isPRN: true)
                                            appState.markTaken(event: event, isPRN: true)
                                        } label: {
                                            Label("Log PRN Dose Now", systemImage: "plus")
                                                .font(.subheadline.weight(.bold))
                                                .foregroundStyle(.white)
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 12)
                                                .background(
                                                    LinearGradient(
                                                        colors: [AppTheme.info, AppTheme.info.opacity(0.8)],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    )
                                                )
                                                .clipShape(Capsule())
                                                .shadow(color: AppTheme.info.opacity(0.35), radius: 6, x: 0, y: 3)
                                        }
                                        .padding(.top, 4)
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                        .padding(18)
                        .glassCard(cornerRadius: 16)
                        .staggeredEntrance(delay: 0.1)

                        // 4. Clinical Consistency Alerts
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Label("PRESCRIPTION CONSISTENCY", systemImage: "exclamationmark.shield.fill")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(output.flags.isEmpty ? AppTheme.success : AppTheme.warning)
                                Spacer()
                            }
                            
                            if output.flags.isEmpty {
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.shield.fill")
                                        .foregroundStyle(AppTheme.success)
                                    Text("No scheduling conflicts or guidelines issues detected in your medication instructions.")
                                        .font(.footnote)
                                        .foregroundStyle(.white.opacity(0.7))
                                }
                            } else {
                                VStack(spacing: 12) {
                                    ForEach(Array(output.flags.enumerated()), id: \.offset) { _, flag in
                                        VStack(alignment: .leading, spacing: 6) {
                                            HStack(alignment: .top, spacing: 8) {
                                                Image(systemName: flag.severity == .critical ? "xmark.octagon.fill" : "exclamationmark.triangle.fill")
                                                    .foregroundStyle(flag.severity == .critical ? AppTheme.danger : AppTheme.warning)
                                                Text(flag.message)
                                                    .font(.footnote.weight(.semibold))
                                                    .foregroundStyle(flag.severity == .critical ? AppTheme.danger : AppTheme.warning)
                                            }
                                            Text("Please verify instructions with your prescriber before logging.")
                                                .font(.caption2)
                                                .foregroundStyle(.white.opacity(0.6))
                                                .padding(.leading, 24)
                                        }
                                        .padding(10)
                                        .background(Color.white.opacity(0.15))
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                    }
                                }
                            }
                        }
                        .padding(18)
                        .glassCard(cornerRadius: 16)
                        .staggeredEntrance(delay: 0.15)

                        // 5. Proactive Safety Assistant
                        if !appState.proactiveSuggestions.isEmpty {
                            VStack(alignment: .leading, spacing: 14) {
                                Label("PROACTIVE ASSISTANT", systemImage: "lightbulb.fill")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(AppTheme.warning)
                                
                                ForEach(appState.proactiveSuggestions) { suggestion in
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(suggestion.title)
                                            .font(.subheadline.weight(.bold))
                                            .foregroundStyle(.white)
                                        Text(suggestion.detail)
                                            .font(.caption)
                                            .foregroundStyle(.white.opacity(0.7))
                                            .lineSpacing(3)
                                        
                                        if let actionTitle = suggestion.actionTitle {
                                            Button {
                                                appState.handleSuggestionAction(suggestion.action)
                                            } label: {
                                                Text(actionTitle)
                                                    .font(.caption.weight(.bold))
                                                    .padding(.horizontal, 14)
                                                    .padding(.vertical, 6)
                                                    .background(AppTheme.primary)
                                                    .foregroundStyle(.black)
                                                    .clipShape(Capsule())
                                            }
                                            .padding(.top, 4)
                                        }
                                    }
                                    .padding(12)
                                    .background(Color.white.opacity(0.15))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                            }
                            .padding(18)
                            .glassCard(cornerRadius: 16)
                            .staggeredEntrance(delay: 0.2)
                        }

                        // 6. Intuio On-Device AI Adherence Summarization
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Label("INTUIO NOTE (ON-DEVICE AI)", systemImage: "sparkles")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(AppTheme.info)
                                Spacer()
                            }
                            
                            if let note = appState.dailyInsightNote {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(note.noteBody)
                                        .font(.subheadline)
                                        .foregroundStyle(.white)
                                        .lineSpacing(4)
                                    
                                    Divider()
                                        .opacity(0.1)
                                    
                                    Text("Generated: \(note.createdAt.formatted(date: .omitted, time: .shortened)) · Model: \(note.modelName)")
                                        .font(.caption2)
                                        .foregroundStyle(.white.opacity(0.6))
                                }
                            } else {
                                Text("Generate a daily summary explaining clinical consistency, dose adherence, and safety metrics.")
                                    .font(.footnote)
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                            
                            if let message = appState.insightNoteErrorMessage, !message.isEmpty {
                                Text(message)
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.danger)
                            }
                            
                            if appState.isGeneratingInsightNote {
                                SafetyPrewarmLoader()
                            } else {
                                Button {
                                    appState.generateDailyInsightNote()
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "sparkles")
                                            .font(.system(size: 12, weight: .bold))
                                        Text(appState.dailyInsightNote == nil ? "Generate Intuio Note" : "Regenerate Note")
                                            .font(.caption.weight(.bold))
                                    }
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        LinearGradient(
                                            colors: [AppTheme.info, AppTheme.info.opacity(0.8)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .clipShape(Capsule())
                                    .shadow(color: AppTheme.info.opacity(0.35), radius: 6, x: 0, y: 3)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(18)
                        .background(
                            ZStack {
                                Color.white.opacity(0.01)
                                RadialGradient(
                                    colors: [AppTheme.info.opacity(0.12), Color.clear],
                                    center: .topLeading,
                                    startRadius: 5,
                                    endRadius: 180
                                )
                            }
                        )
                        .glassCard(cornerRadius: 20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(
                                    LinearGradient(
                                        colors: [AppTheme.info.opacity(0.6), AppTheme.secondary.opacity(0.2), AppTheme.info.opacity(0.1), AppTheme.info.opacity(0.4)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.5
                                )
                        )
                        .shadow(color: AppTheme.info.opacity(0.15), radius: 12, x: 0, y: 6)
                        .staggeredEntrance(delay: 0.25)

                        // 7. Adherence Log
                        VStack(alignment: .leading, spacing: 14) {
                            Label("ADHERENCE LOG", systemImage: "list.bullet.rectangle.portrait.fill")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppTheme.primary)
                            
                            if appState.todayLog.isEmpty {
                                Text("No doses logged yet today.")
                                    .font(.footnote)
                                    .foregroundStyle(.white.opacity(0.7))
                                    .padding(.vertical, 4)
                            } else {
                                VStack(spacing: 10) {
                                    ForEach(appState.todayLog) { log in
                                        HStack {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(AppTheme.success)
                                                .font(.footnote)
                                            Text(log.timestamp.formatted(date: .omitted, time: .shortened))
                                                .font(.footnote.weight(.semibold))
                                                .foregroundStyle(.white)
                                            Spacer()
                                            Text("\(formatDose(log.dose)) \(log.units)\(log.isPRN ? " (PRN)" : "")")
                                                .font(.footnote)
                                                .foregroundStyle(.white.opacity(0.7))
                                        }
                                        .padding(8)
                                        .background(Color.white.opacity(0.1))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                }
                            }
                        }
                        .padding(18)
                        .glassCard(cornerRadius: 16)
                        .staggeredEntrance(delay: 0.3)

                        // 8. PDF Export & Action Area
                        ShareLink(item: PDFExporter.adherenceSummary(plan: plan, logs: appState.todayLog), preview: SharePreview("Adherence Summary")) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("Export Adherence PDF Summary")
                            }
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.white.opacity(0.12))
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(AppTheme.primary.opacity(0.2), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .staggeredEntrance(delay: 0.35)

                        // Disclaimer Card
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: "info.circle.fill")
                                Text("Disclaimer: Medhavn displays clinical rules parsed from your user inputs for convenience only. It does not recommend doses or provide diagnostic opinions. Follow clinical guidelines.")
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.6))
                        }
                        .padding(14)
                        .glassCard(cornerRadius: 12)
                        .staggeredEntrance(delay: 0.4)
                    } else {
                        // Empty State (No medication plan)
                        VStack(spacing: 20) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 64))
                                .foregroundStyle(AppTheme.primary)
                            
                            Text("No Active Plan Configured")
                                .font(.title3.weight(.bold))
                            
                            Text("Please navigate to the Plan tab to enter, scan, or upload prescription instructions and initialize your adherence tracker.")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                        }
                        .padding(32)
                        .glassCard(cornerRadius: 16)
                        .padding(.horizontal, 8)
                        .padding(.top, 60)
                        .staggeredEntrance(delay: 0.0)
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle("Today")
        .onAppear {
            appState.refreshProactiveSuggestions()
            appState.loadDailyInsightNote()
        }
    }

    private func formatDose(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    private func color(for priority: ProactiveSuggestionPriority) -> Color {
        switch priority {
        case .critical: return AppTheme.danger
        case .warning: return AppTheme.warning
        case .info: return AppTheme.primary
        }
    }
}

// MARK: - Safety Prewarm Loader
struct SafetyPrewarmLoader: View {
    @State private var rotateValue: Double = 0.0
    @State private var pulseScale: CGFloat = 1.0
    
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(AppTheme.info.opacity(0.25), lineWidth: 3)
                    .frame(width: 24, height: 24)
                
                Circle()
                    .trim(from: 0.0, to: 0.6)
                    .stroke(
                        LinearGradient(
                            colors: [AppTheme.info, AppTheme.secondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 24, height: 24)
                    .rotationEffect(.degrees(rotateValue))
                    .onAppear {
                        withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                            rotateValue = 360
                        }
                    }
                
                Circle()
                    .fill(AppTheme.info)
                    .frame(width: 8, height: 8)
                    .scaleEffect(pulseScale)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                            pulseScale = 1.3
                        }
                    }
            }
            .frame(width: 24, height: 24)
            
            Text("Analyzing clinical consistency on-device...")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(.vertical, 6)
    }
}
