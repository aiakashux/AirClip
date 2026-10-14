from pathlib import Path

root = Path(__file__).parents[2]
app = "\n".join(path.read_text() for path in (root / "mac/Airclip").rglob("*.swift"))
plist = (root / "mac/Airclip/Resources/Info.plist").read_text()
entitlements = (root / "mac/Airclip/Airclip.entitlements").read_text()
project = (root / "mac/Airclip.xcodeproj/project.pbxproj").read_text()

assert "SPUStandardUpdaterController" in app
assert "SUScheduledCheckInterval" in plist and "86400" in plist
assert "SUEnableSystemProfiling" in plist and "<false/>" in plist
assert "SUEnableInstallerLauncherService" in plist
assert "Sparkle" in project
assert "ENABLE_HARDENED_RUNTIME = YES" in project
assert "-spks" in entitlements and "-spki" in entitlements

analytics = (root / "mac/Airclip/Core/PrivacyAnalytics.swift").read_text()
for forbidden in ("clipboard", "deviceName", "wifi", "ssid", "domain", "timestamp", "hash"):
    assert forbidden not in analytics, forbidden

print("Update and privacy checks passed")
