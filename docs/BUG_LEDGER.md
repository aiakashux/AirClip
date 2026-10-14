# Airclip Bug Ledger

This is the running list for bugs reported in this conversation. Add new reports here before implementation.

| ID | Report | Status | Fix |
|---|---|---|---|
| BUG-001 | Clear History only cleared the current device; offline devices later restored old clips. | Implemented; device QA pending | Clear cutoffs now sync to connected peers and persist for reconnecting peers. |
| BUG-002 | Individually deleted clips returned after peer history backfill. | Implemented; device QA pending | Stable clip IDs plus persisted deletion tombstones prevent resurrection, including legacy ID mismatches. |
| BUG-003 | A removed device could reconnect without scanning a QR code or entering the pairing code. | Implemented; device QA pending | Authentication now requires both the matching space ID and membership in the local paired-device registry. |
| BUG-004 | The macOS clip context menu was visually oversized. | Implemented; visual QA pending | The menu now uses compact native macOS menu icons instead of custom resizable views. |

## Verification checklist

- Clear history while one peer is offline; reconnect it and confirm both histories remain empty.
- Delete one clip while one peer is offline; reconnect it and confirm only that clip stays deleted.
- Remove a device, then put both devices online; confirm it cannot reconnect until QR/code pairing succeeds.
- Two-finger-click a Mac history row; confirm the menu matches standard macOS menu sizing.
