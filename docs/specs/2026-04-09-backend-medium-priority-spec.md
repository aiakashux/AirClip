# AirClip Backend — Medium Priority Gap Spec
**Date:** 2026-04-09
**Scope:** Gaps not covered in the high-priority spec that complete core UX flows
**Depends on:** `2026-04-09-backend-gap-spec.md` (high-priority spec must be implemented first for `account.py` to exist)

---

## Gaps Covered

| # | Gap | Complexity | Blocked by |
|---|-----|------------|------------|
| 1 | Delete individual clip | Low | Nothing |
| 2 | Account email change | Medium | Nothing |
| 3 | Account password change | Medium | Nothing |

---

## Gap 1 — Delete Individual Clip

### Problem
Users cannot remove a single sensitive clip from their catch-up buffer. The only option is "Clear all" (client-side SwiftData wipe). No REST endpoint exists to delete a clip by seq or message_id.

### Design Decision
- Delete by `message_id` — this is the identifier clients already have from `ClipHistoryItem.message_id`.
- Only the **recipient device** may delete a clip (device-scoped JWT required).
- Deletion removes the clip key **and** removes it from the per-account sorted set.
- If the message_id is not found (expired by TTL, already deleted, or wrong device), return 204 silently — idempotent.

### Schema — no changes needed
`message_id` is already in `ClipHistoryItem` and returned by `GET /clips/`.

### Storage additions — `storage.py`

```python
async def delete_clip_by_message_id(account_id: str, message_id: str) -> bool:
    """
    Remove a clip from the history buffer by message_id.
    Scans the per-account sorted set (bounded by CLIP_HISTORY_MAX) and deletes
    the matching clip key + set entry.
    Returns True if found and deleted, False if not found.
    """
    r = get_redis()
    hist_key = f"clips:hist:{account_id}"
    all_seqs = await r.zrange(hist_key, 0, -1)

    for seq_str in all_seqs:
        clip_key = f"clip:{account_id}:{seq_str}"
        data = await r.get(clip_key)
        if not data:
            continue
        clip = json.loads(data)
        if clip.get("id") == message_id:
            await r.delete(clip_key)
            await r.zrem(hist_key, seq_str)
            return True
    return False
```

### Route addition — `clips.py`

```python
@router.delete("/{message_id}", status_code=204)
async def delete_clip(
    message_id: str,
    auth: Tuple[str, str] = Depends(get_current_device),
):
    """
    Delete a single clip from the catch-up buffer.
    Only the recipient device (identified by device JWT) may delete its own clips.
    Returns 204 whether found or not (idempotent).
    """
    account_id, device_id = auth
    await storage.delete_clip_by_message_id(account_id, message_id)
    # No 404 — idempotent deletion
```

### Updated API surface

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| DELETE | `/clips/{message_id}` | device JWT | Delete a single clip from catch-up buffer |

---

## Gap 2 — Account Email Change

### Problem
The frontend displays email (read-only). Users cannot update it. No `PUT /account/email` endpoint exists. The current email is stored in `account:{account_id}` and indexed by `account:email:{email}`.

### Design Decision
- Requires **current password** for confirmation (prevents account takeover if token is leaked).
- New email must not already exist on another account.
- On success: updates the account record AND migrates the email→account_id index key.
- Does NOT invalidate existing JWTs (no token rotation in v1 — acceptable for MVP).

### Schema additions — `schemas.py`

```python
class EmailChangeRequest(BaseModel):
    new_email: EmailStr
    current_password: str
```

### Storage additions — `storage.py`

```python
async def update_account_email(account_id: str, new_email: str) -> Optional[dict]:
    """
    Update account email. Caller is responsible for validating password and
    checking email uniqueness before calling this.
    Migrates the email index key atomically (best-effort; Redis has no transactions
    without Lua scripts, but the window for inconsistency is negligible for MVP).
    """
    account = await get_account_by_id(account_id)
    if not account:
        return None
    r = get_redis()
    old_email = account["email"]
    account["email"] = new_email
    await r.set(f"account:{account_id}", json.dumps(account))
    await r.delete(f"account:email:{old_email}")
    await r.set(f"account:email:{new_email}", account_id)
    return account
```

### Route addition — `account.py`

```python
from .auth import verify_password

@router.put("/email", response_model=AccountProfile)
async def change_email(
    req: EmailChangeRequest,
    account: dict = Depends(get_current_user),
):
    # Verify password
    if not verify_password(req.current_password, account["password_hash"]):
        raise HTTPException(status_code=401, detail="Incorrect password")

    # Check new email not taken
    existing = await storage.get_account_by_email(str(req.new_email))
    if existing and existing["id"] != account["id"]:
        raise HTTPException(status_code=409, detail="Email already in use")

    updated = await storage.update_account_email(account["id"], str(req.new_email))
    return AccountProfile(
        account_id = updated["id"],
        email      = updated["email"],
        plan       = updated.get("plan", "free"),
        created_at = updated["created_at"],
    )
```

---

## Gap 3 — Account Password Change

### Problem
No `PUT /account/password` endpoint exists. Users cannot change their password after registration.

### Design Decision
- Requires **current password** for confirmation.
- Minimum 8 characters enforced server-side (mirrors frontend hint).
- Does NOT invalidate existing device tokens in v1 (acceptable for MVP; can add token revocation list later).

### Schema additions — `schemas.py`

```python
class PasswordChangeRequest(BaseModel):
    current_password: str
    new_password: str
```

### Storage additions — `storage.py`

```python
async def update_account_password(account_id: str, new_password_hash: str) -> bool:
    account = await get_account_by_id(account_id)
    if not account:
        return False
    account["password_hash"] = new_password_hash
    r = get_redis()
    await r.set(f"account:{account_id}", json.dumps(account))
    return True
```

### Route addition — `account.py`

```python
from .auth import hash_password, verify_password

@router.put("/password", status_code=204)
async def change_password(
    req: PasswordChangeRequest,
    account: dict = Depends(get_current_user),
):
    if not verify_password(req.current_password, account["password_hash"]):
        raise HTTPException(status_code=401, detail="Incorrect password")
    if len(req.new_password) < 8:
        raise HTTPException(status_code=422, detail="Password must be at least 8 characters")
    await storage.update_account_password(account["id"], hash_password(req.new_password))
```

---

## Complete API additions (this spec only)

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| DELETE | `/clips/{message_id}` | device JWT | Delete a single clip |
| PUT | `/account/email` | account JWT | Change account email |
| PUT | `/account/password` | account JWT | Change account password |

---

## Implementation order

1. `storage.py` — `delete_clip_by_message_id`, `update_account_email`, `update_account_password`
2. `clips.py` — `DELETE /clips/{message_id}`
3. `account.py` — `PUT /account/email`, `PUT /account/password`

No changes needed to `schemas.py` for gap 1. Add `EmailChangeRequest` and `PasswordChangeRequest` to `schemas.py` before step 3.
