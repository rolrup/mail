from __future__ import annotations

import asyncio
from contextlib import asynccontextmanager
from collections.abc import AsyncIterator

import structlog
import uvicorn
from fastapi import FastAPI
from fastapi.responses import HTMLResponse

from .config import get_settings
from .inbound import router as inbound_router
from .outbound import start_outbound_listener
from .security import init_rate_limiters
from .urbit_client import EyreClient

log = structlog.get_logger()


def configure_logging(json_format: bool = True) -> None:
    processors: list = [
        structlog.contextvars.merge_contextvars,
        structlog.stdlib.add_log_level,
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.StackInfoRenderer(),
        structlog.processors.format_exc_info,
    ]
    if json_format:
        processors.append(structlog.processors.JSONRenderer())
    else:
        processors.append(structlog.dev.ConsoleRenderer())

    structlog.configure(
        processors=processors,
        wrapper_class=structlog.make_filtering_bound_logger(0),
        context_class=dict,
        logger_factory=structlog.PrintLoggerFactory(),
        cache_logger_on_first_use=True,
    )


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    settings = get_settings()
    configure_logging(json_format=False)  # pretty for dev; override in prod
    init_rate_limiters(
        max_per_hour=settings.rate_limit_per_hour,
        ip_max_per_hour=settings.ip_rate_limit_per_hour,
        outbound_max_per_hour=settings.outbound_rate_limit_per_hour,
    )

    eyre = EyreClient(
        url=settings.urbit_url,
        code=settings.urbit_code,
        ship=settings.urbit_ship,
    )

    try:
        await eyre.login()
    except Exception:
        log.error("startup.login_failed", ship=settings.urbit_ship)
        # Continue anyway — health will show disconnected

    app.state.eyre = eyre

    # Start outbound listener as background task
    outbound_task = asyncio.create_task(start_outbound_listener(eyre, settings))

    yield

    outbound_task.cancel()
    try:
        await outbound_task
    except asyncio.CancelledError:
        pass
    await eyre.aclose()


app = FastAPI(title="Urbit Mail Gateway", version="0.1.0", lifespan=lifespan)
app.include_router(inbound_router)


@app.get("/", response_class=HTMLResponse)
async def landing() -> str:
    settings = get_settings()
    domain = settings.mail_domain
    return _LANDING_HTML.replace("{{domain}}", domain)


@app.get("/health")
async def health() -> dict:
    eyre: EyreClient | None = getattr(app.state, "eyre", None)
    ship = get_settings().urbit_ship
    return {
        "status": "ok",
        "ship": f"~{ship}",
        "connected": eyre.connected if eyre else False,
    }


def run() -> None:
    settings = get_settings()
    uvicorn.run(
        "mail_gateway.main:app",
        host=settings.host,
        port=settings.port,
        reload=False,
    )


_LANDING_HTML = """\
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Urbit Mail</title>
<style>
  :root {
    --bg: #0a0a0f;
    --fg: #e0ddd5;
    --accent: #7eb8da;
    --muted: #6b6968;
    --card-bg: #13131a;
    --border: #2a2a35;
  }
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body {
    font-family: 'Inter', -apple-system, BlinkMacSystemFont, system-ui, sans-serif;
    background: var(--bg);
    color: var(--fg);
    min-height: 100vh;
    display: flex;
    flex-direction: column;
    align-items: center;
    padding: 2rem 1rem;
  }
  .container { max-width: 640px; width: 100%; }

  .hero {
    text-align: center;
    padding: 4rem 0 3rem;
  }
  .hero h1 {
    font-size: 2.4rem;
    font-weight: 700;
    letter-spacing: -0.03em;
    margin-bottom: 0.75rem;
  }
  .hero h1 span { color: var(--accent); }
  .hero .tagline {
    font-size: 1.15rem;
    color: var(--muted);
    line-height: 1.6;
    max-width: 480px;
    margin: 0 auto;
  }

  .address-demo {
    text-align: center;
    margin: 2rem 0 3rem;
    font-family: 'JetBrains Mono', 'Fira Code', monospace;
    font-size: 1.3rem;
    color: var(--accent);
    letter-spacing: 0.02em;
  }
  .address-demo .at { color: var(--muted); }

  .features {
    display: grid;
    gap: 1rem;
    margin-bottom: 3rem;
  }
  .feature {
    background: var(--card-bg);
    border: 1px solid var(--border);
    border-radius: 12px;
    padding: 1.5rem;
  }
  .feature h3 {
    font-size: 1rem;
    font-weight: 600;
    margin-bottom: 0.4rem;
  }
  .feature p {
    font-size: 0.9rem;
    color: var(--muted);
    line-height: 1.5;
  }

  .section {
    margin-bottom: 3rem;
  }
  .section h2 {
    font-size: 1.3rem;
    font-weight: 700;
    margin-bottom: 1.2rem;
    text-align: center;
  }
  .section h2 span { color: var(--accent); }
  .pitch {
    background: var(--card-bg);
    border: 1px solid var(--border);
    border-radius: 12px;
    padding: 2rem;
    margin-bottom: 1rem;
  }
  .pitch h3 {
    font-size: 1.05rem;
    font-weight: 600;
    margin-bottom: 0.8rem;
  }
  .pitch ul {
    list-style: none;
    padding: 0;
  }
  .pitch ul li {
    font-size: 0.9rem;
    color: var(--muted);
    line-height: 1.6;
    padding-left: 1.2em;
    position: relative;
  }
  .pitch ul li::before {
    content: '';
    position: absolute;
    left: 0;
    top: 0.55em;
    width: 6px;
    height: 6px;
    border-radius: 50%;
    background: var(--accent);
  }

  .how-it-works {
    background: var(--card-bg);
    border: 1px solid var(--border);
    border-radius: 12px;
    padding: 2rem;
    margin-bottom: 3rem;
  }
  .how-it-works h2 {
    font-size: 1.2rem;
    font-weight: 600;
    margin-bottom: 1.2rem;
  }
  .steps {
    display: flex;
    flex-direction: column;
    gap: 1rem;
  }
  .step {
    display: flex;
    gap: 1rem;
    align-items: flex-start;
  }
  .step-num {
    flex-shrink: 0;
    width: 28px;
    height: 28px;
    border-radius: 50%;
    background: var(--accent);
    color: var(--bg);
    font-weight: 700;
    font-size: 0.85rem;
    display: flex;
    align-items: center;
    justify-content: center;
  }
  .step p {
    font-size: 0.9rem;
    line-height: 1.5;
    color: var(--muted);
    padding-top: 3px;
  }
  .step p strong { color: var(--fg); }

  .footer {
    text-align: center;
    color: var(--muted);
    font-size: 0.8rem;
    padding-top: 2rem;
    border-top: 1px solid var(--border);
    width: 100%;
  }
  .footer a { color: var(--accent); text-decoration: none; }
  .footer a:hover { text-decoration: underline; }

  code {
    font-family: 'JetBrains Mono', 'Fira Code', monospace;
    background: var(--border);
    padding: 0.15em 0.4em;
    border-radius: 4px;
    font-size: 0.85em;
  }
</style>
</head>
<body>
<div class="container">

  <div class="hero">
    <h1>Urbit <span>Mail</span></h1>
    <p class="tagline">
      Your ship is your inbox. Receive and send real email
      from your Urbit identity &mdash; no third-party accounts,
      no data harvesting, no&nbsp;tracking pixels.
    </p>
  </div>

  <div class="address-demo">
    ~your-ship<span class="at">@</span>{{domain}}
  </div>

  <div class="features">
    <div class="feature">
      <h3>Your keys, your mail</h3>
      <p>Messages are delivered directly to your Urbit ship and stored only there. The gateway is a bridge, not a mailbox &mdash; nothing is kept after delivery.</p>
    </div>
    <div class="feature">
      <h3>Invisible infrastructure</h3>
      <p>Your IP address is never exposed. Cloudflare accepts incoming SMTP, the gateway forwards via Urbit's peer-to-peer network. Senders see only the domain.</p>
    </div>
    <div class="feature">
      <h3>Clean content</h3>
      <p>Scripts, tracker pixels, and dangerous HTML are stripped before delivery. You get readable text, not a surveillance payload.</p>
    </div>
    <div class="feature">
      <h3>Two-way communication</h3>
      <p>Reply to any email from your ship. The gateway translates your <code>@p</code> into a proper sender address that the outside world can reply to.</p>
    </div>
  </div>

  <div class="section">
    <h2>Why <span>Urbit Mail</span>?</h2>

    <div class="pitch">
      <h3>You own your mail. Actually own it.</h3>
      <ul>
        <li>Messages live on your ship, not on Google's servers</li>
        <li>No terms of service that can lock you out overnight</li>
        <li>No content scanning to sell you ads</li>
        <li>No &ldquo;your account is suspended, verify your phone number&rdquo;</li>
        <li>Your identity is a cryptographic key, not a username someone else controls</li>
      </ul>
    </div>

    <div class="pitch">
      <h3>Unlimited addresses, one inbox</h3>
      <ul>
        <li>Use <code>~ship.work</code>, <code>~ship.newsletters</code>, <code>~ship.shopping</code> &mdash; all delivered to the same ship</li>
        <li>Give a unique address to every service &mdash; instant disposable emails with no setup</li>
        <li>Labels auto-sort incoming mail by address, so your inbox stays clean</li>
        <li>Like Apple&rsquo;s Hide My Email, but free, unlimited, and under your control</li>
      </ul>
    </div>

    <div class="pitch">
      <h3>Built for the network</h3>
      <ul>
        <li>Ship-to-ship messages travel over Urbit&rsquo;s encrypted peer-to-peer network &mdash; they never touch the public internet</li>
        <li>A group of ships sharing a gateway is a self-hosted corporate email system &mdash; no Microsoft or Google required</li>
        <li>The gateway is stateless: it forwards and forgets. Your ship is the only place mail is stored</li>
      </ul>
    </div>
  </div>

  <div class="how-it-works">
    <h2>How it works</h2>
    <div class="steps">
      <div class="step">
        <div class="step-num">1</div>
        <p>Someone sends an email to <strong>~your-ship@{{domain}}</strong></p>
      </div>
      <div class="step">
        <div class="step-num">2</div>
        <p>Cloudflare receives the message and passes it to the gateway</p>
      </div>
      <div class="step">
        <div class="step-num">3</div>
        <p>The gateway sanitizes the content and delivers it to your ship over Urbit's encrypted network</p>
      </div>
      <div class="step">
        <div class="step-num">4</div>
        <p>You read and reply from your <strong>%mail</strong> &mdash; replies go out as regular email from your <code>@p</code> address</p>
      </div>
    </div>
  </div>

  <div class="footer">
    <p>Powered by <a href="https://urbit.org">Urbit</a> &middot; <a href="https://github.com/rolrup/mail">Source</a></p>
    <p style="font-size: 11px; margin-top: 4px;">Web Push: <a href="https://github.com/will-hanlen/urbit-web-push">urbit-web-push</a> by ~migrev-dolseg</p>
  </div>

</div>
</body>
</html>
"""
