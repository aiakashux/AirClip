import SwiftUI

// MARK: - Onboarding steps

private enum OnboardingStep {
    case choice       // Create or join an AirClip network
    case nameDevice   // Name this device (shared for both paths)
    case showCode     // Create path: show QR + code, wait for others to join
    case enterCode    // Join path: type the code shown on another device
}

// MARK: - OnboardingView

struct OnboardingView: View {
    @ObservedObject private var identity = AirClipIdentity.shared
    @ObservedObject private var pairing  = PairingSession.shared

    @State private var step: OnboardingStep = .choice
    @State private var isCreating  = true   // true = Create, false = Join
    @State private var deviceName  = ""
    @State private var joinCode    = ""
    @State private var isLoading   = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack(alignment: .topLeading) {
            HStack(spacing: 0) {
                leftPanel
                rightPanel
            }

            Color.clear
                .frame(height: 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bgBase)
        .ignoresSafeArea()
        .onAppear {
            deviceName = UserDefaults.standard.string(forKey: "deviceName") ?? ""
        }
    }

    // MARK: - Left branding panel

    private var leftPanel: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [
                    Color.bgBase,
                    Color.bgFloating
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            RadialGradient(
                colors: [
                    Color.syncBlue.opacity(0.90),
                    Color.syncBlue.opacity(0.52),
                    Color.encryptedGreen.opacity(0.22),
                    Color.clear
                ],
                center: UnitPoint(x: 0.50, y: 1.15),
                startRadius: 0,
                endRadius: 300
            )

            LinearGradient(
                colors: [Color.bgBase.opacity(0.85), .clear],
                startPoint: .bottom,
                endPoint: .top
            )
            .frame(height: 260)
            .frame(maxHeight: .infinity, alignment: .bottom)

            VStack(alignment: .leading, spacing: 0) {
                logoMark
                    .padding(.bottom, 48)
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
                    .fill(Color.hoverFill)
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.borderDefault, lineWidth: 0.5))
                    .frame(width: 26, height: 26)
                ZStack {
                    Circle().strokeBorder(Color.textPrimary, lineWidth: 1.8).frame(width: 13, height: 13)
                    Circle().fill(Color.textPrimary).frame(width: 5.5, height: 5.5)
                }
            }
            Text("AirClip").font(.system(size: 14, weight: .semibold)).foregroundColor(Color.textPrimary).tracking(-0.2)
        }
    }

    private var headlineBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Copy anywhere.")
                    .foregroundColor(.textPrimary)
                Text("Paste everywhere.")
                    .foregroundColor(Color.textSecondary)
            }
            .font(.system(size: 26, weight: .bold))
            Text("Your clipboard, synced across all your devices —\nMac, Windows, Android, Linux.\n\nInstant. Private. Always yours.")
                .font(.system(size: 11)).foregroundColor(Color.textSecondary).lineSpacing(4)
        }
        .padding(.bottom, 24)
    }

    private var featureStrip: some View {
        HStack(alignment: .top, spacing: 12) {
            featureCell(icon: .zap,      title: "All your devices",  body: "Always in sync — no ecosystem limits.")
            featureCell(icon: .keyboard, title: "One shortcut",      body: "Copy once. Paste anywhere instantly.")
            featureCell(icon: .lock,     title: "End-to-end encrypted", body: "Only your devices can read your data.")
        }
    }

    private func featureCell(icon: AirClipIconName, title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            AirClipIcon(icon, size: 10).foregroundColor(Color.textSecondary).frame(height: 14)
            Text(title).font(.system(size: 10, weight: .semibold)).foregroundColor(Color.textSecondary)
            Text(body).font(.system(size: 10)).foregroundColor(Color.textTertiary).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Right panel

    private var rightPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch step {
            case .choice:     choiceStep
            case .nameDevice: nameStep
            case .showCode:   showCodeStep
            case .enterCode:  enterCodeStep
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 36)
        .padding(.top, 48)
        .padding(.bottom, 40)
        .background(Color.bgElevated)
        .overlay(alignment: .leading) {
            Rectangle().fill(Color.borderSubtle).frame(width: 0.5)
        }
    }

    // MARK: - Step: Choice

    private var choiceStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Get started")
                    .font(.system(size: 22, weight: .bold)).foregroundColor(.textPrimary)
                Text("Set up this Mac to sync your clipboard with other devices.")
                    .font(.airClipCaption).foregroundColor(.textSecondary).lineSpacing(3)
            }
            .padding(.bottom, 28)

            VStack(spacing: 10) {
                OnboardingChoiceCard(
                    icon: .plus,
                    title: "Create AirClip network",
                    subtitle: "Start fresh — this Mac will be the first device.",
                    accent: Color.syncBlue
                ) {
                    isCreating = true
                    withAnimation { step = .nameDevice }
                }
                OnboardingChoiceCard(
                    icon: .arrowRight,
                    title: "Join AirClip network",
                    subtitle: "Add this Mac to an existing AirClip network.",
                    accent: Color.encryptedGreen
                ) {
                    isCreating = false
                    withAnimation { step = .nameDevice }
                }
            }
        }
    }

    // MARK: - Step: Name device

    private var nameStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            backButton { step = .choice }

            VStack(alignment: .leading, spacing: 6) {
                Text("Name this device")
                    .font(.system(size: 22, weight: .bold)).foregroundColor(.textPrimary)
                Text("A recognisable name helps you identify this Mac on other devices.")
                    .font(.airClipCaption).foregroundColor(.textSecondary).lineSpacing(3)
            }
            .padding(.bottom, 24)

            ClipTextField(placeholder: "e.g. Work MacBook", text: $deviceName)
                .padding(.bottom, 16)

            if let err = errorMessage {
                Text(err).font(.airClipCaption).foregroundColor(Color.destructiveRed).padding(.bottom, 8)
            }

            ClipPrimaryButton(
                title: isCreating ? "Create network" : "Continue",
                isLoading: isLoading,
                isDisabled: deviceName.trimmingCharacters(in: .whitespaces).isEmpty
            ) {
                let name = deviceName.trimmingCharacters(in: .whitespaces)
                AirClipIdentity.shared.setDeviceName(name)

                if isCreating {
                    // Create the AirClip network immediately so LanServer can accept pair_requests.
                    AirClipIdentity.shared.createAirClip(name: name)
                    LanServer.shared.start()
                    pairing.onPairSuccess = finishOnboarding
                    PairingSession.shared.start()
                    withAnimation { step = .showCode }
                } else {
                    LanBrowser.shared.start()
                    withAnimation { step = .enterCode }
                }
            }
        }
    }

    // MARK: - Step: Show code (Create path)

    private var showCodeStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Pair another device")
                    .font(.system(size: 22, weight: .bold)).foregroundColor(.textPrimary)
                Text("Scan the QR code or enter the code on another device to add it to your AirClip network.")
                    .font(.airClipCaption).foregroundColor(.textSecondary).lineSpacing(3)
            }
            .padding(.bottom, 24)

            // QR code
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white)
                    .frame(width: 200, height: 200)

                if let qr = pairing.qrImage {
                    Image(nsImage: qr)
                        .resizable()
                        .interpolation(.none)
                        .frame(width: 188, height: 188)
                } else {
                    ProgressView().scaleEffect(0.8)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.bottom, 16)

            // 8-digit code
            if let code = pairing.currentCode {
                VStack(spacing: 4) {
                    Text("Or enter this code")
                        .font(.airClipCaption).foregroundColor(.textSecondary)
                    Text(formattedCode(code))
                        .font(.system(size: 28, weight: .semibold, design: .monospaced))
                        .foregroundColor(.textPrimary)
                        .tracking(4)
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 28)
            }

            ClipPrimaryButton(title: "Done — I'll pair more devices later") {
                finishOnboarding()
            }
        }
    }

    // MARK: - Step: Enter code (Join path)

    private var enterCodeStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            backButton {
                LanBrowser.shared.stop()
                step = .nameDevice
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Enter pairing code")
                    .font(.system(size: 22, weight: .bold)).foregroundColor(.textPrimary)
                Text("Open AirClip on another device and enter the 8-digit code shown there.")
                    .font(.airClipCaption).foregroundColor(.textSecondary).lineSpacing(3)
            }
            .padding(.bottom, 24)

            // Code field
            ClipTextField(placeholder: "00000000", text: $joinCode)
                .padding(.bottom, 8)

            Text("Make sure both devices are on the same Wi-Fi network.")
                .font(.airClipCaption).foregroundColor(.textTertiary)
                .padding(.bottom, 16)

            if let err = errorMessage {
                Text(err).font(.airClipCaption).foregroundColor(Color.destructiveRed).padding(.bottom, 8)
            }

            ClipPrimaryButton(
                title: "Join network",
                isLoading: isLoading,
                isDisabled: joinCode.trimmingCharacters(in: .whitespaces).count < 8
            ) {
                joinAirClip()
            }
        }
    }

    // MARK: - Actions

    private func joinAirClip() {
        let code = joinCode.trimmingCharacters(in: .whitespaces)
        let name = deviceName.trimmingCharacters(in: .whitespaces)
        isLoading = true; errorMessage = nil

        PairingClient.shared.joinAirClip(code: code, myName: name) { airClipId, devices in
            AirClipIdentity.shared.joinAirClip(airClipId: airClipId, myName: name, allDevices: devices)
            self.isLoading = false
            self.finishOnboarding()
        } onError: { message in
            self.isLoading = false
            self.errorMessage = message
        }
    }

    private func finishOnboarding() {
        PairingSession.shared.stop()
        SyncModeStore.shared.applyRuntimePolicy()
        NotificationCenter.default.post(name: .authDidComplete, object: nil)
    }

    // MARK: - Shared helpers

    private func backButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                AirClipIcon(.arrowLeft, size: 11)
                Text("Back")
                    .font(.system(size: 12))
            }
            .foregroundColor(.textSecondary)
        }
        .buttonStyle(.plain)
        .padding(.bottom, 20)
    }

    private func formattedCode(_ code: String) -> String {
        guard code.count == 8 else { return code }
        return "\(code.prefix(4)) \(code.suffix(4))"
    }
}

private struct OnboardingChoiceCard: View {
    let icon: AirClipIconName
    let title: String
    let subtitle: String
    let accent: Color
    let action: () -> Void

    @State private var isHovered = false
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                AirClipIcon(icon, size: 22)
                    .foregroundColor(accent)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.textPrimary)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(.textSecondary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                AirClipIcon(.arrowRight, size: 11)
                    .foregroundColor(.textTertiary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .fill(isHovered || isPressed ? Color.activeFill : Color.hoverFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .strokeBorder(Color.borderDefault, lineWidth: 0.5)
            )
            .scaleEffect(isPressed ? 0.985 : 1)
            .contentShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: Duration.instant)) {
                isHovered = hovering
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        withAnimation(.easeOut(duration: Duration.instant)) {
                            isPressed = true
                        }
                    }
                }
                .onEnded { _ in
                    withAnimation(.easeOut(duration: Duration.micro)) {
                        isPressed = false
                    }
                }
        )
    }
}

// MARK: - Auth completion notification

extension Notification.Name {
    static let authDidComplete = Notification.Name("com.airclip.authDidComplete")
}
