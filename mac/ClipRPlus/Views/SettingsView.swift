import SwiftUI

struct SettingsView: View {
    @ObservedObject private var authManager = AuthManager.shared

    @State private var deviceName: String = ""
    @State private var serverURL: String = ""
    @State private var devices: [DeviceInfo] = []
    @State private var isLoadingDevices = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Settings")
                    .font(.cliprTitle2)
                    .foregroundColor(.textPrimary)
                Spacer()
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.top, Spacing.xl)
            .padding(.bottom, Spacing.sm)

            ScrollView {
                VStack(spacing: Spacing.xs) {
                    settingsSection("Account") {
                        settingsRow("Email") {
                            Text(authManager.accountEmail ?? "—")
                                .font(.cliprBody)
                                .foregroundColor(.textSecondary)
                        }
                    }

                    settingsSection("This device") {
                        settingsRow("Name") {
                            TextField("", text: $deviceName)
                                .font(.cliprBody)
                                .foregroundColor(.textPrimary)
                                .textFieldStyle(.plain)
                                .multilineTextAlignment(.trailing)
                                .onSubmit { saveDeviceName() }
                        }
                    }

                    settingsSection("Connected devices") {
                        devicesContent
                        HairlineDivider()
                        refreshButton
                    }

                    settingsSection("Server") {
                        settingsRow("URL") {
                            TextField("", text: $serverURL)
                                .font(.cliprMono)
                                .foregroundColor(.textSecondary)
                                .textFieldStyle(.plain)
                                .multilineTextAlignment(.trailing)
                                .onSubmit { saveServerURL() }
                        }
                    }

                    settingsSection("Data") {
                        Button(action: { LocalHistoryStore.shared.clearAll() }) {
                            HStack {
                                Text("Clear local history")
                                    .font(.cliprBody)
                                    .foregroundColor(Color.destructiveRed)
                                Spacer()
                            }
                            .padding(.horizontal, Spacing.md)
                            .frame(height: Layout.rowHeight)
                        }
                        .buttonStyle(.plain)
                    }

                    if let err = errorMessage {
                        Text(err)
                            .font(.cliprCaption)
                            .foregroundColor(Color.destructiveRed)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, Spacing.sm)
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.xl)
            }
        }
        .frame(width: 480, height: 560)
        .background(Color.bgBase)
        .task {
            loadLocalSettings()
            await loadDevices()
        }
    }

    // MARK: - Devices Content

    @ViewBuilder
    private var devicesContent: some View {
        if isLoadingDevices {
            HStack {
                Spacer()
                ProgressView().scaleEffect(0.7)
                Spacer()
            }
            .frame(height: Layout.rowHeight)
        } else if devices.isEmpty {
            HStack {
                Text("No other devices")
                    .font(.cliprBody)
                    .foregroundColor(.textTertiary)
                Spacer()
            }
            .padding(.horizontal, Spacing.md)
            .frame(height: Layout.rowHeight)
        } else {
            ForEach(Array(devices.enumerated()), id: \.element.id) { idx, device in
                DeviceRow(device: device) { approveDevice(device) }
                if idx < devices.count - 1 {
                    HairlineDivider(leadingPad: Spacing.md)
                }
            }
        }
    }

    private var refreshButton: some View {
        Button(action: { Task { await loadDevices() } }) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11, weight: .regular))
                Text("Refresh")
                    .font(.cliprBody)
            }
            .foregroundColor(Color.accent)
            .padding(.horizontal, Spacing.md)
            .frame(height: Layout.rowHeight)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Section Builder

    private func settingsSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.cliprCaptionMed)
                    .foregroundColor(.textTertiary)
                Spacer()
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.bottom, Spacing.xxs)

            VStack(spacing: 0) {
                content()
            }
            .background(
                RoundedRectangle(cornerRadius: Layout.panelCornerRadius)
                    .fill(Color.bgElevated)
                    .overlay(
                        RoundedRectangle(cornerRadius: Layout.panelCornerRadius)
                            .strokeBorder(Color.borderSubtle, lineWidth: 0.5)
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: Layout.panelCornerRadius))
        }
    }

    private func settingsRow<Value: View>(
        _ label: String,
        @ViewBuilder value: () -> Value
    ) -> some View {
        HStack {
            Text(label)
                .font(.cliprBody)
                .foregroundColor(.textPrimary)
            Spacer()
            value()
        }
        .padding(.horizontal, Spacing.md)
        .frame(height: Layout.rowHeight)
    }

    // MARK: - Actions

    private func loadLocalSettings() {
        deviceName = UserDefaults.standard.string(forKey: "deviceName") ?? ""
        serverURL  = UserDefaults.standard.string(forKey: "serverURL") ?? AppConfig.defaultServerURL
    }

    private func saveDeviceName() {
        UserDefaults.standard.set(deviceName, forKey: "deviceName")
    }

    private func saveServerURL() {
        UserDefaults.standard.set(serverURL, forKey: "serverURL")
    }

    private func loadDevices() async {
        isLoadingDevices = true; errorMessage = nil
        do { devices = try await APIClient.shared.listDevices() }
        catch { errorMessage = "Failed to load devices: \(error.localizedDescription)" }
        isLoadingDevices = false
    }

    private func approveDevice(_ device: DeviceInfo) {
        Task {
            do {
                try await APIClient.shared.approveDevice(id: device.id)
                await SyncEngine.shared.approveDevice(targetDeviceId: device.id)
                await loadDevices()
            } catch { errorMessage = "Failed to approve: \(error.localizedDescription)" }
        }
    }
}

// MARK: - Device Row

struct DeviceRow: View {
    let device: DeviceInfo
    let onApprove: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Circle()
                .fill(device.trustStatus == "approved" ? Color.encryptedGreen : Color.warningYellow)
                .frame(width: 6, height: 6)

            VStack(alignment: .leading, spacing: 2) {
                Text(device.name)
                    .font(.cliprBody)
                    .foregroundColor(.textPrimary)
                Text(device.trustStatus == "approved" ? "Approved" : "Pending approval")
                    .font(.cliprCaption)
                    .foregroundColor(device.trustStatus == "approved" ? Color.encryptedGreen : Color.warningYellow)
            }

            Spacer()

            if device.trustStatus == "pending" {
                Button("Approve", action: onApprove)
                    .font(.cliprCaptionMed)
                    .foregroundColor(Color.accent)
                    .buttonStyle(.plain)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xxs)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Color.selectionFill)
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .strokeBorder(Color.accent.opacity(0.3), lineWidth: 0.5)
                            )
                    )
            }
        }
        .padding(.horizontal, Spacing.md)
        .frame(minHeight: 44)
        .background(isHovered ? Color.hoverFill : Color.clear)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }
}
