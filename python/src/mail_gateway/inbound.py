import structlog
from fastapi import APIRouter, Depends, HTTPException, Request

from .config import get_settings
from .models import InboundEmail, MailMessage, parse_recipient_with_labels
from .sanitizer import sanitize
from .security import get_ip_rate_limiter, get_rate_limiter, verify_worker_secret

log = structlog.get_logger()

router = APIRouter()


@router.post(
    "/v1/inbound",
    status_code=202,
    dependencies=[Depends(verify_worker_secret)],
)
async def inbound(request: Request) -> dict:
    body = await request.json()
    email = InboundEmail.from_worker(body)

    # Rate limiting by IP (CF-Connecting-IP or X-Real-IP or client)
    client_ip = (
        request.headers.get("cf-connecting-ip")
        or request.headers.get("x-real-ip")
        or (request.client.host if request.client else "unknown")
    )
    ip_limiter = get_ip_rate_limiter()
    if not ip_limiter.check(client_ip):
        raise HTTPException(status_code=429, detail="IP rate limit exceeded")

    # Rate limiting by sender email
    limiter = get_rate_limiter()
    if not limiter.check(email.from_addr):
        raise HTTPException(status_code=429, detail="Rate limit exceeded")

    # Parse recipient with labels
    try:
        recipient, labels, is_alias = parse_recipient_with_labels(email.to_addr)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc

    # Sanitize body
    # TODO: replace with per-user setting from ship once available
    settings = get_settings()
    clean_body = sanitize(
        email.body_html,
        email.body_text,
        convert_images=settings.convert_images_to_md,
    )

    # Build mail message
    msg = MailMessage.from_inbound(email, recipient, clean_body, labels=labels, is_alias=is_alias)

    # Poke the gateway ship — always go through mail-gateway for routing
    # Aliases always go as mail-message with [%ext addr] — gateway resolves
    eyre = request.app.state.eyre
    try:
        if is_alias and not labels:
            # alias without labels: send as mail-message, gateway resolves alias to ship
            await eyre.poke_with_retry(
                app="mail-gateway",
                mark="mail-message",
                json_data=msg.model_dump_for_urbit(),
            )
        elif is_alias and labels:
            # alias with labels: send as receive-labeled, gateway resolves alias + forwards labels
            await eyre.poke_with_retry(
                app="mail-gateway",
                mark="mail-action",
                json_data=msg.model_dump_for_urbit_labeled(),
            )
        elif labels:
            await eyre.poke_with_retry(
                app="mail-gateway",
                mark="mail-action",
                json_data=msg.model_dump_for_urbit_labeled(),
            )
        else:
            await eyre.poke_with_retry(
                app="mail-gateway",
                mark="mail-message",
                json_data=msg.model_dump_for_urbit(),
            )
    except Exception as exc:
        log.error("inbound.poke_failed", error=str(exc))
        raise HTTPException(status_code=503, detail="Ship unavailable") from exc

    log.info(
        "inbound.accepted",
        from_addr=email.from_addr,
        to=recipient,
        labels=labels or [],
    )
    return {"status": "accepted", "id": msg.id}
