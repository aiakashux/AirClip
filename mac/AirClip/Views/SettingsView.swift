import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject private var identity = AirClipIdentity.shared
    @ObservedObject private var peerManager = PeerManager.shared
    @ObservedObject private var syncModeStore = SyncModeStore.shared

    @State private var activePage: SettingsPage = .general
    @State private var deviceName: String = ""
    @State private var historyDepth: Int = UserDefaults.standard.object(forKey: "historyDepth") as? Int ?? 1

    private enum SettingsPage: String, CaseIterable {
        case general = "General"
        case devices = "Devices"
        case account = "Account"
        case privacy = "Privacy"

        var icon: AirClipIconName {
            switch self {
            case .general: return .settings
            case .devices: return .deviceSync
            case .account: return .userCircle
            case .privacy: return .shield
            }
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            contentPanel
        }
        .frame(width: 700, height: 480)
        .background(Color.bgBase.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.borderDefault, lineWidth: 0.5)
        )
        .onAppear { deviceName = identity.deviceName }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text("Settings")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color.textSecondary)
            }
            .frame(height: 52)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Color.borderSubtle).frame(height: 0.5)
            }

            VStack(spacing: 2) {
                ForEach(SettingsPage.allCases, id: \.self) { page in
                    sidebarItem(page)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 10)

            Spacer()

            Button {
                Task { await AuthManager.shared.signOut() }
            } label: {
                HStack(spacing: 9) {
                    AirClipIcon(.logout, size: 14)
                        .frame(width: 18)
                    Text("Sign out")
                        .font(.system(size: 13))
                    Spacer()
                }
                .foregroundColor(Color.textSecondary)
                .frame(height: 34)
                .padding(.horizontal, 10)
                .background(RoundedRectangle(cornerRadius: 7).fill(Color.clear))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)
            .padding(.bottom, 16)
            .overlay(alignment: .top) {
                Rectangle().fill(Color.borderSubtle).frame(height: 0.5)
            }
        }
        .frame(width: 200)
        .background(Color.bgFloating)
        .overlay(alignment: .trailing) {
            Rectangle().fill(Color.borderSubtle).frame(width: 0.5)
        }
    }

    private func sidebarItem(_ page: SettingsPage) -> some View {
        let active = activePage == page
        return Button {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.82)) {
                activePage = page
            }
        } label: {
            HStack(spacing: 9) {
                AirClipIcon(page.icon, size: 14)
                    .frame(width: 18)
                    .opacity(active ? 0.88 : 0.55)
                Text(page.rawValue)
                    .font(.system(size: 13, weight: active ? .medium : .regular))
                Spacer()
            }
            .foregroundColor(active ? Color.textPrimary : Color.textSecondary)
            .frame(height: 34)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(active ? Color.activeFill : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    private var contentPanel: some View {
        VStack(spacing: 0) {
            HStack(spacing: 9) {
                AirClipIcon(activePage.icon, size: 14)
                    .foregroundColor(Color.textSecondary)
                    .frame(width: 16)
                Text(activePage.rawValue)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color.textPrimary)
                Spacer()
            }
            .frame(height: 52)
            .padding(.horizontal, 20)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Color.borderSubtle).frame(height: 0.5)
            }

            ScrollView {
                VStack(spacing: 18) {
                    switch activePage {
                    case .general: generalPage
                    case .devices: devicesPage
                    case .account: accountPage
                    case .privacy: privacyPage
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.automatic)
        }
    }

    private var generalPage: some View {
        VStack(spacing: 18) {
            section("Profile") {
                HStack(spacing: 12) {
                    Circle()
                        .fill(LinearGradient(
                            colors: [Color.syncBlue.opacity(0.55), Color.encryptedGreen.opacity(0.35)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .overlay(Circle().strokeBorder(Color.borderDefault, lineWidth: 0.5))
                        .frame(width: 38, height: 38)
                        .overlay(Text(initials).font(.system(size: 14, weight: .semibold)).foregroundColor(Color.textPrimary))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(identity.deviceName.isEmpty ? "This Mac" : identity.deviceName)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color.textPrimary)
                        Text("Free")
                            .font(.system(size: 11))
                            .foregroundColor(Color.textSecondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 14)
                .frame(height: 62)
            }

            section("Sync") {
                VStack(spacing: 10) {
                    syncModeSelector
                    Text(syncModeStore.mode.detail)
                        .font(.system(size: 11))
                        .foregroundColor(Color.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(14)
            }

            section("History") {
                VStack(spacing: 0) {
                    row("Keep history for") {
                        EmptyView()
                    }
                    DividerLine()
                    retentionPicker
                }
            }

            statsRow
        }
    }

    private var devicesPage: some View {
        section("Paired devices") {
            VStack(spacing: 0) {
                deviceRow(name: identity.deviceName.isEmpty ? "This Mac" : identity.deviceName, detail: "This device", isOnline: true)
                ForEach(Array(otherDevices.enumerated()), id: \.element.id) { index, device in
                    DividerLine()
                    deviceRow(
                        name: device.deviceName,
                        detail: peerManager.connectedDeviceIds.contains(device.deviceId) ? "Live" : "Offline",
                        isOnline: peerManager.connectedDeviceIds.contains(device.deviceId)
                    )
                }
                if otherDevices.isEmpty {
                    DividerLine()
                    row("No other devices paired yet") {
                        Text("Add from Devices")
                            .font(.system(size: 12))
                            .foregroundColor(Color.textSecondary)
                    }
                }
            }
        }
    }

    private var accountPage: some View {
        VStack(spacing: 18) {
            section("Account") {
                VStack(spacing: 0) {
                    row("Device name") {
                        TextField("", text: $deviceName)
                            .font(.system(size: 13))
                            .foregroundColor(Color.textPrimary)
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                            .onChange(of: deviceName) { _, newValue in
                                let limitedName = DeviceDisplayText.limitedName(newValue)
                                if limitedName != newValue {
                                    deviceName = limitedName
                                }
                            }
                            .onSubmit { saveDeviceName() }
                    }
                    if let airClipId = identity.airClipId {
                        DividerLine()
                        row("AirClip ID") {
                            Text(String(airClipId.prefix(8)).lowercased() + "...")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(Color.textSecondary)
                        }
                    }
                }
            }

            section("Data") {
                Button { LocalHistoryStore.shared.clearAll() } label: {
                    rowLabelOnly("Clear local history", destructive: true)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var privacyPage: some View {
        VStack(spacing: 18) {
            section("Network access") {
                VStack(spacing: 0) {
                    row("Wi-Fi network name") {
                        Button("Open Location Services") {
                            openLocationServicesSettings()
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.textLink)
                    }
                    DividerLine()
                    row("Used for pairing") {
                        Text("Same network check")
                            .font(.system(size: 12))
                            .foregroundColor(Color.textSecondary)
                    }
                }
            }

            section("Encryption") {
                VStack(spacing: 0) {
                    row("End-to-end encryption") {
                        Text("On")
                            .font(.system(size: 12))
                            .foregroundColor(Color.encryptedGreen)
                    }
                    DividerLine()
                    row("Local clipboard history") {
                        Text("Private")
                            .font(.system(size: 12))
                            .foregroundColor(Color.textSecondary)
                    }
                }
            }
        }
    }

    private var retentionPicker: some View {
        HStack(spacing: 4) {
            ForEach(["7 days", "30 days", "90 days"].indices, id: \.self) { index in
                Button {
                    historyDepth = index
                    UserDefaults.standard.set(index, forKey: "historyDepth")
                    LocalHistoryStore.shared.pruneToRetention(days: [7, 30, 90][index])
                } label: {
                        Text(["7 days", "30 days", "90 days"][index])
                            .font(.system(size: 11.5, weight: historyDepth == index ? .medium : .regular))
                        .foregroundColor(historyDepth == index ? Color.syncBlue : Color.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 26)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(historyDepth == index ? Color.syncBlue.opacity(0.18) : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.activeFill)
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.borderSubtle, lineWidth: 0.5))
        )
        .padding(14)
    }

    private var statsRow: some View {
        HStack(spacing: 8) {
            statCard(value: "\(identity.pairedDevices.count)", label: "Devices", blue: true)
            statCard(
                value: syncModeStore.mode.label,
                label: "Sync",
                blue: syncModeStore.mode != .paused
            )
            statCard(value: ["7d", "30d", "90d"][historyDepth], label: "History", blue: false)
        }
    }

    private func statCard(value: String, label: String, blue: Bool) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(blue ? Color.syncBlue : Color.textPrimary)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(Color.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 13)
        .padding(.vertical, 12)
        .background(cardBackground(cornerRadius: 8))
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color.textTertiary)
                .padding(.horizontal, 2)
            VStack(spacing: 0) { content() }
                .background(cardBackground(cornerRadius: 10))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private func row<Content: View>(_ label: String, @ViewBuilder value: () -> Content) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(Color.textPrimary)
            Spacer()
            value()
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 42)
    }

    private func rowLabelOnly(_ label: String, destructive: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(destructive ? Color.destructiveRed : Color.textPrimary)
            Spacer()
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 42)
    }

    private func toggleRow(_ label: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(Color.textPrimary)
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(Color.syncBlue)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 42)
    }

    private var syncModeSelector: some View {
        HStack(spacing: 4) {
            ForEach(SyncMode.allCases, id: \.rawValue) { mode in
                Button {
                    syncModeStore.setMode(mode)
                } label: {
                    Text(mode.label)
                        .font(.system(size: 11.5, weight: syncModeStore.mode == mode ? .medium : .regular))
                        .foregroundColor(syncModeStore.mode == mode ? Color.textPrimary : Color.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(syncModeStore.mode == mode ? Color.segmentSelected : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.activeFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.borderSubtle, lineWidth: 0.5)
                )
        )
    }

    private func deviceRow(name: String, detail: String, isOnline: Bool) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.activeFill)
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.borderSubtle, lineWidth: 0.5))
                AirClipIcon(.laptop, size: 13)
                    .foregroundColor(Color.textSecondary)
            }
            .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.system(size: 13))
                    .foregroundColor(Color.textPrimary)
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundColor(Color.textSecondary)
            }
            Spacer()
            Circle()
                .fill(isOnline ? Color.encryptedGreen : Color.textSecondary.opacity(0.24))
                .frame(width: 6, height: 6)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 46)
    }

    private func cardBackground(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.bgElevated)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.borderDefault, lineWidth: 0.5)
            )
    }

    private var initials: String {
        let words = identity.deviceName.split(separator: " ")
        let chars = words.prefix(2).compactMap { $0.first }
        return chars.isEmpty ? "R" : String(chars).uppercased()
    }

    private var otherDevices: [PairedDevice] {
        identity.pairedDevices.values
            .filter { $0.deviceId != identity.deviceId }
            .sorted { $0.deviceName < $1.deviceName }
    }

    private func saveDeviceName() {
        let trimmed = deviceName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        AirClipIdentity.shared.setDeviceName(trimmed)
    }

    private func openLocationServicesSettings() {
        CurrentWiFiNetwork.shared.requestAccessAndRefresh()
        let urls = [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices",
            "x-apple.systempreferences:com.apple.preference.security"
        ]
        for rawURL in urls {
            guard let url = URL(string: rawURL), NSWorkspace.shared.open(url) else { continue }
            return
        }
    }
}

private struct DividerLine: View {
    var body: some View {
        Rectangle()
            .fill(Color.borderSubtle)
            .frame(height: 0.5)
    }
}
