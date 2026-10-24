# Airclip security, cleanup and release-readiness audit

Date: 22 October 2026. Updated after reviewing the latest working-tree changes and rerunning available checks. Scope: active Mac and Android clients, repository organization, and Mac App Store preparation. No upload, publication, production attack, pairing reset or installed-app data migration was performed.

**Release decision: NOT READY for public distribution.** The latest changes improve stale-peer handling, reconnect recovery, duplicate-history behavior and dark-mode UI. The LAN authentication/pairing protocol remains a security release blocker. Passing compilation, lint and the tests below does not make this a penetration-test certification.

## Work completed

| Finding | Change | Verification |
|---|---|---|
| **Critical: reconnect can substitute a paired device's encryption key** | Mac incoming/outgoing authentication and registration, plus Android incoming/outgoing authentication and registration, now require the saved pairing key. Ordinary reconnect cannot rotate that key. | Production Mac handler test failed on the original code with an attacker key, then passed after the fix. Tests exercise both connection directions. Android key-pin tests cover matching, substituted, absent and empty keys. |
| **High: Mac private key persisted in preferences** | Moved the 64-byte keypair to Keychain, using device-only accessibility. Existing identity migrates without regeneration; old preferences are removed only after successful write/read-back. Locked/corrupt storage fails closed. | Release build plus production migration code tested with fake Keychain APIs for successful migration, failed write, locked storage and corrupt data. Actual signed-app Keychain behavior still requires testing. |
| **High: peer file IDs used as cache path components** | Restrict file IDs to `[A-Za-z0-9_-]{1,128}`, reject negative sizes and invalid names, reject unsafe remote metadata, and guard persisted metadata before cache access. Chunk-size arithmetic now avoids overflow. | Malicious traversal/absolute/backslash/empty/oversized IDs and malformed metadata tested on both platforms; valid file round trips retained. |
| **High: exported Android widget handles send/paste broadcasts** | Widget receiver is no longer exported. System widget delivery and app-owned explicit PendingIntents remain the intended entry points. | Release manifest/lint validation. Actual launcher/widget interaction remains device QA. |
| **Medium: Android pairing codes used non-cryptographic random generation** | Use `SecureRandom.nextInt(1_000_000)` with existing six-digit formatting. | Existing pairing tests pass. This does not solve pairing transport/rate limiting. |
| **Release error: Android API 29 call on minimum API 26** | Guard `ContentResolver.loadThumbnail` by OS version; existing image/PDF/media thumbnail fallbacks remain available. | Release lint changed from one error to zero errors; Release assembly passes. |
| **Clutter: empty obsolete screen files** | Removed Android `AuthScreen.kt` and `DebugScreen.kt`, both empty compatibility stubs with no screen implementation. | Android compilation/tests pass. |
| **Clutter: duplicate Mac artwork** | Removed seven byte-identical SVGs that were not assigned by their imageset manifests. Assigned originals remain. | Mac asset warnings about those unassigned children are gone; Release build passes. |
| **Misleading documentation** | Documented internet requests for previews/updates/opt-in analytics, pinned keys and remaining authentication limitations; corrected obsolete eight-digit protocol examples. | Documentation compared with active code. |
| **Latest changes reviewed (22 Oct)** | Both clients now expire peers that stop acknowledging heartbeats; Mac path recovery restarts LAN discovery and clears stale endpoint cache; Mac history avoids redundant SwiftData writes for identical reconnect history and narrows eviction to oldest unsaved items; Android now presents update notes/actions and applies the selected theme to system bars. | New heartbeat boundary test passes; Android unit test suite now has 74 tests. These changes improve reliability but do not provide cryptographic peer authentication. |
| **Android discovery crash on the connected phone (22 Oct)** | A live NSD resolve callback threw `KeyManager: keypair not initialised` while reading an unavailable key and terminated the app. Outgoing discovery now skips that result until a public key is available, while preserving the strict accessor for callers that require an initialized key. | Rebuilt the debug APK and reran all 74 Android unit tests. Live reconnect retest is in progress; this code fix is not yet a verified end-to-end result. |
| **Android active filter icon loses contrast in dark mode (22 Oct)** | The fixed-black active vector was rendered without tint on the dark Home search surface. Both search layouts now tint its active state with the theme's primary text color. | The rebuilt debug APK and all 74 unit tests pass; the updated build was installed in place on the OnePlus 6. On-device visual confirmation is pending while the phone is locked. |

All pre-existing working-tree changes, including icon/UI/history work, were preserved. No broad reorganization or feature removal was performed.

## Open security findings

### P0 — Authenticated sessions and pairing are still missing

Relevant files: `mac/Airclip/Core/PeerConnection.swift`, `PeerManager.swift`, `PairingClient.swift`; Android `lan/LanServer.kt`, `LanBrowser.kt`, `PeerManager.kt`, `pairing/PairingClient.kt`.

IDs and public keys are public information. After the pinning fix, an attacker that knows the correct public pairing key still does not have to prove possession of the private key. NaCl sealed boxes authenticate ciphertext integrity for a recipient but **do not authenticate the sender**. The connection then accepts control operations, including history deletion/clear and device removal. WebSocket control messages are not integrity-protected as a session. An active network attacker can also tamper with them.

Required before release: design and implement a versioned mutually authenticated session, bind identities to the transcript, authenticate every data/control frame, prevent replay, set timeouts/limits and fail closed without a legacy fallback. Use an established reviewed protocol/library rather than treating the new key comparison as authentication. Test Mac↔Android interoperability and downgrade rejection.

Initial pairing sends its short code and trust metadata over plain WebSocket. A secure pairing design must cover interception/MITM, code guessing, expiry, single-use behavior and throttling across connections. No effective cross-connection attempt budget was found. Android's secure RNG fix is only one part of this work.

### P1 — Network/resource limits need adversarial testing and hardening

The Mac receive loop and Android WebSocket server do not enforce an application-level maximum message size before JSON/base64 processing. Repeated connections, oversized messages, image decompression and transfer stalls need bounded memory, time and concurrency policies. Mac link previews download via `URLSession.data` before checking/truncating response sizes; this is not a download-size cap. Test oversized/compressed responses and redirects without contacting arbitrary third-party targets.

### P1 — Preview network behavior needs a product/privacy decision

Both clients fetch website metadata/images automatically from clipboard links. A URL containing a private token can be sent to its origin just by displaying a clip. Local/private hostnames can also be requested. This is active behavior, not dead code. A pending question asks whether to make previews opt-in, keep them, or remove remote previews. No preview feature was deleted.

### P2 — At-rest content, deletion and logging review

Keychain protects device key material; it does not encrypt the SwiftData/JSON clipboard history, thumbnail caches, downloaded files or widget preview preferences. Decide the intended at-rest threat model and retention behavior. Verify clear-history/leave-space/uninstall behavior, temporary-file cleanup, backups and whether downloaded files intentionally survive removal.

A limited tracked-text scan found no matching private-key blocks, common GitHub tokens, AWS access-key IDs or Stripe live keys. This is **not** a full secret scan of Git history, ignored files or every token format. No secrets were printed. Logs still need a runtime check with canary clipboard content and malformed peer inputs; exception strings can contain input-derived details.

## Mac App Store readiness

| Item | Status / action |
|---|---|
| App Sandbox and hardened runtime | Enabled in project settings. Verify effective entitlements of the signed archive and extension, not only source settings. |
| External updater | **Blocker.** Sparkle is linked, starts automatically and has update UI/feed configuration and Mach exceptions. An App Store build must exclude the external updater, its UI, feed keys, framework and associated entitlements. Preserve direct-download support until the pending distribution decision is answered. Merely hiding a menu is insufficient. |
| Privacy manifest | Present, declaring UserDefaults and optional analytics. File timestamp access exists (`contentModificationDateKey`) but no file-timestamp category is declared. Review the actual data use—including cross-device metadata—and add the accurate approved reason before archive validation. Audit embedded SDK/extension manifests as well. |
| Privacy disclosures | Reconcile the privacy policy and App Store privacy answers with analytics, updates, automatic previews, local storage, clipboard capture and LAN file sharing. Analytics is opt-in; it is not an undisclosed hidden menu. |
| Encryption/export compliance | Complete Apple's encryption questionnaire for libsodium/NaCl usage. Do not assume an HTTPS-only exemption or add a blanket exemption flag. |
| Signing and archive | Builds here used `CODE_SIGNING_ALLOWED=NO`. No App Store distribution-signed archive, provisioning validation, upload validation or TestFlight run was performed. |
| App minimum OS | macOS 26.0 in the project. Confirm that this is the intended supported audience; test oldest supported OS and current OS. |
| Shortcuts/accessibility | Validate paste automation, global shortcuts, permission denial/revocation and sandbox behavior in a signed build. Explain permission-dependent functionality to reviewers. |
| Share extension | Active Finder share extension deliberately uses an invisible transient view and transfers file URLs through the pasteboard. This is functional integration, not disposable hidden UI. Test sandbox URL access and denial paths. |
| Licenses/assets | Confirm distribution rights for Beary.ttf and bundled icons; prepare third-party acknowledgements and review dependency licenses. Missing proof in this audit is not a conclusion that rights do not exist. |
| Review experience | Supply accurate screenshots, support/privacy links, steps to pair with Android, local-network requirements and any reviewer setup. No cloud-account demo credentials should be invented for this LAN product. |

Apple references: [Mac App Store review rules, including §2.4.5](https://developer.apple.com/app-store/review/guidelines/), [distribution preparation](https://developer.apple.com/documentation/Xcode/preparing-your-app-for-distribution), [required-reason APIs](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api), [privacy manifests](https://developer.apple.com/documentation/bundleresources/adding-a-privacy-manifest-to-your-app-or-third-party-sdk).

## Inventory: retained pending review

These are candidates or product decisions, not authorization to delete them.

| Location / behavior | Evidence / recommendation |
|---|---|
| `backend/` | README explicitly calls it inactive legacy cloud relay. Keep until approved; remove or archive as a coherent module with its tests/dependencies, not isolated snippets. |
| `ios/` | Planned client with source and setup instructions, no active Mac/Android build role. Potentially important future work. |
| Android `auth/`, `ws/`, `device/DeviceApi.kt`, `ClipsApi.kt` | Legacy cloud APIs have declarations but no active app call sites found. TokenStore uses old DataStore storage. Remove only after confirmation and a reference/dependency check. |
| Mac `Core/AuthManager.swift`, `APIClient.swift`; `AppConfig.defaultServerURL` | Compatibility shim/stub and old localhost setting; no active call sites found for the shim/API. Retained with the legacy decision. |
| `commonMain/androidx/compose/...` | Copied framework source outside the Android app's configured source tree. Looks like reference/debug material; preserve pending confirmation. |
| `Claude outputs/airclipcasestudyv3.html` | Prototype/case-study material, not an active client screen. |
| Root `Airclip-v1.0.0.apk` | Tracked old binary while current app version is 2.0. Recommend release assets outside source history, but do not delete the user's retained artifact without approval. |
| Android unused-resource warnings | Eight locations include splash/scanner artwork, bookmark icons, settings icon, a color resource and scanner layout. Some may be library overrides or ongoing work; lint alone is not proof they are safe to delete. |
| Sparkle and Android update controls | Live features. Need distribution-channel decisions, not “dead code” deletion. |
| Automatic link previews | Live background internet behavior. Pending product choice. |
| Analytics | Visible settings control, disabled by default; keep unless explicitly changed. |
| `agent.md`, older architecture/setup notes | Some instructions still describe a backend-first, text-only MVP and 20-item limits inconsistent with current LAN/file support. Reconcile governance/docs deliberately; do not follow stale architecture text as permission to delete working features. |

No concealed debug/admin screen or secret menu was identified in the inspected active navigation. Mac context menu contains Open, Settings, About and Quit. A hidden titlebar/menu indicator or `accessibilityHidden` decorative asset is not a hidden feature.

## Code organization

The largest files are Mac `MainWindowView.swift` (~5,000 lines), Android `ClipboardScreen.kt` (~1,860), onboarding screens (~1,400 each), and `MainViewModel.kt` (~970). These are maintenance risks, not automatically unused code.

Recommended sequence after security protocol work: separate preview/network loading from views; extract device/settings/pairing components by feature; retain platform-neutral policy functions with tests; keep native platform adapters at the boundary. Use dedicated refactor changes with characterization coverage. Avoid a mass rename/move in this already-modified working tree.

## Verification performed

- Mac **Release build and Xcode Analyze pass** on 22 Oct with the `Airclip` scheme, signing disabled. Xcode Analyze is not a complete Swift security proof.
- Android **Release assembly and release lint pass** on 22 Oct using Android Studio’s bundled Java 21. Lint: **0 errors, 97 warnings, 2 hints**. Warnings were not suppressed or baselined away.
- Android unit tests: **74 passed**, zero failures/errors/skips (one new heartbeat timeout boundary test).
- Isolated Mac policy/security runner: `python3 scripts/check-mac-policies.py` (13 checks). Includes production auth handlers, trust policy, Keychain migration with a fake backend, file metadata, capture, deletion policy and existing UI policies.
- Dark-mode regression checks: **76 color pairs pass** across the Mac and Android token sets. This is a token-level contrast check; it does not replace visual review of every screen, overlay or material surface on device.
- Dependency advisory lookup: OSV query of **20 explicitly versioned direct Maven dependencies** returned no advisory matches at audit time. This excludes transitive dependencies, Compose BOM members, Swift packages, website/backend and vendored native library versions; it is not a clean bill of health for the whole dependency tree.
- Android native-library lint warns that bundled libsodium arm64 and JNA x86_64 are not 16 KB aligned. Resolve/rebuild dependencies and test appropriate devices before Android store distribution. Android target/compile SDK is also old; plan the upgrade separately.
- `git diff --check` passes on 22 Oct.
- Android emulator retry on 22 Oct: the Pixel_6a AVD points to an installed Android 36 Play Store arm64 image, but emulator 36.4.9 exits before boot with **“No initial system image for this configuration!”**. A OnePlus 6 (Android 11 / API 30) then appeared over ADB. Its installed Airclip 2.0 signing certificate matched the current debug APK; successive debug APKs were updated in place with `adb install -r` and app data was not cleared. Once unlocked, Home, Devices, Settings, appearance choices and Home filters rendered in dark mode, with the paired Mac shown online. A network discovery callback then crashed on an uninitialized key and Home's active filter icon had poor contrast. The fixes above were installed on the phone after passing builds, but the phone locked again before visual/reconnect retesting. Pairing, scanner and clip transfer scenarios remain unverified. The Sony BRAVIA_VU3 was not used.
- No public endpoints or other people's devices were attacked. Security reproductions used isolated local harnesses and synthetic data.

## Tests to run before launch, in order

1. **Protocol adversarial suite (release gate):** impersonation using correct public IDs/keys, substituted keys, replayed and reordered messages, tampered control frames, fake discovery, removed devices, invalid/expired/reused pairing codes, brute-force attempts and downgrade attempts. Use two controlled test devices and an isolated network.
2. **Signed sandbox migration suite:** fresh install; upgrade from the previous build with real history; Keychain locked/denied; stable identity after restart; old-key migration; reset/leave-space; downloaded-file bookmarks; share extension and shortcuts. Never use irreplaceable clipboard data for these tests.
3. **Mac↔Android end-to-end suite:** text, Unicode, long text, URLs, images, colors, empty/large/multiple files; both directions; duplicate suppression; local copy must not resend; offline catch-up; deletion propagation; paused/manual modes; revoked device; interrupted/resumed transfer.
4. **Network lifecycle suite:** sleep/wake, process kill/relaunch, Wi-Fi changes, hotspot, Ethernet, VPN, IPv6, port conflict, permission denied/revoked, multiple peers, no internet and unstable connectivity.
5. **Resource/fuzz suite:** malformed JSON/base64, unexpected types, huge/truncated images, path traversal, oversized WebSocket frames, stalled transfers, disk full, memory pressure and connection floods. Verify bounded failure and cleanup.
6. **Privacy suite:** canary clipboard strings must not appear in logs/analytics; verify disabled analytics; inventory preview/update traffic; validate retention and cache deletion; inspect archive privacy report and manifests.
7. **UI/accessibility suite:** dark/light/system switching, large text, keyboard-only use, VoiceOver/TalkBack, reduced motion/transparency, contrast over Mac materials, focus order, empty/error/offline/loading states, and display scaling/multiple monitors.
8. **Performance/soak suite:** extended idle and transfer sessions; CPU/energy/memory/network use; large-history scrolling; launch time; repeated reconnects; no runaway listeners, timers or duplicate services.
9. **Distribution suite:** reproducible clean Release build; full resolved dependency/SBOM/advisory and license audit; signed App Store archive with no Sparkle; entitlement/privacy/export-compliance validation; internal TestFlight; oldest supported and current OS/hardware checks.

The unresolved protocol work and distribution decisions must be completed before this becomes a launch approval. App Store signing/archive validation and Android real-device UI/sync testing remain outstanding.
