import SwiftUI

struct FloatingPillChatHost: View {
    @EnvironmentObject private var appState: AppState
    @State private var showChat = false

    var body: some View {
        FloatingPillLauncher(showChat: $showChat)
            .sheet(isPresented: $showChat) {
                IntuioChatSheetView()
                    .environmentObject(appState)
            }
    }
}

private struct FloatingPillLauncher: View {
    @Binding var showChat: Bool
    @State private var floatOffset: CGSize = .zero

    var body: some View {
        Button {
            showChat = true
        } label: {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 58, height: 58)
                    .overlay(
                        Circle()
                            .stroke(.white.opacity(0.45), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.16), radius: 10, y: 6)

                Image(systemName: "pills.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(AppTheme.primary)
            }
        }
        .offset(floatOffset)
        .frame(width: 76, height: 76)
        .padding(.trailing, 16)
        .padding(.bottom, 80)
        .accessibilityLabel("Open Intuio Chat")
        .onAppear {
            withAnimation(
                .easeInOut(duration: 2.2)
                .repeatForever(autoreverses: true)
            ) {
                floatOffset = CGSize(width: 8, height: -9)
            }
        }
    }
}

private struct IntuioChatSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState

    @State private var messages: [IntuioChatMessage] = [
        IntuioChatMessage(role: .assistant, text: "Hi, I'm Intuio. Ask me about your medication schedule, reminders, or safety checks.")
    ]
    @State private var composerText = ""
    @State private var isLoadingModel = true
    @State private var isSending = false
    @State private var modelLoadFailed = false
    @State private var modelReady = false
    @State private var downloadProgress: Double = 0
    @State private var showDownloadConsent = false

    private var chatEngine: IntuioAssistantChatEngine { appState.sharedChatEngine }

    var body: some View {
        ZStack {
            MeshBackgroundView()
                .ignoresSafeArea()

            NavigationStack {
                VStack(spacing: 12) {
                    if isLoadingModel {
                        VStack(spacing: 6) {
                            HStack(spacing: 6) {
                                ProgressView().controlSize(.small)
                                Text(downloadProgress > 0 && downloadProgress < 1
                                     ? String(format: "Downloading model… %.0f%%", downloadProgress * 100)
                                     : "Loading Intuio AI model…")
                                    .font(.footnote)
                                    .foregroundStyle(.white)
                            }
                            if downloadProgress > 0 && downloadProgress < 1 {
                                ProgressView(value: downloadProgress)
                                    .tint(AppTheme.primary)
                                    .padding(.horizontal, 20)
                            }
                        }
                    } else if modelLoadFailed || !modelReady {
                        Label("Fallback mode · on-device rules", systemImage: "bolt.horizontal.circle.fill")
                            .font(.footnote)
                            .foregroundStyle(AppTheme.warning)
                    } else {
                        Label("Intuio AI ready · on-device", systemImage: "checkmark.circle.fill")
                            .font(.footnote)
                            .foregroundStyle(AppTheme.success)
                    }

                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 10) {
                                ForEach(messages) { message in
                                    messageBubble(message)
                                        .id(message.id)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                        }
                        .onChange(of: messages.count) { _, _ in
                            if let lastID = messages.last?.id {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    proxy.scrollTo(lastID, anchor: .bottom)
                                }
                            }
                        }
                    }

                    HStack(spacing: 10) {
                        TextField(isLoadingModel ? "Model loading, reply will use fallback…" : "Message Intuio", text: $composerText)
                            .textFieldStyle(.roundedBorder)
                            .disabled(isSending)

                        Button {
                            sendMessage()
                        } label: {
                            if isSending {
                                ProgressView()
                                    .controlSize(.small)
                                    .frame(width: 24, height: 24)
                            } else {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundStyle(AppTheme.primary)
                            }
                        }
                        .disabled(composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
                }
                .navigationTitle("Intuio Chat")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
                .task {
                    await loadModel()
                }
                .sheet(isPresented: $showDownloadConsent) {
                    IntuioChatDownloadConsentSheetView(
                        isPresented: $showDownloadConsent,
                        onConsent: {
                            appState.startModelDownloadWithConsent()
                            Task { await loadModel() }
                        },
                        onSkip: {
                            modelReady = false
                            modelLoadFailed = false
                        }
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func messageBubble(_ message: IntuioChatMessage) -> some View {
        HStack {
            if message.role == .assistant {
                bubble(message.text, isAssistant: true)
                Spacer(minLength: 36)
            } else {
                Spacer(minLength: 36)
                bubble(message.text, isAssistant: false)
            }
        }
    }

    private func bubble(_ text: String, isAssistant: Bool) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(isAssistant ? Color.white : Color.black)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(isAssistant ? AppTheme.cardBackground : AppTheme.primary)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func loadModel() async {
        print("[IntuioChatView] 🚀 loadModel() called — isModelWarmedUp=\(appState.isModelWarmedUp)")

        if appState.isModelWarmedUp {
            print("[IntuioChatView] ✅ Model already warmed up — skipping download")
            isLoadingModel = false
            modelReady = true
            modelLoadFailed = false
            return
        }

        if !appState.isDownloadConsentGiven {
            print("[IntuioChatView] 📋 Model not ready and no consent — showing consent prompt")
            isLoadingModel = false
            showDownloadConsent = true
            return
        }

        isLoadingModel = true
        modelLoadFailed = false
        modelReady = false
        downloadProgress = 0

        let loaded = await chatEngine.warmupWithProgress { fraction in
            Task { @MainActor in
                if fraction.isFinite {
                    self.downloadProgress = min(max(fraction, 0.0), 1.0)
                } else {
                    self.downloadProgress = 0.0
                }
            }
        }

        print("[IntuioChatView] warmup result: loaded=\(loaded)")
        isLoadingModel = false
        modelReady = loaded
        modelLoadFailed = !loaded
        appState.isModelWarmedUp = loaded

        if modelLoadFailed {
            messages.append(IntuioChatMessage(
                role: .assistant,
                text: "Model download timed out — using on-device fallback. Responses are still safe and helpful."
            ))
        }
    }

    private func sendMessage() {
        let text = composerText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        composerText = ""
        messages.append(IntuioChatMessage(role: .user, text: text))
        isSending = true

        let turns = messages.map { message in
            IntuioAssistantTurn(
                role: message.role == .assistant ? .assistant : .user,
                text: message.text
            )
        }

        let useModel = modelReady
        Task {
            let reply: String
            if useModel {
                reply = await withTaskGroup(of: String.self) { group in
                    group.addTask { await self.chatEngine.generateReply(for: text, history: turns, appState: self.appState) }
                    group.addTask {
                        try? await Task.sleep(for: .seconds(20))
                        return "I'm sorry, generating a response took too long. Please try again."
                    }
                    let result = await group.next() ?? "Something went wrong. Please try again."
                    group.cancelAll()
                    return result
                }
            } else {
                reply = chatEngine.fallbackReplyPublic(for: text, appState: appState)
            }
            messages.append(IntuioChatMessage(role: .assistant, text: reply))
            isSending = false
        }
    }
}

private struct IntuioChatMessage: Identifiable {
    enum Role {
        case user
        case assistant
    }

    let id = UUID()
    let role: Role
    let text: String
}

// MARK: - Download Consent Sheet

private struct IntuioChatDownloadConsentSheetView: View {
    @Binding var isPresented: Bool
    let onConsent: () -> Void
    let onSkip: () -> Void

    @State private var pillPulse = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer()

                Image(systemName: "pills.circle.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.gray, .white)
                    .font(.system(size: 80))
                    .scaleEffect(pillPulse ? 1.09 : 1.0)
                    .animation(
                        .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                        value: pillPulse
                    )
                    .padding(.bottom, 28)

                Text("Ready for Intuio AI?")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Text("Download the AI model to get intelligent medication insights powered by on-device machine learning.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.82))
                    .multilineTextAlignment(.center)
                    .padding(.top, 12)
                    .padding(.horizontal, 32)

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
                        onConsent()
                        isPresented = false
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
                        onSkip()
                        isPresented = false
                    } label: {
                        Text("Continue without AI model")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                            .underline()
                    }
                }
                .padding(.bottom, 48)
            }
            .background {
                MeshBackgroundView()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { isPresented = false }
                }
            }
            .onAppear { pillPulse = true }
        }
    }
}