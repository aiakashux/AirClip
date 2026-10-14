# Airclip 2.0.0 Beta 1

Mac and Android beta downloads built from source commit `438a05b30f88daeab70c24160cd34ea0872ca5f2` on 17 September 2026.

## Downloads

- **Mac:** `Airclip-2.0.0-beta.1-mac.dmg`, macOS 26+, Apple silicon and Intel.
- **Android:** `Airclip-2.0.0-beta.1-android.apk`, Android 8+.
- `SHA256SUMS.txt` contains checksums for both downloads.

Install both apps and connect your devices to the same Wi-Fi. Pair them in Airclip. Copy on your Mac; use Share or Send in Airclip on Android to send text back.

## Installation notes

The Mac beta is ad-hoc signed, **not Developer ID signed or Apple-notarized**. macOS may block it. Read [Apple's guidance](https://support.apple.com/en-us/102445) before deciding whether to open it. Do not disable Gatekeeper.

The Android APK is signed with Airclip's release key. An older development build may use a different key and cannot be updated in place. Save important clips before uninstalling: uninstalling removes local app data.

These packages use the current internal app version 2.0, build/version code 2. The beta label identifies this distribution. Future packages must increment the internal build/version code.

## Verification

- Release builds completed for both platforms.
- All 56 Android unit tests passed.
- Android release signature verified; Mac ad-hoc signature and DMG integrity verified.
- Fresh installation, upgrades, and transfer between physical devices have not been verified for these release packages.
