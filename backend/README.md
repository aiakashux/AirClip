# Clipr+ Backend

FastAPI server for Clipr+ — E2E encrypted clipboard sync.

## Setup

```bash
cd backend
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

## Environment Variables

Create a `.env` file in the `backend/` directory:

```
REDIS_URL=redis://localhost:6379
JWT_SECRET=your-secret-key
```

## Running

Start Redis, then:

```bash
uvicorn app.main:app --reload
```

The server starts at `http://localhost:8000`.

## API

### REST

- `POST /auth/register` — create account (email, password)
- `POST /auth/login` — login, returns JWT
- `POST /devices/register` — register a device (requires JWT)
- `GET /devices/` — list account devices (requires JWT)
- `POST /devices/{device_id}/approve` — approve a pending device (requires JWT)

### WebSocket

Connect to `/ws` with a device-scoped JWT via header:

```
Authorization: Bearer <device_token>
```

Client messages: `register_device`, `approve_device`, `send_clipboard`, `ack`
Server messages: `device_pending`, `deliver_clipboard`

See `docs/protocol.md` for full protocol spec.
