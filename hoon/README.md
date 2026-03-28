# Hoon Desk — ~mail

Urbit desk containing all Gall agents, UI, and CLI tools.

## Agents

| Agent | Purpose |
|-------|---------|
| `mail-client` | Mailbox, compose, web UI, forwarding, settings |
| `mail-gateway` | Relay between Urbit and external email, whitelist, aliases |
| `mail-registry` | Public gateway directory with DNS verification |
| `mail-push` | W3C Web Push notifications (VAPID + AES-GCM) |
| `mail-recovery` | Hourly auto-backup, crash recovery from JSON |

## Installation

On any Urbit ship:

```
|install ~dister-poster-midnev %mail
```

For development on a fake ship:

```
|merge %mail our %landscape, =gem %only-that
|mount %mail
cp -r hoon/* /path/to/pier/mail/
|commit %mail
```

## File Structure

```
app/                 Gall agents
sur/                 Type definitions (state, actions, gateway types)
lib/                 Utilities (JSON, forwarding, UI templates)
  mail-client.hoon   JSON serialization, forwarding engine, helpers
  mail-ui.hoon       Page layout, inbox/sent tables, mobile cards, CSS
  mail-ui-settings.hoon  Settings, forwarding rules, icon config
  mail-ui-gateway.hoon   Gateway admin, whitelist, aliases, pricing
js/mail.js           Client-side JS (markdown, polling, drafts, validation)
mar/mail/            Mark files (message, action, gateway-action, update)
gen/mail/            CLI generators (inbox, sent, read, unread, labels)
img/                 PNG icons, SVG tile
doc/                 In-app documentation (udon)
```

## Web UI

Server-rendered HTML via Sail. No SPA framework. All pages at `/mail/*`.

| Path | Description |
|------|-------------|
| `/mail` | Inbox (search, labels, pagination) |
| `/mail/sent` | Sent messages |
| `/mail/compose` | Compose (reply/forward/new) |
| `/mail/read?id=` | Read message |
| `/mail/settings` | Account, aliases, forwarding, icon |
| `/mail/gateway` | Gateway admin panel |
| `/mail/help` | Documentation |
| `/mail/backup` | Backup & restore |
| `/mail/api/status` | JSON: unread count, total (ETag) |
| `/mail/api/avatar?ship=` | JSON: avatar URL from %contacts |

## State

Current version: `state-20`. Versioned state with migration support. Auto-backup to `%mail-recovery` every hour.

Key state fields: inbox, sent, trash (maps of envelopes), gateway config, forwarding rules (conditions DSL), aliases, custom icon URL.

## CLI

```
+mail!mail/inbox          List inbox
+mail!mail/sent           List sent
+mail!mail/read <@uv>     Read message by ID
+mail!mail/unread         Unread count
+mail!mail/labels         Label statistics
```
