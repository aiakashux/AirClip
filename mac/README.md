# Clipr+ Mac Client

Electron tray app for E2E encrypted clipboard sync (MVP Task 1).

## Prerequisites

- Node.js 18+
- Backend running at `http://localhost:8000` (with Redis)

## Setup

```bash
cd mac
npm install
```

## Run

```bash
npm start
```

The app runs as a **tray icon** (no dock icon). Right-click the tray icon for the menu.

## Usage

1. **Login / Register** — Opens a small window. Enter email + password, click Login or Register.
   - On success the app generates an X25519 keypair, registers the device with the backend, and connects the WebSocket.
2. **Send Test Message** — Encrypts `"hello-from-mac"` with libsodium sealed box and sends it to all trusted peer devices via WebSocket.
3. **Show Logs** — Opens a log panel showing connection events, sent/received messages, and decrypted plaintext.
4. **Reconnect WS** — Manually reconnect if the WebSocket dropped.

## State

Tokens, device ID, and keypair are stored in `mac/.local/state.json` (gitignored). Delete this file to reset.

## Architecture

```
src/
  config.ts       — Backend URLs and paths
  state.ts        — Load/save local state (JSON file)
  crypto.ts       — libsodium sealed box encrypt/decrypt
  api.ts          — REST client (login, register, device registration, device list)
  websocket.ts    — WebSocket client with auto-reconnect
  main.ts         — Electron main process (tray, IPC, orchestration)
  preload.ts      — Context bridge for renderer
  renderer/
    clipr.d.ts    — Window.clipr type declarations
    login.html/ts — Login/register form
    logs.html/ts  — Log display panel
```
