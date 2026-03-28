# Cloudflare Email Worker — ~mail

Cloudflare Worker that receives inbound email via Email Routing and forwards to the Python bridge as HTTPS POST.

## Requirements

- Cloudflare account (free tier)
- Domain with Cloudflare DNS
- Email Routing enabled on domain

## Setup

```bash
npm install
cp wrangler.example.toml wrangler.toml
# Edit wrangler.toml with your bridge URL and secret

npx wrangler deploy
```

## Configuration

Edit `wrangler.toml`:

| Variable | Description |
|----------|-------------|
| `BRIDGE_URL` | Python bridge URL (e.g. `https://bridge.example.com/v1/inbound`) |
| `WORKER_SECRET` | Shared secret for authenticating with bridge |

## How it works

1. Cloudflare Email Routing catches all email for your domain
2. Worker extracts: from, to, subject, body (text + HTML), message-id, reply-to
3. POSTs JSON to bridge with Bearer token auth
4. Bridge handles sanitization, @p lookup, and delivery to ship
