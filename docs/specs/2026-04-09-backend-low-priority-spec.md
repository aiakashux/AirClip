# AirClip Backend — Low Priority Gap Spec
**Date:** 2026-04-09
**Scope:** Future features — not required for v1 launch. Specs are design-level; implementation details deferred until prioritized.
**Note:** Some of these have high complexity or security implications. Review carefully before implementing.

---

## Gaps Covered

| # | Gap | Complexity | Notes |
|---|-----|------------|-------|
| 1 | Device trust/approval workflow | High | Security-critical; replaces current auto-trust |
| 2 | Server-side search | Medium | Limited scope — metadata only (can't search encrypted content) |
| 3 | Keyboard shortcuts sync | Low | Simple settings extension |
| 4 | E2E encryption toggle | High | Security risk if misimplemented; defer to v2 |
| 5 | Image / binary clipboard | High | Requires infrastructure changes; scope separately |

> **Auto-sync toggle** is already persisted via `POST /account/settings` (high-priority spec). No additional backend work needed — the `sync_enabled` field is stored and returned. Client enforces it locally.

---

## Gap 1 — Device Trust / Approval Workflow

### Current state
Backend auto-approves every device (`trust_status = "trusted"` in `create_device`). The frontend has the full pending-approval UI built and waiting.

### Design
Replace auto-trust with a manual approval flow:

**Registration:**
- New devices are created with `trust_status = "pending"`.
- The registering device is told to wait (`trust_status: "pending"` in response).
- Frontend polls `GET /devices/{device_id}/status` or uses WebSocket notification.

**Approval:**
- An already-trusted device on the same account calls `POST /devices/{device_id}/approve`.
- Backend sets `trust_status = "trusted"`, persists, and sends a WebSocket notification to the newly approved device: `{"type": "device_approved"}`.
- The approved device reconnects and starts syncing.

**Revocation:**
- Any trusted device can call `POST /devices/{device_id}/revoke`.
- Sets `trust_status = "revoked"`, deletes presence key.
- If device is currently connected, the WS handler checks trust on every `send_clipboard` call (already does this) — revoked device is silently dropped.

### New endpoints

```
POST /devices/{device_id}/approve   — account JWT, approves a pending device
POST /devices/{device_id}/revoke    — account JWT, revokes any device
GET  /devices/{device_id}/status    — device JWT OR account JWT, returns current trust_status
```

### Schema additions

```python
class DeviceStatusResponse(BaseModel):
    device_id: str
    trust_status: Literal["trusted", "pending", "revoked"]
    is_online: bool
```

### Storage changes

```python
# In create_device — change default
trust_status = "pending"    # was "trusted" (DEV MODE comment can be removed)

# New function
async def approve_device(account_id: str, device_id: str) -> Optional[dict]:
    return await update_device_trust(device_id, "trusted")

async def revoke_device(account_id: str, device_id: str) -> Optional[dict]:
    device = await update_device_trust(device_id, "revoked")
    await delete_presence(device_id)
    return device
```

### WebSocket notification
When a device is approved, send to the newly approved device if it is currently connected (polling):

```python
# In devices.py approve endpoint:
await manager.send_json(device_id, {"type": "device_approved"})
```

The client WebSocket listener handles `device_approved` → calls `onRefreshDevices()` → auto-connects.

### Security notes
- Only the device owner (same account) may approve or revoke.
- A device cannot approve itself.
- Revoked device JWTs remain technically valid until expiry, but the WS handler and clip delivery both check `trust_status` on every operation, so revocation is effective immediately.

---

## Gap 2 — Server-side Metadata Search

### Current state
`GET /clips/` accepts `after_seq` and `limit` only. Text search happens client-side on the local store. This is acceptable for MVP but doesn't scale to large histories or cross-device search.

### Design constraint
**Encrypted content cannot be searched server-side.** The backend only stores `ciphertext` (opaque bytes). Full-text search is architecturally impossible without a fundamental protocol change.

What CAN be filtered server-side:

| Filter param | Type | Description |
|---|---|---|
| `clip_type` | string | `url`, `code`, `color`, `text` |
| `from_device_id` | string | Filter clips from a specific device |
| `since_ms` | int | Unix ms timestamp — clips after this time |
| `until_ms` | int | Unix ms timestamp — clips before this time |

### New endpoint signature

```
GET /clips/?after_seq=0&limit=20&clip_type=url&from_device_id=abc&since_ms=0&until_ms=0
```

### Storage change — `storage.py`

```python
async def get_clip_history(
    account_id: str,
    device_id: str,
    after_seq: int,
    limit: int,
    clip_type: Optional[str] = None,
    from_device_id: Optional[str] = None,
    since_ms: Optional[int] = None,
    until_ms: Optional[int] = None,
) -> List[dict]:
    # ... existing logic ...
    for seq_str in all_seq_strs:
        if len(clips) >= limit:
            break
        data = await r.get(f"clip:{account_id}:{seq_str}")
        if data:
            clip = json.loads(data)
            if clip.get("to_device_id") != device_id:
                continue
            if clip_type and clip.get("clip_type") != clip_type:
                continue
            if from_device_id and clip.get("from_device_id") != from_device_id:
                continue
            created_ms = _iso_to_ms(clip.get("created_at", ""))
            if since_ms and created_ms < since_ms:
                continue
            if until_ms and created_ms > until_ms:
                continue
            clips.append(clip)
    return clips
```

### Route change — `clips.py`

```python
@router.get("/", response_model=List[ClipHistoryItem])
async def get_clips(
    after_seq:      int            = Query(0,    ge=0),
    limit:          int            = Query(20,   ge=1, le=100),
    clip_type:      Optional[str]  = Query(None),
    from_device_id: Optional[str]  = Query(None),
    since_ms:       Optional[int]  = Query(None),
    until_ms:       Optional[int]  = Query(None),
    auth: Tuple[str, str] = Depends(get_current_device),
) -> List[ClipHistoryItem]:
    account_id, device_id = auth
    clips = await storage.get_clip_history(
        account_id, device_id, after_seq, limit,
        clip_type=clip_type,
        from_device_id=from_device_id,
        since_ms=since_ms,
        until_ms=until_ms,
    )
    return [ClipHistoryItem(...) for c in clips]
```

---

## Gap 3 — Keyboard Shortcuts Sync

### Current state
Shortcuts are hardcoded in the macOS settings UI. No persistence, no cross-device sync.

### Design
Extend `AccountSettings` (already in high-priority spec) with a `shortcuts` JSON field.

### Schema addition — `schemas.py`

```python
class ShortcutBindings(BaseModel):
    open_airclip:   str = "cmd+shift+v"
    paste_last:  str = "cmd+shift+p"

class AccountSettings(BaseModel):
    sync_enabled:        bool             = True
    history_days:        int              = 30
    encryption_enabled:  bool             = True
    shortcuts:           ShortcutBindings = ShortcutBindings()
```

### Storage change — `storage.py`

```python
# In get_account_settings — update default:
return {
    "sync_enabled": True,
    "history_days": 30,
    "encryption_enabled": True,
    "shortcuts": {"open_airclip": "cmd+shift+v", "paste_last": "cmd+shift+p"},
}

# In update_account_settings — add shortcuts handling:
if "shortcuts" in patch and patch["shortcuts"] is not None:
    existing_shortcuts = settings.get("shortcuts", {})
    existing_shortcuts.update(patch["shortcuts"])
    settings["shortcuts"] = existing_shortcuts
```

No new endpoints needed — `GET/PATCH /account/settings` already handles it once the schema is updated.

---

## Gap 4 — E2E Encryption Toggle

### Current state
Frontend shows an "End-to-end encryption" toggle (local state only). Backend always handles ciphertext as opaque bytes with no knowledge of encryption state.

### Design recommendation
**Do not implement in v1.** Rationale:

1. **Security risk:** Allowing an unencrypted mode means the server could read clipboard content if an attacker controls the server or performs MITM. The threat model collapses.
2. **Protocol complexity:** The WebSocket protocol would need to distinguish encrypted vs plaintext payloads, and clients would need to handle both modes simultaneously.
3. **No real use case:** The stated reason for this toggle was convenience, but AirClip's core value proposition is "private by default." Disabling encryption undermines that.

### If implemented in the future
- Add `encryption_mode: Literal["e2e", "server_stored"]` to `AccountSettings`.
- Server-stored mode: clips stored as plaintext in Redis (requires access control review).
- All clients on the account must agree on the mode; mismatched modes fail silently or produce garbage.
- Requires a key renegotiation protocol.

**Verdict: Mark as `won't implement` for v1. Remove the toggle from the UI or display it as permanently enabled.**

---

## Gap 5 — Image / Binary Clipboard

### Current state
AirClip is text-only. `ClipType` enum covers `url`, `code`, `color`, `text`. No binary payload support anywhere in the stack.

### Scale of change
This is a significant feature that touches every layer:

**Protocol changes:**
- `send_clipboard` payload needs a `content_type` field (`"text/plain"`, `"image/png"`, etc.)
- Binary data must be base64-encoded or chunked for WebSocket transport
- Large images (>100KB) cannot be sent in a single WS frame without chunking

**Backend changes:**
- `ClipboardPayload` schema: add `content_type: str`, keep `ciphertext` as base64
- Storage: increase or remove `CLIP_HISTORY_MAX` limit for image types (they are larger)
- Consider a separate storage tier (Redis unsuitable for large blobs — use object storage like S3/R2)
- File upload endpoint: `POST /clips/upload` for out-of-band large payloads

**Client changes (both platforms):**
- macOS: monitor `NSPasteboard` for image types alongside text
- Android: `ClipboardMonitor` currently only emits text; needs MIME-type detection

### High-level spec (for scoping, not implementation)

```
POST /clips/upload
  Auth: device JWT
  Body: multipart/form-data { file: binary, content_type: str, to_device_ids: [str] }
  Response: { upload_id: str, message_ids: [str] }

GET /clips/download/{upload_id}
  Auth: device JWT (must be a recipient)
  Response: binary (encrypted blob)
```

**Storage:**
- Small images (<50KB): keep in Redis as base64 alongside text clips
- Large images: store in object storage; Redis entry contains a signed download URL
- TTL: same 30-min catch-up window for images; object storage object deleted after delivery

**Verdict: Scope as a separate project milestone. Do not mix with v1.**

---

## Summary

| Gap | Recommendation | Effort |
|-----|---------------|--------|
| Device trust/approval | Implement for v1.1 — blocks multi-device security model | 1–2 days |
| Server-side metadata search | Implement alongside clip_type (low effort, additive) | 0.5 days |
| Keyboard shortcuts sync | Trivial extension of settings spec — include in settings PR | 1 hour |
| E2E encryption toggle | Do not implement; remove toggle from UI or lock it on | 0 |
| Image/binary clipboard | Separate milestone; scope independently | 1–2 weeks |
