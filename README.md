# AirClip

**Clipboard sync between your Mac and Android — private, local, encrypted.**

AirClip copies whatever you copy on one device and pastes it on the other. No cloud. No account. Works on your local Wi-Fi network using end-to-end encryption.

---

## What It Does

- Copy on Mac → paste on Android (and vice versa)
- Syncs text, links, and clipboard content automatically or on demand
- Keeps a local history of your recent clips on each device
- Blocks sensitive content (passwords, OTPs) from syncing — your rules
- Pairs devices once via QR code, then works silently in the background

## How It Works

AirClip discovers devices on the same Wi-Fi network using Bonjour (Mac) and NSD (Android). Clipboard packets are encrypted with NaCl sealed boxes before leaving the device. Nothing touches a server.

```
Mac app                          Android app
  ├─ Clipboard monitor             ├─ Foreground sync service
  ├─ Bonjour advertise/browse      ├─ Android NSD advertise/discover
  ├─ LAN WebSocket peer ◄────────► ├─ LAN WebSocket peer
  ├─ Local history                 ├─ Local history
  └─ Menu bar UI                   └─ Jetpack Compose UI
```

Transport: WebSocket over TCP `7878` · Discovery: `_airclip._tcp` · Encryption: NaCl sealed box

---

## Platforms

| Platform | Status |
|----------|--------|
| macOS (menu bar app) | ✅ Active |
| Android | ✅ Active |
| iOS | 🔜 Planned |
| Windows | 🔜 Planned |

---

## Project Structure

```
AirClip/
  android/      Android app (Kotlin + Jetpack Compose)
  mac/          macOS app (Swift + SwiftUI)
  backend/      Legacy relay (not used in current MVP)
  docs/         Architecture, protocol, product requirements
  scripts/      Dev utilities
```

---

## Build

### Android

Open `android/` in Android Studio, or run tests via:

```bash
cd android
JAVA_HOME='/Applications/Android Studio.app/Contents/jbr/Contents/Home' \
  ./gradlew testDebugUnitTest
```

### macOS

Open `mac/AirClip.xcodeproj` in Xcode, or build from terminal:

```bash
xcodebuild \
  -project mac/AirClip.xcodeproj \
  -scheme AirClip \
  -configuration Debug \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

---

## Sync Modes

| Mode | Behavior |
|------|----------|
| Auto | Every clipboard change syncs instantly |
| Manual | You tap/click to send |
| Paused | Nothing syncs until resumed |

## Sensitive Clipboard Policy

Detects passwords, OTPs, and credit card numbers. Per-device policy: **Block**, **Ask**, or **Allow**.

---

## Docs

- [Architecture](docs/architecture.md)
- [Protocol](docs/protocol.md)
- [Product Requirements](docs/PRODUCT_REQUIREMENTS.md)
- [Roadmap Status](docs/ROADMAP_STATUS.md)
- [Security](SECURITY.md)
- [Contributing](CONTRIBUTING.md)
