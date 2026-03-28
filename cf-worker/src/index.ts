/**
 * Cloudflare Email Worker for Urbit Mail Gateway.
 *
 * Receives incoming emails via Cloudflare Email Routing,
 * extracts envelope + body, and forwards as JSON POST
 * to the mail-gateway Python service.
 *
 * Secrets (set via `wrangler secret put`):
 *   GATEWAY_URL    — e.g. https://gw.ships.to/v1/inbound
 *   GATEWAY_SECRET — shared Bearer token
 */

export interface Env {
  GATEWAY_URL: string;
  GATEWAY_SECRET: string;
}

export default {
  async email(message: ForwardableEmailMessage, env: Env): Promise<void> {
    const sender = message.from;
    const recipient = message.to;
    const subject = message.headers.get("subject") || "";

    // Read raw email body (the full RFC 5322 message)
    const raw = await streamToString(message.raw);

    // Extract text and HTML parts from raw MIME
    const { text, html } = parseMimeBodies(raw);

    // Collect a subset of headers for the gateway
    const rawHeaders: Record<string, string> = {};
    for (const key of ["message-id", "date", "reply-to", "in-reply-to", "references"]) {
      const val = message.headers.get(key);
      if (val) rawHeaders[key] = val;
    }

    const payload = {
      from: sender,
      to: recipient,
      subject: subject,
      body_text: text || undefined,
      body_html: html || undefined,
      raw_headers: Object.keys(rawHeaders).length > 0 ? rawHeaders : undefined,
    };

    const resp = await fetch(env.GATEWAY_URL, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${env.GATEWAY_SECRET}`,
      },
      body: JSON.stringify(payload),
    });

    if (!resp.ok) {
      // Log for Cloudflare dashboard / Logpush
      console.error(
        `Gateway error: ${resp.status} ${resp.statusText}`,
        await resp.text().catch(() => ""),
      );
      // Throw so Cloudflare marks the email as failed and can retry
      throw new Error(`Gateway returned ${resp.status}`);
    }
  },
};

// ── Helpers ──────────────────────────────────────────────

async function streamToString(stream: ReadableStream): Promise<string> {
  const reader = stream.getReader();
  const decoder = new TextDecoder();
  let result = "";
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    result += decoder.decode(value, { stream: true });
  }
  result += decoder.decode();
  return result;
}

/**
 * Minimal MIME parser — extracts text/plain and text/html parts.
 * Handles both simple single-part messages and multipart/* structures.
 *
 * This runs under the 10ms CPU limit, so we keep it simple:
 * no recursive multipart, no charset conversion beyond UTF-8.
 */
function parseMimeBodies(raw: string): { text: string; html: string } {
  let text = "";
  let html = "";

  const contentType = extractHeader(raw, "content-type") || "text/plain";

  // Single-part message
  if (!contentType.toLowerCase().includes("multipart")) {
    const body = extractBody(raw);
    const decoded = decodeBody(raw, body);
    if (contentType.toLowerCase().includes("text/html")) {
      html = decoded;
    } else {
      text = decoded;
    }
    return { text, html };
  }

  // Multipart — find boundary
  const boundaryMatch = contentType.match(/boundary\s*=\s*"?([^";\s]+)"?/i);
  if (!boundaryMatch) {
    // Can't parse, return raw body as text
    text = extractBody(raw);
    return { text, html };
  }

  const boundary = boundaryMatch[1];
  const body = extractBody(raw);
  const parts = body.split(`--${boundary}`);

  for (const part of parts) {
    if (part.startsWith("--") || part.trim() === "") continue;

    const partCt = (extractHeader(part, "content-type") || "text/plain").toLowerCase();
    const partBody = extractBody(part);
    const decoded = decodeBody(part, partBody);

    if (partCt.includes("text/plain") && !text) {
      text = decoded;
    } else if (partCt.includes("text/html") && !html) {
      html = decoded;
    }
  }

  return { text, html };
}

function extractHeader(message: string, name: string): string | null {
  const regex = new RegExp(`^${name}:\\s*(.+(?:\\r?\\n[ \\t]+.+)*)`, "im");
  const match = message.match(regex);
  return match ? match[1].replace(/\r?\n[ \t]+/g, " ").trim() : null;
}

function extractBody(message: string): string {
  // Body starts after first blank line
  const idx = message.search(/\r?\n\r?\n/);
  return idx >= 0 ? message.slice(idx).replace(/^\r?\n\r?\n/, "") : message;
}

function decodeBody(headers: string, body: string): string {
  const cte = (extractHeader(headers, "content-transfer-encoding") || "").toLowerCase().trim();

  if (cte === "base64") {
    try {
      const binaryStr = atob(body.replace(/\s/g, ""));
      const bytes = Uint8Array.from(binaryStr, (c) => c.charCodeAt(0));
      return new TextDecoder("utf-8").decode(bytes);
    } catch {
      return body;
    }
  }

  if (cte === "quoted-printable") {
    const raw = body
      .replace(/=\r?\n/g, "") // soft line breaks
      .replace(/=([0-9A-Fa-f]{2})/g, (_, hex: string) =>
        String.fromCharCode(parseInt(hex, 16)),
      );
    // quoted-printable produces raw bytes as char codes — decode as UTF-8
    const bytes = Uint8Array.from(raw, (c) => c.charCodeAt(0));
    return new TextDecoder("utf-8").decode(bytes);
  }

  // 7bit, 8bit, binary — return as-is
  return body;
}
