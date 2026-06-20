# AirClip Manual Validation Queue

Updated: 2026-06-18

Use this after the current implementation queue is finished. These tests assume one Mac and one Android phone on the same Wi-Fi, with fresh builds installed on both.

## Device Management Reliability

1. Fresh-reset both devices.
2. Start AirClip on Mac.
3. Start AirClip on Android.
4. Pair with QR.
5. Confirm pairing completes in under 20 seconds.
6. Restart both apps.
7. Confirm both devices still show as paired.
8. Confirm both devices connect automatically on the same Wi-Fi.
9. Wait at least 30 seconds.
10. Confirm each device shows a recent last-seen value for the other device.
11. Set sync mode to Paused.
12. Confirm Mac Devices says sync is paused, not just offline.
13. Confirm Android Devices says sync is paused, not just offline.
14. Resume sync.
15. Turn Android Wi-Fi off.
16. Confirm Mac eventually shows Android offline or no connected peer.
17. Confirm Mac shows the same-Wi-Fi/no-nearby-devices hint.
18. Confirm Android shows the no-paired-devices-nearby hint when it cannot see Mac.
19. Turn Android Wi-Fi back on.
20. Confirm devices reconnect without re-pairing.
21. Remove Android from Mac.
22. Confirm Android disappears from Mac's paired-device list.
23. Confirm the active Mac-to-Android peer disconnects.
24. Try copying normal text on Mac.
25. Confirm removed Android does not receive it.
26. Restart both apps without re-pairing.
27. Confirm removed Android cannot reconnect to Mac.
28. Re-pair Android with Mac.
29. Confirm sync works again after re-pairing.
30. Remove Mac from Android.
31. Confirm Mac disappears from Android's paired-device list.
32. Confirm the active Android-to-Mac peer disconnects.
33. Try sending from the Android widget.
34. Confirm removed Mac does not receive it.

## Sync Mode Regression

1. Set both devices to Auto.
2. Copy normal text on Mac.
3. Confirm Android receives it once.
4. Copy normal text on Android or send from widget.
5. Confirm Mac receives it once.
6. Set both devices to Manual.
7. Copy normal text on Mac.
8. Confirm Android does not receive it automatically.
9. Use explicit send on Mac.
10. Confirm Android receives it once.
11. Use explicit Android widget send.
12. Confirm Mac receives it once.
13. Set both devices to Paused.
14. Confirm Android service, notification, listener, discovery, and peer count stop.
15. Confirm Mac listener, browser, advertisement, and peer count stop.
16. Restart both apps while Paused.
17. Confirm both remain Paused and do not reconnect.
18. Resume both apps.
19. Confirm they reconnect without duplicate history entries.

## Sensitive Clipboard Regression

1. Set sensitive API-token rule to Ask on both devices.
2. Copy normal URL on Mac.
3. Confirm Android receives it.
4. Copy API-token-shaped text on Mac.
5. Confirm Android does not receive it automatically.
6. Explicitly send the token from Mac.
7. Confirm the local confirmation prompt appears.
8. Cancel the prompt.
9. Confirm Android does not receive the token.
10. Send again and confirm.
11. Confirm Android receives it once.
12. Set API-token rule to Block on Android.
13. Try Android widget send with token-shaped text.
14. Confirm no send occurs and Mac does not receive it.
15. Set API-token rule to Allow on Android.
16. Try Android widget send with token-shaped text.
17. Confirm Mac receives it once.
18. Inspect logs and confirm validation secret plaintext is absent.

## History And Recovery Smoke Tests

1. Copy five normal text items from Mac.
2. Confirm Android history shows each once, newest first.
3. Send five normal text items from Android.
4. Confirm Mac history shows each once, newest first.
5. Tap a history item on Android.
6. Confirm it copies locally and does not echo back to Mac.
7. Tap a history item on Mac.
8. Confirm it copies locally and does not echo back to Android.
9. Delete one item on each device.
10. Restart both apps.
11. Confirm deleted items stay deleted.
12. Clear history on each device.
13. Restart both apps.
14. Confirm history stays empty.
15. Copy normal text, a URL, and an image from Mac.
16. Confirm Android type filters show each item under the expected Text, Links, or Images filter.
17. Send normal text, a URL, and an image from Android if image send is available.
18. Confirm Mac type filters show each item under the expected Text, Links, or Images filter.
19. Search Android history by clip text, type name, and source device name.
20. Search Mac history by clip text, type name, and source device name.
21. Save one old or low-priority clip on each device.
22. Add enough unsaved clips to exceed the normal visible history cap.
23. Confirm saved clips remain visible after pruning pressure.
24. Restart both apps.
25. Confirm saved clips remain saved and visible.
26. Change retention to 7 days, 30 days, 90 days, and forever where available.
27. Confirm unsaved old clips follow retention while saved clips remain protected.
28. Confirm long text, long URLs, empty history, many items, and image previews do not break layout.
29. Disconnect Wi-Fi on Android.
30. Copy three items on Mac.
31. Reconnect Android Wi-Fi.
32. Confirm reconnect behavior does not overwrite the active Android clipboard unexpectedly.
33. While Android is offline, send three clips from Mac.
34. Reconnect Android and wait for the devices to authenticate.
35. Confirm Android history backfills the missed clips without changing the active Android clipboard.
36. While Mac is offline or AirClip is stopped, send three clips from Android.
37. Reconnect or relaunch Mac AirClip and wait for authentication.
38. Confirm Mac history backfills the missed clips without changing the active Mac clipboard.
39. Repeat a reconnect with clips that already exist in history.
40. Confirm duplicates are not added for the same source/content/timestamp window.
41. Send a long text clip from Android that is longer than 40 characters.
42. Confirm Android history preview can be copied back as the full original text.
43. Reconnect Mac and confirm Mac backfills the full long Android text, not just the preview.
44. Search Android history for words beyond the first 40 characters.
45. Confirm the long text clip appears in search results.
46. Tap a text history item on Android.
47. Confirm it copies locally and does not echo back to Mac.
48. Tap an image history item on Android.
49. Confirm it copies locally and does not echo back to Mac as a duplicate.
50. Tap a history item on Mac main window and menu bar popover.
51. Confirm it copies locally and does not echo back to Android.
52. Repeat the same history tap after reconnect backfill.
53. Confirm no duplicate history entry appears on either device.

## Runtime Diagnostics

1. Start both apps on the same Wi-Fi with sync enabled.
2. Confirm no warning diagnostic appears when listener, discovery, and advertisement start normally.
3. Force Android listener failure by occupying TCP port 7878, then start AirClip.
4. Confirm Android Devices shows "Local listener could not start".
5. Release port 7878 and restart AirClip.
6. Confirm the Android listener diagnostic clears.
7. Disable or block Android NSD/mDNS through network/VPN/private-DNS conditions if available.
8. Confirm Android Devices shows discovery or advertisement guidance instead of only "No paired devices nearby".
9. On macOS, deny Local Network permission or block Bonjour/mDNS if available.
10. Confirm the Mac Devices hub shows discovery blocked or listener blocked guidance.
11. Restore permissions/network access.
12. Confirm diagnostics clear after AirClip restarts or reconnects.
