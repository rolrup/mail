# Python Bridge — ~mail Gateway

FastAPI service that bridges email APIs and an Urbit ship running `%mail-gateway`.

## Requirements

- Python 3.12+
- Running Urbit ship with `%mail` desk installed and gateway enabled
- Email API account (Mailgun, Resend, or SendGrid)
- Cloudflare Worker forwarding inbound email (see `cf-worker/`)

## Setup

```bash
cp .env.example .env
# Edit .env with your configuration

# Using Docker:
docker compose up -d

# Or directly:
pip install -e .
python -m mail_gateway.main
```

## Configuration

See `.env.example` for all options. Key settings:

| Variable | Description |
|----------|-------------|
| `URBIT_URL` | Ship Eyre URL (e.g. `http://localhost:8080`) |
| `URBIT_CODE` | Ship +code for authentication |
| `URBIT_SHIP` | Ship @p without ~ |
| `MAIL_DOMAIN` | Email domain (e.g. `urbitmail.net`) |
| `WORKER_SECRET` | Shared secret with Cloudflare Worker |
| `OUTBOUND_PROVIDER` | `mailgun`, `mailgun-eu`, `resend`, or `sendgrid` |
| `OUTBOUND_API_KEY` | API key for outbound email |

## Files

| File | Purpose |
|------|---------|
| `main.py` | FastAPI app, routes, lifespan |
| `inbound.py` | POST /v1/inbound — email → Urbit |
| `outbound.py` | SSE subscriber — Urbit → email API |
| `urbit_client.py` | Eyre HTTP client (poke, subscribe, scry) |
| `security.py` | Rate limiting, worker auth |
| `sanitizer.py` | HTML sanitization (nh3) |
| `models.py` | Data models, @p parsing, @uv conversion |
| `config.py` | Pydantic settings from env |

## Endpoints

| Method | Path | Description |
|--------|------|-------------|
| POST | `/v1/inbound` | Receive email from Cloudflare Worker |
| GET | `/` | Landing page (HTML) |
| GET | `/health` | Health check |

## Rate Limiting

- Per-sender: 30/hour (inbound email)
- Per-IP: 60/hour (inbound requests)
- Per-ship outbound: 10/hour
