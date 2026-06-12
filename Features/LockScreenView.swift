import SwiftUI
import LocalAuthentication

struct LockScreenView: View {
    @EnvironmentObject private var appState: AppState

    @State private var enteredPin: String = ""
    @State private var shake: Bool = false
    @State private var wrongAttempts: Int = 0
    @State private var errorMessage: String = ""

    private let pinLength = 4

    var body: some View {
        ZStack {
            VStack(spacing: 32) {
                Spacer()

                // App icon + prompt
                VStack(spacing: 12) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.white.opacity(0.9))

                    Text("Intuio is locked")
                        .font(.title2.bold())
                        .foregroundStyle(.white)

                    Text("Enter your 4-digit PIN")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.75))
                }

                // PIN dots
                HStack(spacing: 20) {
                    ForEach(0..<pinLength, id: \.self) { i in
                        Circle()
                            .fill(i < enteredPin.count ? Color.white : Color.white.opacity(0.3))
                            .frame(width: 16, height: 16)
                    }
                }
                .modifier(ShakeModifier(trigger: shake))

                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(AppTheme.danger)
                        .padding(.horizontal)
                }

                // Number pad
                VStack(spacing: 16) {
                    ForEach([[1,2,3],[4,5,6],[7,8,9]], id: \.self) { row in
                        HStack(spacing: 24) {
                            ForEach(row, id: \.self) { num in
                                PinKeyButton(label: "\(num)") { appendDigit("\(num)") }
                            }
                        }
                    }
                    HStack(spacing: 24) {
                        // Face ID button
                        PinKeyButton(label: "", systemImage: biometricSymbol, secondary: true) {
                            Task { _ = await appState.authenticateBiometric() }
                        }
                        .opacity(appState.biometricLockEnabled ? 1 : 0)
                        .disabled(!appState.biometricLockEnabled)

                        PinKeyButton(label: "0") { appendDigit("0") }

                        PinKeyButton(label: "", systemImage: "delete.left", secondary: true) { deleteDigit() }
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 40)
        }
        // Background uses MeshBackgroundView for consistent dark theme
        .background {
            MeshBackgroundView()
        }
        .onAppear {
            if appState.biometricLockEnabled {
                Task {
                    try? await Task.sleep(for: .milliseconds(600))
                    _ = await appState.authenticateBiometric()
                }
            }
        }
    }

    // MARK: – Helpers

    private var biometricSymbol: String {
        let context = LAContext()
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            return context.biometryType == .faceID ? "faceid" : "touchid"
        }
        return "faceid"
    }

    private func appendDigit(_ digit: String) {
        guard enteredPin.count < pinLength else { return }
        enteredPin += digit
        if enteredPin.count == pinLength {
            validate()
        }
    }

    private func deleteDigit() {
        guard !enteredPin.isEmpty else { return }
        enteredPin.removeLast()
        errorMessage = ""
    }

    private func validate() {
        if appState.verifyPIN(enteredPin) {
            appState.unlockApp()
        } else {
            wrongAttempts += 1
            withAnimation(.default) { shake.toggle() }
            errorMessage = wrongAttempts >= 3
                ? "Incorrect PIN (\(wrongAttempts) attempts)"
                : "Incorrect PIN – try again"
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                enteredPin = ""
            }
        }
    }
}

// MARK: – Sub-views

private struct PinKeyButton: View {
    var label: String
    var systemImage: String? = nil
    var secondary: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(secondary ? Color.white.opacity(0.1) : Color.white.opacity(0.2))
                    .frame(width: 72, height: 72)
                if let sym = systemImage {
                    Image(systemName: sym)
                        .font(.title2)
                        .foregroundStyle(.white)
                } else {
                    Text(label)
                        .font(.title.weight(.regular))
                        .foregroundStyle(.white)
                }
            }
        }
    }
}

private struct ShakeModifier: ViewModifier {
    var trigger: Bool

    func body(content: Content) -> some View {
        content
            .offset(x: trigger ? 8 : 0)
            .animation(
                trigger
                    ? .spring(response: 0.1, dampingFraction: 0.2).repeatCount(4, autoreverses: true)
                    : .default,
                value: trigger
            )
    }
}
