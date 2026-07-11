import SwiftUI

// MARK: - Tracker Selection View (Signup Step)

/// Presented after the Consent Checklist and before the main tab shell.
/// Lets the user choose which tracker (if any) should occupy the 3rd tab bar slot
/// in place of Insights. Insights is never lost — it moves to the Hub when displaced.
struct TrackerSelectionView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.horizontalSizeClass) private var hSizeClass

    @State private var selectedPreference: TrackerPreference?
    @State private var animateCards = false

    private var isPad: Bool { hSizeClass == .regular }

    private var backgroundLayer: some View {
        MeshBackgroundView()
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ScrollView(showsIndicators: false) {
                    VStack {
                        if isPad { Spacer(minLength: 0) }

                        VStack(alignment: .leading, spacing: 28) {
                            // Header
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Personalize Your Experience")
                                    .font(isPad ? .system(size: 36, weight: .bold) : .title.weight(.bold))
                                    .foregroundStyle(.primary)

                                Text("Choose a tracker for quick access in your tab bar. You can always change this later in Settings.")
                                    .font(isPad ? .title3 : .subheadline)
                                    .foregroundStyle(.primary.opacity(0.75))
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            // Tracker option cards
                            VStack(spacing: 14) {
                                trackerOptionCard(
                                    preference: .period,
                                    icon: "drop.fill",
                                    color: AppTheme.danger,
                                    title: "Period Tracker",
                                    subtitle: "Cycle tracking, predictions & symptom logging",
                                    delay: 0.1
                                )

                                trackerOptionCard(
                                    preference: .fertility,
                                    icon: "heart.circle.fill",
                                    color: Color(red: 0.93, green: 0.42, blue: 0.60),
                                    title: "Fertility Tracker",
                                    subtitle: "Ovulation, treatments & lab tracking",
                                    delay: 0.2
                                )
                            }

                            // Continue button
                            if let selected = selectedPreference {
                                Button {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                        appState.completeTrackerSelection(selected)
                                    }
                                } label: {
                                    HStack {
                                        Image(systemName: "checkmark.circle.fill")
                                        Text("Continue with \(selected.displayName)")
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.large)
                                .frame(maxWidth: .infinity)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                            }

                            // Skip option
                            Button {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                    appState.completeTrackerSelection(.none)
                                }
                            } label: {
                                Text("Skip — I'll use the default Insights tab")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.primary.opacity(0.6))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                            }
                        }
                        .frame(maxWidth: 520)
                        .padding(.horizontal, isPad ? 40 : 20)
                        .padding(.top, isPad ? 0 : 20)
                        .padding(.bottom, 20)

                        if isPad { Spacer(minLength: 0) }
                    }
                    .frame(minHeight: geo.size.height)
                }
                .safeAreaPadding(.bottom)
            }
            .background { backgroundLayer }
            .navigationTitle("Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(.regularMaterial, for: .navigationBar)
            .onAppear {
                withAnimation(.easeOut(duration: 0.6).delay(0.15)) {
                    animateCards = true
                }
            }
        }
    }

    // MARK: - Tracker Option Card

    @ViewBuilder
    private func trackerOptionCard(
        preference: TrackerPreference,
        icon: String,
        color: Color,
        title: String,
        subtitle: String,
        delay: Double
    ) -> some View {
        let isSelected = selectedPreference == preference

        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                selectedPreference = preference
            }
        } label: {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [color, color.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 52, height: 52)

                    Image(systemName: icon)
                        .foregroundStyle(.white)
                        .font(.system(size: 24, weight: .bold))
                }
                .shadow(color: color.opacity(0.3), radius: 6, x: 0, y: 3)

                // Labels
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                // Selection indicator
                ZStack {
                    Circle()
                        .stroke(isSelected ? color : Color.white.opacity(0.3), lineWidth: 2)
                        .frame(width: 26, height: 26)

                    if isSelected {
                        Circle()
                            .fill(color)
                            .frame(width: 18, height: 18)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .padding(isPad ? 20 : 16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(
                        isSelected ? color.opacity(0.6) : Color.white.opacity(0.16),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .shadow(
                color: isSelected ? color.opacity(0.15) : Color.clear,
                radius: 12, x: 0, y: 4
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
        .opacity(animateCards ? 1 : 0)
        .offset(y: animateCards ? 0 : 20)
        .animation(.easeOut(duration: 0.5).delay(delay), value: animateCards)
    }
}
