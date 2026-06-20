> Status: Historical review note.
> This note reflects an earlier backend-relay MVP review. Use it as context only; current product planning lives in `docs/PRODUCT_REQUIREMENTS.md`.

Project: AirClip (cross-platform E2E encrypted clipboard sync)
	•	MVP scope: Central relay server (cross-network)
	•	Non-goals (for now): cloud sync, multi-user sharing, images/files, iOS
	•	Hard requirements:
	•	End-to-end encryption (server cannot read clipboard content)
	•	Loop prevention (no infinite copy bounce)
	•	Device + account model must be sane
	•	Minimal data retention (avoid storing clipboard history server-side)
	•	Safe logging: no secrets, no clipboard plaintext in logs
	•	Current backend stack: FastAPI (Python), (add DB/redis if any)
	•	Threat model (baseline):
	•	Attacker on same Wi-Fi can sniff traffic
	•	Attacker can spoof device discovery packets
	•	Replay attacks on clipboard events
	•	Unauthorized device attempts to pair
	•	Token leakage / weak auth
	•	Definition of done for backend MVP:
	•	Pairing flow works with explicit user approval
	•	After pairing, devices can send encrypted clipboard payloads
	•	Server routes messages but cannot decrypt
	•	Dedupe/loop prevention works
	•	Basic rate limiting and abuse protections exist
