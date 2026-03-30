# Clipr+ Development Setup

This document explains how to run the Clipr+ MVP locally for development.

It covers:

- backend setup
- Redis setup
- Mac client setup
- Android client setup
- local network testing
- common troubleshooting

This guide assumes the current MVP scope:

- Mac ↔ Android clipboard sync
- FastAPI backend
- Redis short-term storage
- Android Studio for Android app
- Electron for Mac app

---

# 1. Prerequisites

Make sure these tools are installed.

## Required

### Backend
- Python 3.10+
- pip
- virtualenv or venv
- Redis

### Mac App
- Node.js 18+
- npm

### Android App
- Android Studio
- Android SDK
- Gradle (usually via Android Studio)

---

# 2. Repository Structure

Expected project layout:

```text
Clipr+
├── backend
├── mac
├── android
└── docs
```

---

# 3. Backend Setup

Go to the backend directory.

```bash
cd backend
```

Create and activate a virtual environment.

```bash
python3 -m venv .venv
source .venv/bin/activate
```

Install dependencies.

```bash
pip install -r requirements.txt
```

If your project uses additional packages for tests, also install them.

Example:

```bash
pip install httpx pynacl
```

---

# 4. Start Redis

Clipr+ uses Redis for:

- short-term clipboard history
- pending delivery queue
- sequence ordering

If Redis is installed locally:

```bash
redis-server
```

Default Redis port:

```text
6379
```

You should see something like:

```text
Ready to accept connections
```

---

# 5. Start Backend API

From the `backend` directory:

```bash
source .venv/bin/activate
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Expected output:

```text
Uvicorn running on http://0.0.0.0:8000
Application startup complete
```

Why `0.0.0.0` matters:

- allows Android device on same Wi-Fi to access backend
- localhost-only will not work for physical Android device testing

---

# 6. Run Backend Tests

From `backend`:

## Integration smoke test

```bash
python3 scripts/integration_test.py
```

## Crypto end-to-end test

```bash
python3 scripts/crypto_e2e_test.py
```

Expected result:

- all tests pass
- no failed assertions

---

# 7. Mac Client Setup

Go to the Mac app folder.

```bash
cd mac
```

Install dependencies:

```bash
npm install
```

Run the Mac app:

```bash
npm start
```

Expected output includes:

```text
Clipr starting...
App ready
WebSocket connected
Clipboard polling started
```

---

# 8. Android Client Setup

Open the `android` folder in **Android Studio**.

Let Gradle sync finish.

If prompted, install missing SDK packages.

---

## Build and Run

Use either:

- Android emulator
- physical Android device

### Recommended for MVP testing
Use a **physical Android device** on the same Wi-Fi network as your Mac.

---

# 9. Android Local Server URL

When testing with a physical Android device, backend URL must use your Mac’s local IP address.

Find your Mac IP:

```bash
ifconfig
```

Look for your active network interface. Example:

```text
192.168.0.48
```

Then use:

```text
http://192.168.0.48:8000
```

inside the Android app.

---

## Emulator special case

If using Android emulator:

```text
http://10.0.2.2:8000
```

This is the emulator alias for the host machine.

---

# 10. Android Network Security Notes

For local HTTP development, Android may block cleartext traffic by default.

If needed, configure:

- `network_security_config.xml`
- AndroidManifest network security settings

This is only for local dev.

Production should use:

```text
HTTPS / WSS
```

---

# 11. Full Local Run Order

Recommended startup order:

### Terminal A — Redis

```bash
redis-server
```

### Terminal B — Backend

```bash
cd backend
source .venv/bin/activate
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

### Terminal C — Mac App

```bash
cd mac
npm start
```

### Android Studio — Android App

- Run app
- set backend URL
- login / register
- connect device

---

# 12. Basic Manual Test Flow

## Live sync

1. Open Mac app
2. Open Android app
3. Connect both to same account
4. Copy text on Mac
5. Confirm Android receives it

---

## Offline catch-up

1. Close Android app or disable network
2. Copy several texts on Mac
3. Reopen Android
4. Confirm missed items appear automatically

---

## Tap-to-copy

1. Open Android clipboard history
2. Tap an item
3. Confirm it copies to Android clipboard
4. Confirm it does **not** re-send to Mac

---

# 13. Common Development States

## Mac app healthy state

Example logs:

```text
WebSocket connected
Clipboard polling started
Fetched devices from server
```

## Android healthy state

Example state:

- AccountTokenReady
- DeviceTokenReady
- WS Connected
- Clipboard Monitoring ON

## Backend healthy state

Example logs:

```text
WebSocket /ws [accepted]
GET /clips 200 OK
POST /devices/register 200 OK
```

---

# 14. Common Problems and Fixes

## Problem: Android cannot connect to backend

### Possible causes
- backend started on localhost only
- wrong local IP
- phone not on same Wi-Fi
- Android cleartext HTTP blocked

### Fix
- run backend on `0.0.0.0`
- use Mac LAN IP
- confirm same Wi-Fi
- configure Android network security for local dev

---

## Problem: Mac app shows token expired

### Cause
Account token expired.

### Fix
- login again
- app should refresh session state

---

## Problem: Android misses offline clipboard items

### Causes to check
- backend not reachable
- WS not reconnecting
- device keypair not restored on cold start
- lastSeenSeq/catch-up path issue

### Fix
- verify Android reconnect logs
- verify key restore works
- verify server history still within 30-minute retention window

---

## Problem: Clipboard loops or duplicates

### Causes
- loop-prevention hash not recorded early enough
- duplicate item merge issue

### Fix
- verify recent hash cache
- verify duplicate suppression by msg_id / seq

---

# 15. Resetting Local State

Sometimes development requires a clean reset.

---

## Reset Mac app state

Delete Electron user data folder if needed.

Example:

```bash
rm -rf ~/Library/Application\ Support/clipr-mac
```

Then restart the app.

---

## Reset Android app state

On device:

- App Info
- Storage
- Clear storage / clear cache

or uninstall and reinstall.

---

## Reset Redis

Warning: this deletes all short-term clipboard state.

```bash
redis-cli FLUSHALL
```

Use only for development reset.

---

# 16. Useful Logs to Watch

## Backend

Watch for:

- WebSocket accepted
- pending delivery
- hello latest_seq
- catch-up requests
- auth failures

---

## Mac

Watch for:

- WebSocket connected
- clipboard polling started
- fetched devices
- catch-up behavior
- session expired

---

## Android

Watch for:

- session restore
- auto-connect decision
- hello(latest_seq)
- fetchMissedClips
- decrypt success/failure
- local history merge

---

# 17. Recommended Dev Workflow

Best workflow during MVP development:

1. Start Redis
2. Start backend
3. Run Mac app
4. Run Android app
5. Test live sync
6. Test offline reconnect
7. Verify clipboard history
8. Verify no duplicate resend

Avoid changing protocol and UI at the same time.
Keep one fix pass focused on one layer.

---

# 18. Current MVP Limits

Development/testing assumptions:

- text only
- history cap = 20
- server catch-up window ≈ 30 minutes
- one account with multiple trusted devices
- Android may behave differently across OEM background policies

---

# 19. Related Documentation

See:

```text
README.md
docs/architecture.md
docs/protocol.md
docs/security.md
docs/mvp-scope.md
```

---

# End of Development Setup