# AGENTS.md

This file defines how AI coding agents should work inside the Clipr+ repository.

It exists to protect the project architecture, reduce accidental regressions, and keep changes understandable.

Agents must follow these rules before making code changes.

---

# 1. Project Purpose

Clipr+ is a secure cross-device clipboard sync system.

Current MVP goal:

> Copy text on Mac → it appears on Android securely and reliably.

The current MVP supports:

- Mac clipboard sender
- Android clipboard receiver + local history
- backend relay server
- Redis short-term history
- WebSocket real-time delivery
- offline catch-up within retention window

This repository is still in MVP stage.  
Agents must prefer **minimal safe changes** over broad refactors.

---

# 2. Core Architecture Rules

Agents must preserve these architecture boundaries.

## 2.1 Backend owns ordering

The backend is the only layer that assigns sequence numbers.

Rules:

- sequence numbers are assigned by backend only
- clients must never invent their own sequence numbers
- ordering logic must remain based on backend seq values
- `lastSeenSeq` must be treated as client-side state derived from backend ordering

---

## 2.2 Clients own encryption and decryption

Encryption and decryption happen on clients, not on the server.

Rules:

- sender client encrypts clipboard payload before network transmission
- receiver client decrypts payload locally
- backend only relays encrypted data
- backend must never require plaintext clipboard to function

---

## 2.3 Server stores short-lived data only

Server is a temporary relay, not permanent storage.

Current rules:

- Redis history retention is short-lived
- server history is capped
- local clipboard history is owned by each client device
- UI should use client-local history, not server history, as the source of truth for display

---

## 2.4 Local history is client truth for UI

Clipboard list shown to users must come from local client state.

Rules:

- Android clipboard history UI reads local history
- Mac clipboard history UI reads local history
- server history is only for catch-up / recovery
- agents must not redesign UI to depend directly on server as the primary history source

---

# 3. Security Rules

These rules are mandatory.

## 3.1 Never log plaintext clipboard content

Agents must never add logs that print clipboard text.

Allowed logs:

- sequence numbers
- counts
- lengths
- hashes
- device ids
- event types
- connection state

Not allowed:

- plaintext clipboard
- decoded ciphertext
- private keys
- device tokens
- account tokens
- raw secrets

---

## 3.2 Never log secrets

Do not log:

- JWT secret
- access tokens
- private keys
- raw encrypted key storage
- API credentials

If logging is necessary, redact or hash.

---

## 3.3 Do not weaken token handling

Rules:

- WebSocket auth must use header-based bearer token
- do not move tokens into query params
- account token and device token must remain separate concepts
- do not reuse one token type for a different responsibility

---

## 3.4 Key persistence must survive normal restart

For clients that decrypt messages, persisted key material must survive app restart if the product requires catch-up after restart.

Agents must not introduce changes that cause decrypt keys to disappear on normal reopen.

---

# 4. Clipboard Sync Rules

These are product-critical behaviors.

## 4.1 Real-time sync

When online:

- copied clipboard items should be delivered in real time to trusted devices

## 4.2 Offline catch-up

When a device reconnects:

- it should compare `lastSeenSeq` vs backend `latest_seq`
- it should fetch missed items
- it should merge them into local history
- it should not replace local history blindly

## 4.3 Local history cap

Current MVP rule:

- keep newest **20** clipboard items locally
- oldest items are trimmed first

Agents must preserve this unless explicitly asked to change product behavior.

## 4.4 Server retention

Current MVP rule:

- short retention window
- capped history size
- used only for reconnect catch-up

Agents must not silently expand or redesign retention policy.

## 4.5 Tap-to-copy must stay local

When a user taps a history item on Android:

- item should copy to local system clipboard
- it should not automatically re-send to other devices
- loop-prevention logic must remain intact

---

# 5. Code Change Rules

These rules define how agents should edit code.

## 5.1 Prefer minimal diffs

Always make the smallest safe change.

Do not:

- refactor unrelated modules
- rename large groups of files without reason
- rewrite working logic just to make code "cleaner"

Do:

- fix root cause directly
- change only files relevant to the issue
- explain why the bug happened before patching

---

## 5.2 Do not mix diagnosis and broad refactor

When debugging runtime issues:

1. diagnose exact failing path
2. confirm root cause
3. apply focused fix

Do not use debugging as an excuse to restructure the whole codebase.

---

## 5.3 Preserve behavior unless product rule is explicitly changing

If the product behavior is not being intentionally changed:

- do not alter protocol
- do not alter sequence semantics
- do not alter Redis key model
- do not alter encryption rules
- do not alter token roles

---

## 5.4 Keep UI logic and business logic reasonably separated

UI files should not absorb major sync or protocol logic unless the platform/framework strongly requires it.

Avoid:

- putting sync state machines directly into UI rendering code
- hiding important business rules inside click handlers
- duplicating protocol logic in multiple UI components

---

## 5.5 Avoid duplicated send/fetch logic

There should be one clear path for:

- sending clipboard
- reconnect catch-up
- merging local history
- suppressing re-send loops

If multiple paths exist, agents should prefer consolidating into a shared helper only when asked or when fixing a real bug.

---

# 6. Naming Rules

Use plain, direct names.

Prefer:

- `sendClipboard`
- `fetchMissedClips`
- `lastSeenSeq`
- `historyStore`
- `wsClient`
- `copyHistoryItem`
- `deviceToken`

Avoid vague names like:

- `orchestrator`
- `artifact`
- `managerService`
- `reconciler`
- `syncCoordinatorEngine`

Function names should describe **what happens**, not sound impressive.

Comments should explain **behavior**, not repeat code.

---

# 7. Performance Rules

Do not prematurely optimize, but protect hot paths.

## 7.1 Hot paths in this repo

Main hot paths are:

- clipboard monitoring
- websocket receive/send
- catch-up fetch loop
- local history merge
- Android UI list rendering

## 7.2 Avoid waste in hot paths

Avoid:

- repeated full sorting when not needed
- duplicate network calls
- repeated disk reads inside loops
- unnecessary full-state rebuilds
- repeated hash calculations if value already known

## 7.3 Respect current caps

Current MVP caps are part of performance control:

- local history cap
- server history cap
- short retention window

Do not silently remove these constraints.

---

# 8. Logging Rules

Logs should help debugging without leaking user data.

Preferred log style:

- short
- structured
- event-oriented
- safe to share internally

Examples of good logs:

- `WS connected`
- `hello latest_seq=125`
- `catch-up page=0 count=5`
- `history merged items=3`
- `clipboard send skipped knownHash=...`

Examples of bad logs:

- raw clipboard text
- full decrypted preview in logs
- full token values
- raw key data

Temporary debug logs are allowed during diagnosis, but agents should remove or reduce them after the issue is fixed unless the log is broadly useful.

---

# 9. Documentation Rules

When changing architecture-relevant behavior, update docs if needed.

Update docs when changing:

- protocol
- sequence rules
- token usage
- history limits
- encryption flow
- reconnect behavior

Relevant docs:

- `README.md`
- `docs/architecture.md`
- `docs/protocol.md`
- `docs/security.md`
- `docs/mvp-scope.md`

Do not leave docs knowingly inconsistent with code after major behavior changes.

---

# 10. Testing Expectations

Agents should think in terms of behavior verification.

For sync-related changes, verify at least:

## 10.1 Live sync
- copy on Mac
- item appears on Android

## 10.2 Offline catch-up
- Android offline
- copy items on Mac
- reopen Android
- missed items appear automatically

## 10.3 History trimming
- exceed 20 items
- oldest items removed
- newest items remain

## 10.4 Loop prevention
- tap Android history item
- copy locally
- do not resend to server

## 10.5 No plaintext logs
- inspect logs
- ensure clipboard text is not printed

Agents should include a short manual QA checklist when making non-trivial sync changes.

---

# 11. Tooling Guidance

This repo should eventually adopt automated standards tooling.

Recommended, but may not yet be fully installed:

## Backend
- `ruff`
- `black`

## Mac / TypeScript / Electron
- `eslint`
- `prettier`

## Android / Kotlin
- `ktlint`
- `detekt`

Until tooling is fully added, agents must be extra careful to follow local style and avoid introducing inconsistency.

---

# 12. Known MVP Constraints

Agents must respect current MVP boundaries.

Current MVP intentionally does NOT include:

- Windows client
- iOS client
- permanent cloud clipboard archive
- image/file clipboard sync
- advanced device management UI
- enterprise-scale infrastructure

Do not add features outside MVP scope unless explicitly requested.

---

# 13. Preferred Agent Workflow

Agents should use this workflow for non-trivial work:

## Step 1 — Understand
Read relevant files and documentation first.

## Step 2 — Diagnose
State root cause clearly.

## Step 3 — Patch
Make the smallest safe fix.

## Step 4 — Verify
Explain how to test behavior.

## Step 5 — Document
Update docs if protocol/architecture changed.

This workflow is preferred over “big cleanup” style edits.

---

# 14. When to Ask for Clarification

Ask for clarification only when:

- product behavior is genuinely ambiguous
- two possible fixes would change user-visible behavior differently
- security tradeoff is significant

Do not ask for clarification just because the repo is messy.  
Make the best focused technical judgment you can.

---

# 15. Summary of Non-Negotiables

Agents must preserve these rules:

- backend assigns seq
- clients encrypt/decrypt
- no plaintext clipboard logs
- no tokens in query params
- local history is client UI truth
- tap-to-copy must not resend
- catch-up must work after reconnect
- local history cap is 20
- changes should be minimal and targeted

If a proposed change conflicts with these rules, stop and explain the conflict before proceeding.