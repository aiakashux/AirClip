import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var authManager: AuthManager
    @EnvironmentObject private var syncEngine:  SyncEngine

    @State private var serverURL      = UserDefaults.standard.string(forKey: "serverURL") ?? AppConfig.defaultServerURL
    @State private var historyDays    = UserDefaults.standard.integer(forKey: "historyDays").nonZero ?? 30
    @State private var isSigningOut   = false
    @State private var showSignOutAlert = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Account") {
                    LabeledContent("Email",    value: authManager.accountEmail ?? "—")
                    LabeledContent("Device ID", value: (authManager.deviceId ?? "—").prefix(16) + "…")
                }

                Section("Sync") {
                    HStack {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(syncEngine.isConnected
                                ? Color(red: 0.35, green: 0.83, blue: 0.60)
                                : Color.secondary)
                        Text(syncEngine.isConnected ? "LAN sync active" : "No peers connected")
                            .foregroundStyle(.secondary)
                    }

                    Button(syncEngine.isConnected ? "Disconnect" : "Connect") {
                        if syncEngine.isConnected {
                            syncEngine.disconnect()
                        } else {
                            syncEngine.connect()
                        }
                    }
                }

                Section {
                    Picker("History retention", selection: $historyDays) {
                        Text("7 days").tag(7)
                        Text("30 days").tag(30)
                        Text("90 days").tag(90)
                    }
                    .onChange(of: historyDays) { _, days in
                        UserDefaults.standard.set(days, forKey: "historyDays")
                        LocalHistoryStore.shared.pruneToRetention(days: days)
                    }
                } header: {
                    Text("History")
                } footer: {
                    Text("Items older than this are pruned on next open.")
                }

                Section("Server") {
                    TextField("Server URL", text: $serverURL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .onSubmit {
                            UserDefaults.standard.set(serverURL, forKey: "serverURL")
                        }
                }

                Section {
                    Button(role: .destructive) {
                        showSignOutAlert = true
                    } label: {
                        HStack {
                            if isSigningOut { ProgressView().scaleEffect(0.8) }
                            Text("Sign Out")
                        }
                    }
                    .disabled(isSigningOut)
                }
            }
            .navigationTitle("Settings")
            .alert("Sign Out?", isPresented: $showSignOutAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Sign Out", role: .destructive) { signOut() }
            } message: {
                Text("Your clipboard history on this device will be cleared.")
            }
        }
    }

    private func signOut() {
        isSigningOut = true
        Task {
            await authManager.signOut()
            isSigningOut = false
        }
    }
}

private extension Int {
    var nonZero: Int? { self == 0 ? nil : self }
}
