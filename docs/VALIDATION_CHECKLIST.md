# AirClip Current Feature Validation Checklist

Created: 2026-06-08

## Purpose

This document is the Phase 0 validation tracker. Use it before building new features.

Goal:

> Prove what currently works in the Mac + Android LAN-first app, identify blockers, and avoid building on stale assumptions.

## Current Validation Run

Date: 2026-06-13

Environment checks from this machine:

| Check | Result | Evidence / next action |
|---|---:|---|
| Xcode installed | Pass | `xcodebuild -version` reports Xcode 26.5 build 17F42. |
| Mac package/project metadata | Pass with pinned resolution | Automatic package refresh hangs while fetching `swift-sodium`, but the checkout already matches `Package.resolved` at 0.10.0. `xcodebuild -list ... -disableAutomaticPackageResolution -onlyUsePackageVersionsFromResolvedFile` succeeds. |
| Mac Debug build | Pass | `xcodebuild -project mac/AirClip.xcodeproj -scheme AirClip -configuration Debug -destination 'platform=macOS' -disableAutomaticPackageResolution -onlyUsePackageVersionsFromResolvedFile CODE_SIGNING_ALLOWED=NO build` completed with `BUILD SUCCEEDED`. |
| Mac launch | Pass | Debug `AirClip.app` launches and remains running. Fresh state has no `com.airclip.airclip` identity defaults, so LAN port 7878 is correctly not listening before onboarding is completed. |
| Mac visual automation | Partial | Screen capture and synthetic pointer events work, but Accessibility inspection is unavailable. The Manual send runtime action was invoked in the live Debug app through LLDB after proving automatic capture was suppressed. |
| Android Gradle build | Pass | `JAVA_HOME='/Applications/Android Studio.app/Contents/jbr/Contents/Home' ./gradlew assembleDebug` succeeded. APK: `android/app/build/outputs/apk/debug/app-debug.apk` (19 MB). |
| Android device install | Pass | Debug APK installed successfully over wireless ADB on a OnePlus 6 (`ONEPLUS A6000`) running Android 11 / API 30. |
| Android launch/runtime | Pass with findings | App launches, renders all three primary tabs, starts `SyncService`, advertises `_airclip._tcp`, and listens on TCP 7878. No app crash was observed. |
| Global sync mode hardening | Pass | Android rejects foreground-service startup while unpaired or Paused, uses an idempotent runtime lifecycle gate, keeps one peer observer, and initializes widget cold-start sends in identity -> keys -> engine -> runtime -> peer order. |
| Mac sync mode restart cycles | Pass | Five persisted Paused -> Manual restart cycles completed. Every Paused launch had `0` AirClip listeners on port 7878; every Manual launch had exactly `1`. The original unset preference was restored and correctly resolved to Manual with one listener. |
| Paired sync mode validation | Pass | Paired Mac `192.168.0.164` and OnePlus 6 `192.168.0.77` completed bidirectional Auto and Manual transfers, full Paused teardown, restart persistence, echo suppression, and five transfer-bearing pause/resume cycles. |
| Sensitive-content implementation | Complete | Android and macOS classifiers, Block/Ask/Allow policy, persisted per-category controls, automatic-send guards, manual confirmation, widget handling, and transport fallback checks passed automated and paired physical-device validation on 2026-06-14. |
| Android emulator | Environment repaired | Existing Pixel 6a AVD was broken because its Android 36 system image lacked `system.img`. Android command-line tools were installed and the 2.3 GB system image was reinstalled. Physical-device validation was used instead. |
| Backend pytest | Pass after stale test retirement | Rewrote the obsolete Redis presence and relay WebSocket tests around the current SQLite account/device bootstrap and heartbeat WebSocket behavior. `backend/.venv/bin/python -m pytest -q backend/tests` now reports `12 passed`. |
| Physical device validation | Partial pass | Build, install, launch, foreground service, LAN listener, mDNS advertisement, and primary screens were validated. Cross-device pairing/sync still requires a paired Mac identity. |
| Android pairing repair | Pass for current identities | Android paired with the retained Mac identity and persisted the relationship across restart. No destructive reset was used. |
| Mac -> Android image sync | Pass on physical OnePlus 6 | Received PNG matched the Mac source byte-for-byte (1,041,734 bytes, identical SHA-256). Android preserves encrypted image data, persists it, renders list/detail previews, and copies it as an image URI. Decoder regression coverage passes. |

## Current Feature Inventory

Status meanings:

- `Source exists`: code paths are present, but behavior is not proven.
- `Manual validation needed`: requires running the app/device flow.
- `Blocked`: cannot be checked until environment or device setup is fixed.
- `Missing / unclear`: no clear complete implementation found yet.

| Feature | Current status | Evidence / files |
|---|---|---|
| macOS native app | Builds and launches, manual UI validation needed | `mac/AirClip.xcodeproj`, `mac/AirClip/AirClipApp.swift`; use pinned package-resolution flags. |
| macOS menu bar behavior | Source exists, manual validation needed | `LSUIElement` in `mac/AirClip/Resources/Info.plist`; `StatusBarController.swift`. |
| macOS local network permission | Source exists, manual validation needed | `NSLocalNetworkUsageDescription`, `_airclip._tcp` in `Info.plist`. |
| macOS clipboard monitoring | Source exists, manual validation needed | `mac/AirClip/Core/ClipboardMonitor.swift`. |
| macOS LAN server/browser | Source exists, manual validation needed | `LanServer.swift`, `LanBrowser.swift`, `PeerManager.swift`, `PeerConnection.swift`. |
| macOS local history | Source exists, manual validation needed | SwiftData `LocalHistoryStore.swift`. |
| macOS saved clips | Source exists, manual validation needed | `ClipboardItem.isSaved`, save actions in `MainWindowView.swift`. |
| macOS delete clip | Source exists, manual validation needed | `delete(_ item:)` in `MainWindowView.swift`. |
| macOS retention setting | Source exists, manual validation needed | `pruneToRetention(days:)` in `LocalHistoryStore.swift`; settings call in `MainWindowView.swift`. |
| macOS device removal | Source exists, manual validation needed | `AirClipIdentity.removeDevice`, remove UI in `MainWindowView.swift`. |
| Android app | Builds, manual validation needed | `android/app/src/main/java/com/airclip/airclip`; debug APK built successfully. |
| Android foreground sync service | Builds, manual validation needed | `SyncService`; manifest foreground service declarations. |
| Android LAN server/browser | Builds, manual validation needed | `lan/LanServer.kt`, `lan/LanBrowser.kt`, `lan/PeerManager.kt`. |
| Android widget | Builds, manual validation needed | `widget/AirClipWidget.kt`, `WidgetState.kt`, `ClipboardSendActivity.kt`. |
| Android manual send | Builds, manual validation needed | Widget send launches `ClipboardSendActivity`. |
| Android receive/paste widget state | Builds, manual validation needed | Widget `PENDING` state and paste action in `AirClipWidget.kt`. |
| Android local history | Builds, manual validation needed | `ClipHistoryStore.kt`; `ClipboardScreen.kt`. |
| Android saved clips | Builds, manual validation needed | `ClipHistoryStore.setSaved`, UI save actions. |
| Android delete clip | Builds, manual validation needed | `MainViewModel.onDeleteClip`, `ClipHistoryStore.delete` path should be verified. |
| Android device removal | Builds, manual validation needed | `AirClipIdentity.removeDevice`, `MainViewModel.onRemoveDevice`. |
| Sensitive clipboard blocking | Complete | Local classifiers cover password-like strings, common API/token formats, private-key headers, labeled and known-word recovery phrases, Luhn-valid payment cards, and contextual OTPs. Per-category Block/Ask/Allow controls persist, paired auto/manual behavior passed, and widget sends use the same policy. |
| Global sync modes | Complete | Auto, Manual, and Paused policies passed paired bidirectional validation. Paused removes listeners, discovery, advertisements, peers, Android service, and active notification. Restart persistence, echo suppression, and five duplicate-free pause/resume cycles passed. |
| Windows support | Missing | No Windows client present. |
| iOS production app | Source-only / future | `ios/README.md` says Xcode project setup is manual. |

## Build Validation Tasks

### Mac

Command-line build:

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

Then:

1. Run the Debug app.
2. Confirm AirClip appears in the menu bar and not the Dock.
3. Complete create/join AirClip onboarding.
4. Confirm Local Network permission appears when LAN sync starts.
5. Confirm TCP port 7878 listens after pairing.

Pass criteria:

- Debug build succeeds.
- App launches without crash.
- Menu bar icon appears.
- Main window/popover opens.
- No repeated permission or startup errors.

Current result:

- Debug build passes.
- App launches and stays running.
- Fresh identity state is detected; sync correctly does not start before onboarding.
- Visual onboarding confirmation is still manual because Accessibility and Screen Recording automation permissions are unavailable.

### Android

1. Use Android Studio's bundled JBR:
   `JAVA_HOME='/Applications/Android Studio.app/Contents/jbr/Contents/Home'`
2. Run `cd android && ./gradlew assembleDebug`.
3. Install on a physical Android device.
4. Grant any required notification/local-network related permissions.
5. Add the AirClip widget to the home screen.

Pass criteria:

- Debug APK builds.
- App launches.
- Foreground sync service starts.
- Widget renders all expected states.
- No crash during pairing or sync startup.

Current result:

- Build passes with Android Studio's bundled JBR.
- APK path: `android/app/build/outputs/apk/debug/app-debug.apk`.
- APK installs and runs on a OnePlus 6 with Android 11.
- `SyncService` runs as a foreground service.
- Android listens on TCP 7878 and advertises `_airclip._tcp`.
- No fatal exception or process crash was observed.

### Backend

Backend is legacy or future optional infrastructure for the LAN-first direction. It is not active clipboard transport.

1. Run `cd backend && .venv/bin/python -m pytest -q backend/tests`.
2. Run `python scripts/integration_test.py` only if backend bootstrap is intentionally reactivated.
3. Run `python scripts/crypto_e2e_test.py` only if backend bootstrap is intentionally reactivated.

Pass criteria:

- Backend tests pass for the code that remains.
- Backend role is documented as legacy or future optional infrastructure.

Current result:

- Test runner works after installing dev dependencies plus `pynacl`.
- Stale Redis presence and relay WebSocket tests were retired or rewritten.
- Current backend test suite passes: `12 passed`.

## Manual End-to-End Validation

Use a Mac and physical Android phone on the same Wi-Fi.

### Global Sync Mode Validation Run — 2026-06-13

Environment:

- Mac: Debug `AirClip.app`, device `My Mac`, `192.168.0.164`.
- Android: OnePlus 6 (`ONEPLUS_A6000`), Android 11 / API 30, `192.168.0.77`.
- Pairing: retained Mac identity paired to the existing Android identity; neither identity was reset.
- Transport: TCP 7878 and `_airclip._tcp` on the same Wi-Fi.
- Target: transfers observed within the five-second sampling window; no payload missed the two-second product target during direct observation.

Implementation finding:

- macOS sends a serialized `ClipboardPacket`; Android had been storing that JSON envelope as clipboard text.
- `ClipboardWirePayload` now decodes packet text/kind while preserving ordinary JSON clipboard content.
- The first cycle audit found a delayed duplicate after reconnect because live delivery and history reconciliation used different message IDs. Android now uses a stable plaintext hash plus source and a two-second reconciliation window. A fresh five-cycle run plus an extra reconnect produced no duplicates.

Paired mode evidence:

| Check | Payload / evidence | Result |
|---|---|---:|
| Mac Auto -> Android | `AC_AUTO_M2A_FIXED_20260613_2314`; exact text shown from `My Mac` | Pass |
| Android Auto -> Mac | `AC_AUTO_A2M_2323`; exact value returned by `pbpaste` | Pass |
| Android Manual blocks capture | Staged clipboard produced no Mac change and no send log | Pass |
| Android Manual explicit send | `MANUAL_SEND_2325`; exact value received by Mac | Pass |
| Mac Manual blocks capture | `AC_MAC_MANUAL_233236`; Android history count remained `0` before explicit action | Pass |
| Mac Manual explicit send | Live app `SyncModeStore.sendCurrentClipboard()` action; Android history count changed to `1` | Pass |
| Both Auto echo suppression | `AC_ECHO_M2A_232817`; one inbound history record and no Android resend | Pass |
| Instrumented LAN timing | `AC_TIMING_234855`; Android DataStore observed the clip 737 ms after `pbcopy` | Pass |

Paused runtime evidence:

```text
Android: no SyncService, no active notification, no TCP 7878 listener,
no _airclip._tcp advertisement, discovery stopped, peer count zero.
Mac: no TCP 7878 listener, no Bonjour advertisement, browser stopped,
peer count zero.
Both apps restored the same Paused runtime state after cold restart.
```

Pause/resume duplicate run:

```text
AC_R2CYCLE_1_234631 final history count: 1
AC_R2CYCLE_2_234651 final history count: 1
AC_R2CYCLE_3_234711 final history count: 1
AC_R2CYCLE_4_234732 final history count: 1
AC_R2CYCLE_5_234752 final history count: 1

Every paused phase: Android service 0, Android listener 0, Mac listener 0.
Every resumed phase: Android service 1, Android listener 1, Mac listener 1.
An additional reconnect after cycle 5 still left every payload at count 1.
```

Outcome:

- Global Sync Modes became the first completed roadmap feature.
- Sensitive Clipboard Protection became the next validation target and was
  subsequently completed on 2026-06-14.

### Sensitive Clipboard Protection Validation Run — 2026-06-14

Implemented:

- Local-only classifiers on Android and macOS; clipboard plaintext is not sent to a backend for classification.
- Categories: passwords, API keys/tokens, private keys, recovery phrases, payment cards, and one-time codes.
- Per-category persisted actions: `Block`, `Ask`, and `Allow`. Missing or invalid values resolve to `Ask`.
- `Ask` blocks automatic transfer and requires confirmation for an explicit send.
- `Block` rejects automatic and explicit sends.
- `Allow` permits both automatic and explicit sends for that category.
- Android main-app and widget send paths require policy approval before transport.
- macOS automatic capture, main-window send, and menu-bar send paths require policy approval before transport.
- Transport-level fallback guards reject sensitive sends that bypass the normal UI policy path.
- Prompt state exposes only category/reason metadata; pending clipboard plaintext remains in memory and is not logged.

Automated evidence:

| Check | Command / evidence | Result |
|---|---|---:|
| Android policy tests | `JAVA_HOME='/Applications/Android Studio.app/Contents/jbr/Contents/Home' ./gradlew testDebugUnitTest` | Pass |
| Android Debug APK | Same Gradle run with `assembleDebug`; output `android/app/build/outputs/apk/debug/app-debug.apk` | Pass |
| macOS policy check | `swiftc -parse-as-library mac/AirClip/Core/SensitiveClipboardPolicy.swift mac/Tests/SensitiveClipboardPolicyCheck.swift ...` | Pass |
| macOS Debug build | `xcodebuild -project mac/AirClip.xcodeproj -scheme AirClip -configuration Debug -derivedDataPath /tmp/AirClipDerivedData build CODE_SIGNING_ALLOWED=NO` | Pass |
| Known sensitive fixtures | OpenAI-style token, private-key header, labeled and unlabeled recovery phrase, labeled Luhn-valid card, contextual password/OTP, high-entropy password | Pass |
| Safe fixtures | Normal URL containing `token=`, ordinary prose, UUID, phone number, 12-word normal sentence | Pass |
| Rule behavior | Block rejects explicit send; Ask blocks auto and confirms explicit send; Allow permits auto | Pass |

Paired physical validation:

- Initial `adb devices -l` returned no connected devices on 2026-06-14.
- Resume attempt at 01:15 Asia/Dhaka confirmed the OnePlus responds at
  `192.168.0.77`, TCP `7878` is open, and Bonjour advertises Android instance
  `69a458da-909d-47e8-a075-f725f949d415`.
- Direct `adb connect 192.168.0.77:5555` returned `Connection refused`; USB
  debugging or Android wireless debugging must be enabled before installing the
  new APK.
- At 01:18, `_adb-tls-connect._tcp` resolved the OnePlus 6 at
  `192.168.0.77:38025`. Restarting the ADB daemon connected successfully as
  `ONEPLUS_A6000`, and `adb install -r` upgraded the app without clearing its
  identity, pairings, history, or Manual sync preference.
- The newly built Mac app was launched from
  `/tmp/AirClipDerivedData/Build/Products/Debug/AirClip.app` with the retained
  identity. It was restored to Manual mode and has exactly one TCP `7878`
  listener.
- Mac Auto -> Android safe controls transferred twice while the authenticated
  peer was live. Android logged only the two 14-byte controls.
- Mac Auto -> Android sensitive matrix passed: password (27 bytes), API token
  (40 bytes), private key (60 bytes), recovery phrase (84 bytes), payment card
  (25 bytes), and OTP (32 bytes) produced no Android inbound event.
- The token-shaped validation value was absent from Android logcat plaintext.
- Android Manual safe control `ANDROID_MANUAL_CONTROL_055903` transferred to
  the Mac exactly.
- Android `Ask` showed the local confirmation dialog with category-only text.
  Cancel left the Mac clipboard at its baseline. A fresh confirmed token
  transferred exactly and Android logged one `Clip sent` event to one peer.
- During the settings portion, the OnePlus dropped off Wi-Fi entirely:
  `192.168.0.170` stopped answering ping and TCP `7878`, and both
  `_adb-tls-connect._tcp` and `_airclip._tcp` advertisements disappeared.
- Android API-token `Block` persisted as `ALWAYS_BLOCK`; a valid GitHub-token
  shape produced no prompt, no send log, and no Mac clipboard change.
- Android API-token `Allow` transferred a valid token directly with no prompt
  and one send event. The `ALLOW` value survived a cold app restart.
- Android Auto transferred `ANDROID_AUTO_SAFE_063614` and suppressed a valid
  API token, leaving the Mac clipboard at the safe control.
- Widget safe send initially exposed a lifecycle defect: the transparent
  activity read the clipboard in `onCreate`, before Android granted foreground
  clipboard access. `ClipboardSendActivity` now reads once after window focus.
- After the fix, widget safe send transferred once. Widget sensitive `Ask`
  showed the native category-only dialog; cancel sent nothing and confirm sent
  the exact token once.
- Android policy preferences were restored to Manual and `Ask` after restart.
  macOS was restored to Manual and `Ask`.
- The disposable validation clipboard helper was uninstalled and the phone's
  screen timeout was restored to 30 seconds.
- Android logcat contained only lengths/hashes/category metadata; validation
  secret plaintext was absent.

Completion state:

- Sensitive Clipboard Protection is **complete**.
- Overall roadmap is now `2/5` complete.
- The transient Android `Address already in use` listener warning observed
  after a forced runtime restart is tracked under Device Management
  Reliability; one process and one foreground service were present, and the
  outbound authenticated connection remained functional.

### Earlier Blocked Run — 2026-06-10

Environment:

- Mac: Debug `AirClip.app`, device name `My Mac`.
- Android target: OnePlus 6 at `192.168.0.77`; AirClip port 7878 reachable.
- ADB: unavailable; `adb devices -l` returned no devices.
- Network: Mac `192.168.0.164`, Android target `192.168.0.77`.

Automated checks:

```text
Android unit tests: PASS
Android Debug APK build: PASS
macOS sync-mode policy check: PASS
macOS Debug build: PASS
git diff --check for changed sync-mode files: PASS
```

Mac persisted runtime cycles:

```text
Cycles 1-5, Paused: 0 AirClip listeners on TCP 7878
Cycles 1-5, Manual: 1 AirClip listener on TCP 7878
Restored preference: unset
Restored fallback runtime: Manual, 1 listener on TCP 7878
```

Blocked checks:

- Install the hardened APK on the OnePlus 6.
- Pair the current Mac and Android identities.
- Auto and Manual transfer in both directions using unique payloads.
- Android Paused service, notification, listener, and mDNS shutdown.
- Live pause/resume without restarting either app.
- Five transfer-bearing pause/resume cycles and duplicate-history checks.
- Inbound echo suppression and Android focus behavior in Manual mode.

Outcome:

- This blocked run was superseded by the completed paired validation on 2026-06-13.

### Pairing

| Step | Expected result | Status |
|---|---|---|
| Reset local identity/history on both devices. | Both devices show unpaired/empty state. | Not run |
| Start AirClip on Mac. | Mac advertises `_airclip._tcp`. | Not run |
| Start AirClip on Android. | Android starts foreground service and discovery. | Not run |
| Use QR/code pairing. | Pairing completes in under 20 seconds. | Not run |
| Restart both apps. | Paired devices persist. | Not run |

### Mac -> Android Sync

| Step | Expected result | Status |
|---|---|---|
| Copy normal text on Mac. | Android receives text within 2 seconds. | Not run |
| Paste on Android. | Pasted value matches Mac clipboard. | Not run |
| Open Android history. | New item appears once, newest first. | Not run |
| Copy the same text again. | Duplicate behavior is intentional and not noisy. | Not run |
| Copy a long URL. | Android displays it without broken layout. | Not run |

### Android -> Mac Sync

| Step | Expected result | Status |
|---|---|---|
| Copy normal text on Android. | Widget shows ready/send state, if designed that way. | Not run |
| Tap widget Send. | Mac receives text within 2 seconds. | Not run |
| Paste on Mac. | Pasted value matches Android clipboard. | Not run |
| Open Mac history. | New item appears once with source device label. | Not run |

### History

| Step | Expected result | Status |
|---|---|---|
| Save/pin one Mac history item. | Item is marked saved and survives app restart. | Not run |
| Delete one Mac history item. | Item disappears and stays deleted after restart. | Not run |
| Clear Mac history. | History is empty after restart. | Not run |
| Save/pin one Android history item. | Item is marked saved and survives app restart. | Not run |
| Delete one Android history item. | Item disappears and stays deleted after restart. | Not run |
| Clear Android history. | History is empty after restart. | Not run |

### Device Management

| Step | Expected result | Status |
|---|---|---|
| View paired device list on Mac. | Android appears with clear name/status. | Not run |
| View paired device list on Android. | Mac appears with clear name/status. | Not run |
| Turn off Android Wi-Fi. | Mac shows no nearby/connected peer. | Not run |
| Restore Wi-Fi. | Devices reconnect without re-pairing. | Not run |
| Remove Android from Mac. | Sync stops until re-paired. | Not run |
| Remove Mac from Android. | Sync stops until re-paired. | Not run |

### Trust and Safety

| Step | Expected result | Status |
|---|---|---|
| Copy password-like text on Mac. | Current expected behavior: likely syncs; this confirms need for sensitive blocking. | Not run |
| Copy API-token-like text on Mac. | Current expected behavior: likely syncs; this confirms need for sensitive blocking. | Not run |
| Check logs while syncing. | Clipboard plaintext should not appear in logs. | Not run |
| Pause/disable sync if available. | Outbound auto-sync stops. | Not run |

## Findings From Android Device Validation

### High priority

1. Opening or refocusing AirClip silently captures the current Android clipboard.

   `MainActivity.onWindowFocusChanged(true)` calls `MainViewModel.onAppForegrounded()`. That method reads `ClipboardManager.primaryClip` and immediately calls `SyncEngine.sendClip(text)`.

   Observed result:

   - Launching AirClip imported the phone's existing clipboard into AirClip history.
   - Logs showed `Clip saved locally (no peers)`.
   - If a peer had been connected, the same path would broadcast the clipboard automatically.

   Product impact:

   - This violates the desired "automatic until risky" trust model.
   - Merely opening the app can transmit content the user did not intentionally copy for AirClip.
   - Fix this as part of global sync modes before sensitive-content classification.

2. No global sync control is visible.

   The Android Settings screen exposes device name, reset, AirClip ID, device count, and retention. It does not expose auto-sync, manual-only, or pause controls.

### Medium priority

1. Clipboard selection duplicates the same item.

   Selecting a history item shows a large detail/action panel and also leaves the selected item visible in the list below. With a single item, this reads as duplicate content rather than detail + source row.

2. Selected history row uses a destructive red fill.

   The selected list row becomes bright red even though no delete confirmation is active. Red should be reserved for destructive intent or error state.

3. Devices network map has weak information density.

   With one device, the map consumes most of the screen while placing the device tile in the upper-left. Radar rings overlap the tile and the rest of the panel is empty.

4. Cold launch is visibly slow on the test device.

   Android reported about 4 seconds to display `MainActivity`, with 65 and 33 skipped frames during initial composition. This was a debug build on an older OnePlus 6, so release profiling is needed before treating it as a production regression.

### Passed behavior

- App installs and launches.
- Clipboard, Devices, and Settings tabs render without clipping or crash.
- Search, All/Saved filters, Copy/Save/Delete actions, device pairing affordance, and retention UI are visible.
- Foreground sync service starts.
- LAN WebSocket listener starts on port 7878.
- mDNS discovery and advertisement start.
- Existing identity, keypair, history, and retention data persist across reinstall with `adb install -r`.

## Validation Outcome Template

Use this format after each real test run:

```text
Date:
Mac build:
Android build:
Devices:
Network:

Passed:
- 

Failed:
- 

Blocked:
- 

Design issues observed:
- 

Next fix:
- 
```

## Top 5 Build Order After Validation

Do these one by one after the current validation blockers are resolved:

Progress: `3/5` fully complete. Current build: physical-device validation for `#3` and `#4`.

1. Global sync modes: auto-sync, manual only, paused. **Complete** — paired runtime validation passed on 2026-06-13.
2. Sensitive clipboard blocking. **Complete** — paired runtime validation passed on 2026-06-14.
3. Device management reliability: online/offline, last seen, remove/re-pair behavior. **In progress**.
4. History polish: search, saved item retention protection, clearer source labels. **In progress**.
5. Architecture doc reconciliation: replace relay/Redis assumptions with current LAN-first source of truth. **Complete**.
