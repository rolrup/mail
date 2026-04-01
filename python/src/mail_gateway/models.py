import re
import uuid
from datetime import datetime, timezone

from pydantic import BaseModel, Field, field_validator
from urbitob import is_valid_patp
_LABEL_RE = re.compile(r"^[a-z][a-z0-9-]*$")


def parse_recipient(to: str) -> str:
    """Extract @p from '~ship@domain', 'ship@domain', or plain '~ship'. Returns '~ship'.
    Raises ValueError if not a valid @p (use parse_recipient_with_labels for alias support).
    """
    ship, _, is_alias = parse_recipient_with_labels(to)
    if is_alias:
        raise ValueError(f"Invalid @p: {ship}")
    return ship


def parse_recipient_with_labels(to: str) -> tuple[str, list[str], bool]:
    """Extract @p and labels from address. Returns (ship_or_alias, labels, is_alias).

    Addresses like 'ship-name.label1.label2@domain' yield ('~ship-name', ['label1', 'label2'], False).
    Non-@p local parts like 'john@domain' yield ('john', [], True) — treated as alias.
    Dots are the delimiter — @p uses only hyphens, so parsing is unambiguous.
    """
    addr = to.strip()
    # strip domain part if present
    domain = ""
    if "@" in addr:
        addr, domain = addr.split("@", 1)

    # try as @p first
    ship_candidate = addr if addr.startswith("~") else f"~{addr}"

    # split on dots to separate ship from labels
    parts = ship_candidate.split(".")
    ship = parts[0]
    labels = parts[1:]

    if is_valid_patp(ship):
        # valid @p — normal ship address
        valid_labels = []
        for label in labels:
            if not label:
                continue
            if not _LABEL_RE.match(label):
                raise ValueError(f"Invalid label: {label!r} (must match [a-z][a-z0-9-]*)")
            valid_labels.append(label)
        return ship, valid_labels, False

    # not a valid @p — treat as alias
    # first part is alias name, rest are labels (like ship.label1.label2)
    alias_parts = addr.lstrip("~").split(".")
    alias = alias_parts[0]
    alias_labels = [l for l in alias_parts[1:] if l]
    return alias, alias_labels, True


def to_uv(hex_id: str) -> str:
    """Convert hex UUID to Urbit @uv format.

    @uv = base32 with charset 0-9a-v, prefix '0v',
    '.' separator every 5 digits from the right.
    """
    n = int(hex_id.replace("-", ""), 16)
    if n == 0:
        return "0v0"
    chars = "0123456789abcdefghijklmnopqrstuv"
    digits = []
    while n:
        digits.append(chars[n & 0x1F])
        n >>= 5
    raw = "".join(reversed(digits))
    # insert dots every 5 chars from the right
    chunks: list[str] = []
    while len(raw) > 5:
        chunks.append(raw[-5:])
        raw = raw[:-5]
    chunks.append(raw)
    return "0v" + ".".join(reversed(chunks))


def to_da(iso_str: str) -> str:
    """Convert ISO 8601 to Urbit @da format.

    @da = ~YYYY.M.D..HH.MM.SS
    Double dot between date and time.
    """
    dt = datetime.fromisoformat(iso_str.replace("Z", "+00:00"))
    dt = dt.astimezone(timezone.utc)
    return (
        f"~{dt.year}.{dt.month}.{dt.day}"
        f"..{dt.hour}.{dt.minute}.{dt.second}"
    )


class InboundEmail(BaseModel):
    from_addr: str  # aliased from "from" in JSON
    to_addr: str  # aliased from "to" in JSON
    subject: str = ""
    body_text: str | None = None
    body_html: str | None = None
    raw_headers: dict[str, str] | None = None

    model_config = {"populate_by_name": True}

    # Accept both snake_case and the short names from the Worker JSON
    @classmethod
    def from_worker(cls, data: dict) -> "InboundEmail":
        return cls(
            from_addr=data.get("from_addr") or data.get("from", ""),
            to_addr=data.get("to_addr") or data.get("to", ""),
            subject=data.get("subject", ""),
            body_text=data.get("body_text"),
            body_html=data.get("body_html"),
            raw_headers=data.get("raw_headers"),
        )

    @field_validator("from_addr")
    @classmethod
    def _from_not_empty(cls, v: str) -> str:
        if not v.strip():
            raise ValueError("from address is required")
        return v.strip()

    @field_validator("to_addr")
    @classmethod
    def _to_not_empty(cls, v: str) -> str:
        if not v.strip():
            raise ValueError("to address is required")
        return v.strip()


class MailMessage(BaseModel):
    id: str  # @uv string
    from_: dict = Field(alias="from")  # {"ext": "..."} or {"urbit": "~..."}
    to: dict  # {"ext": "..."} or {"urbit": "~..."}
    subject: str
    body: str
    sent_at: str  # @da string
    labels: list[str] = []
    recv_addr: str = ""  # original email address the message was sent to
    reply_to: str = ""  # Reply-To address from email headers

    model_config = {"populate_by_name": True}

    def model_dump_for_urbit(self) -> dict:
        """Serialize to the JSON format expected by Hoon marks."""
        return {
            "id": self.id,
            "from": self.from_,
            "to": self.to,
            "cc": [],
            "reply-to": {"ext": self.reply_to} if self.reply_to else False,
            "subject": self.subject,
            "body": self.body,
            "sent-at": self.sent_at,
        }

    def model_dump_for_urbit_labeled(self) -> dict:
        """Serialize as receive-labeled action for Hoon marks."""
        return {
            "receive-labeled": {
                "id": self.id,
                "from": self.from_,
                "to": self.to,
                "cc": [],
                "reply-to": {"ext": self.reply_to} if self.reply_to else False,
                "subject": self.subject,
                "body": self.body,
                "sent-at": self.sent_at,
                "labels": self.labels,
                "recv-addr": self.recv_addr,
            }
        }

    @classmethod
    def from_inbound(
        cls,
        email: InboundEmail,
        recipient: str,
        body: str,
        labels: list[str] | None = None,
        is_alias: bool = False,
    ) -> "MailMessage":
        raw_id = uuid.uuid4().hex
        reply_to = ""
        if email.raw_headers:
            reply_to = email.raw_headers.get("reply-to", "")
        # alias: to=[%ext "alias@domain"], normal: to=[%urbit ~ship]
        if is_alias:
            to_contact = {"ext": email.to_addr}
        else:
            to_contact = {"urbit": recipient}
        return cls(
            id=to_uv(raw_id),
            from_={"ext": email.from_addr},
            to=to_contact,
            subject=email.subject,
            body=body,
            sent_at=to_da(datetime.now(timezone.utc).isoformat()),
            labels=labels or [],
            recv_addr=email.to_addr,
            reply_to=reply_to,
        )
