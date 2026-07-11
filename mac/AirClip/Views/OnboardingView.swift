import AppKit
import SwiftUI

// MARK: - Onboarding steps

private enum OnboardingStep {
    case choice
    case nameDevice
    case showCode
    case enterCode
}

// MARK: - OnboardingView

struct OnboardingView: View {
    @ObservedObject private var pairing = PairingSession.shared

    private let firstRunPermissionPromptKey = "com.airclip.didPromptFirstRunPermissions.v1"

    @State private var step: OnboardingStep = .choice
    @State private var isCreating = true
    @State private var deviceName = ""
    @State private var joinCode = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isJoinModalPresented = false

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let contentWidth = min(max(size.width - 64, 260), 348)
            let isCompact = size.height < 720
            let heroHeight = isCompact ? max(292, size.height * 0.52) : min(620, size.height * 0.68)

            ZStack(alignment: .topLeading) {
                Color.white

                if step == .choice {
                    MacInitialSplashScreen(
                        onJoin: {
                            presentJoinModal()
                        },
                        onCreate: {
                            isCreating = true
                            errorMessage = nil
                            withAnimation(.easeOut(duration: 0.18)) { step = .nameDevice }
                        }
                    )
                } else if step == .nameDevice && isCreating {
                    MacCreateAirclipModal(
                        deviceName: $deviceName,
                        errorMessage: errorMessage,
                        isLoading: isLoading,
                        onCreate: continueAfterName,
                        onBack: {
                            errorMessage = nil
                            withAnimation(.easeOut(duration: 0.18)) { step = .choice }
                        }
                    )
                    .transition(.opacity.combined(with: .offset(y: 10)))
                } else {
                    VStack(spacing: 0) {
                        OnboardingOrbitalHero()
                            .frame(height: heroHeight)
                            .frame(maxWidth: .infinity)
                            .clipped()

                        stepContent(width: contentWidth, isCompact: isCompact)
                            .frame(width: contentWidth)
                            .padding(.top, isCompact ? 14 : 20)
                            .padding(.bottom, max(24, size.height * 0.04))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }

                if isJoinModalPresented {
                    MacJoinAirclipModal(
                        qrImage: pairing.qrImage,
                        code: pairing.currentCode,
                        onClose: dismissJoinModal
                    )
                    .transition(.opacity.combined(with: .offset(y: 12)))
                    .zIndex(10)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .onAppear {
            deviceName = UserDefaults.standard.string(forKey: "deviceName")
                ?? Host.current().localizedName
                ?? "My Mac"
            requestFirstRunPermissionsIfNeeded()
        }
    }

    @ViewBuilder
    private func stepContent(width: CGFloat, isCompact: Bool) -> some View {
        switch step {
        case .choice:
            choiceStep(isCompact: isCompact)
        case .nameDevice:
            nameStep(width: width, isCompact: isCompact)
        case .showCode:
            showCodeStep(width: width, isCompact: isCompact)
        case .enterCode:
            enterCodeStep(width: width, isCompact: isCompact)
        }
    }

    // MARK: - Step: Choice

    private func choiceStep(isCompact: Bool) -> some View {
        VStack(spacing: isCompact ? 20 : 28) {
            Text("Copy anywhere. Paste\neverywhere.")
                .font(.system(size: isCompact ? 21 : 24, weight: .regular))
                .foregroundStyle(Color(hex: "#202327"))
                .multilineTextAlignment(.center)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 20) {
                OnboardingSplashButton(
                    title: "Create an Airclip",
                    icon: .plus,
                    style: .primary
                ) {
                    isCreating = true
                    errorMessage = nil
                    withAnimation(.easeOut(duration: 0.18)) { step = .nameDevice }
                }

                OnboardingSplashButton(
                    title: "Join your Airclip",
                    icon: .link,
                    style: .secondary
                ) {
                    isCreating = false
                    errorMessage = nil
                    withAnimation(.easeOut(duration: 0.18)) { step = .nameDevice }
                }
            }
        }
    }

    // MARK: - Step: Name device

    private func nameStep(width: CGFloat, isCompact: Bool) -> some View {
        VStack(spacing: isCompact ? 14 : 18) {
            VStack(spacing: 6) {
                Text("Name this device")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(Color(hex: "#202327"))
                Text(isCreating ? "This Mac will start your Airclip." : "This name appears on your other devices.")
                    .font(.system(size: 13))
                    .foregroundStyle(Color(hex: "#6A7282"))
                    .multilineTextAlignment(.center)
            }

            OnboardingTextField(placeholder: "e.g. Work MacBook", text: $deviceName)
                .onChange(of: deviceName) { _, newValue in
                    let limitedName = DeviceDisplayText.limitedName(newValue)
                    if limitedName != newValue {
                        deviceName = limitedName
                    }
                }

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.destructiveRed)
                    .multilineTextAlignment(.center)
            }

            OnboardingSplashButton(
                title: isCreating ? "Create an Airclip" : "Continue",
                icon: isCreating ? .plus : .arrowRight,
                style: .primary,
                isLoading: isLoading,
                isDisabled: deviceName.trimmingCharacters(in: .whitespaces).isEmpty
            ) {
                continueAfterName()
            }

            OnboardingBackButton {
                withAnimation(.easeOut(duration: 0.18)) { step = .choice }
            }
        }
    }

    // MARK: - Step: Show code

    private func showCodeStep(width: CGFloat, isCompact: Bool) -> some View {
        VStack(spacing: isCompact ? 12 : 16) {
            Text("Add another device")
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(Color(hex: "#202327"))

            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(hex: "#F5F4F7"))
                    .frame(width: min(width, 240), height: min(width, 240))

                if let qr = pairing.qrImage {
                    Image(nsImage: qr)
                        .resizable()
                        .interpolation(.none)
                        .frame(width: min(width - 32, 208), height: min(width - 32, 208))
                } else {
                    ProgressView().controlSize(.small)
                }
            }

            if let code = pairing.currentCode {
                VStack(spacing: 4) {
                    Text("Numeric code")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color(hex: "#868C98"))
                        .textCase(.uppercase)
                    Text(formattedCode(code))
                        .font(.system(size: 30, weight: .regular, design: .monospaced))
                        .foregroundStyle(Color(hex: "#202327"))
                        .tracking(5)
                }
            }

            OnboardingSplashButton(title: "Done", icon: .tick, style: .primary) {
                finishOnboarding(opening: .openDevicesTab)
            }
        }
    }

    // MARK: - Step: Enter code

    private func enterCodeStep(width: CGFloat, isCompact: Bool) -> some View {
        VStack(spacing: isCompact ? 14 : 18) {
            VStack(spacing: 6) {
                Text("Join your Airclip")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(Color(hex: "#202327"))
                Text("Enter the 6-digit code from another device on the same Wi-Fi.")
                    .font(.system(size: 13))
                    .foregroundStyle(Color(hex: "#6A7282"))
                    .multilineTextAlignment(.center)
            }

            OnboardingTextField(placeholder: "000000", text: $joinCode)

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.destructiveRed)
                    .multilineTextAlignment(.center)
            }

            OnboardingSplashButton(
                title: "Join your Airclip",
                icon: .link,
                style: .primary,
                isLoading: isLoading,
                isDisabled: PairingSession.normalizedCode(joinCode).count < 6
            ) {
                joinAirClip()
            }

            OnboardingBackButton {
                LanBrowser.shared.stop()
                withAnimation(.easeOut(duration: 0.18)) { step = .nameDevice }
            }
        }
    }

    // MARK: - Actions

    private func presentJoinModal() {
        let name = deviceName.trimmingCharacters(in: .whitespaces).isEmpty
            ? (Host.current().localizedName ?? "My Mac")
            : deviceName.trimmingCharacters(in: .whitespaces)
        deviceName = name
        AirClipIdentity.shared.setDeviceName(name)
        errorMessage = nil
        LanServer.shared.start()
        pairing.onPairSuccess = { finishOnboarding(opening: .openDevicesTab) }
        PairingSession.shared.start()
        withAnimation(.timingCurve(0.16, 1, 0.3, 1, duration: 0.22)) {
            isJoinModalPresented = true
        }
    }

    private func dismissJoinModal() {
        pairing.onPairSuccess = nil
        PairingSession.shared.stop()
        withAnimation(.easeOut(duration: 0.16)) {
            isJoinModalPresented = false
        }
    }

    private func continueAfterName() {
        let name = deviceName.trimmingCharacters(in: .whitespaces)
        AirClipIdentity.shared.setDeviceName(name)
        errorMessage = nil

        if isCreating {
            AirClipIdentity.shared.createAirClip(name: name)
            LanServer.shared.start()
            pairing.onPairSuccess = { finishOnboarding(opening: .openDevicesTab) }
            PairingSession.shared.start()
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .openDevicesTab, object: nil)
            }
            withAnimation(.easeOut(duration: 0.18)) { step = .showCode }
        } else {
            LanBrowser.shared.start()
            withAnimation(.easeOut(duration: 0.18)) { step = .enterCode }
        }
    }

    private func joinAirClip() {
        let code = PairingSession.normalizedCode(joinCode)
        let name = deviceName.trimmingCharacters(in: .whitespaces)
        isLoading = true
        errorMessage = nil

        PairingClient.shared.joinAirClip(code: code, myName: name) { airClipId, devices in
            AirClipIdentity.shared.joinAirClip(airClipId: airClipId, myName: name, allDevices: devices)
            self.isLoading = false
            self.finishOnboarding(opening: .openDevicesTab)
        } onError: { message in
            self.isLoading = false
            self.errorMessage = message
        }
    }

    private func finishOnboarding(opening tabNotification: Notification.Name) {
        pairing.onPairSuccess = nil
        isJoinModalPresented = false
        PairingSession.shared.stop()
        SyncModeStore.shared.applyRuntimePolicy()
        NotificationCenter.default.post(name: .authDidComplete, object: nil)
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: tabNotification, object: nil)
        }
    }

    private func requestFirstRunPermissionsIfNeeded() {
        guard !AirClipIdentity.shared.isPaired else { return }

        if UserDefaults.standard.bool(forKey: firstRunPermissionPromptKey) {
            CurrentWiFiNetwork.shared.requestAccessAndRefresh()
            return
        }

        UserDefaults.standard.set(true, forKey: firstRunPermissionPromptKey)
        CurrentWiFiNetwork.shared.requestAccessAndRefresh()

        Task {
            try? await Task.sleep(nanoseconds: 700_000_000)
            await DeviceNotificationCoordinator.shared.requestAuthorizationForOnboarding()

            try? await Task.sleep(nanoseconds: 700_000_000)
            await MainActor.run {
                guard !AirClipIdentity.shared.isPaired else { return }
                LanBrowser.shared.start()
            }

            try? await Task.sleep(nanoseconds: 1_200_000_000)
            await MainActor.run {
                guard !AirClipIdentity.shared.isPaired else { return }
                LanBrowser.shared.stop()
            }
        }
    }

    private func formattedCode(_ code: String) -> String {
        guard code.count == 6 else { return code }
        return "\(code.prefix(3)) \(code.suffix(3))"
    }
}

// MARK: - Initial Mac splash

private enum MacInitialSplashMetrics {
    static let width: CGFloat = 860
    static let height: CGFloat = 608
    static let artworkCanvasHeight: CGFloat = 720
    static let artworkContentOffsetY: CGFloat = 40
    static let contentTop: CGFloat = 42
    static let orbitCenter = CGPoint(x: 430, y: 179)
    static let titlebarArtworkCompensation: CGFloat = 12
    static let innerOrbitDiameter: CGFloat = 253.8521
    static let outerOrbitDiameter: CGFloat = 380
    static let innerOrbitRadius: CGFloat = innerOrbitDiameter / 2
}

private struct MacInitialSplashScreen: View {
    let onJoin: () -> Void
    let onCreate: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.white

            MacSplashArtwork()
                .offset(y: -MacInitialSplashMetrics.titlebarArtworkCompensation)

            Text("Copy anywhere. Paste everywhere.")
                .font(.custom("Beary", size: 24))
                .lineSpacing(12)
                .foregroundStyle(Color(hex: "#202327"))
                .multilineTextAlignment(.center)
                .frame(width: 341, height: 72)
                .position(x: 429.5, y: 488)

            HStack(spacing: 20) {
                MacSplashButton(
                    title: "Join your Airclip",
                    svg: MacSplashSVG.joinIcon,
                    foreground: Color(hex: "#202327"),
                    background: Color(hex: "#EFF0F1"),
                    width: 230,
                    action: onJoin
                )

                MacSplashButton(
                    title: "Create an Airclip",
                    svg: MacSplashSVG.createIcon,
                    foreground: .white,
                    background: .black,
                    width: 237,
                    action: onCreate
                )
            }
            .frame(width: 487, height: 60)
            .position(x: 429.5, y: 578)
        }
        .frame(width: MacInitialSplashMetrics.width, height: MacInitialSplashMetrics.height)
    }
}

private struct MacSplashArtwork: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            Circle()
                .fill(Color(hex: "#7F8FF9"))
                .frame(width: 613, height: 613)
                .blur(radius: 119.2607)
                .position(x: 430, y: 105.5)

            Circle()
                .fill(Color(hex: "#2E47F0"))
                .frame(width: 410.297, height: 410.297)
                .blur(radius: 84.3991)
                .position(x: 430.0035, y: 150.1485)

            Circle()
                .fill(Color(hex: "#070D30"))
                .frame(width: 224.7522, height: 224.7522)
                .blur(radius: 63.4630)
                .position(x: 430, y: 179)

            Circle()
                .stroke(Color.white.opacity(0.10), lineWidth: 0.9066)
                .frame(
                    width: MacInitialSplashMetrics.innerOrbitDiameter,
                    height: MacInitialSplashMetrics.innerOrbitDiameter
                )
                .position(MacInitialSplashMetrics.orbitCenter)

            Circle()
                .stroke(Color.white.opacity(0.10), lineWidth: 0.9066)
                .frame(
                    width: MacInitialSplashMetrics.outerOrbitDiameter,
                    height: MacInitialSplashMetrics.outerOrbitDiameter
                )
                .position(MacInitialSplashMetrics.orbitCenter)

            MacSplashOrbitingShapes()

            MacSplashSVGImage(svg: MacSplashSVG.logo)
                .frame(width: 195, height: 50)
                .position(MacInitialSplashMetrics.orbitCenter)
        }
        .offset(y: MacInitialSplashMetrics.artworkContentOffsetY)
        .frame(width: MacInitialSplashMetrics.width, height: MacInitialSplashMetrics.artworkCanvasHeight)
        .clipped()
    }
}

private struct MacSplashOrbitingShapes: View {
    private let center = MacInitialSplashMetrics.orbitCenter
    private let duration: TimeInterval = 20

    var body: some View {
        TimelineView(.animation) { timeline in
            let progress = timeline.date.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: duration) / duration
            let angle = -(progress * 360)

            ZStack(alignment: .topLeading) {
                MacSplashSVGImage(svg: MacSplashSVG.triangleShape)
                    .frame(width: 15, height: 14)
                    .position(pointOnInnerOrbit(startAngle: 90, drift: angle))

                Circle()
                    .fill(Color(hex: "#50B4F7"))
                    .frame(width: 14.1929, height: 14.1929)
                    .position(pointOnInnerOrbit(startAngle: 210, drift: angle))

                RoundedRectangle(cornerRadius: 1.9884, style: .continuous)
                    .fill(Color(hex: "#50B4F7"))
                    .frame(width: 14.4495, height: 13.9453)
                    .rotationEffect(.degrees(45))
                    .position(pointOnInnerOrbit(startAngle: 330, drift: angle))
            }
        }
    }

    private func pointOnInnerOrbit(startAngle: Double, drift: Double) -> CGPoint {
        let radians = (startAngle + drift) * .pi / 180
        let radius = MacInitialSplashMetrics.innerOrbitRadius
        return CGPoint(
            x: center.x + cos(radians) * radius,
            y: center.y - sin(radians) * radius
        )
    }
}

private struct MacSplashButton: View {
    let title: String
    let svg: String
    let foreground: Color
    let background: Color
    let width: CGFloat
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            HStack(alignment: .bottom, spacing: 12) {
                MacSplashSVGImage(svg: svg)
                    .frame(width: 20, height: 20, alignment: .center)

                Text(title)
                    .font(.custom("Beary", size: 18))
                    .foregroundStyle(foreground)
                    .lineLimit(1)
                    .offset(y: 1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .frame(width: width, height: 60, alignment: .center)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(background)
            )
            .scaleEffect(isPressed ? 0.985 : 1)
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        withAnimation(.easeOut(duration: 0.08)) { isPressed = true }
                    }
                }
                .onEnded { _ in
                    withAnimation(.easeOut(duration: 0.12)) { isPressed = false }
                }
        )
    }
}

private struct MacSplashSVGImage: View {
    let svg: String

    var body: some View {
        Image(nsImage: MacSplashSVG.image(from: svg))
            .resizable()
            .scaledToFit()
    }
}

private struct MacCreateAirclipModal: View {
    @Binding var deviceName: String

    let errorMessage: String?
    let isLoading: Bool
    let onCreate: () -> Void
    let onBack: () -> Void

    private var isCreateDisabled: Bool {
        deviceName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.white

            Button(action: onBack) {
                MacSplashSVGImage(svg: MacSplashSVG.backArrowIcon)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .position(x: 192, y: 96)
            .accessibilityLabel("Back")

            MacSplashSVGImage(svg: MacSplashSVG.logoBlue)
                .frame(width: 157, height: 40)
                .position(x: 430.5, y: 96)

            VStack(spacing: 0) {
                Text("Name this device")
                    .font(.custom("Beary", size: 32))
                    .foregroundStyle(Color(hex: "#202327"))
                    .frame(width: 254, height: 35)

                Text("Helps you recognise it on your other devices.")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(Color(hex: "#6A7282"))
                    .frame(width: 364, height: 24)
                    .padding(.top, 4)

                MacCreateDeviceNameField(text: $deviceName)
                    .padding(.top, 32)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(Color.destructiveRed)
                        .multilineTextAlignment(.center)
                        .frame(width: 348)
                        .padding(.top, 8)
                }

                MacCreateModalButton(
                    title: "Create an Airclip",
                    svg: MacSplashSVG.createIcon,
                    isLoading: isLoading,
                    isDisabled: isCreateDisabled,
                    action: onCreate
                )
                .padding(.top, errorMessage == nil ? 16 : 8)
            }
            .frame(width: 364, height: 301, alignment: .top)
            .position(x: 430, y: 350.5)
        }
        .frame(width: MacInitialSplashMetrics.width, height: MacInitialSplashMetrics.height)
    }
}

private struct MacCreateDeviceNameField: View {
    @Binding var text: String
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField("", text: $text)
            .font(.system(size: 20, weight: .regular))
            .foregroundStyle(Color(hex: "#202327"))
            .textFieldStyle(.plain)
            .focused($isFocused)
            .onChange(of: text) { _, newValue in
                let limitedName = DeviceDisplayText.limitedName(newValue)
                if limitedName != newValue {
                    text = limitedName
                }
            }
            .padding(.horizontal, 16)
            .frame(width: 348, height: 64)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(
                                isFocused ? Color(hex: "#202327").opacity(0.35) : Color(hex: "#D6D6D6"),
                                lineWidth: 1
                            )
                    )
            )
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    isFocused = true
                }
            }
    }
}

private struct MacCreateModalButton: View {
    let title: String
    let svg: String
    let isLoading: Bool
    let isDisabled: Bool
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                        .frame(width: 20, height: 20)
                } else {
                    MacSplashSVGImage(svg: svg)
                        .frame(width: 20, height: 20)
                }

                Text(title)
                    .font(.custom("Beary", size: 18))
                    .foregroundStyle(Color.white)
                    .lineLimit(1)
                    .offset(y: 1.5)
            }
            .frame(width: 348, height: 60)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.black)
            )
            .scaleEffect(isPressed ? 0.985 : 1)
            .opacity(isDisabled ? 0.45 : 1)
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled || isLoading)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        withAnimation(.easeOut(duration: 0.08)) { isPressed = true }
                    }
                }
                .onEnded { _ in
                    withAnimation(.easeOut(duration: 0.12)) { isPressed = false }
                }
        )
    }
}

private struct MacJoinAirclipModal: View {
    let qrImage: NSImage?
    let code: String?
    let onClose: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.white

            Button(action: onClose) {
                MacSplashSVGImage(svg: MacSplashSVG.backArrowIcon)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .position(x: 192, y: 96)
            .accessibilityLabel("Back")

            VStack(spacing: 0) {
                Text("Join your Airclip")
                    .font(.custom("Beary", size: 32))
                    .foregroundStyle(Color(hex: "#202327"))
                    .frame(width: 238, height: 35)

                Text("Open Airclip on an existing device and scan this QR code or have them enter the code below")
                    .font(.system(size: 16, weight: .regular))
                    .lineSpacing(4)
                    .foregroundStyle(Color(hex: "#6F7785"))
                    .multilineTextAlignment(.center)
                    .frame(width: 364, height: 48)
                    .padding(.top, 4)

                MacJoinQRCodeCard(qrImage: qrImage)
                    .padding(.top, 60)

                MacJoinCodeView(code: code)
                    .padding(.top, 40)
            }
            .frame(width: 364, height: 435, alignment: .top)
            .position(x: 430, y: 297.5)
        }
        .frame(width: MacInitialSplashMetrics.width, height: MacInitialSplashMetrics.height)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.white)
        .ignoresSafeArea()
    }
}

private struct MacJoinQRCodeCard: View {
    let qrImage: NSImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28.5714, style: .continuous)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 28.5714, style: .continuous)
                        .strokeBorder(Color(hex: "#F7F7F6"), lineWidth: 16.0714)
                )
                .frame(width: 200, height: 200)

            if let qrImage {
                Image(nsImage: qrImage)
                    .resizable()
                    .interpolation(.none)
                    .frame(width: 157, height: 157)
            } else {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 157, height: 157)
            }
        }
        .frame(width: 200, height: 200)
    }
}

private struct MacJoinCodeView: View {
    let code: String?

    private var digits: [String] {
        let normalized = PairingSession.normalizedCode(code ?? "")
        return Array(normalized.padding(toLength: 6, withPad: "0", startingAt: 0).prefix(6)).map(String.init)
    }

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    Text(digits[index])
                        .frame(width: 38, height: 48)
                }
            }
            .padding(.horizontal, 8)
            .frame(width: 138, height: 48)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(hex: "#F5F5F5"))
            )

            Text("-")
                .frame(width: 14, height: 48)

            HStack(spacing: 4) {
                ForEach(3..<6, id: \.self) { index in
                    Text(digits[index])
                        .frame(width: 38, height: 48)
                }
            }
            .padding(.horizontal, 8)
            .frame(width: 138, height: 48)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(hex: "#F5F5F5"))
            )
        }
        .font(.system(size: 28, weight: .semibold))
        .foregroundStyle(Color(hex: "#202327"))
        .frame(width: 314, height: 48)
        .accessibilityLabel(code.map { "Pairing code \($0)" } ?? "Pairing code loading")
    }
}

enum MacSplashSVG {
    static var logoBlue: String {
        logo.replacingOccurrences(of: "fill=\"white\"", with: "fill=\"#4657F5\"")
    }

    static let logoSidebar = """
    <svg width="97" height="24" viewBox="0 0 97 24" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M10.0781 2.38862C13.263 -0.796154 18.4264 -0.796258 21.6113 2.38862C24.7962 5.5735 24.7961 10.7369 21.6113 13.9218L13.9218 21.6113C10.7369 24.796 5.57348 24.7961 2.38861 21.6113C-0.796266 18.4264 -0.79614 13.263 2.38861 10.0781L10.0781 2.38862ZM19.8642 4.13569C17.6444 1.91594 14.0449 1.91604 11.8251 4.13569L4.13568 11.8251C1.91607 14.045 1.91594 17.6445 4.13568 19.8642C6.35542 22.0839 9.95493 22.0838 12.1747 19.8642L19.8642 12.1748C22.0839 9.95494 22.0839 6.35544 19.8642 4.13569ZM11.998 8.50385C12.9631 7.53874 14.528 7.53873 15.4931 8.50385C16.458 9.46899 16.4582 11.0339 15.4931 11.999L10.2499 17.2412C9.2848 18.2062 7.71992 18.2063 6.75482 17.2412C5.79001 16.276 5.78986 14.7111 6.75482 13.746L11.998 8.50385Z" fill="#4C3977"/><path d="M83.1836 7.09453H85.5162V8.52643C86.1013 7.98754 86.7557 7.57183 87.4793 7.27929C88.2184 6.97135 89.0113 6.81738 89.8581 6.81738C90.7357 6.81738 91.5595 6.98675 92.3293 7.32548C93.1145 7.66421 93.792 8.12611 94.3617 8.71119C94.9468 9.28088 95.4087 9.95834 95.7474 10.7436C96.0861 11.5134 96.2555 12.3448 96.2555 13.2379C96.2555 14.1155 96.0861 14.9469 95.7474 15.7321C95.4087 16.502 94.9468 17.1795 94.3617 17.7645C93.792 18.3342 93.1145 18.7884 92.3293 19.1272C91.5595 19.4659 90.7357 19.6352 89.8581 19.6352C89.0113 19.6352 88.2184 19.489 87.4793 19.1964C86.7557 18.8885 86.1013 18.4651 85.5162 17.9262V24.0002H83.1836V7.09453ZM89.7196 17.6952C90.3046 17.6952 90.8512 17.5798 91.3593 17.3488C91.8674 17.1025 92.3139 16.7791 92.6988 16.3788C93.0838 15.9785 93.384 15.5089 93.5995 14.97C93.8151 14.4311 93.9229 13.8537 93.9229 13.2379C93.9229 12.622 93.8151 12.0446 93.5995 11.5057C93.384 10.9514 93.0838 10.4741 92.6988 10.0738C92.3139 9.6735 91.8674 9.35786 91.3593 9.12691C90.8512 8.88056 90.3046 8.75738 89.7196 8.75738C89.1499 8.75738 88.6033 8.88056 88.0798 9.12691C87.5717 9.35786 87.1252 9.6735 86.7403 10.0738C86.3707 10.4741 86.0705 10.9514 85.8395 11.5057C85.624 12.0446 85.5162 12.622 85.5162 13.2379C85.5162 13.8537 85.624 14.4311 85.8395 14.97C86.0705 15.5089 86.3707 15.9785 86.7403 16.3788C87.1252 16.7791 87.5717 17.1025 88.0798 17.3488C88.6033 17.5798 89.1499 17.6952 89.7196 17.6952Z" fill="#4C3977"/><path d="M80.4702 7.09507V19.3586H78.1144V7.09507H80.4702ZM77.9297 3.51531C77.9297 3.14578 78.0606 2.83015 78.3223 2.5684C78.5841 2.30665 78.9074 2.17578 79.2923 2.17578C79.6618 2.17578 79.9775 2.30665 80.2392 2.5684C80.5164 2.83015 80.6549 3.14578 80.6549 3.51531C80.6549 3.90023 80.5164 4.22356 80.2392 4.48531C79.9775 4.74705 79.6618 4.87793 79.2923 4.87793C78.9074 4.87793 78.5841 4.74705 78.3223 4.48531C78.0606 4.22356 77.9297 3.90023 77.9297 3.51531Z" fill="#4C3977"/><path d="M73.0547 2.45312H75.3873V19.3588H73.0547V2.45312Z" fill="#4C3977"/><path d="M60.207 13.2379C60.207 12.3448 60.3764 11.5134 60.7151 10.7436C61.0539 9.95834 61.5081 9.28088 62.0777 8.71119C62.6628 8.12611 63.3403 7.66421 64.1101 7.32548C64.8954 6.98675 65.7345 6.81738 66.6275 6.81738C67.6283 6.81738 68.5444 7.03294 69.3758 7.46405C70.2227 7.87976 70.9386 8.44175 71.5237 9.15L69.9763 10.7205C69.6068 10.1354 69.1295 9.6658 68.5444 9.31167C67.9593 8.94215 67.3204 8.75738 66.6275 8.75738C66.0578 8.75738 65.5266 8.88056 65.0339 9.12691C64.5412 9.35786 64.1101 9.67349 63.7406 10.0738C63.3711 10.4741 63.0785 10.9514 62.863 11.5057C62.6474 12.0446 62.5397 12.6297 62.5397 13.261C62.5397 13.8768 62.6474 14.4619 62.863 15.0162C63.0785 15.5551 63.3711 16.0247 63.7406 16.425C64.1101 16.8253 64.5412 17.1487 65.0339 17.395C65.5266 17.626 66.0578 17.7414 66.6275 17.7414C67.3204 17.7414 67.9593 17.5644 68.5444 17.2102C69.1295 16.8407 69.6068 16.3634 69.9763 15.7783L71.5237 17.3257C70.9386 18.034 70.2227 18.596 69.3758 19.0117C68.529 19.4274 67.6129 19.6352 66.6275 19.6352C65.7345 19.6352 64.8954 19.4659 64.1101 19.1271C63.3403 18.7884 62.6628 18.3342 62.0777 17.7645C61.5081 17.1794 61.0539 16.502 60.7151 15.7321C60.3764 14.9469 60.207 14.1155 60.207 13.2379Z" fill="#4C3977"/><path d="M51.3164 7.09453H53.649V8.06453C54.0647 7.66421 54.5189 7.35627 55.0116 7.14072C55.5197 6.92516 56.0509 6.81738 56.6052 6.81738C57.3443 6.81738 58.0525 6.97905 58.73 7.30238C59.4228 7.61032 60.0079 8.07992 60.4852 8.71119C60.1465 8.97294 59.8078 9.25778 59.469 9.56572C59.1303 9.87365 58.8609 10.1123 58.6607 10.2817C58.3682 9.88135 58.0294 9.57342 57.6445 9.35786C57.2596 9.1423 56.8593 9.01913 56.4435 8.98834C55.8585 8.95754 55.3196 9.08072 54.8269 9.35786C54.3496 9.61961 53.957 10.0045 53.649 10.5126V19.3581H51.3164V7.09453Z" fill="#4C3977"/><path d="M48.5991 7.09507V19.3586H46.2434V7.09507H48.5991ZM46.0586 3.51531C46.0586 3.14578 46.1895 2.83015 46.4512 2.5684C46.713 2.30665 47.0363 2.17578 47.4212 2.17578C47.7907 2.17578 48.1064 2.30665 48.3681 2.5684C48.6453 2.83015 48.7838 3.14578 48.7838 3.51531C48.7838 3.90023 48.6453 4.22356 48.3681 4.48531C48.1064 4.74705 47.7907 4.87793 47.4212 4.87793C47.0363 4.87793 46.713 4.74705 46.4512 4.48531C46.1895 4.22356 46.0586 3.90023 46.0586 3.51531Z" fill="#4C3977"/><path d="M29.7734 19.3591L36.3094 2.33789H37.9953L44.5313 19.3591H42.0139L40.582 15.5946H33.7227L32.2908 19.3591H29.7734ZM34.5311 13.516H39.7737L37.1408 6.6798L34.5311 13.516Z" fill="#4C3977"/></svg>
    """

    static let logo = """
    <svg width="195" height="50" viewBox="0 0 195 50" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M20.8438 4.9404C27.4312 -1.64675 38.111 -1.64685 44.6983 4.9404C51.2856 11.5277 51.2856 22.2076 44.6983 28.7949L28.795 44.6982C22.2077 51.2854 11.5279 51.2853 4.94051 44.6982C-1.64684 38.1109 -1.64684 27.431 4.94051 20.8437L20.8438 4.9404ZM41.0841 8.55466C36.4929 3.96355 29.0493 3.96365 24.4581 8.55466L8.55477 24.458C3.96359 29.0491 3.96359 36.4928 8.55477 41.084C13.146 45.6749 20.5896 45.675 25.1807 41.084L41.0841 25.1806C45.6751 20.5895 45.6751 13.1458 41.0841 8.55466ZM24.8145 17.5898C26.8107 15.5937 30.0469 15.5937 32.0431 17.5898C34.039 19.586 34.0391 22.8223 32.0431 24.8183L21.2003 35.6611C19.2041 37.6572 15.967 37.6572 13.9708 35.6611C11.9749 33.665 11.9749 30.4287 13.9708 28.4326L24.8145 17.5898Z" fill="white"/><path d="M168.367 15.7254H173.046V18.5978C174.22 17.5168 175.533 16.6829 176.984 16.096C178.467 15.4783 180.058 15.1694 181.756 15.1694C183.517 15.1694 185.169 15.5092 186.714 16.1887C188.289 16.8682 189.648 17.7948 190.791 18.9684C191.964 20.1112 192.891 21.4702 193.57 23.0454C194.25 24.5898 194.59 26.2576 194.59 28.049C194.59 29.8095 194.25 31.4774 193.57 33.0526C192.891 34.5969 191.964 35.9559 190.791 37.1296C189.648 38.2724 188.289 39.1835 186.714 39.863C185.169 40.5425 183.517 40.8823 181.756 40.8823C180.058 40.8823 178.467 40.5889 176.984 40.002C175.533 39.3843 174.22 38.5349 173.046 37.4539V49.6386H168.367V15.7254ZM181.478 36.9906C182.652 36.9906 183.749 36.759 184.768 36.2957C185.787 35.8015 186.683 35.1529 187.455 34.3498C188.227 33.5468 188.829 32.6048 189.262 31.5237C189.694 30.4427 189.91 29.2845 189.91 28.049C189.91 26.8136 189.694 25.6553 189.262 24.5743C188.829 23.4624 188.227 22.5049 187.455 21.7019C186.683 20.8988 185.787 20.2657 184.768 19.8024C183.749 19.3082 182.652 19.0611 181.478 19.0611C180.336 19.0611 179.239 19.3082 178.189 19.8024C177.17 20.2657 176.274 20.8988 175.502 21.7019C174.761 22.5049 174.158 23.4624 173.695 24.5743C173.263 25.6553 173.046 26.8136 173.046 28.049C173.046 29.2845 173.263 30.4427 173.695 31.5237C174.158 32.6048 174.761 33.5468 175.502 34.3498C176.274 35.1529 177.17 35.8015 178.189 36.2957C179.239 36.759 180.336 36.9906 181.478 36.9906Z" fill="white"/><path d="M162.92 15.7261V40.327H158.195V15.7261H162.92ZM157.824 8.54502C157.824 7.80375 158.087 7.17058 158.612 6.64551C159.137 6.12044 159.785 5.85791 160.558 5.85791C161.299 5.85791 161.932 6.12044 162.457 6.64551C163.013 7.17058 163.291 7.80375 163.291 8.54502C163.291 9.31718 163.013 9.96579 162.457 10.4909C161.932 11.0159 161.299 11.2785 160.558 11.2785C159.785 11.2785 159.137 11.0159 158.612 10.4909C158.087 9.96579 157.824 9.31718 157.824 8.54502Z" fill="white"/><path d="M148.051 6.41357H152.73V40.3267H148.051V6.41357Z" fill="white"/><path d="M122.273 28.049C122.273 26.2576 122.613 24.5898 123.293 23.0454C123.972 21.4702 124.883 20.1112 126.026 18.9684C127.2 17.7948 128.559 16.8682 130.103 16.1887C131.678 15.5092 133.362 15.1694 135.153 15.1694C137.161 15.1694 138.998 15.6018 140.666 16.4667C142.365 17.3006 143.801 18.4279 144.975 19.8487L141.871 22.9991C141.13 21.8254 140.172 20.8834 138.998 20.173C137.825 19.4317 136.543 19.0611 135.153 19.0611C134.01 19.0611 132.945 19.3082 131.956 19.8024C130.968 20.2657 130.103 20.8988 129.362 21.7019C128.621 22.5049 128.034 23.4624 127.601 24.5743C127.169 25.6553 126.953 26.829 126.953 28.0954C126.953 29.3308 127.169 30.5045 127.601 31.6164C128.034 32.6974 128.621 33.6394 129.362 34.4425C130.103 35.2455 130.968 35.8941 131.956 36.3883C132.945 36.8516 134.01 37.0833 135.153 37.0833C136.543 37.0833 137.825 36.7281 138.998 36.0177C140.172 35.2764 141.13 34.3189 141.871 33.1453L144.975 36.2493C143.801 37.6701 142.365 38.7975 140.666 39.6314C138.967 40.4653 137.13 40.8823 135.153 40.8823C133.362 40.8823 131.678 40.5425 130.103 39.863C128.559 39.1835 127.2 38.2724 126.026 37.1296C124.883 35.9559 123.972 34.5969 123.293 33.0526C122.613 31.4774 122.273 29.8095 122.273 28.049Z" fill="white"/><path d="M104.438 15.7254H109.117V17.6712C109.951 16.8682 110.862 16.2505 111.85 15.818C112.869 15.3856 113.935 15.1694 115.047 15.1694C116.529 15.1694 117.95 15.4937 119.309 16.1424C120.699 16.7601 121.873 17.7021 122.83 18.9684C122.151 19.4935 121.471 20.0649 120.792 20.6826C120.112 21.3004 119.572 21.7791 119.17 22.1189C118.583 21.3158 117.904 20.6981 117.132 20.2657C116.36 19.8333 115.557 19.5862 114.723 19.5244C113.549 19.4626 112.468 19.7097 111.48 20.2657C110.522 20.7907 109.734 21.5629 109.117 22.5821V40.3263H104.438V15.7254Z" fill="white"/><path d="M98.9869 15.7261V40.327H94.2613V15.7261H98.9869ZM93.8906 8.54502C93.8906 7.80375 94.1532 7.17058 94.6782 6.64551C95.2033 6.12044 95.8519 5.85791 96.6241 5.85791C97.3653 5.85791 97.9985 6.12044 98.5236 6.64551C99.0795 7.17058 99.3575 7.80375 99.3575 8.54502C99.3575 9.31718 99.0795 9.96579 98.5236 10.4909C97.9985 11.0159 97.3653 11.2785 96.6241 11.2785C95.8519 11.2785 95.2033 11.0159 94.6782 10.4909C94.1532 9.96579 93.8906 9.31718 93.8906 8.54502Z" fill="white"/><path d="M61.2227 40.3269L74.3339 6.18213H77.7159L90.8272 40.3269H85.7773L82.9048 32.7752H69.145L66.2726 40.3269H61.2227ZM70.7665 28.6056H81.2833L76.0018 14.8921L70.7665 28.6056Z" fill="white"/></svg>
    """

    static let joinIcon = """
    <svg width="20" height="20" viewBox="0 0 20 20" fill="none" xmlns="http://www.w3.org/2000/svg"><path fill-rule="evenodd" clip-rule="evenodd" d="M9.0685 3.34516C10.4734 1.94029 12.7511 1.94029 14.156 3.34516C15.5294 4.71854 15.5601 6.92612 14.2483 8.33689C14.2345 8.32274 14.2206 8.30864 14.2065 8.29461C12.3135 6.40158 9.24431 6.40158 7.35128 8.29461L7.17885 8.46704C6.93477 8.71112 6.93477 9.10685 7.17885 9.35092C7.42293 9.595 7.81865 9.595 8.06273 9.35092L8.23517 9.17849C9.64004 7.77362 11.9178 7.77362 13.3227 9.17849C14.7275 10.5834 14.7275 12.8611 13.3227 14.266L10.9341 16.6545C9.52923 18.0594 7.25149 18.0594 5.84662 16.6545C4.47323 15.2811 4.44246 13.0736 5.75429 11.6628C5.76811 11.6769 5.78204 11.691 5.79607 11.7051C7.6891 13.5981 10.7583 13.5981 12.6513 11.7051L12.8238 11.5326C13.0678 11.2886 13.0678 10.8928 12.8238 10.6488C12.5797 10.4047 12.184 10.4047 11.9399 10.6487L11.7674 10.8212C10.3626 12.2261 8.08482 12.2261 6.67995 10.8212C5.27508 9.41632 5.27508 7.13857 6.67995 5.7337L9.0685 3.34516ZM4.99545 10.6504C3.95764 8.80357 4.22451 6.42138 5.79607 4.84982L8.18462 2.46127C10.0776 0.568248 13.1468 0.568248 15.0399 2.46127C16.9329 4.3543 16.9329 7.4235 15.0399 9.31652L15.0072 9.34923C16.045 11.1961 15.7781 13.5783 14.2065 15.1499L11.818 17.5384C9.92496 19.4314 6.85576 19.4314 4.96274 17.5384C3.06971 15.6454 3.06971 12.5762 4.96274 10.6832L4.99545 10.6504Z" fill="#202327"/></svg>
    """

    static let createIcon = """
    <svg width="20" height="20" viewBox="0 0 20 20" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M10.001 1.04199C14.9485 1.04199 18.959 5.05245 18.959 10C18.959 14.9476 14.9485 18.958 10.001 18.958C5.05343 18.958 1.04297 14.9476 1.04297 10C1.04297 5.05245 5.05343 1.04199 10.001 1.04199ZM10.001 2.29199C5.74378 2.29199 2.29297 5.74281 2.29297 10C2.29297 14.2572 5.74378 17.708 10.001 17.708C14.2582 17.708 17.709 14.2572 17.709 10C17.709 5.74281 14.2582 2.29199 10.001 2.29199ZM10.001 6.04199C10.3462 6.04199 10.626 6.32181 10.626 6.66699V9.375H13.334C13.6792 9.375 13.959 9.65482 13.959 10C13.959 10.3452 13.6792 10.625 13.334 10.625H10.626V13.333C10.626 13.6782 10.3462 13.958 10.001 13.958C9.6558 13.958 9.37598 13.6782 9.37598 13.333V10.625H6.66797C6.32279 10.625 6.04297 10.3452 6.04297 10C6.04297 9.65482 6.32279 9.375 6.66797 9.375H9.37598V6.66699C9.37598 6.32181 9.6558 6.04199 10.001 6.04199Z" fill="white"/></svg>
    """

    static let triangleShape = """
    <svg width="15" height="14" viewBox="0 0 15 14" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M2.10171 13.0357C0.4444 13.0241 -0.555111 11.1961 0.329554 9.79463L5.89035 0.985198C6.74578 -0.36999 8.73942 -0.316969 9.52162 1.08177L14.4891 9.96477C15.28 11.379 14.2504 13.1206 12.63 13.1093L2.10171 13.0357Z" fill="#50B4F7"/></svg>
    """

    static let backArrowIcon = """
    <svg width="32" height="32" viewBox="0 0 32 32" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M4.33203 16.0003C4.33203 16.4984 4.5529 16.9605 4.76206 17.3075C4.98776 17.6819 5.29129 18.0684 5.62428 18.4453C6.29227 19.2014 7.16385 20.0134 8.00968 20.7479C8.86047 21.4867 9.70833 22.167 10.3417 22.6614C10.6589 22.909 10.9235 23.1109 11.1094 23.2513C11.2024 23.3215 11.2757 23.3764 11.3261 23.414L11.3842 23.4572L11.3996 23.4686L11.405 23.4725C11.8497 23.8001 12.4762 23.7056 12.8038 23.2609C13.1313 22.8162 13.0364 22.1903 12.5918 21.8627L12.5748 21.8502L12.5214 21.8105C12.4742 21.7753 12.4043 21.7229 12.315 21.6555C12.1363 21.5205 11.8801 21.325 11.5723 21.0848C10.9557 20.6035 10.1369 19.9463 9.32101 19.2378C8.50018 18.525 7.70512 17.7799 7.12312 17.1212C7.0863 17.0795 7.05068 17.0385 7.01625 16.9983L26.6654 16.9983C27.2177 16.9983 27.6654 16.5506 27.6654 15.9983C27.6654 15.446 27.2177 14.9983 26.6654 14.9983L7.01963 14.9983C7.05301 14.9594 7.08751 14.9198 7.12312 14.8795C7.70512 14.2207 8.50018 13.4756 9.32101 12.7628C10.1369 12.0543 10.9557 11.3971 11.5723 10.9158C11.8801 10.6756 12.1363 10.4802 12.315 10.3452C12.4043 10.2777 12.4742 10.2253 12.5214 10.1901L12.5748 10.1505L12.5918 10.1379C13.0364 9.81034 13.1313 9.18437 12.8038 8.73972C12.4762 8.29505 11.8497 8.20053 11.405 8.52808L11.3996 8.53203L11.3842 8.54343L11.3261 8.58661C11.2757 8.6242 11.2024 8.6791 11.1094 8.74933C10.9235 8.88974 10.6589 9.09166 10.3417 9.33925C9.70833 9.83362 8.86047 10.5139 8.00968 11.2527C7.16385 11.9872 6.29227 12.7992 5.62428 13.5553C5.29129 13.9322 4.98776 14.3187 4.76206 14.6932C4.55416 15.038 4.33469 15.4967 4.33205 15.9913" fill="#202327"/></svg>
    """

    static func image(from svg: String) -> NSImage {
        NSImage(data: Data(svg.utf8)) ?? NSImage(size: NSSize(width: 1, height: 1))
    }
}

// MARK: - Splash hero

private struct OnboardingOrbitalHero: View {
    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let baseWidth: CGFloat = 412
            let heroDiameter = min(max(width * 1.25, 420), height * 1.34)
            let center = CGPoint(x: width / 2, y: min(height * 0.47, heroDiameter * 0.57))
            let outerDiameter = heroDiameter * 0.80
            let innerDiameter = heroDiameter * 0.55

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(hex: "#10175D"),
                                Color(hex: "#293CDA"),
                                Color(hex: "#5A6BFF"),
                                Color(hex: "#EEF2FF")
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: heroDiameter * 0.55
                        )
                    )
                    .frame(width: heroDiameter, height: heroDiameter)
                    .position(center)

                Circle()
                    .stroke(Color.white.opacity(0.13), lineWidth: 1)
                    .frame(width: outerDiameter, height: outerDiameter)
                    .position(center)

                Circle()
                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
                    .frame(width: innerDiameter, height: innerDiameter)
                    .position(center)

                OrbitalMarkers(center: center, radius: innerDiameter / 2)

                AirClipSplashLogo()
                    .position(center)
            }
            .frame(width: width, height: height)
            .scaleEffect(width < baseWidth ? max(0.90, width / baseWidth) : 1, anchor: .top)
        }
    }
}

private struct OrbitalMarkers: View {
    let center: CGPoint
    let radius: CGFloat

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let drift = t / 18.0 * 360.0

            ZStack {
                orbitalMarker(.roundedSquare, angle: 220 + drift)
                orbitalMarker(.circle, angle: 108 + drift)
                orbitalMarker(.triangle, angle: 326 + drift)
            }
        }
    }

    private func orbitalMarker(_ shape: MarkerShape, angle: Double) -> some View {
        let radians = angle * .pi / 180
        let point = CGPoint(
            x: center.x + cos(radians) * radius,
            y: center.y + sin(radians) * radius
        )

        return markerShape(shape, angle: angle)
            .position(point)
    }

    @ViewBuilder
    private func markerShape(_ shape: MarkerShape, angle: Double) -> some View {
        switch shape {
        case .roundedSquare:
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color(hex: "#50B4F7"))
                .frame(width: 14, height: 14)
        case .circle:
            Circle()
                .fill(Color(hex: "#50B4F7"))
                .frame(width: 14, height: 14)
        case .triangle:
            Triangle()
                .fill(Color(hex: "#50B4F7"))
                .frame(width: 14, height: 14)
                .rotationEffect(.degrees(angle + 72))
        }
    }
}

private enum MarkerShape {
    case roundedSquare
    case circle
    case triangle
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct AirClipSplashLogo: View {
    var body: some View {
        HStack(spacing: 14) {
            SplashClipMark()
                .stroke(Color.white, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                .frame(width: 44, height: 44)

            Text("Airclip")
                .font(.system(size: 45, weight: .regular))
                .foregroundStyle(Color.white)
                .tracking(-1)
        }
    }
}

private struct SplashClipMark: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let scaleX = rect.width / 44
        let scaleY = rect.height / 44
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * scaleX, y: rect.minY + y * scaleY)
        }

        path.move(to: p(15, 30))
        path.addLine(to: p(28, 17))
        path.addCurve(to: p(35, 24), control1: p(32, 13), control2: p(39, 20))
        path.addLine(to: p(20, 39))
        path.addCurve(to: p(6, 25), control1: p(12, 47), control2: p(-2, 33))
        path.addLine(to: p(21, 10))
        path.addCurve(to: p(38, 27), control1: p(31, 0), control2: p(48, 17))
        path.addLine(to: p(24, 41))
        return path
    }
}

// MARK: - Controls

private enum OnboardingButtonStyle {
    case primary
    case secondary
}

private struct OnboardingSplashButton: View {
    let title: String
    let icon: AirClipIconName
    let style: OnboardingButtonStyle
    var isLoading: Bool = false
    var isDisabled: Bool = false
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .tint(foreground)
                        .frame(width: 20, height: 20)
                } else {
                    AirClipIcon(icon, size: 20)
                        .foregroundStyle(foreground)
                        .frame(width: 20, height: 20)
                }

                Text(title)
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(foreground)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 8)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(background)
            )
            .scaleEffect(isPressed ? 0.985 : 1)
            .opacity(isDisabled ? 0.45 : 1)
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled || isLoading)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        withAnimation(.easeOut(duration: 0.08)) { isPressed = true }
                    }
                }
                .onEnded { _ in
                    withAnimation(.easeOut(duration: 0.12)) { isPressed = false }
                }
        )
    }

    private var background: Color {
        switch style {
        case .primary:
            return Color.black
        case .secondary:
            return Color(hex: "#F5F4F7")
        }
    }

    private var foreground: Color {
        switch style {
        case .primary:
            return Color.white
        case .secondary:
            return Color(hex: "#202327")
        }
    }
}

private struct OnboardingTextField: View {
    let placeholder: String
    @Binding var text: String
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField(
            "",
            text: $text,
            prompt: Text(placeholder).foregroundColor(Color(hex: "#99A1AF"))
        )
        .font(.system(size: 18, weight: .regular))
        .foregroundStyle(Color(hex: "#202327"))
        .textFieldStyle(.plain)
        .focused($isFocused)
        .padding(.horizontal, 18)
        .frame(height: 56)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(hex: "#F5F4F7"))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(isFocused ? Color(hex: "#202327").opacity(0.22) : .clear, lineWidth: 1)
                )
        )
    }
}

private struct OnboardingBackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("Back")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Color(hex: "#6A7282"))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Auth completion notification

extension Notification.Name {
    static let authDidComplete = Notification.Name("com.airclip.authDidComplete")
}
