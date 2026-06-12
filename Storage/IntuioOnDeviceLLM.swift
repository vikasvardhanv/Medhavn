import Foundation

#if canImport(MLX) && canImport(MLXLLM) && canImport(MLXLMCommon)
import MLX
import MLXLLM
import MLXLMCommon
#if canImport(MLXHuggingFace)
import MLXHuggingFace
#endif
#if canImport(HuggingFace)
import HuggingFace
#endif
#if canImport(Tokenizers)
import Tokenizers
#endif
#endif

enum IntuioLocalModelRuntime: String {
    case mlx = "MLX"
    case ruleBased = "RuleBased"
}

struct IntuioAssistantTurn {
    let role: IntuioAssistantRole
    let text: String
}

enum IntuioAssistantRole {
    case user
    case assistant
}

protocol IntuioAssistantChatting {
    var modelName: String { get }
    func warmup() async -> Bool
    func generateReply(for userText: String, history: [IntuioAssistantTurn]) async -> String
}

enum IntuioLocalNoteEngineFactory {
    static func make() -> IntuioLocalNoteGenerating {
        #if canImport(MLX) && canImport(MLXLLM) && canImport(MLXLMCommon) && !targetEnvironment(simulator)
        return IntuioMLXNoteEngine()
        #else
        return IntuioMicroSLMNoteEngine()
        #endif
    }

    static var runtime: IntuioLocalModelRuntime {
        #if canImport(MLX) && canImport(MLXLLM) && canImport(MLXLMCommon) && !targetEnvironment(simulator)
        return .mlx
        #else
        return .ruleBased
        #endif
    }
}

struct IntuioMLXNoteEngine: IntuioLocalNoteGenerating {
    let modelName: String

    init(modelName: String = "mlx-community/Qwen2-0.5B-Instruct-4bit") {
        self.modelName = modelName
    }

    func generateNote(input: IntuioNoteInput) async -> String {
        let prompt = buildPrompt(input: input)

        #if canImport(MLX) && canImport(MLXLLM) && canImport(MLXLMCommon) && !targetEnvironment(simulator)
        let generated = await generateWithMLX(prompt: prompt)
        if let generated, !generated.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return generated
        }
        #endif

        return await IntuioMicroSLMNoteEngine().generateNote(input: input)
    }

    private func buildPrompt(input: IntuioNoteInput) -> String {
        let planName = input.parsed.drugName ?? "Medication"
        let todayEvents = input.output.schedule
            .flatMap(\.events)
            .filter { Calendar.current.isDateInToday($0.date) && !$0.isPRN }
        let takenScheduled = input.logsToday.filter { !$0.isPRN }.count
        let totalScheduled = todayEvents.count
        let remaining = max(0, totalScheduled - takenScheduled)

        let nextEvent = todayEvents
            .filter { $0.date > input.now }
            .sorted { $0.date < $1.date }
            .first

        let nextDoseLine: String
        if let nextEvent {
            nextDoseLine = "Next dose at \(nextEvent.date.formatted(date: .omitted, time: .shortened))."
        } else {
            nextDoseLine = "No additional scheduled dose today."
        }

        let flags = input.output.flags.map(\.message).joined(separator: " | ")
        let reminderState = input.remindersEnabled
            ? (input.notificationsAuthorized ? "enabled" : "permission-missing")
            : "disabled"

        let prnLine: String
        if let prn = input.parsed.prnRule {
            let maxDoses = prn.maxPerDayDoses.map(String.init) ?? "not-specified"
            let maxAmount = prn.maxPer24HoursAmount.map { String(format: "%.1f", $0) } ?? "not-specified"
            prnLine = "PRN \(prn.indication), max doses \(maxDoses), max amount \(maxAmount)."
        } else {
            prnLine = "No PRN regimen."
        }

        return """
        Write a concise daily patient note in under 80 words.
        Medication: \(planName)
        Scheduled taken: \(takenScheduled)/\(totalScheduled), remaining: \(remaining)
        \(nextDoseLine)
        Safety flags: \(flags.isEmpty ? "none" : flags)
        Reminder status: \(reminderState)
        \(prnLine)
        Tone: calm, clear, no diagnosis, no treatment change.
        """
    }

    #if canImport(MLX) && canImport(MLXLLM) && canImport(MLXLMCommon) && !targetEnvironment(simulator)
    private func generateWithMLX(prompt: String) async -> String? {
        do {
            let output = try await IntuioMLXRuntime.shared.generate(prompt: prompt, modelID: modelName)
            return output
        } catch {
            return nil
        }
    }
    #endif
}

struct IntuioAssistantChatEngine: IntuioAssistantChatting {
    let modelName: String

    init(modelName: String = "mlx-community/Qwen2-0.5B-Instruct-4bit") {
        self.modelName = modelName
    }

    func warmup() async -> Bool {
        await warmupWithProgress { _ in }
    }

    /// Warm up the model and stream fractional download progress (0.0–1.0) via `onProgress`.
    func warmupWithProgress(onProgress: @escaping @Sendable (Double) -> Void) async -> Bool {
        #if canImport(MLX) && canImport(MLXLLM) && canImport(MLXLMCommon) && !targetEnvironment(simulator)
        print("[IntuioChat] 🔄 Starting MLX warmup for model: \(modelName)")
        do {
            try await IntuioMLXRuntime.shared.warmup(modelID: modelName, onProgress: { fraction in
                print(String(format: "[IntuioChat] 📥 Download progress: %.0f%%", fraction * 100))
                onProgress(fraction)
            })
            print("[IntuioChat] ✅ MLX warmup complete — model loaded and ready")
            return true
        } catch {
            print("[IntuioChat] ❌ MLX warmup failed: \(error)")
            return false
        }
        #else
        // Simulator: Metal/MLX is unavailable. Return false so the UI
        // honestly shows fallback mode instead of "Intuio AI ready".
        print("[IntuioChat] ⚠️ Running in Simulator — MLX is unavailable (no Metal GPU). Using rule-based fallback.")
        onProgress(1.0)
        return false
        #endif
    }

    func generateReply(for userText: String, history: [IntuioAssistantTurn]) async -> String {
        let prompt = buildPrompt(userText: userText, history: history)

        #if canImport(MLX) && canImport(MLXLLM) && canImport(MLXLMCommon) && !targetEnvironment(simulator)
        print("[IntuioChat] 🧠 Sending to MLX engine (\(modelName)), prompt length: \(prompt.count) chars")
        do {
            let output = try await IntuioMLXRuntime.shared.generate(
                prompt: prompt, modelID: modelName, maxTokens: 220, temperature: 0.35
            )
            let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
            print("[IntuioChat] 💬 MLX response (\(trimmed.count) chars): \(trimmed.prefix(120))")
            if !trimmed.isEmpty {
                return trimmed
            }
            print("[IntuioChat] ⚠️ MLX returned empty output — falling back")
        } catch {
            print("[IntuioChat] ❌ MLX generation error: \(error) — falling back")
        }
        #else
        print("[IntuioChat] ⚠️ generateReply called but MLX not available (Simulator). Using rule-based reply for: \(userText.prefix(80))")
        #endif

        let reply = fallbackReply(for: userText)
        print("[IntuioChat] 📋 Fallback reply: \(reply.prefix(100))")
        return reply
    }

    private func buildPrompt(userText: String, history: [IntuioAssistantTurn]) -> String {
        let recentHistory = history.suffix(8)
        let historyLines = recentHistory.map { turn in
            let role = turn.role == .user ? "User" : "Assistant"
            return "\(role): \(turn.text)"
        }.joined(separator: "\n")

        return """
        You are Intuio, a concise medication support assistant in a patient app.
        Keep responses short, practical, and safety-first.
        Never diagnose, never prescribe medication changes, and recommend clinician/pharmacist review for uncertainty.

        Conversation:
        \(historyLines)
        User: \(userText)
        Assistant:
        """
    }

    func fallbackReplyPublic(for userText: String) -> String {
        fallbackReply(for: userText)
    }

    private func fallbackReply(for userText: String) -> String {
        let q = userText.lowercased()

        // Missed / late dose
        if q.contains("miss") || q.contains("forgot") || q.contains("late") || q.contains("skip") {
            return "If you missed a dose, take it as soon as you remember — unless it's almost time for your next one. Never double-dose. When in doubt, check with your pharmacist."
        }
        // Side effects / reactions
        if q.contains("side effect") || q.contains("reaction") || q.contains("rash") || q.contains("dizz") || q.contains("nause") || q.contains("vomit") {
            return "Side effects vary by medication. Mild effects (nausea, dizziness) often ease after a few days. Severe or sudden symptoms — call your clinician or seek urgent care immediately."
        }
        // Pain
        if q.contains("pain") || q.contains("hurt") || q.contains("ache") {
            return "If your pain is worsening or new, contact your clinician. Don't adjust pain medication doses without guidance — some combinations can be dangerous."
        }
        // Interaction
        if q.contains("interact") || q.contains("combine") || q.contains("together") || q.contains("mix") {
            return "Drug interactions can be serious. Use the Interactions Checker in Hub → Safety to scan your vault, and always confirm with your pharmacist before combining medications."
        }
        // Refill / running out
        if q.contains("refill") || q.contains("running out") || q.contains("pills left") || q.contains("prescription") {
            return "You can track pills remaining and set refill reminders in your Vault. Contact your pharmacy or clinician a few days before running out to avoid interruption."
        }
        // Schedule / reminder
        if q.contains("remind") || q.contains("schedule") || q.contains("when") || q.contains("time") {
            return "Your dose schedule is set up in the Vault. Check your DoseMap tab to see today's upcoming doses and mark them as taken."
        }
        // Medication access / what meds
        if q.contains("access") || q.contains("my medication") || q.contains("what med") || q.contains("know about") {
            return "I can see your medications in the Vault and your dose history on the DoseMap. Ask me about a specific medication, schedule, or interaction and I'll give you details."
        }
        // Food / alcohol
        if q.contains("food") || q.contains("eat") || q.contains("alcohol") || q.contains("drink") {
            return "Some medications should be taken with food to reduce stomach upset, while others need an empty stomach for proper absorption. Check your prescription label or ask your pharmacist."
        }
        // Storage
        if q.contains("store") || q.contains("refrigerat") || q.contains("temperature") || q.contains("heat") {
            return "Most medications should be stored in a cool, dry place away from direct sunlight. Some need refrigeration — check the label and keep them out of reach of children."
        }
        // Pregnancy / breastfeeding
        if q.contains("pregnan") || q.contains("breastfeed") || q.contains("nursing") {
            return "Medication safety during pregnancy or breastfeeding varies significantly. Always consult your OB or clinician before continuing or stopping any medication."
        }
        // Greeting
        if q.contains("hello") || q.contains("hi") || q == "hey" {
            return "Hi! I'm Intuio, your on-device medication assistant. Ask me about your schedule, missed doses, interactions, refills, or anything about your medications."
        }
        // Thanks
        if q.contains("thank") || q.contains("great") || q.contains("awesome") {
            return "Happy to help! Let me know if you have any other questions about your medications."
        }

        return "I can help with your medication schedule, missed doses, interactions, refill tracking, and safety questions. What would you like to know?"
    }

    private func breakFallback(error: Error) {
        _ = error
    }
}

#if canImport(MLX) && canImport(MLXLLM) && canImport(MLXLMCommon)
actor IntuioMLXRuntime {
    static let shared = IntuioMLXRuntime()

    private var cachedModelID: String?
    private var container: ModelContainer?

    private init() {
        // Allow the Metal GPU cache to hold model weights comfortably.
        // 20 MB was far too small for a ≈320 MB 4-bit model and caused
        // buffer thrashing / EXC_BAD_ACCESS crashes during inference.
        Memory.cacheLimit = 512 * 1024 * 1024   // 512 MB
    }

    func warmup(modelID: String, onProgress: @escaping @Sendable (Double) -> Void) async throws {
        print("[IntuioMLXRuntime] 📦 Loading model: \(modelID)")
        _ = try await loadModel(modelID: modelID, onProgress: onProgress)
        print("[IntuioMLXRuntime] ✅ Model loaded and cached")
    }

    func generate(prompt: String, modelID: String, maxTokens: Int = 96, temperature: Float = 0.3) async throws -> String {
        print("[IntuioMLXRuntime] ⚙️ Generating: maxTokens=\(maxTokens) temp=\(temperature)")
        let modelContainer = try await loadModel(modelID: modelID)
        let generatedText = try await modelContainer.perform { context in
            let input = try await context.processor.prepare(input: .init(prompt: prompt))
            let parameters = GenerateParameters(maxTokens: maxTokens, temperature: temperature, topP: 0.9)
            var localChunks: [String] = []

            for await item in try MLXLMCommon.generate(input: input, parameters: parameters, context: context) {
                switch item {
                case .chunk(let chunk):
                    localChunks.append(chunk)
                case .info, .toolCall:
                    break
                }
            }

            return localChunks.joined()
        }

        return generatedText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func loadModel(modelID: String, onProgress: @escaping @Sendable (Double) -> Void = { _ in }) async throws -> ModelContainer {
        if cachedModelID == modelID, let container {
            onProgress(1.0)
            return container
        }

        let configuration = LLMModelFactory.shared.configuration(id: modelID)
        let loaded = try await LLMModelFactory.shared.loadContainer(
            from: #hubDownloader(HubClient.default),
            using: #huggingFaceTokenizerLoader(),
            configuration: configuration,
            progressHandler: { progress in
                // Some runtime backends can briefly emit non-finite progress values.
                // Clamp aggressively so UI consumers (ProgressView/CoreGraphics) never receive NaN/inf.
                let rawFraction = progress.fractionCompleted
                let fraction: Double
                if rawFraction.isFinite {
                    fraction = min(max(rawFraction, 0.0), 1.0)
                } else {
                    fraction = 0.0
                }
                onProgress(fraction)
            }
        )
        cachedModelID = modelID
        container = loaded
        return loaded
    }
}
#endif
