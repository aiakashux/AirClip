import SwiftUI

private enum OnboardingStep { case auth, deviceName, pendingApproval }

struct OnboardingView: View {
    @ObservedObject private var authManager = AuthManager.shared

    @State private var step: OnboardingStep = .auth
    @State private var isLogin = false
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var deviceName = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        HStack(spacing: 0) {
            leftPanel
            rightPanel
        }
        .frame(width: 720, height: 520)
    }

    // MARK: - Left branding panel

    private var leftPanel: some View {
        ZStack(alignment: .bottomLeading) {
            // Base dark gradient
            LinearGradient(
                colors: [
                    Color(red: 7/255,  green: 7/255,  blue: 14/255),
                    Color(red: 10/255, green: 7/255,  blue: 26/255)
                ],
                startPoint: .top, endPoint: .bottom
            )

            // Purple radial glow rising from below
            RadialGradient(
                stops: [
                    .init(color: Color(red: 108/255, green: 52/255, blue: 248/255).opacity(0.92), location: 0),
                    .init(color: Color(red: 74/255,  green: 28/255, blue: 200/255).opacity(0.68), location: 0.26),
                    .init(color: Color(red: 44/255,  green: 14/255, blue: 138/255).opacity(0.30), location: 0.52),
                    .init(color: .clear, location: 0.70)
                ],
                center: UnitPoint(x: 0.5, y: 1.15),
                startRadius: 0,
                endRadius: 420
            )

            // Bottom vignette so text reads cleanly
            LinearGradient(
                colors: [Color(red: 7/255, green: 7/255, blue: 16/255).opacity(0.85), .clear],
                startPoint: .bottom, endPoint: .top
            )
            .frame(height: 260)
            .frame(maxHeight: .infinity, alignment: .bottom)

            // Content
            VStack(alignment: .leading, spacing: 0) {
                logoMark
                Spacer()
                headlineBlock
                featureStrip
            }
            .padding(28)
        }
        .frame(width: 380)
        .clipped()
    }

    private var logoMark: some View {
        HStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.white.opacity(0.20), lineWidth: 0.5)
                    )
                    .frame(width: 26, height: 26)
                ZStack {
                    Circle()
                        .strokeBorder(Color.white.opacity(0.85), lineWidth: 1.8)
                        .frame(width: 13, height: 13)
                    Circle()
                        .fill(Color.white.opacity(0.85))
                        .frame(width: 5.5, height: 5.5)
                }
            }
            Text("Ring")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.80))
                .tracking(-0.2)
        }
    }

    private var headlineBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            (Text("Copy anywhere.\n").foregroundColor(.white.opacity(0.88)) +
             Text("Paste everywhere.").foregroundColor(.white.opacity(0.40)))
                .font(.system(size: 26, weight: .bold))
                .lineSpacing(2)
                .tracking(-0.5)

            Text("Your clipboard, synced across all your devices —\nMac, Windows, Android, Linux.\n\nInstant. Private. Always yours.")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.40))
                .lineSpacing(3)
        }
        .padding(.bottom, 24)
    }

    private var featureStrip: some View {
        HStack(alignment: .top, spacing: 12) {
            featureCell(icon: "bolt.fill",  title: "All your devices",
                        body: "Always in sync — no ecosystem limits.")
            featureCell(icon: "keyboard",   title: "One shortcut",
                        body: "Copy once. Paste anywhere instantly.")
            featureCell(icon: "lock.fill",  title: "End-to-end encrypted",
                        body: "Only your devices can read your data.")
        }
    }

    private func featureCell(icon: String, title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.55))
                .frame(height: 14)
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.white.opacity(0.65))
            Text(body)
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.32))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Right form panel

    private var rightPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch step {
            case .auth:            authForm
            case .deviceName:      deviceNameForm
            case .pendingApproval: pendingForm
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 36)
        .padding(.top, 48)
        .padding(.bottom, 40)
        .background(Color(red: 14/255, green: 14/255, blue: 18/255))
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Color.white.opacity(0.07))
                .frame(width: 0.5)
        }
    }

    // MARK: - Auth form

    private var authForm: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Social buttons
            HStack(spacing: 8) {
                socialButton(label: "Google",   sfIcon: "g.circle.fill")
                socialButton(label: "Facebook", sfIcon: "f.circle.fill")
            }
            .padding(.bottom, 14)

            // "or" divider
            HStack(spacing: 10) {
                Rectangle().fill(Color.white.opacity(0.08)).frame(height: 0.5)
                Text("or")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.22))
                Rectangle().fill(Color.white.opacity(0.08)).frame(height: 0.5)
            }
            .padding(.bottom, 14)

            // Fields
            VStack(alignment: .leading, spacing: 12) {
                authField(label: "Email", placeholder: "you@example.com",
                          text: $email, isSecure: false)

                VStack(alignment: .leading, spacing: 8) {
                    fieldLabel("Password")
                    passwordField
                    if !isLogin {
                        Text("Must be at least 8 characters")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.25))
                    } else {
                        Button("Forgot password?") {}
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.28))
                            .buttonStyle(.plain)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
            }
            .padding(.bottom, 16)

            // Error
            if let err = errorMessage {
                Text(err)
                    .font(.system(size: 11))
                    .foregroundColor(Color.destructiveRed)
                    .padding(.bottom, 8)
            }

            // Submit
            submitButton
                .padding(.bottom, 12)

            // Switch link
            HStack(spacing: 4) {
                Text(isLogin ? "Don't have an account?" : "Already have an account?")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.32))
                Button(isLogin ? "Create one" : "Sign in") {
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.82)) {
                        isLogin.toggle()
                        errorMessage = nil
                    }
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.60))
                .buttonStyle(.plain)
                .underline(true, color: .white.opacity(0.18))
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private func socialButton(label: String, sfIcon: String) -> some View {
        Button(action: {}) {
            HStack(spacing: 8) {
                Image(systemName: sfIcon)
                    .font(.system(size: 14))
                Text(label)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(.white.opacity(0.72))
            .frame(maxWidth: .infinity)
            .frame(height: 36)
            .background(Color.white.opacity(0.06))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private func authField(label: String, placeholder: String,
                            text: Binding<String>, isSecure: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel(label)
            Group {
                if isSecure {
                    SecureField("", text: text,
                                prompt: Text(placeholder).foregroundColor(.white.opacity(0.20)))
                } else {
                    TextField("", text: text,
                              prompt: Text(placeholder).foregroundColor(.white.opacity(0.20)))
                }
            }
            .font(.system(size: 12))
            .foregroundColor(.white.opacity(0.88))
            .textFieldStyle(.plain)
            .padding(.horizontal, 12)
            .frame(height: 36)
            .background(Color.white.opacity(0.06))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private var passwordField: some View {
        ZStack(alignment: .trailing) {
            Group {
                if showPassword {
                    TextField("", text: $password,
                              prompt: Text(isLogin ? "Your password" : "8+ characters")
                                  .foregroundColor(.white.opacity(0.20)))
                } else {
                    SecureField("", text: $password,
                                prompt: Text(isLogin ? "Your password" : "8+ characters")
                                    .foregroundColor(.white.opacity(0.20)))
                }
            }
            .font(.system(size: 12))
            .foregroundColor(.white.opacity(0.88))
            .textFieldStyle(.plain)
            .padding(.leading, 12)
            .padding(.trailing, 36)
            .frame(height: 36)

            Button(action: { showPassword.toggle() }) {
                Image(systemName: showPassword ? "eye.slash" : "eye")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(showPassword ? 0.65 : 0.32))
            }
            .buttonStyle(.plain)
            .padding(.trailing, 10)
        }
        .background(Color.white.opacity(0.06))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(.white.opacity(0.45))
    }

    private var submitButton: some View {
        Button(action: { Task { await handleAuth() } }) {
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(Color.white)
                if isLoading {
                    ProgressView().scaleEffect(0.65).tint(.black)
                } else {
                    Text(isLogin ? "Sign in" : "Create account")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(red: 14/255, green: 14/255, blue: 18/255))
                        .tracking(-0.1)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 36)
        }
        .buttonStyle(.plain)
        .disabled(isLoading || email.isEmpty || password.isEmpty)
        .opacity((email.isEmpty || password.isEmpty) ? 0.50 : 1.0)
    }

    // MARK: - Device name form

    private var deviceNameForm: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Name this device")
                    .font(.ringTitle2)
                    .foregroundColor(.textPrimary)
                Text("A recognisable name helps you identify this Mac on other devices.")
                    .font(.ringCaption)
                    .foregroundColor(.textSecondary)
            }

            ClipTextField(placeholder: "e.g. Work MacBook", text: $deviceName)

            if let err = errorMessage {
                Text(err)
                    .font(.ringCaption)
                    .foregroundColor(Color.destructiveRed)
            }

            ClipPrimaryButton(
                title: "Continue",
                isLoading: isLoading,
                isDisabled: deviceName.isEmpty
            ) { Task { await handleDeviceRegister() } }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Pending approval form

    private var pendingForm: some View {
        VStack(alignment: .center, spacing: Spacing.lg) {
            Image(systemName: "checkmark.shield")
                .font(.system(size: 30, weight: .regular))
                .foregroundColor(Color.warningYellow)

            VStack(spacing: Spacing.xs) {
                Text("Approval required")
                    .font(.ringBodyMedium)
                    .foregroundColor(.textPrimary)
                Text("Open Ring on a trusted device and approve \"\(deviceName)\" in Settings → Connected Devices.")
                    .font(.ringCaption)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
            }

            if isLoading { ProgressView().scaleEffect(0.7) }

            Button("Check again") { Task { await checkApproval() } }
                .font(.ringCaption)
                .foregroundColor(.textSecondary)
                .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .task { await pollForApproval() }
    }

    // MARK: - Actions

    private func handleAuth() async {
        isLoading = true; errorMessage = nil
        do {
            if isLogin { try await authManager.login(email: email, password: password) }
            else        { try await authManager.register(email: email, password: password) }
            step = .deviceName
        } catch { errorMessage = error.localizedDescription }
        isLoading = false
    }

    private func handleDeviceRegister() async {
        isLoading = true; errorMessage = nil
        do {
            let status = try await authManager.registerDevice(name: deviceName)
            if status == .approved {
                SyncEngine.shared.connect()
                ClipboardMonitor.shared.start()
                authManager.isDeviceApproved = true
                NotificationCenter.default.post(name: .authDidComplete, object: nil)
            } else { step = .pendingApproval }
        } catch { errorMessage = error.localizedDescription }
        isLoading = false
    }

    private func checkApproval() async {
        do {
            let approved = try await authManager.checkApproval()
            if approved {
                SyncEngine.shared.connect()
                ClipboardMonitor.shared.start()
                NotificationCenter.default.post(name: .authDidComplete, object: nil)
            }
        } catch {}
    }

    private func pollForApproval() async {
        while step == .pendingApproval {
            try? await Task.sleep(for: .seconds(5))
            await checkApproval()
        }
    }
}
