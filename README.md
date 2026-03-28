# ~mail — Email for Urbit

Urbit Mail Gateway (UMG) is a system that bridges email and the Urbit network. It consists of three components that work together to enable ships to send and receive standard email.

## Architecture

```
Internet Email (SMTP)
        ↓
Cloudflare Email Routing + Worker (cf-worker/)
        ↓ HTTPS POST
Python Bridge (python/)
        ↓ Ames poke
Urbit Ship — Gateway Agent (hoon/app/mail-gateway.hoon)
        ↓ Ames poke
Urbit Ship — Client Agent (hoon/app/mail-client.hoon)
```

Outbound path is reversed: client → gateway → bridge → email API (Mailgun/Resend/SendGrid). Currently only Mailgun was tested.

### Components

**`hoon/`** — Urbit desk installed on user ships. Contains 5 Gall agents:
- `mail-client` — mailbox (inbox/sent/trash), compose, forwarding rules, web UI (Sail)
- `mail-gateway` — relay between Urbit and external email, whitelist, alias management
- `mail-registry` — public directory of gateways with DNS verification
- `mail-push` — W3C Web Push notifications (VAPID + AES-GCM)
- `mail-recovery` — hourly JSON backups with crash recovery

**`python/`** — Bridge service running on a VPS alongside the gateway ship. Handles:
- Inbound: receives sanitized email from Cloudflare Worker, delivers to ship via Ames
- Outbound: subscribes to gateway's `/outbound` path, sends via email API
- Rate limiting, HTML sanitization (nh3), content security

**`cf-worker/`** — Cloudflare Email Worker. Receives raw SMTP via Email Routing, extracts headers/body, POSTs JSON to the bridge. Lightweight (~100 lines TypeScript). 10ms runtime limit by CF.

## Installation

### Client (end user)

```
|install ~dister-poster-midnev %mail
```

Web UI available at `/mail` on your ship.

### Gateway (operator)

Requires: VPS, domain with DNS control, Cloudflare account (free tier), email API account.

1. Deploy Hoon desk on a ship (see `hoon/README.md`)
2. Deploy Python bridge (see `python/README.md`)
3. Deploy Cloudflare Worker (see `cf-worker/README.md`)
4. Configure DNS: MX → Cloudflare, TXT `_urbit-gw.domain` for registry verification

## State & Data

All mail is stored locally on the user's ship in the agent state. No external database. State versioned (`state-20`), auto-backup hourly to `%mail-recovery` agent as JSON. Recovery on crash: JSON restore → noun cast → reinit.

Forwarding rules support conditions: `label, @alias, -exclude` (comma-separated). Labels are propagated through forwarding chains.

## Limitations

- Outbound email limited by email API tier (Mailgun free: 100/day)
- Per-user rate limit: 10 outbound/hour
- No attachments (plain text / markdown only)
- iOS PWA icon caching is aggressive (Apple limitation)
- `%contacts` avatar integration requires Tlon Groups desk

## Tech Stack

- Hoon (Gall agents, Sail SSR, Eyre HTTP)
- Python 3.12 (FastAPI, httpx, nh3)
- TypeScript (Cloudflare Workers)
- Vanilla JS (~900 lines, no framework)

## License

MIT

## Credits

- Web Push implementation: [urbit-web-push](https://github.com/will-hanlen/urbit-web-push) by ~migrev-dolseg