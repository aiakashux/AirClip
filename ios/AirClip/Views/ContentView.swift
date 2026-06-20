import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var authManager: AuthManager
    @EnvironmentObject private var syncEngine:  SyncEngine

    var body: some View {
        TabView {
            ClipboardHistoryView()
                .tabItem {
                    Label("History", systemImage: "doc.on.clipboard")
                }

            DevicesView()
                .tabItem {
                    Label("Devices", systemImage: "laptopcomputer.and.iphone")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}
