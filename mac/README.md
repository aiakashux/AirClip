# AirClip macOS App

Native SwiftUI macOS app for AirClip.

The current macOS app is part of the LAN-first Mac + Android MVP. It advertises and discovers `_airclip._tcp` peers, listens on TCP `7878`, encrypts clipboard packets for paired devices, and stores local history with SwiftData.

## Requirements

1. Xcode 15 or later.
2. macOS SDK compatible with the project.
3. Local signing team when running from Xcode.

## Build

From the repository root:

```bash
xcodebuild \
  -project mac/AirClip.xcodeproj \
  -scheme AirClip \
  -configuration Debug \
  -destination 'platform=macOS' \
  -disableAutomaticPackageResolution \
  -onlyUsePackageVersionsFromResolvedFile \
  CODE_SIGNING_ALLOWED=NO \
  build
```

For interactive development, open `mac/AirClip.xcodeproj` and run the `AirClip` scheme.

## Current Responsibilities

1. Pair with Android using QR/code flows.
2. Monitor `NSPasteboard`.
3. Apply sync mode and sensitive clipboard policies.
4. Encrypt and send clipboard packets to paired LAN peers.
5. Receive and decrypt live clipboard packets.
6. Merge history backfill without changing the active clipboard.
7. Store local history in SwiftData.
8. Show devices, settings, history, saved clips, and diagnostics.

## Important Files

```text
mac/AirClip/
  AirClipApp.swift
  AppConfig.swift
  Core/
    AirClipIdentity.swift
    ClipboardMonitor.swift
    CryptoManager.swift
    LanBrowser.swift
    LanServer.swift
    LocalHistoryStore.swift
    PeerConnection.swift
    PeerManager.swift
    SensitiveClipboardPolicy.swift
    SensitiveClipboardProtectionStore.swift
    SyncEngine.swift
    SyncModeStore.swift
  MenuBar/
    StatusBarController.swift
  Views/
    ClipTypeDetector.swift
    MainWindowView.swift
    OnboardingView.swift
    PopoverView.swift
    SettingsView.swift
```

## Notes

The previous README described account auth, backend WebSocket connection, and server catch-up. That is legacy for the current MVP. The active transport is LAN peer-to-peer with local pairing state.
