# AirClip Development Setup

This guide describes the current AirClip MVP: native macOS plus Android clipboard sync over the local network.

The older backend, Redis, and Electron relay setup is legacy. The backend source remains in the repo for historical or future optional work, but it is not required for the active LAN-first clipboard flow.

## Active MVP

AirClip currently focuses on:

1. Pairing one Mac and one Android device.
2. Discovering paired devices on the same Wi-Fi network.
3. Exchanging clipboard packets over LAN WebSocket connections on TCP `7878`.
4. Encrypting clipboard payloads before network transfer.
5. Supporting Auto, Manual, and Paused sync modes.
6. Blocking or confirming sensitive clipboard content before send.
7. Keeping local history on each device.
8. Backfilling recent local history after peer authentication.

## Prerequisites

Install:

1. Xcode with macOS development tools.
2. Android Studio.
3. Android SDK and platform tools.
4. JDK bundled with Android Studio or another compatible JDK.
5. A Mac and Android device on the same Wi-Fi network for full manual validation.

Recommended physical-device setup:

1. Disable VPNs that isolate local network traffic.
2. Avoid guest Wi-Fi networks that block peer discovery.
3. Keep both devices awake during pairing and reconnect tests.
4. Allow Local Network permission on macOS when prompted.
5. Allow the Android foreground service and notification permission when prompted.

## Repository Layout

```text
AirClip
├── mac/          Native macOS app
├── android/      Native Android app
├── backend/      Legacy backend source, not active clipboard transport
├── docs/         Product, validation, protocol, and roadmap docs
└── scripts/      Utility scripts
```

## macOS Build

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

Expected result:

```text
** BUILD SUCCEEDED **
```

Known warning class:

1. Some AppKit menu APIs may emit deprecation warnings.
2. Existing peer-connection diagnostics may emit warnings while the runtime is being hardened.

## Run macOS App

Use Xcode:

1. Open `mac/AirClip.xcodeproj`.
2. Select the `AirClip` scheme.
3. Run on `My Mac`.

Or run the built app from Xcode's derived data output after a successful build.

When running for the first time, approve Local Network access if macOS prompts for it. Without that permission, peer discovery and incoming LAN connections may fail.

## Android Unit Tests

From `android/`:

```bash
JAVA_HOME='/Applications/Android Studio.app/Contents/jbr/Contents/Home' ./gradlew testDebugUnitTest
```

Expected result:

```text
BUILD SUCCESSFUL
```

Known warning class:

1. Deprecated NSD callback APIs may warn on the current Android implementation.
2. Compose icon deprecation warnings may appear for older outlined icons.
3. A small number of nonce parameters may be reported as unused in crypto plumbing.

## Run Android App

Use Android Studio:

1. Open the `android/` folder.
2. Let Gradle sync finish.
3. Select a physical Android device or emulator.
4. Run the debug app.

Physical device testing is strongly preferred because LAN discovery, foreground service behavior, clipboard access, and battery restrictions are more realistic than on an emulator.

## Pairing Flow

Use the in-app pairing UI:

1. Start AirClip on macOS.
2. Start AirClip on Android.
3. Put both devices on the same Wi-Fi network.
4. Use QR or code pairing.
5. Confirm that both devices show the peer in the Devices view.
6. Wait for the LAN status to move from paired to connected.

Pairing stores local device identity and trusted peer metadata on each device. There is no active account login or cloud approval flow in the LAN-first MVP.

## Runtime Flow

After pairing:

1. Each device advertises `_airclip._tcp` on the local network.
2. Each device listens for WebSocket peers on TCP `7878`.
3. Peers authenticate with local identity metadata.
4. Unknown or removed devices are rejected.
5. Clipboard packets are encrypted and sent to authenticated peers.
6. Peers exchange heartbeat messages to refresh last-seen presence.
7. Recent history records may be backfilled after authentication.

## Sync Modes

Auto:

1. Clipboard changes are captured automatically.
2. Allowed content is sent to connected peers.
3. Sensitive content follows the configured policy.

Manual:

1. Clipboard changes are not sent automatically.
2. Explicit send actions still work.
3. Sensitive content still follows the configured policy.

Paused:

1. LAN runtime is stopped.
2. Listener, advertisement, browser, and active peers are torn down.
3. No automatic or manual sends should leave the device.

## Local History

History is local to each device.

Current behavior:

1. Text, links, and images can be recorded locally.
2. Saved clips are protected from normal retention pruning.
3. Search matches clip text, type, and source device label.
4. Filters support All, Text, Links, and Images.
5. History backfill merges peer history without writing to the active clipboard.

## Sensitive Clipboard Protection

Sensitive checks run locally before sending.

Covered examples include:

1. Password-like strings.
2. API keys and tokens.
3. Private keys.
4. Recovery phrases.
5. Payment cards.
6. One-time codes.

Each category can be configured as:

1. Block.
2. Ask.
3. Allow.

Block rejects automatic and explicit sends. Ask blocks automatic sends and requires confirmation for explicit sends. Allow permits sending for that category.

## Manual Validation Queue

Use `docs/MANUAL_VALIDATION_QUEUE.md` for the current user-facing manual test list.

The highest-value validation passes are:

1. Fresh pairing from reset state.
2. Auto and Manual text transfer both directions.
3. Paused mode teardown.
4. Sensitive Block, Ask, and Allow behavior.
5. Remove device and verify reconnect rejection.
6. Re-pair after removal.
7. History search, filters, save, delete, clear, retention, and restart persistence.
8. Reconnect backfill without overwriting the active clipboard.
9. Wi-Fi disconnect and reconnect recovery.
10. Duplicate suppression after send, receive, tap-to-copy, and backfill.

## Troubleshooting

### Devices do not see each other

Check:

1. Both devices are on the same Wi-Fi network.
2. The network allows local peer discovery.
3. VPN is disabled or configured to allow LAN access.
4. macOS Local Network permission is granted.
5. Android foreground service is running.
6. AirClip is not in Paused mode.

### Devices are paired but not connected

Check:

1. TCP port `7878` is not already occupied.
2. Firewall rules allow local inbound connections.
3. Android battery restrictions have not stopped the foreground service.
4. The Devices screen diagnostic message for listener, advertisement, or discovery errors.

### Android listener reports address already in use

The LAN server startup path is intended to be idempotent. If this warning appears during forced restart testing:

1. Stop the Android foreground service.
2. Relaunch the app.
3. Toggle Paused on and off.
4. Re-run the restart cycle and record whether the warning returns.

This remains part of the manual validation queue.

### Clipboard does not sync

Check:

1. Current sync mode.
2. Sensitive policy for the copied content.
3. Whether the peer is connected in Devices.
4. Whether the item already exists and duplicate suppression skipped it.
5. Whether clipboard permissions are restricted by the OS.

### History item tap causes an echo

History tap-to-copy should suppress the immediate local clipboard echo. If an item duplicates after tapping:

1. Record which platform was tapped.
2. Record whether the item was text, link, or image.
3. Record whether the duplicate arrived through live sync or reconnect backfill.

## Backend Status

The backend is not needed to build, run, pair, or sync the current MVP.

Current backend status:

1. Source remains in `backend/`.
2. Backend tests now cover the current minimal account/device bootstrap and heartbeat WebSocket behavior.
3. Backend auth/account/device bootstrap is legacy or future optional infrastructure, not active clipboard transport.
4. Do not treat backend relay docs, old specs, or old plans as current AirClip behavior.

If cloud relay returns later, it should be explicitly opt-in, encrypted end to end, sensitive-policy aware, and clearly distinct from the LAN-first flow.
