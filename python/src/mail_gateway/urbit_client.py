from __future__ import annotations

import asyncio
import json
import uuid
from collections.abc import AsyncIterator

import httpx
import structlog

log = structlog.get_logger()


class EyreError(Exception):
    pass


class EyreClient:
    """Minimal async Eyre HTTP API client."""

    def __init__(self, url: str, code: str, ship: str) -> None:
        self.url = url.rstrip("/")
        self.code = code
        self.ship = ship  # without ~
        self._client = httpx.AsyncClient(timeout=30)
        self._cookie: str | None = None
        self._channel_id: str = f"mail-gw-{uuid.uuid4().hex[:12]}"
        self._event_id: int = 0
        self._connected: bool = False
        self._subscriptions: list[tuple[str, str]] = []

    @property
    def connected(self) -> bool:
        return self._connected

    # ── Auth ──────────────────────────────────────────────

    async def login(self) -> None:
        resp = await self._client.post(
            f"{self.url}/~/login",
            data=f"password={self.code}",
            headers={"Content-Type": "application/x-www-form-urlencoded"},
        )
        resp.raise_for_status()
        cookie_name = f"urbauth-~{self.ship}"
        for c in resp.cookies.jar:
            if c.name == cookie_name:
                self._cookie = f"{c.name}={c.value}"
                self._connected = True
                log.info("eyre.login", ship=self.ship)
                return
        raise EyreError(f"Login succeeded but no {cookie_name} cookie returned")

    def _headers(self) -> dict[str, str]:
        h: dict[str, str] = {"Content-Type": "application/json"}
        if self._cookie:
            h["Cookie"] = self._cookie
        return h

    # ── Poke ──────────────────────────────────────────────

    async def poke(self, app: str, mark: str, json_data: dict, ship: str | None = None) -> None:
        self._event_id += 1
        body = [
            {
                "id": self._event_id,
                "action": "poke",
                "ship": ship or self.ship,
                "app": app,
                "mark": mark,
                "json": json_data,
            }
        ]
        resp = await self._request(
            "PUT",
            f"{self.url}/~/channel/{self._channel_id}",
            json=body,
        )
        if resp.status_code == 204:
            return
        resp.raise_for_status()

    # ── Scry ──────────────────────────────────────────────

    async def scry(self, app: str, path: str) -> dict:
        resp = await self._request("GET", f"{self.url}/~/scry/{app}{path}.json")
        resp.raise_for_status()
        return resp.json()

    # ── Subscribe ─────────────────────────────────────────

    async def subscribe(self, app: str, path: str) -> None:
        self._event_id += 1
        body = [
            {
                "id": self._event_id,
                "action": "subscribe",
                "ship": self.ship,
                "app": app,
                "path": path,
            }
        ]
        resp = await self._request(
            "PUT",
            f"{self.url}/~/channel/{self._channel_id}",
            json=body,
        )
        if resp.status_code not in (200, 204):
            resp.raise_for_status()
        if (app, path) not in self._subscriptions:
            self._subscriptions.append((app, path))

    async def ack(self, event_id: int) -> None:
        self._event_id += 1
        body = [
            {
                "id": self._event_id,
                "action": "ack",
                "event-id": event_id,
            }
        ]
        await self._request(
            "PUT",
            f"{self.url}/~/channel/{self._channel_id}",
            json=body,
        )

    async def event_stream(self) -> AsyncIterator[dict]:
        """Yield parsed SSE events from the channel.

        Each yielded dict has an extra ``"sse_id"`` key (int) taken from the
        SSE ``id:`` field — this is the value that must be passed to ``ack()``.

        On disconnect, re-login, create a fresh channel, re-subscribe,
        and resume streaming.
        """
        url = f"{self.url}/~/channel/{self._channel_id}"
        while True:
            try:
                async with self._client.stream(
                    "GET", url, headers=self._headers(), timeout=None
                ) as resp:
                    resp.raise_for_status()
                    buf = ""
                    sse_id: int | None = None
                    async for line in resp.aiter_lines():
                        if line.startswith("id:"):
                            try:
                                sse_id = int(line[3:].strip())
                            except ValueError:
                                sse_id = None
                        elif line.startswith("data:"):
                            buf += line[5:].strip()
                        elif line == "" and buf:
                            try:
                                event = json.loads(buf)
                            except json.JSONDecodeError:
                                log.warning("sse.parse_error", raw=buf[:200])
                                buf = ""
                                sse_id = None
                                continue
                            buf = ""
                            if sse_id is not None:
                                event["sse_id"] = sse_id
                            sse_id = None
                            yield event
            except (httpx.ReadError, httpx.RemoteProtocolError, httpx.ReadTimeout) as exc:
                log.warning("sse.disconnected", error=str(exc))
                await self._reconnect()
                url = f"{self.url}/~/channel/{self._channel_id}"

    async def _reconnect(self) -> None:
        """Re-login, create a fresh channel, and re-subscribe."""
        await asyncio.sleep(2)
        try:
            await self.login()
        except Exception:
            log.error("sse.reconnect_login_failed")
            await asyncio.sleep(5)
            return
        # Fresh channel so Eyre doesn't confuse old/new state
        self._channel_id = f"mail-gw-{uuid.uuid4().hex[:12]}"
        self._event_id = 0
        # Re-subscribe to all tracked subscriptions
        for app, path in self._subscriptions:
            try:
                await self.subscribe(app, path)
                log.info("sse.resubscribed", app=app, path=path)
            except Exception:
                log.error("sse.resubscribe_failed", app=app, path=path)

    # ── Internal ──────────────────────────────────────────

    async def _request(self, method: str, url: str, **kwargs: object) -> httpx.Response:
        kwargs.setdefault("headers", self._headers())  # type: ignore[arg-type]
        resp = await self._client.request(method, url, **kwargs)
        if resp.status_code == 403:
            log.info("eyre.reauth")
            await self.login()
            kwargs["headers"] = self._headers()  # type: ignore[index]
            resp = await self._client.request(method, url, **kwargs)
        return resp

    async def poke_with_retry(self, app: str, mark: str, json_data: dict, retries: int = 3) -> None:
        for attempt in range(retries):
            try:
                await self.poke(app, mark, json_data)
                return
            except (httpx.HTTPStatusError, httpx.ConnectError, httpx.ReadError) as exc:
                if attempt == retries - 1:
                    raise
                wait = 2 ** attempt
                log.warning("poke.retry", attempt=attempt + 1, wait=wait, error=str(exc))
                await asyncio.sleep(wait)
                try:
                    await self.login()
                except Exception:
                    pass

    async def aclose(self) -> None:
        self._connected = False
        await self._client.aclose()
