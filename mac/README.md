# Ring macOS Client

Native Swift menu-bar app for Ring. Requires macOS 14 (Sonoma) or later.

## Requirements

- Xcode 15 or later
- macOS 14+ SDK
- Apple Developer account (free tier is fine for local builds)

## Build & Run

1. Open `Ring.xcodeproj` in Xcode
2. Select the **Ring** scheme and your Mac as the run destination
3. In **Signing & Capabilities**, set your development team
4. Press **⌘R** to build and run

The app hides from the Dock (`LSUIElement = YES`). Look for the clipboard icon in the menu bar.

## Project Layout

```
mac/
  Ring/
    RingApp.swift          @main entry point + AppDelegate
    AppConfig.swift             Default server URL + constants
    MenuBar/
      StatusBarController.swift NSStatusItem + NSPopover management
    Views/
      PopoverView.swift         Clipboard history list (SwiftUI)
      SettingsView.swift        Account, devices, server URL (SwiftUI)
      OnboardingView.swift      Register/login + device approval flow
    Core/
      ClipboardMonitor.swift    NSPasteboard polling + loop prevention
      CryptoManager.swift       X25519 keypair + AES-GCM encrypt/decrypt
      SyncEngine.swift          WebSocket connection + catch-up flow
      LocalHistoryStore.swift   SwiftData model (ClipboardItem, cap 20)
      AuthManager.swift         Keychain token management
      APIClient.swift           REST calls (URLSession async/await)
    Resources/
      Info.plist
    Ring.entitlements
  Ring.xcodeproj/
```

## Security Properties

| Property | Implementation |
|---|---|
| E2E encryption | X25519 key agreement → HKDF-SHA256 → AES-GCM |
| Private key storage | Keychain (`kSecClassGenericPassword`, `AfterFirstUnlock`) |
| WebSocket auth | `Authorization: Bearer <device_token>` header only |
| Loop prevention | `remoteUpdateInProgress` flag + SHA-256 hash ring (last 10) |
| Tap-to-copy | Writes `NSPasteboard` directly; never sends to server |
| No plaintext logs | Decryption errors swallowed; no clipboard content logged |
| No sandbox | `com.apple.security.app-sandbox` is absent from entitlements |

## Server URL

Default: `https://api.ring.com`

To switch to a dev server, open **Settings** from the popover and update the Server URL field.

## Distribution

Build a Release archive in Xcode (**Product → Archive**) and export as a
"Developer ID" or "Direct Distribution" app. No App Store required.
