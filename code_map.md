# Code Map

Important components in AirClip

Backend

app/main.py
    FastAPI entrypoint

app/ws_router.py
    WebSocket connection handling

app/clipboard_service.py
    clipboard relay logic

app/history_store.py
    Redis history storage

Mac Client

src/clipboardMonitor.ts
    detects clipboard changes

src/wsClient.ts
    websocket communication

src/historyStore.ts
    local clipboard history

Android Client

MainViewModel.kt
    clipboard sync state machine

KeyManager.kt
    encryption key persistence

ClipboardHistoryStore.kt
    local history storage