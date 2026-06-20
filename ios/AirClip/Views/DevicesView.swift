import SwiftUI

struct DevicesView: View {
    @EnvironmentObject private var authManager: AuthManager
    @State private var devices:    [DeviceInfo] = []
    @State private var isLoading   = false
    @State private var errorText   = ""

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && devices.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if devices.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "laptopcomputer.and.iphone")
                            .font(.system(size: 36, weight: .thin))
                            .foregroundStyle(.tertiary)
                        Text("No devices")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    List {
                        Section("Trusted devices") {
                            ForEach(devices) { device in
                                DeviceRowView(device: device, myId: authManager.deviceId) {
                                    removeDevice(device)
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Devices")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { Task { await loadDevices() } } label: {
                        if isLoading {
                            ProgressView().scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
            }
            .overlay(alignment: .bottom) {
                if !errorText.isEmpty {
                    Text(errorText)
                        .font(.callout)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.red.opacity(0.85))
                        .clipShape(Capsule())
                        .padding(.bottom, 20)
                }
            }
        }
        .task { await loadDevices() }
    }

    private func loadDevices() async {
        isLoading = true
        errorText = ""
        do {
            devices = try await APIClient.shared.listDevices()
        } catch {
            errorText = error.localizedDescription
        }
        isLoading = false
    }

    private func removeDevice(_ device: DeviceInfo) {
        Task {
            do {
                try await APIClient.shared.deleteDevice(id: device.id)
                devices.removeAll { $0.id == device.id }
            } catch {
                errorText = error.localizedDescription
            }
        }
    }
}

// MARK: - Row

private struct DeviceRowView: View {
    let device:   DeviceInfo
    let myId:     String?
    let onRemove: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(device.name)
                        .font(.body)
                    if device.id == myId {
                        Text("this device")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
                Text(device.id.prefix(12) + "…")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .monospaced()
            }

            Spacer()

            if let isOnline = device.isOnline {
                Circle()
                    .fill(isOnline ? Color(red: 0.35, green: 0.83, blue: 0.60) : Color.secondary.opacity(0.4))
                    .frame(width: 8, height: 8)
            }
        }
        .swipeActions(edge: .trailing) {
            if device.id != myId {
                Button(role: .destructive, action: onRemove) {
                    Label("Remove", systemImage: "trash")
                }
            }
        }
    }
}
