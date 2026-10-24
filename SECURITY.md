# Security Policy

## Scope

Airclip handles clipboard data — which can include passwords, OTPs, and sensitive personal content. Security issues are taken seriously.

## Supported Versions

| Version | Supported |
|---------|-----------|
| Latest on `main` | ✅ |
| Older commits | ❌ |

## Reporting a Vulnerability

**Do not open a public GitHub issue for security vulnerabilities.**

Email: **newajmazumder52@gmail.com**

Include:
- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Your suggested fix (optional)

You'll get a response within 72 hours. Please allow time to patch before public disclosure.

## Security Model

- All clipboard packets are encrypted with **NaCl sealed boxes** before leaving the device
- Device identity keys are generated locally and never leave the device
- No clipboard content is sent to any server — LAN only
- Clipboard contents are not classified or filtered before sync; users control transfer through the sync mode and paired-device membership
- Pairing uses a QR code or short-lived six-digit code.
- Mac private keys are stored in Keychain; legacy preference keys migrate only after verified persistence. Android uses Keystore-backed encrypted preferences.
- Reconnect public keys are pinned to pairing records. Sealed boxes protect payload confidentiality but do not authenticate the sender.

## Pre-release limitations

The current LAN protocol lacks cryptographic proof of peer identity and authenticated/replay-protected control messages. Pairing messages use an unencrypted WebSocket transport. These are release blockers, not a production-grade authenticated channel. See [the security and readiness audit](docs/audits/2026-10-21-security-readiness.md) before distributing a release.
