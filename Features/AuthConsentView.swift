import SwiftUI

// MARK: - Adaptive layout helper
private extension View {
    /// Constrains content to a readable card width on iPad, full-width on iPhone.
    func adaptiveCardFrame() -> some View {
        self.frame(maxWidth: 520)
    }
}

struct LoginView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.horizontalSizeClass) private var hSizeClass

    enum AuthMode: String, CaseIterable {
        case login = "Login"
        case signup = "Sign Up"
    }

    @State private var mode: AuthMode = .login
    @State private var email = ""
    @State private var password = ""
    @State private var fullName = ""
    @State private var referralCodeInput = ""
    @State private var sexChoice: Sex?
    @State private var confirmPassword = ""
    @State private var showForgotPassword = false
    @State private var showOTPVerification = false
    @State private var enteredOTP = ""
    @State private var isSendingOTP = false
    @State private var otpError: String? = nil

    private var isPad: Bool { hSizeClass == .regular }

    private var backgroundLayer: some View {
        MeshBackgroundView()
    }

    private var canSubmit: Bool {
        !appState.isAuthenticating
        && !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !password.isEmpty
        && (mode == .login || (!confirmPassword.isEmpty && !fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && sexChoice != nil))
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ScrollView(showsIndicators: false) {
                    VStack {
                        if isPad { Spacer(minLength: 0) }

                        VStack(alignment: .leading, spacing: 28) {
                            // Header
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Welcome")
                                    .font(isPad ? .system(size: 40, weight: .bold) : .largeTitle.weight(.bold))
                                    .foregroundStyle(.primary)

                                Text("Sign in to save your medication plans and logs on this device.")
                                    .font(isPad ? .title3 : .body)
                                    .foregroundStyle(.primary.opacity(0.92))
                            }

                            // Card
                            VStack(alignment: .leading, spacing: 18) {
                                Text("ACCOUNT")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.primary.opacity(0.8))

                                Picker("Mode", selection: $mode) {
                                    ForEach(AuthMode.allCases, id: \.self) { option in
                                        Text(option.rawValue).tag(option)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .onChange(of: mode) { _, _ in
                                    appState.authErrorMessage = nil
                                }

                                Text(mode == .login ? "SIGN IN" : "CREATE ACCOUNT")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.primary.opacity(0.8))

                                VStack(spacing: 12) {
                                    if mode == .signup {
                                        fieldRow {
                                            TextField("Full Name", text: $fullName)
                                                .textInputAutocapitalization(.words)
                                        }
                                        fieldRow {
                                            Picker("Sex", selection: $sexChoice) {
                                                Text("Select sex").tag(Sex?.none)
                                                ForEach(Sex.allCases) { Text($0.title).tag(Sex?.some($0)) }
                                            }
                                            .pickerStyle(.menu)
                                            .tint(.primary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                        fieldRow {
                                            TextField("Referral code (optional)", text: $referralCodeInput)
                                                .textInputAutocapitalization(.characters)
                                                .autocorrectionDisabled()
                                        }
                                    }

                                    fieldRow {
                                        TextField(
                                            "",
                                            text: $email,
                                            prompt: Text("Email").foregroundStyle(.primary.opacity(0.62))
                                        )
                                        .textContentType(.emailAddress)
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled()
                                    }

                                    fieldRow {
                                        SecureField(
                                            "",
                                            text: $password,
                                            prompt: Text("Password").foregroundStyle(.primary.opacity(0.62))
                                        )
                                        .textContentType(mode == .login ? .password : .newPassword)
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled()
                                    }

                                    if mode == .signup {
                                        fieldRow {
                                            SecureField(
                                                "",
                                                text: $confirmPassword,
                                                prompt: Text("Confirm Password").foregroundStyle(.primary.opacity(0.62))
                                            )
                                            .textContentType(.oneTimeCode)
                                            .textInputAutocapitalization(.never)
                                            .autocorrectionDisabled()
                                        }
                                    }
                                }

                                Button(mode == .login ? "Login" : (isSendingOTP ? "Sending Code..." : "Create Account")) {
                                    Task {
                                        if mode == .signup {
                                            guard password == confirmPassword else {
                                                appState.authErrorMessage = "Passwords do not match."
                                                return
                                            }
                                            isSendingOTP = true
                                            let sent = await appState.sendSignupOTP(email: email)
                                            isSendingOTP = false
                                            if sent {
                                                enteredOTP = ""
                                                otpError = nil
                                                showOTPVerification = true
                                            } else {
                                                appState.authErrorMessage = "Failed to send verification code email. Please check your email and try again."
                                            }
                                        } else {
                                            _ = await appState.login(email: email, password: password)
                                        }
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.large)
                                .frame(maxWidth: .infinity)
                                .disabled(!canSubmit)

                                if mode == .login {
                                    HStack {
                                        Spacer()
                                        Button("Forgot password?") {
                                            appState.passwordResetEmailSent = false
                                            appState.passwordResetError = nil
                                            showForgotPassword = true
                                        }
                                        .font(.subheadline)
                                        .foregroundStyle(.tint)
                                    }
                                }

                                if appState.isAuthenticating {
                                    HStack(spacing: 10) {
                                        ProgressView()
                                        Text(mode == .login ? "Signing in..." : "Creating account...")
                                            .foregroundStyle(.white.opacity(0.7))
                                            .font(.subheadline)
                                    }
                                }

                                if let errorText = appState.authErrorMessage {
                                    Text(errorText)
                                        .foregroundStyle(AppTheme.danger)
                                        .font(.subheadline)
                                }
                            }
                            .padding(isPad ? 24 : 18)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(.white.opacity(0.16), lineWidth: 1)
                            )
                        }
                        .adaptiveCardFrame()
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
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(.regularMaterial, for: .navigationBar)
            .sheet(isPresented: $showForgotPassword) {
                ForgotPasswordView()
            }
            .sheet(isPresented: $showOTPVerification) {
                NavigationStack {
                    ZStack {
                        MeshBackgroundView()
                            .ignoresSafeArea()
                        
                        VStack(spacing: 24) {
                            Text("Verify Your Email")
                                .font(.title.weight(.bold))
                                .foregroundStyle(.white)
                            
                            Text("We've sent a 6-digit verification code to \(email). Please enter it below to complete your registration.")
                                .font(.body)
                                .foregroundStyle(.white.opacity(0.8))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            
                            VStack(spacing: 12) {
                                TextField("Enter 6-Digit Code", text: $enteredOTP)
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.center)
                                    .font(.title2.weight(.bold))
                                    .padding(16)
                                    .background(Color.primary.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(.white.opacity(0.2), lineWidth: 1)
                                    )
                                
                                if let otpError {
                                    Text(otpError)
                                        .foregroundStyle(AppTheme.danger)
                                        .font(.caption)
                                }
                            }
                            .padding(.horizontal)
                            
                            Button {
                                Task {
                                    if await appState.verifySignupOTP(code: enteredOTP) {
                                        if let sexChoice { appState.setSex(sexChoice) }
                                        appState.pendingReferralCode = referralCodeInput.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                                        let success = await appState.signup(email: email, password: password, fullName: fullName)
                                        if success {
                                            showOTPVerification = false
                                        } else {
                                            otpError = appState.authErrorMessage ?? "Registration failed."
                                        }
                                    } else {
                                        otpError = "Incorrect or expired code. Please try again."
                                    }
                                }
                            } label: {
                                Text("Verify & Create Account")
                                    .font(.headline.weight(.bold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(AppTheme.primary)
                                    .foregroundStyle(.black)
                                    .clipShape(Capsule())
                            }
                            .disabled(enteredOTP.count < 6)
                            .padding(.horizontal)
                            
                            Button("Resend Code") {
                                Task {
                                    otpError = nil
                                    _ = await appState.sendSignupOTP(email: email)
                                }
                            }
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.primary)
                        }
                        .padding()
                        .glassCard(cornerRadius: 24)
                        .padding()
                    }
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                showOTPVerification = false
                            }
                            .foregroundStyle(.white)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func fieldRow<F: View>(@ViewBuilder field: () -> F) -> some View {
        VStack(spacing: 8) {
            field()
                .textFieldStyle(.plain)
                .foregroundStyle(.primary)
                .font(isPad ? .title3 : .body)
                .padding(.horizontal, 4)
                .padding(.vertical, isPad ? 12 : 10)
            Divider().overlay(.primary.opacity(0.2))
        }
    }
}

struct ForgotPasswordView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var hSizeClass

    @State private var email = ""

    private var isPad: Bool { hSizeClass == .regular }

    private var canSubmit: Bool {
        !appState.isRequestingPasswordReset && !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ScrollView(showsIndicators: false) {
                    VStack {
                        if isPad { Spacer(minLength: 0) }

                        VStack(alignment: .leading, spacing: 24) {
                            Text("Enter the email address for your account and we'll send you a link to reset your password.")
                                .font(isPad ? .title3 : .body)
                                .foregroundStyle(.white.opacity(0.7))

                            VStack(spacing: 8) {
                                TextField(
                                    "",
                                    text: $email,
                                    prompt: Text("Email").foregroundStyle(.primary.opacity(0.62))
                                )
                                .textFieldStyle(.plain)
                                .foregroundStyle(.primary)
                                .font(isPad ? .title3 : .body)
                                .textContentType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .padding(.horizontal, 4)
                                .padding(.vertical, isPad ? 12 : 10)
                                Divider().overlay(.primary.opacity(0.2))
                            }

                            Button("Send Reset Link") {
                                Task { await appState.requestPasswordReset(email: email) }
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .frame(maxWidth: .infinity)
                            .disabled(!canSubmit)

                            if appState.isRequestingPasswordReset {
                                HStack(spacing: 10) {
                                    ProgressView()
                                    Text("Sending…")
                                        .foregroundStyle(.white.opacity(0.7))
                                        .font(.subheadline)
                                }
                            }

                            if appState.passwordResetEmailSent {
                                Label("Check your inbox — a reset link is on its way.", systemImage: "envelope.badge.fill")
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                    .padding(12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(.tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
                            }

                            if let error = appState.passwordResetError {
                                Text(error)
                                    .foregroundStyle(AppTheme.danger)
                                    .font(.subheadline)
                            }
                        }
                        .adaptiveCardFrame()
                        .padding(.horizontal, isPad ? 40 : 20)
                        .padding(.top, isPad ? 0 : 16)
                        .padding(.bottom, 20)

                        if isPad { Spacer(minLength: 0) }
                    }
                    .frame(minHeight: geo.size.height)
                }
                .safeAreaPadding(.bottom)
            }
            .navigationTitle("Reset Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

struct ConsentChecklistView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.horizontalSizeClass) private var hSizeClass

    @State private var acknowledgeEducationalOnly = false
    @State private var acknowledgeConfirmClinician = false
    @State private var acknowledgePrivacyPolicy = false
    @State private var acknowledgeProcessingConsent = false

    private var isPad: Bool { hSizeClass == .regular }

    private var backgroundLayer: some View {
        MeshBackgroundView()
    }

    private var allChecked: Bool {
        acknowledgeEducationalOnly
        && acknowledgeConfirmClinician
        && acknowledgePrivacyPolicy
        && acknowledgeProcessingConsent
    }

    @ViewBuilder
    private func consentRow(_ text: String, isOn: Binding<Bool>, isPad: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(text)
                .font(isPad ? .body : .subheadline)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            Toggle("", isOn: isOn)
                .labelsHidden()
                .fixedSize()
        }
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ScrollView {
                    VStack {
                        if isPad { Spacer(minLength: 0) }

                        VStack(alignment: .leading, spacing: 20) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Medhavn is a medication adherence and reminder tool.")
                                    .font(isPad ? .title2.bold() : .title3.bold())
                                    .foregroundStyle(.primary)

                                Text("It helps you follow the prescription instructions already written for you by your licensed clinician or pharmacist. Medhavn does not prescribe, recommend, or calculate any medication dose.")
                                    .font(isPad ? .body : .subheadline)
                                    .foregroundStyle(.primary.opacity(0.75))
                            }

                            HStack {
                                Text("REQUIRED CONSENT CHECKLIST")
                                    .font(.headline)
                                    .foregroundStyle(.white.opacity(0.7))
                                Spacer()
                                Button("Accept All") {
                                    acknowledgeEducationalOnly = true
                                    acknowledgeConfirmClinician = true
                                    acknowledgePrivacyPolicy = true
                                    acknowledgeProcessingConsent = true
                                }
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.primary)
                            }

                            VStack(spacing: isPad ? 16 : 12) {
                                consentRow(
                                    "I understand this app does not prescribe or recommend any dose — all dosing information comes from my own existing prescription",
                                    isOn: $acknowledgeEducationalOnly,
                                    isPad: isPad
                                )
                                Divider().overlay(.primary.opacity(0.2))

                                consentRow(
                                    "I will confirm unclear medication instructions with a pharmacist or clinician before following them",
                                    isOn: $acknowledgeConfirmClinician,
                                    isPad: isPad
                                )
                                Divider().overlay(.primary.opacity(0.2))

                                consentRow(
                                    "I accept privacy terms for local storage and handling of my medication data on this device",
                                    isOn: $acknowledgePrivacyPolicy,
                                    isPad: isPad
                                )
                                Divider().overlay(.primary.opacity(0.2))

                                consentRow(
                                    "I consent to this app processing the prescription text I enter to generate a reminder schedule",
                                    isOn: $acknowledgeProcessingConsent,
                                    isPad: isPad
                                )
                                Divider().overlay(.primary.opacity(0.2))
                            }

                            Button("Continue") {
                                appState.disclaimerAccepted = acknowledgeEducationalOnly
                                appState.privacyPolicyAccepted = acknowledgePrivacyPolicy
                                appState.processingConsentAccepted = acknowledgeProcessingConsent
                                appState.completeConsentChecklist()
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .frame(maxWidth: .infinity)
                            .disabled(!allChecked)
                        }
                        .adaptiveCardFrame()
                        .padding(.horizontal, isPad ? 40 : 20)
                        .padding(.top, isPad ? 0 : 12)
                        .padding(.bottom, 20)

                        if isPad { Spacer(minLength: 0) }
                    }
                    .frame(minHeight: geo.size.height)
                }
                .safeAreaPadding(.bottom)
            }
            .background { backgroundLayer }
            .navigationTitle("Consent")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(.regularMaterial, for: .navigationBar)
        }
    }
}
