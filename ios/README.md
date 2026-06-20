# AirClip — iOS

## Xcode Project Setup

The Swift source files are complete. Create the Xcode project to wire them together.

### 1. New Project

File → New → Project → iOS → App
- Product Name: `AirClip`
- Bundle ID: `com.airclip.airclip`
- Interface: SwiftUI
- Language: Swift
- Minimum Deployment: iOS 17.0

Delete the generated `ContentView.swift` and `AirClipApp.swift` (the source tree has the real ones).

### 2. Add Source Files

Drag the entire `ios/AirClip/` folder into the project navigator. When prompted, add to the `AirClip` target.

### 3. Add Swift Package: swift-sodium

File → Add Packages → `https://github.com/jedisct1/swift-sodium`
- Add to the `AirClip` target only (not extensions).

### 4. Add Widget Extension Target

File → New → Target → Widget Extension
- Product Name: `AirClipWidget`
- Include Configuration Intent: NO (we use AppIntent instead)

In the widget target:
- Add `ios/AirClip/Widget/AirClipWidget.swift`, `AirClipWidgetBundle.swift`, `WidgetSharedState.swift`, `AppIntents.swift` to this target
- Also add `ios/AirClip/AppConfig.swift` to this target

Add the App Group entitlement to the widget target:
- Signing & Capabilities → + Capability → App Groups → `group.com.airclip.airclip`

### 5. Add Share Extension Target

File → New → Target → Share Extension
- Product Name: `AirClipShare`

In the share extension target:
- Replace the generated `ShareViewController.swift` with `ios/AirClip/ShareExtension/ShareViewController.swift`
- Replace the generated `Info.plist` with `ios/AirClip/ShareExtension/Info.plist`
- Add `ios/AirClip/AppConfig.swift` to this target

### 6. Main App Entitlements

Signing & Capabilities → + Capability → App Groups → `group.com.airclip.airclip`

Set `AirClip.entitlements` as the entitlements file for the AirClip target.

### 7. Info.plist Keys

Copy the keys from `ios/AirClip/Resources/Info.plist` into the main app's Info.plist (or set as the Info.plist source).

Key keys:
- `NSLocalNetworkUsageDescription` — required for local network permission dialog
- `NSBonjourServices` → `_airclip._tcp` — required for NWBrowser
- `BGTaskSchedulerPermittedIdentifiers` → `com.airclip.airclip.refresh`
- `UIBackgroundModes` → `fetch`
- `CFBundleURLTypes` → scheme `AirClip` (for widget + share extension deep links)

### 8. SwiftData Model Container

In `ContentView.swift`, the `@Query` macro and `modelContainer` modifier require the SwiftData container to be in the environment. `LocalHistoryStore.shared.container` provides it.

Add `.modelContainer(LocalHistoryStore.shared.container)` at the `WindowGroup` level in `AirClipApp.swift` if needed.

## Architecture

```
AirClip (main app)
├── Core/               — LAN sync + auth + crypto (mirrors Mac app exactly)
│   ├── LanServer.swift     NWListener on port 7878, advertises _airclip._tcp
│   ├── LanBrowser.swift    NWBrowser discovers peers, hands off to PeerManager
│   ├── PeerConnection.swift WebSocket handshake + clip relay
│   ├── PeerManager.swift   Owns authenticated peers, deduplicates, broadcasts
│   ├── SyncEngine.swift    Orchestrator — connect/disconnect/send/receive
│   ├── CryptoManager.swift NaCl sealed-box via swift-sodium (identical to Mac)
│   ├── AuthManager.swift   Keychain tokens, login, device registration
│   ├── APIClient.swift     REST client for auth + device registry
│   └── LocalHistoryStore.swift SwiftData clipboard history
├── Views/              — SwiftUI tabs
│   ├── ContentView.swift   TabView (History / Devices / Settings)
│   ├── ClipboardHistoryView.swift
│   ├── DevicesView.swift
│   ├── LoginView.swift
│   └── SettingsView.swift
├── Widget/             — WidgetKit + AppIntent (iOS 17+)
│   ├── AirClipWidget.swift    4-state timeline widget (.systemMedium)
│   ├── AirClipWidgetBundle.swift
│   ├── WidgetSharedState.swift  App Group UserDefaults bridge
│   └── AppIntents.swift    PasteClipIntent + SendClipIntent
└── ShareExtension/     — Share Sheet integration
    ├── ShareViewController.swift  Queues text → opens airclip://send
    └── Info.plist

```

## Key Design Decisions

| Decision | Reason |
|----------|--------|
| No clipboard monitoring | iOS bans background clipboard reads; user initiates sends explicitly |
| UIPasteboard writes allowed from background | Only reads are restricted; inbound clips write to pasteboard fine |
| App Group for widget state | WidgetKit runs in a separate process; can't talk to main app directly |
| SendClipIntent opens main app | Reading clipboard in an AppIntent is unreliable; main app does the actual read+encrypt |
| BGAppRefreshTask for background refresh | Keeps device cache fresh; LAN server resumes on foreground |
| NWListener + NWBrowser | Same Network.framework primitives as Mac; protocol-compatible |
