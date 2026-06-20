# AirClip

AirClip is a LAN-first clipboard sync app for Mac and Android.

The current MVP pairs a Mac and Android phone, syncs clipboard content privately over the local network, and gives the user clear control over what is sent, stored, paused, or removed.

## Current MVP

Active direction:

1. Mac + Android sync over LAN.
2. Bonjour / Android NSD discovery with `_airclip._tcp`.
3. Local WebSocket transport on TCP `7878`.
4. Per-device encryption.
5. Local clipboard history on each device.
6. Global sync modes: Auto, Manual, Paused.
7. Sensitive clipboard policy: Block, Ask, Allow.
8. Device removal/re-pairing and presence diagnostics.

The backend relay and Redis catch-up model are legacy. They are not the active clipboard transport for the current MVP.

## What Works

Implemented or partially implemented:

1. Mac and Android pairing.
2. Bidirectional LAN clipboard sync.
3. Manual send and paused mode.
4. Sensitive clipboard protection.
5. Local history with saved clips.
6. Search, type filters, source labels, and relative time.
7. History backfill after peer authentication.
8. Heartbeat-based last-seen updates.
9. Runtime diagnostics for listener/discovery failures.

See [docs/ROADMAP_STATUS.md](docs/ROADMAP_STATUS.md) for the active implementation tracker and [docs/MANUAL_VALIDATION_QUEUE.md](docs/MANUAL_VALIDATION_QUEUE.md) for the manual test queue.

## Not In Current MVP

1. Default cloud relay.
2. Permanent cloud clipboard history.
3. Redis sequence-number catch-up.
4. Server-side pending device approval.
5. Windows support.
6. iOS support.

## Architecture

```text
Mac app
  ├─ Clipboard monitor
  ├─ Local history
  ├─ Bonjour advertise/browse
  └─ LAN WebSocket peer
          │ encrypted clipboard packets
          ▼
Android app
  ├─ Foreground sync service
  ├─ Local history
  ├─ Android NSD advertise/discover
  └─ LAN WebSocket peer
```

The backend source remains in the repo, but treat it as legacy/future optional infrastructure unless a new product decision reactivates it.

## Project Structure

```text
AirClip/
  android/                 Android app
  mac/                     macOS app
  backend/                 Legacy backend source
  docs/
    PRODUCT_REQUIREMENTS.md
    ROADMAP_STATUS.md
    MANUAL_VALIDATION_QUEUE.md
    VALIDATION_CHECKLIST.md
    architecture.md
    mvp-scope.md
    protocol.md
```

## Build

### Android

```bash
cd android
JAVA_HOME='/Applications/Android Studio.app/Contents/jbr/Contents/Home' ./gradlew testDebugUnitTest
```

Open `android/` in Android Studio to build and install the app.

### macOS

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

Open `mac/AirClip.xcodeproj` in Xcode for local development.

## Documentation

Start here:

1. [Product requirements](docs/PRODUCT_REQUIREMENTS.md)
2. [Roadmap status](docs/ROADMAP_STATUS.md)
3. [Manual validation queue](docs/MANUAL_VALIDATION_QUEUE.md)
4. [Architecture](docs/architecture.md)
5. [Protocol](docs/protocol.md)
6. [MVP scope](docs/mvp-scope.md)
