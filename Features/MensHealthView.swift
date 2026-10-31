import SwiftUI

/// Preventive-care tracker for men: heart and vitals logging plus a check-up list.
/// Intervals are typical guidance only; the screen says to follow a doctor's advice.
struct MensHealthView: View {
    @EnvironmentObject private var appState: AppState
    @State private var systolic = ""
    @State private var diastolic = ""
    @State private var weight = ""

    private struct Check: Identifiable {
        let id: String
        let title: String
        let detail: String
        let intervalDays: Int?   // nil: no fixed schedule, so only the last date is shown
    }

    private let checks: [Check] = [
        Check(id: "checkup", title: "Annual check-up", detail: "A yearly visit with your doctor.", intervalDays: 365),
        Check(id: "bp", title: "Blood pressure check", detail: "Yearly, or as your doctor advises.", intervalDays: 365),
        Check(id: "cholesterol", title: "Cholesterol test", detail: "Often every 4 to 6 years from your 20s. Ask your doctor.", intervalDays: 1825),
        Check(id: "diabetes", title: "Blood sugar screening", detail: "Often every 3 years from age 35, sooner if overweight. Ask your doctor.", intervalDays: 1095),
        Check(id: "colorectal", title: "Colorectal screening", detail: "Usually starts around 45. Ask which test and how often.", intervalDays: nil),
        Check(id: "prostate", title: "Prostate screening talk", detail: "Many men discuss PSA testing from 50, or 45 with higher risk.", intervalDays: nil),
        Check(id: "selfcheck", title: "Testicular self-check", detail: "Once a month.", intervalDays: 30),
        Check(id: "skin", title: "Skin check", detail: "Yearly, or when a mole changes.", intervalDays: 365),
    ]

    private var weightUnit: String { Locale.current.measurementSystem == .us ? "lb" : "kg" }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                vitalsCard
                checksCard
                Text("This is general information, not medical advice. Follow your doctor's guidance on what and when to test.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(16)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .background { MeshBackgroundView() }
        .navigationTitle("Men's Health")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Heart and vitals

    private var vitalsCard: some View {
        card("Heart & vitals") {
            if let bp = latest(.bloodPressure) { reading("Blood pressure", "\(bp.value) \(bp.unit)", bp.timestamp) }
            if let w = latest(.weight) { reading("Weight", "\(w.value) \(w.unit)", w.timestamp) }

            HStack(spacing: 8) {
                field("Sys", $systolic)
                Text("/").foregroundStyle(.white.opacity(0.6))
                field("Dia", $diastolic)
                Button("Log BP") {
                    appState.addHealthMetric(type: .bloodPressure, value: "\(systolic)/\(diastolic)", unit: "mmHg")
                    systolic = ""; diastolic = ""
                }
                .buttonStyle(pill)
                .disabled(Int(systolic) == nil || Int(diastolic) == nil)
            }
            HStack(spacing: 8) {
                field("Weight (\(weightUnit))", $weight)
                Button("Log weight") {
                    appState.addHealthMetric(type: .weight, value: weight, unit: weightUnit)
                    weight = ""
                }
                .buttonStyle(pill)
                .disabled(Double(weight) == nil)
            }
        }
    }

    // MARK: Check-ups

    private var checksCard: some View {
        card("Check-ups & screenings") {
            ForEach(checks) { check in
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(check.title).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                        Text(check.detail).font(.caption).foregroundStyle(.white.opacity(0.65))
                        statusText(for: check)
                    }
                    Spacer()
                    Button("Done today") { appState.markPreventiveCheckDone(check.id) }
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.primary)
                }
                .padding(.vertical, 4)
            }
        }
    }

    @ViewBuilder private func statusText(for check: Check) -> some View {
        if let last = appState.preventiveChecks[check.id] {
            if let days = check.intervalDays, let due = Calendar.current.date(byAdding: .day, value: days, to: last) {
                let overdue = due < Date()
                Text(overdue ? "Overdue since \(due.formatted(date: .abbreviated, time: .omitted))" : "Next around \(due.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(overdue ? AppTheme.danger : AppTheme.primary)
            } else {
                Text("Last discussed \(last.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption2).foregroundStyle(AppTheme.primary)
            }
        } else {
            Text("Not logged yet").font(.caption2).foregroundStyle(.white.opacity(0.5))
        }
    }

    // MARK: Pieces

    private func latest(_ type: HealthMetricType) -> HealthMetricRecord? {
        appState.healthMetrics.first { $0.type == type }
    }

    private func reading(_ title: String, _ value: String, _ date: Date) -> some View {
        HStack {
            Text(title).font(.subheadline).foregroundStyle(.white.opacity(0.8))
            Spacer()
            VStack(alignment: .trailing, spacing: 0) {
                Text(value).font(.subheadline.weight(.bold)).foregroundStyle(.white)
                Text(date.formatted(date: .abbreviated, time: .omitted)).font(.caption2).foregroundStyle(.white.opacity(0.55))
            }
        }
    }

    private func field(_ placeholder: String, _ text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .keyboardType(.decimalPad)
            .padding(10)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .foregroundStyle(.white)
    }

    private var pill: some PrimitiveButtonStyle { BorderedProminentButtonStyle() }

    private func card<C: View>(_ title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline.weight(.bold)).foregroundStyle(.white)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 16)
    }
}
