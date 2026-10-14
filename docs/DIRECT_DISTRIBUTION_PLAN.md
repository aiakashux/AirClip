# Airclip direct distribution and updates

Updated 18 September 2026. The client update checks and metadata paths below are implemented; production signing, notarization, and release publication still require the release credentials.

## Recommended setup

Keep application source in its existing repository. If source is private, use a separate public `airclip-releases` repository containing only release notes and downloadable binaries. Do not expose the source repository or embed private GitHub credentials in the app. [GitHub releases](https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases) support binary assets and download counts.

Host the small static website and update metadata on Cloudflare Pages under an owned domain. Link to versioned GitHub release assets. No application backend or database is required for this setup. Hosting downloads does not put clipboard contents in the cloud.

Suggested paths, subject to the chosen domain:

```text
/download                         stable installation page
/updates/mac/appcast.xml          Sparkle feed
/updates/android/stable.json      version and download metadata
/changelog                        readable release history

GitHub release assets:
Airclip-mac-1.0.1.dmg
Airclip-android-1.0.1.apk
SHA256SUMS.txt
```

Never replace the contents of an already published versioned file. Publish a new version and update the stable links. Budget for the domain and Apple membership; hosting can begin within provider free allowances, subject to their terms and limits. Do not add paid storage until there is a concrete need.

## Mac packaging

Use a Release build signed with Developer ID Application, enable hardened runtime, notarize with Apple, and staple the ticket to the distribution package as appropriate. Deliver a DMG with an obvious drag-to-Applications flow. This uses Apple's direct distribution process; it does not require an App Store listing. [Apple distribution signing](https://developer.apple.com/documentation/xcode/creating-distribution-signed-code-for-the-mac), [notarization workflow](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow).

Verify the downloaded package on a clean Mac with Gatekeeper enabled. Do not make security-warning bypass instructions the standard installation path. Publish only architectures actually built and tested; current project minimum is macOS 26.0, which must either be disclosed or deliberately lowered and tested before launch.

Add Sparkle 2 before the broad public beta. Include Check for Updates, release notes and a controllable automatic-check setting. Serve its appcast over HTTPS and sign update archives with Sparkle's signing mechanism; keep the private update key backed up outside Git. Follow Sparkle's privacy settings and omit optional system profiling. Test a real old-build → new-build upgrade. [Sparkle documentation](https://sparkle-project.org/documentation/).

## Android packaging

Distribute a release-signed APK. An AAB is not the normal direct-install artifact. Keep the package identifier stable and use the same release signing identity for updates; protect and back up the keystore and passwords separately. The existing `Airclip-debug.apk` is a development artifact, not the public release. Existing debug installations may need a deliberate migration/reinstall because the signing certificate differs; document data consequences before asking testers to uninstall. [Android signing](https://developer.android.com/studio/publish/app-signing).

For the first release, add Check for Updates that reads small HTTPS metadata and opens the official download page. An optional foreground check, at most daily, can show a dismissible update banner. The user downloads the APK and Android handles installation approval. Avoid a custom silent installer, background push service or extra installer permissions in Airclip. Explain the browser's install-from-this-source setting in the guide. [Android alternative distribution](https://developer.android.com/distribute/marketing-tools/alternative-distribution).

Validate metadata types, increasing version code and an allowlisted HTTPS destination before displaying the update link. Unavailable or malformed metadata must not interrupt local sync. Show installed and available versions and release notes. Never promise silent APK updates on ordinary unmanaged devices.

Android's developer-verification rollout is changing. Its current overview describes a 30 September 2026 milestone for participating stores in Brazil, Indonesia, Singapore and Thailand, followed by broader coverage in 2027. Before launch, review the current path for outside-Play distribution and the intended countries; do not assume sideloading avoids registration indefinitely. [Android verification overview](https://developer.android.com/developer-verification?authuser=0).

## Version policy

Both platforms currently declare version `1.0`, build/code `1`. Before choosing the beta label, check whether these versions have already been distributed. Never lower the internal build/code for an update.

Use `MAJOR.MINOR.PATCH` for visible versions: major for substantial breaking changes, minor for compatible features, patch for fixes. Increase Mac `CFBundleVersion` and Android `versionCode` for every distributed build. Keep one release ledger with source commit, platform, version, build/code, artifact checksum, minimum OS and compatible companion versions.

Platforms can ship fixes independently; do not rebuild Android merely because Mac has a UI fix. Tag platform-only releases unambiguously, for example `mac-v1.0.1`. Keep beta and stable feeds separate if both are actually used.

Keep wire-protocol compatibility separate from marketing version. Prefer compatibility with the preceding public companion release. For a breaking protocol change, specify the compatible pair and show an actionable mismatch state. Local-history migrations must preserve existing data. A withdrawn build should be superseded by a higher-numbered fixed build; blindly downgrading can break data stores.

## Release procedure

1. Choose a known commit and assign version/build numbers.
2. Run relevant tests and build both affected release artifacts.
3. Sign, notarize Mac, verify APK signature, create checksums and release notes.
4. Test fresh install and upgrade from the previous public release: history, settings and pairing survive.
5. Exercise text/link transfers both ways, Android foreground/background cases, sleep/wake, reconnect and internet-disabled LAN operation.
6. Upload immutable artifacts; verify actual downloaded files.
7. Publish update metadata last, then update website links.
8. If defective, withdraw the feed entry and ship a higher-build fix. Retain previous artifacts for diagnosis; do not promise safe downgrade without testing migrations.

Start with a documented manual release procedure; automate these same steps once the first release succeeds. Keep signing credentials outside source control and restrict publishing access.

## Local-first promise

Recommended wording: **Clipboard sync stays on your local network. Downloads and update checks use the internet.**

The updater must never carry clipboard content, device names, paired-device identities or usage statistics. Hosting providers still receive normal connection metadata such as IP addresses. Offer manual checks and a way to disable automatic checks. Local sync should continue when update hosting is unreachable.

Keep iOS and Windows outside this launch: the repository describes them as planned, and iOS distribution is a separate decision.
