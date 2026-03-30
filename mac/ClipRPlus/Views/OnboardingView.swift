import SwiftUI

private enum OnboardingStep { case auth, deviceName, pendingApproval }

struct OnboardingView: View {
    @ObservedObject private var authManager = AuthManager.shared

    @State private var step: OnboardingStep = .auth
    @State private var isLogin = true
    @State private var email = ""
    @State private var password = ""
    @State private var deviceName = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Color.bgBase.ignoresSafeArea()

            VStack(spacing: 0) {
                // Logo mark
                VStack(spacing: 10) {
                    Image(systemName: "doc.on.clipboard.fill")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(Color.accent)

                    Text("Clipr+")
                        .font(.cliprTitle1)
                        .foregroundColor(.textPrimary)
                }
                .frame(height: 100)

                // Step content
                switch step {
                case .auth:            authStepView
                case .deviceName:      deviceNameStepView
                case .pendingApproval: pendingStepView
                }

                Spacer()
            }
            .padding(.horizontal, Spacing.xl)
        }
        .frame(width: 360, height: 480)
    }

    // MARK: - Auth Step

    private var authStepView: some View {
        VStack(spacing: Spacing.md) {
            SegmentedPicker(
                options: ["Log In", "Create Account"],
                selected: isLogin ? 0 : 1
            ) { idx in isLogin = idx == 0 }

            VStack(spacing: Spacing.xs) {
                ClipTextField(placeholder: "Email", text: $email)
                ClipTextField(placeholder: "Password", text: $password, isSecure: true)
            }

            errorView

            ClipPrimaryButton(
                title: isLogin ? "Log In" : "Create Account",
                isLoading: isLoading,
                isDisabled: email.isEmpty || password.isEmpty
            ) { Task { await handleAuth() } }
        }
        .padding(.top, Spacing.md)
    }

    // MARK: - Device Name Step

    private var deviceNameStepView: some View {
        VStack(spacing: Spacing.md) {
            VStack(spacing: Spacing.xs) {
                Text("Name this device")
                    .font(.cliprBodyMedium)
                    .foregroundColor(.textPrimary)

                Text("A recognisable name helps you identify this Mac on other devices.")
                    .font(.cliprCaption)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
            }

            ClipTextField(placeholder: "e.g. Work MacBook", text: $deviceName)

            errorView

            ClipPrimaryButton(
                title: "Continue",
                isLoading: isLoading,
                isDisabled: deviceName.isEmpty
            ) { Task { await handleDeviceRegister() } }
        }
        .padding(.top, Spacing.md)
    }

    // MARK: - Pending Step

    private var pendingStepView: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "checkmark.shield")
                .font(.system(size: 30, weight: .regular))
                .foregroundColor(Color.warningYellow)

            VStack(spacing: Spacing.xs) {
                Text("Approval required")
                    .font(.cliprBodyMedium)
                    .foregroundColor(.textPrimary)

                Text("Open Clipr+ on a trusted device and approve \"\(deviceName)\" in Settings → Connected Devices.")
                    .font(.cliprCaption)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
            }

            if isLoading {
                ProgressView().scaleEffect(0.7)
            }

            Button("Check again") {
                Task { await checkApproval() }
            }
            .font(.cliprCaption)
            .foregroundColor(.textSecondary)
            .buttonStyle(.plain)
        }
        .padding(.top, Spacing.lg)
        .task { await pollForApproval() }
    }

    // MARK: - Error View

    @ViewBuilder
    private var errorView: some View {
        if let err = errorMessage {
            Text(err)
                .font(.cliprCaption)
                .foregroundColor(Color.destructiveRed)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 2)
        }
    }

    // MARK: - Actions

    private func handleAuth() async {
        isLoading = true; errorMessage = nil
        do {
            if isLogin { try await authManager.login(email: email, password: password) }
            else { try await authManager.register(email: email, password: password) }
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
            } else { step = .pendingApproval }
        } catch { errorMessage = error.localizedDescription }
        isLoading = false
    }

    private func checkApproval() async {
        do {
            let approved = try await authManager.checkApproval()
            if approved { SyncEngine.shared.connect(); ClipboardMonitor.shared.start() }
        } catch {}
    }

    private func pollForApproval() async {
        while step == .pendingApproval {
            try? await Task.sleep(for: .seconds(5))
            await checkApproval()
        }
    }
}
