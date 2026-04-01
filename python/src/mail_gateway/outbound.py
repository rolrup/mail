import httpx
import structlog

from .config import Settings
from .security import get_outbound_rate_limiter
from .urbit_client import EyreClient

log = structlog.get_logger()


async def send_email(
    provider: str,
    api_key: str,
    from_addr: str,
    to_addr: str,
    subject: str,
    body: str,
    cc: list[str] | None = None,
    reply_to: str = "",
) -> None:
    """Send an email via external provider API."""
    cc = cc or []
    async with httpx.AsyncClient(timeout=15) as client:
        if provider == "resend":
            payload = {
                "from": from_addr,
                "to": [to_addr],
                "subject": subject,
                "text": body,
            }
            if cc:
                payload["cc"] = cc
            if reply_to:
                payload["reply_to"] = reply_to
            resp = await client.post(
                "https://api.resend.com/emails",
                headers={"Authorization": f"Bearer {api_key}"},
                json=payload,
            )
        elif provider in ("mailgun", "mailgun-eu"):
            # api_key format: "key:domain" e.g. "key-xxx:mg.ships.to"
            parts = api_key.split(":", 1)
            key = parts[0]
            domain = parts[1] if len(parts) > 1 else "mg.example.com"
            host = "api.eu.mailgun.net" if provider == "mailgun-eu" else "api.mailgun.net"
            data = {
                "from": from_addr,
                "to": to_addr,
                "subject": subject,
                "text": body,
            }
            if cc:
                data["cc"] = ", ".join(cc)
            if reply_to:
                data["h:Reply-To"] = reply_to
            resp = await client.post(
                f"https://{host}/v3/{domain}/messages",
                auth=("api", key),
                data=data,
            )
        elif provider == "sendgrid":
            personalization = {"to": [{"email": to_addr}]}
            if cc:
                personalization["cc"] = [{"email": addr} for addr in cc]
            sg_payload = {
                    "personalizations": [personalization],
                    "from": {"email": from_addr},
                    "subject": subject,
                    "content": [{"type": "text/plain", "value": body}],
                }
            if reply_to:
                sg_payload["reply_to"] = {"email": reply_to}
            resp = await client.post(
                "https://api.sendgrid.com/v3/mail/send",
                headers={
                    "Authorization": f"Bearer {api_key}",
                    "Content-Type": "application/json",
                },
                json=sg_payload,
            )
        else:
            raise ValueError(f"Unknown provider: {provider}")

        resp.raise_for_status()
        log.info("outbound.sent", to=to_addr, cc=cc, provider=provider)


async def start_outbound_listener(eyre: EyreClient, settings: Settings) -> None:
    """Subscribe to the gateway ship and forward outbound emails."""
    await eyre.subscribe("mail-gateway", "/outbound")
    log.info("outbound.subscribed")

    async for event in eyre.event_stream():
        try:
            sse_id = event.get("sse_id")
            if sse_id is not None:
                await eyre.ack(sse_id)

            json_data = event.get("json")
            log.info("outbound.event_raw", keys=list(event.keys()), response=event.get("response"), mark=event.get("mark"), has_json=json_data is not None, json_type=type(json_data).__name__ if json_data else None, json_keys=list(json_data.keys()) if isinstance(json_data, dict) else None)
            if not json_data:
                continue
            # Accept both %mail-message and %json marks from gateway
            if not isinstance(json_data, dict) or "to" not in json_data:
                log.info("outbound.skipped", reaвson="not a message dict", json_data=str(json_data)[:200])
                continue

            msg = json_data if isinstance(json_data, dict) else {}
            to = msg.get("to", {})
            from_ = msg.get("from", {})

            # Only handle external recipients
            if "ext" not in to:
                continue

            to_addr = to["ext"]

            # Block outbound to own domain — would create email loop
            if settings.mail_domain and to_addr.endswith(f"@{settings.mail_domain}"):
                log.warning("outbound.loop_blocked", to=to_addr, domain=settings.mail_domain)
                continue

            # Outbound rate limit — prevent abuse via email API
            outbound_limiter = get_outbound_rate_limiter()
            from_ship = from_.get("urbit", "unknown")
            from_ship_patp = f"~{from_ship.lstrip('~')}"  # normalized ~ship
            if not outbound_limiter.check(from_ship):
                log.warning("outbound.rate_limited", ship=from_ship, to=to_addr)
                msg_id = msg.get("id", "")
                try:
                    await eyre.poke_with_retry(
                        app="mail-gateway",
                        mark="mail-gateway-action",
                        json_data={"delivery-failed": {"id": msg_id, "ship": from_ship_patp, "reason": "Rate limit exceeded — try again later"}},
                    )
                except Exception:
                    log.exception("outbound.rate_limit_notify_failed")
                continue
            # Translate from: ~ship → ship@MAIL_DOMAIN
            # Check for sendas:alias label — use alias as from address
            from_ship = from_ship.lstrip("~")
            labels = msg.get("labels", [])
            send_alias = None
            other_labels = []
            for label in labels:
                if label.startswith("sendas:"):
                    send_alias = label[7:]  # strip "sendas:" prefix
                else:
                    other_labels.append(label)
            if send_alias:
                from_local = send_alias
            elif other_labels:
                from_local = f"{from_ship}.{'.'.join(other_labels)}"
            else:
                from_local = from_ship
            from_addr = f"{from_local}@{settings.mail_domain}"

            subject = msg.get("subject", "")
            body = msg.get("body", "")

            # Extract CC addresses from message
            cc_list = []
            for cc_contact in msg.get("cc", []):
                if isinstance(cc_contact, dict) and "ext" in cc_contact:
                    cc_list.append(cc_contact["ext"])

            # Extract Reply-To from message
            reply_to_contact = msg.get("reply-to", {})
            reply_to = reply_to_contact.get("ext", "") if isinstance(reply_to_contact, dict) else ""

            await send_email(
                provider=settings.outbound_provider,
                api_key=settings.outbound_api_key,
                from_addr=from_addr,
                to_addr=to_addr,
                subject=subject,
                body=body,
                cc=cc_list,
                reply_to=reply_to,
            )

            # Confirm delivery back to the ship
            await eyre.poke_with_retry(
                app="mail-gateway",
                mark="mail-gateway-action",
                json_data={"delivered": msg.get("id", "")},
            )

        except Exception as exc:
            log.exception("outbound.error")
            msg_id = msg.get("id", "")
            reason = str(exc)[:200]
            try:
                await eyre.poke_with_retry(
                    app="mail-gateway",
                    mark="mail-gateway-action",
                    json_data={"delivery-failed": {"id": msg_id, "ship": from_ship_patp, "reason": reason}},
                )
            except Exception:
                log.exception("outbound.error_notify_failed")
