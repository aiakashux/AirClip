# AirClip Backend

Status: legacy / inactive for the current LAN-first MVP.

The backend source remains in the repository from an earlier relay-based product direction. The current Mac + Android MVP syncs clipboard content directly over LAN and does not use this backend as the active clipboard transport.

## Current Guidance

Do not use this backend README as the source of truth for current AirClip sync behavior.

Use:

1. `docs/PRODUCT_REQUIREMENTS.md`
2. `docs/ROADMAP_STATUS.md`
3. `docs/architecture.md`
4. `docs/protocol.md`

## Legacy Purpose

The backend was originally intended for:

1. Account registration/login.
2. Device registration.
3. Device approval.
4. WebSocket relay.
5. Redis-backed short-term history and catch-up.

Those assumptions are not active in the LAN-first MVP.

## If Reactivated Later

If cloud relay returns, it should be:

1. Explicit opt-in.
2. End-to-end encrypted.
3. Sensitive-policy aware.
4. Clear about remote-network status.
5. Re-documented before implementation resumes.
