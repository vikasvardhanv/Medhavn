import SwiftUI

/// Full-screen experience shown once on first install.
/// Step 1: Consent prompt — discloses download size and asks the user to confirm.
/// Step 2: Download progress — shown only after the user taps "Download Now".
/// After `AppState.isFirstLaunchSetupDone` becomes true this view is never shown again.
struct FirstLaunchSetupView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ZStack {
            if appState.isDownloadConsentGiven {
                DownloadProgressView()
            } else {
                DownloadConsentPromptView()
            }
        }
        // Background uses MeshBackgroundView for consistent dark theme
        .background {
            MeshBackgroundView()
        }
    }
}

// MARK: - Step 1: Consent Prompt

/// Shown before any download begins.
/// Discloses the download size and lets the user choose to proceed or skip.
private struct DownloadConsentPromptView: View {
    @EnvironmentObject private var appState: AppState
    @State private var pillPulse = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Image(systemName: "pills.circle.fill")
                .symbolRenderingMode(.palette)
                .foregroundStyle(.gray, .white)
                .font(.system(size: 100))
                .scaleEffect(pillPulse ? 1.09 : 1.0)
                .animation(
                    .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                    value: pillPulse
                )
                .padding(.bottom, 32)

            Text("Set up Intuio AI Assistant")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Text("Intuio is your on-device AI assistant for medication questions and insights. It runs entirely on your device — no data is ever sent to a server.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.82))
                .multilineTextAlignment(.center)
                .padding(.top, 12)
                .padding(.horizontal, 32)

            // Download disclosure card
            VStack(alignment: .leading, spacing: 14) {
                Label("One-time download required", systemImage: "arrow.down.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)

                HStack(spacing: 10) {
                    Image(systemName: "internaldrive")
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(width: 20)
                    Text("Download size: approximately 320 MB")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.9))
                }

                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "wifi")
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(width: 20)
                    Text("A Wi-Fi connection is recommended. The download happens once; the model is then cached on your device for all future use.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.75))
                }

                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "lock.shield")
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(width: 20)
                    Text("The AI model never leaves your device. All processing is fully on-device and offline.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.75))
                }
            }
            .padding(20)
            .background(.white.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 24)
            .padding(.top, 32)

            Spacer()

            VStack(spacing: 16) {
                Button {
                    appState.startModelDownloadWithConsent()
                } label: {
                    Text("Download Now (~320 MB)")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(.white)
                        .foregroundStyle(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 24)

                Button {
                    appState.skipFirstLaunchSetup()
                } label: {
                    Text("Skip — use app without AI assistant")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                        .underline()
                }
            }
            .padding(.bottom, 48)
        }
        .onAppear { pillPulse = true }
    }
}

// MARK: - Step 2: Download Progress

/// Shown after the user has consented to the download.
private struct DownloadProgressView: View {
    @EnvironmentObject private var appState: AppState

    @State private var progress: Double = 0.0
    @State private var elapsed: Double  = 0.0
    @State private var ticker: Timer?
    @State private var showSkip   = false
    @State private var pillPulse  = false
    @State private var doneScale: Double = 0.0

    private let tickInterval: Double = 0.5
    private let targetFraction: Double = 0.92
    private let targetSeconds:  Double = 90

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Image(systemName: "pills.circle.fill")
                .symbolRenderingMode(.palette)
                .foregroundStyle(.gray, .white)
                .font(.system(size: 100))
                .scaleEffect(pillPulse ? 1.09 : 1.0)
                .animation(
                    .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                    value: pillPulse
                )
                .padding(.bottom, 32)

            Text("Setting up Intuio")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)

            Text("Downloading your AI assistant")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.82))
                .padding(.top, 6)

            Text("≈ 320 MB · one-time only")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.55))
                .padding(.top, 2)

            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.18), lineWidth: 9)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        Color.white,
                        style: StrokeStyle(lineWidth: 9, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.45), value: progress)

                if appState.isModelWarmedUp {
                    Image(systemName: "checkmark")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(.white)
                        .scaleEffect(doneScale)
                        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: doneScale)
                } else {
                    VStack(spacing: 2) {
                        Text("\(Int(progress * 100))%")
                            .font(.system(size: 26, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                        Text(elapsedLabel)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.65))
                    }
                }
            }
            .frame(width: 120, height: 120)
            .padding(.top, 40)

            statusText
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.75))
                .padding(.top, 20)
                .padding(.horizontal, 32)
                .animation(.easeInOut, value: appState.modelPrewarmFailed)

            VStack(spacing: 24) {
                if appState.modelPrewarmFailed {
                    retryButton
                    skipButton
                } else if showSkip && !appState.isModelWarmedUp {
                    skipButton
                }
            }
            .padding(.top, 18)

            Spacer()

            Text("After this setup you can use all features offline.\nThe AI model never leaves your device.")
                .font(.caption2)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.4))
                .padding(.bottom, 36)
                .padding(.horizontal, 40)
        }
        .onAppear {
            pillPulse = true
            startTicker()
        }
        .onDisappear {
            ticker?.invalidate()
        }
        .onChange(of: appState.isModelWarmedUp) { _, warmedUp in
            if warmedUp {
                withAnimation(.linear(duration: 0.3)) { progress = 1.0 }
                doneScale = 1.0
                ticker?.invalidate()
                Task {
                    try? await Task.sleep(for: .seconds(1.4))
                    appState.completeFirstLaunchSetup()
                }
            }
        }
        .onChange(of: appState.modelPrewarmFailed) { _, failed in
            if failed { ticker?.invalidate() }
        }
    }

    @ViewBuilder private var statusText: some View {
        if appState.isModelWarmedUp {
            Text("AI assistant is ready!")
                .foregroundStyle(.white)
        } else if appState.modelPrewarmFailed {
            Text("Download failed. Please check your internet connection,\nthen tap Retry.")
        } else {
            Text("Keep the app open to complete setup.\nYou can return to it any time.")
        }
    }

    private var retryButton: some View {
        Button {
            retryDownload()
        } label: {
            Label("Retry Download", systemImage: "arrow.clockwise")
                .font(.subheadline.bold())
                .padding(.horizontal, 28)
                .padding(.vertical, 12)
                .background(.white.opacity(0.18))
                .clipShape(Capsule())
                .foregroundStyle(.white)
        }
    }

    private var skipButton: some View {
        Button {
            ticker?.invalidate()
            appState.skipFirstLaunchSetup()
        } label: {
            Text("Continue without AI assistant")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
                .underline()
        }
    }

    private var elapsedLabel: String {
        guard elapsed >= 1 else { return "connecting…" }
        let m = Int(elapsed) / 60
        let s = Int(elapsed) % 60
        return m > 0 ? String(format: "%d:%02d", m, s) : "\(Int(elapsed)) s"
    }

    private func startTicker() {
        let increment = targetFraction / (targetSeconds / tickInterval)
        ticker = Timer.scheduledTimer(withTimeInterval: tickInterval, repeats: true) { _ in
            elapsed += tickInterval
            if progress < targetFraction {
                progress = min(targetFraction, progress + increment)
            }
            if elapsed >= 60 { showSkip = true }
        }
    }

    private func retryDownload() {
        progress = 0
        elapsed  = 0
        showSkip = false
        startTicker()
        appState.retryModelPrewarm()
    }
}

#Preview {
    FirstLaunchSetupView()
        .environmentObject(AppState())
}
