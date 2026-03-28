import hmac
import time
from collections import defaultdict

from fastapi import Depends, HTTPException, Request

from .config import Settings, get_settings


def verify_worker_secret(
    request: Request,
    settings: Settings = Depends(get_settings),
) -> None:
    auth = request.headers.get("authorization", "")
    if not auth.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing bearer token")
    token = auth[7:]
    if not hmac.compare_digest(token, settings.worker_secret):
        raise HTTPException(status_code=401, detail="Invalid token")


class RateLimiter:
    """In-memory per-sender rate limiter with sliding window."""

    def __init__(self, max_per_hour: int = 30):
        self.max_per_hour = max_per_hour
        self._hits: dict[str, list[float]] = defaultdict(list)

    def check(self, key: str) -> bool:
        """Return True if the request is allowed."""
        now = time.monotonic()
        cutoff = now - 3600
        timestamps = self._hits[key]
        # prune old entries
        self._hits[key] = [t for t in timestamps if t > cutoff]
        if not self._hits[key]:
            self._hits[key] = [now]
            return True
        if len(self._hits[key]) >= self.max_per_hour:
            return False
        self._hits[key].append(now)
        return True


# Singletons — created at import time, reconfigured in lifespan
_rate_limiter: RateLimiter | None = None
_ip_rate_limiter: RateLimiter | None = None
_outbound_rate_limiter: RateLimiter | None = None


def get_rate_limiter() -> RateLimiter:
    global _rate_limiter
    if _rate_limiter is None:
        _rate_limiter = RateLimiter()
    return _rate_limiter


def get_ip_rate_limiter() -> RateLimiter:
    global _ip_rate_limiter
    if _ip_rate_limiter is None:
        _ip_rate_limiter = RateLimiter()
    return _ip_rate_limiter


def get_outbound_rate_limiter() -> RateLimiter:
    global _outbound_rate_limiter
    if _outbound_rate_limiter is None:
        _outbound_rate_limiter = RateLimiter()
    return _outbound_rate_limiter


def init_rate_limiters(
    max_per_hour: int,
    ip_max_per_hour: int = 60,
    outbound_max_per_hour: int = 50,
) -> None:
    global _rate_limiter, _ip_rate_limiter, _outbound_rate_limiter
    _rate_limiter = RateLimiter(max_per_hour)
    _ip_rate_limiter = RateLimiter(ip_max_per_hour)
    _outbound_rate_limiter = RateLimiter(outbound_max_per_hour)
