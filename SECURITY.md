# Security Policy

## Scope

AirClip handles clipboard data — which can include passwords, OTPs, and sensitive personal content. Security issues are taken seriously.

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
- Sensitive content detection (passwords, OTPs, card numbers) runs locally before any sync decision
- Pairing is done via QR code — no unauthenticated device can receive clips
