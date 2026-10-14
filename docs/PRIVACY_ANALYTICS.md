# Privacy-first analytics

Analytics is **off by default**. Users can enable or disable it in Settings. Turning it off deletes queued counters. Clipboard sync never depends on analytics or update services.

One anonymous aggregate payload may be sent per day. It contains no persistent identifier and no event times:

| Field | Value |
|---|---|
| `schemaVersion` | Payload format number (`1`) |
| `appVersion` | Airclip's public version |
| `platform` | `macos` or `android` |
| `osMajor` | Major OS release only |
| `counts` | Aggregate counts for the events below |

Allowed event counters: `pairing_success`, `pairing_failure`, `first_transfer` (once per installation after opt-in), `transfer_failure`, `update_check`, `update_available`, `update_opened`, and `update_failure`.

Airclip never sends clipboard content, images, URLs, domains, content hashes, device names or identifiers, Wi-Fi names, cryptographic material, or event timestamps. The Vercel endpoint validates this fixed schema and writes accepted aggregate payloads to deployment logs; Vercel may independently retain ordinary request metadata such as IP address and request time under its own policies.
