import re

import html2text
import nh3

_TRACKER_RE = re.compile(
    r'<img\b[^>]*(?:width\s*=\s*["\']?1["\']?\s+height\s*=\s*["\']?1["\']?'
    r"|height\s*=\s*[\"']?1[\"']?\s+width\s*=\s*[\"']?1[\"']?)[^>]*/?>",
    re.IGNORECASE,
)

# Tags allowed through nh3 sanitization (security pass)
_SAFE_TAGS = {
    "p", "br", "a", "ul", "ol", "li",
    "b", "i", "em", "strong", "blockquote",
    "h1", "h2", "h3", "h4", "h5", "h6",
    "pre", "code", "div", "span", "img",
    "table", "thead", "tbody", "tr", "td", "th",
    "hr",
}

_SAFE_ATTRS: dict[str, set[str]] = {
    "a": {"href"},
    "img": {"src", "alt"},
}


def _make_converter(*, convert_images: bool) -> html2text.HTML2Text:
    h = html2text.HTML2Text()
    h.body_width = 0  # no wrapping
    h.ignore_images = not convert_images
    h.ignore_links = False
    h.protect_links = False
    h.unicode_snob = True  # use unicode instead of ascii approximations
    h.skip_internal_links = True
    h.ignore_tables = True  # email layout tables → plain text, not md tables
    return h


def _clean_markdown(text: str) -> str:
    """Post-process html2text output to remove email template artifacts."""
    # Strip zero-width / invisible Unicode junk used by email marketers:
    #   U+200B zero-width space, U+200C/D zero-width (non-)joiner,
    #   U+200E/F direction marks, U+034F combining grapheme joiner,
    #   U+2060 word joiner, U+FEFF BOM/zero-width no-break space,
    #   U+00AD soft hyphen, U+2028/2029 line/paragraph separator
    text = re.sub(r"[\u200b-\u200f\u034f\u2060\ufeff\u00ad\u2028\u2029]+", "", text)
    # Replace non-breaking spaces with regular spaces
    text = text.replace("\u00a0", " ")
    # Rejoin linked images split across lines by html2text:
    #   [ \n ![alt](img) \n ](url) → [![alt](img)](url)
    # Handles whitespace/newlines between [ and ![ and between ) and ](
    text = re.sub(
        r"\[\s*(!\[[^\]]*\]\([^)]*\))\s*\]\s*\(",
        r"[\1](",
        text,
        flags=re.DOTALL,
    )
    # Remove linked images with generic/empty alt: [![Image: image](img)](url) → remove
    text = re.sub(
        r"\[\s*!\[Image:\s*image\s*\]\([^)]*\)\s*\]\([^)]+\)",
        "",
        text,
        flags=re.IGNORECASE | re.DOTALL,
    )
    # Remove standalone [Image: image] with generic/empty alt text
    text = re.sub(r"\[Image:\s*image\s*\]", "", text, flags=re.IGNORECASE)
    # Remove empty markdown images and links: ![](url), [](url)
    text = re.sub(r"!\[]\([^)]*\)", "", text)
    text = re.sub(r"\[]\([^)]*\)", "", text)
    # Remove orphaned ! from stripped images (![](url) → ! after url removal)
    text = re.sub(r"^\s*!+\s*$", "", text, flags=re.MULTILINE)
    # Collapse [text](mailto:text) where link text matches email → just text
    text = re.sub(r"\[([^\]]+)]\(mailto:\1\)", r"\1", text)
    # Collapse [url](url) where link text matches href → just url
    text = re.sub(r"\[([^\]]+)]\(\1\)", r"\1", text)
    # Remove lines that are only pipes and whitespace (layout table remnants)
    text = re.sub(r"^[\s|]+$", "", text, flags=re.MULTILINE)
    # Remove horizontal rules (--- or ***) that are just decorative
    text = re.sub(r"^\s*[-*_]{3,}\s*$", "", text, flags=re.MULTILINE)
    # Remove "View in your browser" / "View online" lines
    text = re.sub(r"^.*(?:view\s+(?:in\s+(?:your\s+)?)?browser|view\s+online).*$", "", text, flags=re.MULTILINE | re.IGNORECASE)
    # Images: ensure each image (or group of consecutive images) is on its own line
    # Don't break [![ (image inside link) — only add newline before standalone ![
    text = re.sub(r"([^\n\[])(\s*\!\[)", r"\1\n\2", text)
    # Put newline after image that is followed by non-image text
    # Don't break before ] which closes a linked image [![...](img)](url)
    text = re.sub(r"(\!\[[^\]]*\]\([^)]*\))\s*(?!\s*\!\[)(?!\s*\]\()(\S)", r"\1\n\2", text)
    # Same for [Image: ...] placeholders from html2text
    text = re.sub(r"([^\n])\s*(\[Image:)", r"\1\n\2", text)
    text = re.sub(r"(\[Image:[^\]]*\])\s*(?!\s*\[Image:)(\S)", r"\1\n\2", text)
    # Strip leading whitespace before list items: " * " → "* ", " 1. " → "1. "
    text = re.sub(r"^ +([*\-+] )", r"\1", text, flags=re.MULTILINE)
    text = re.sub(r"^ +(\d+\.? )", r"\1", text, flags=re.MULTILINE)
    # Remove blank lines between consecutive list items (unordered and ordered)
    text = re.sub(r"(^[*\-+] .+)\n\n(?=[*\-+] )", r"\1\n", text, flags=re.MULTILINE)
    text = re.sub(r"(^\d+\\?\. .+)\n\n(?=\d+\\?\.)", r"\1\n", text, flags=re.MULTILINE)
    # Remove backslash escaping on ordered list numbers: 1\. → 1.
    text = re.sub(r"^(\d+)\\(\. )", r"\1\2", text, flags=re.MULTILINE)
    # Collapse runs of spaces on a single line
    text = re.sub(r" {2,}", " ", text)
    # Collapse excessive blank lines
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()


def sanitize(
    body_html: str | None,
    body_text: str | None,
    *,
    convert_images: bool = False,
) -> str:
    """Return clean markdown/plain text from email body."""
    if not body_html:
        return body_text or ""

    # 1. Remove tracker pixels
    html = _TRACKER_RE.sub("", body_html)

    # 2. Security pass — strip dangerous tags/attrs (scripts, iframes, etc.)
    clean_html = nh3.clean(
        html,
        tags=_SAFE_TAGS,
        attributes=_SAFE_ATTRS,
    )

    # 3. Convert sanitized HTML to markdown
    converter = _make_converter(convert_images=convert_images)
    plain = converter.handle(clean_html)

    # 4. Clean up email template artifacts
    plain = _clean_markdown(plain)

    return plain or body_text or ""
