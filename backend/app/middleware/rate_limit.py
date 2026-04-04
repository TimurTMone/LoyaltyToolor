"""Simple in-memory rate limiter — no Redis needed."""

import time
from collections import defaultdict
from fastapi import HTTPException, Request


class RateLimiter:
    """Per-IP sliding-window rate limiter."""

    def __init__(self, max_requests: int, window_seconds: int):
        self.max_requests = max_requests
        self.window = window_seconds
        self._hits: dict[str, list[float]] = defaultdict(list)

    def _clean(self, key: str) -> None:
        now = time.monotonic()
        self._hits[key] = [t for t in self._hits[key] if now - t < self.window]

    def check(self, key: str) -> None:
        self._clean(key)
        if len(self._hits[key]) >= self.max_requests:
            raise HTTPException(status_code=429, detail="Too many requests")
        self._hits[key].append(time.monotonic())


# Shared instances
otp_limiter = RateLimiter(max_requests=5, window_seconds=300)      # 5 OTPs per 5 min
chat_limiter = RateLimiter(max_requests=20, window_seconds=60)     # 20 msgs per min
auth_limiter = RateLimiter(max_requests=10, window_seconds=60)     # 10 verify attempts per min


def get_client_ip(request: Request) -> str:
    forwarded = request.headers.get("x-forwarded-for")
    if forwarded:
        return forwarded.split(",")[0].strip()
    return request.client.host if request.client else "unknown"
