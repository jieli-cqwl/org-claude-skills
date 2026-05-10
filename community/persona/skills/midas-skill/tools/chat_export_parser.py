#!/usr/bin/env python3
"""
Midas Skill — Chat Export Parser

Parses exported chat logs from WhatsApp, WeChat, Telegram, and iMessage
into a clean, normalized Markdown format suitable for Midas signal extraction.

Supports:
  - WhatsApp exported .txt files (iOS and Android formats)
  - WeChat exported via WeChatMsg / PyWxDump (CSV or TXT)
  - Telegram exported JSON (from "Export chat history")
  - iMessage exported via iMazing or similar tools (CSV)
  - Generic text chat logs with timestamp + sender + message patterns

Usage:
    python chat_export_parser.py <input_file> [--output <output_path>]
                                               [--format <auto|whatsapp|wechat|telegram|imessage>]
                                               [--person <name>]
                                               [--complaints-only]

Examples:
    # Auto-detect format
    python chat_export_parser.py "WhatsApp Chat with Family.txt"

    # Parse Telegram JSON export
    python chat_export_parser.py result.json --format telegram

    # Extract only complaint-like messages (high signal for Midas Lens 2)
    python chat_export_parser.py chat.txt --complaints-only

    # Filter to a specific person's messages
    python chat_export_parser.py chat.txt --person "Sofia"
"""

import argparse
import csv
import json
import re
import sys
from datetime import datetime
from pathlib import Path


# ---------------------------------------------------------------------------
# WhatsApp parser
# ---------------------------------------------------------------------------

# iOS: [DD/MM/YYYY, HH:MM:SS] Sender: Message
# Android: DD/MM/YYYY, HH:MM - Sender: Message
# Also handles: M/D/YY, MM/DD/YY, YYYY-MM-DD variants
WHATSAPP_RE = re.compile(
    r"^\[?(\d{1,4}[/\-]\d{1,2}[/\-]\d{1,4}),?\s+"
    r"(\d{1,2}:\d{2}(?::\d{2})?(?:\s*[APap][Mm])?)\]?\s*"
    r"[-–—]?\s*"
    r"([^:]+?):\s+(.+)",
    re.MULTILINE,
)


def parse_whatsapp(filepath: str) -> list:
    """Parse a WhatsApp .txt export file."""
    with open(filepath, "r", encoding="utf-8") as f:
        content = f.read()

    messages = []
    # WhatsApp system messages to skip
    system_patterns = [
        "Messages and calls are end-to-end encrypted",
        "created group",
        "added you",
        "changed the group",
        "left the group",
        "removed you",
        "changed their phone number",
        "<Media omitted>",
        "image omitted",
        "video omitted",
        "audio omitted",
        "sticker omitted",
        "document omitted",
        "GIF omitted",
        "Contact card omitted",
    ]

    for match in WHATSAPP_RE.finditer(content):
        text = match.group(4).strip()
        if any(p.lower() in text.lower() for p in system_patterns):
            continue
        if not text:
            continue

        messages.append({
            "timestamp": f"{match.group(1)} {match.group(2)}",
            "user": match.group(3).strip(),
            "text": text,
        })
    return messages


# ---------------------------------------------------------------------------
# WeChat parser (WeChatMsg / PyWxDump CSV export)
# ---------------------------------------------------------------------------

def parse_wechat_csv(filepath: str) -> list:
    """Parse a WeChat CSV export (WeChatMsg or PyWxDump format)."""
    messages = []
    with open(filepath, "r", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            # Common column names across tools
            sender = (
                row.get("sender") or row.get("NickName") or
                row.get("talker") or row.get("from") or "unknown"
            )
            text = (
                row.get("content") or row.get("message") or
                row.get("Message") or row.get("msg") or ""
            ).strip()
            ts = (
                row.get("timestamp") or row.get("createTime") or
                row.get("time") or row.get("StrTime") or ""
            )

            if not text or text.startswith("["):  # Skip [image], [video] etc.
                continue

            messages.append({
                "timestamp": ts,
                "user": sender.strip(),
                "text": text,
            })
    return messages


def parse_wechat_txt(filepath: str) -> list:
    """Parse WeChat TXT exports with YYYY-MM-DD HH:MM sender: content format."""
    with open(filepath, "r", encoding="utf-8") as f:
        content = f.read()

    pattern = re.compile(
        r"^(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}(?::\d{2})?)\s+"
        r"(.+?)[:：]\s*(.+)$",
        re.MULTILINE,
    )
    messages = []
    for match in pattern.finditer(content):
        text = match.group(3).strip()
        if not text:
            continue
        messages.append({
            "timestamp": match.group(1),
            "user": match.group(2).strip(),
            "text": text,
        })
    return messages


# ---------------------------------------------------------------------------
# Telegram parser (JSON export)
# ---------------------------------------------------------------------------

def parse_telegram(filepath: str) -> list:
    """Parse Telegram's JSON export format."""
    with open(filepath, "r", encoding="utf-8") as f:
        data = json.load(f)

    msg_list = data if isinstance(data, list) else data.get("messages", [])
    messages = []

    for msg in msg_list:
        if msg.get("type") != "message":
            continue

        # Text can be a string or list of text entities
        raw_text = msg.get("text", "")
        if isinstance(raw_text, list):
            text = "".join(
                part if isinstance(part, str) else part.get("text", "")
                for part in raw_text
            )
        else:
            text = raw_text

        text = text.strip()
        if not text:
            continue

        sender = msg.get("from", msg.get("actor", "unknown"))
        ts = msg.get("date", "")

        messages.append({
            "timestamp": ts,
            "user": sender,
            "text": text,
        })
    return messages


# ---------------------------------------------------------------------------
# iMessage parser (CSV export via iMazing or similar)
# ---------------------------------------------------------------------------

def parse_imessage_csv(filepath: str) -> list:
    """Parse iMessage CSV export."""
    messages = []
    with open(filepath, "r", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            sender = (
                row.get("Sender") or row.get("sender") or
                row.get("From") or row.get("from") or "unknown"
            )
            text = (
                row.get("Text") or row.get("text") or
                row.get("Message") or row.get("message") or
                row.get("Body") or row.get("body") or ""
            ).strip()
            ts = (
                row.get("Date") or row.get("date") or
                row.get("Timestamp") or row.get("timestamp") or ""
            )

            if not text:
                continue

            messages.append({
                "timestamp": ts,
                "user": sender.strip(),
                "text": text,
            })
    return messages


# ---------------------------------------------------------------------------
# Classification and complaint detection
# ---------------------------------------------------------------------------

COMPLAINT_PATTERNS = [
    r"i wish",
    r"someone should",
    r"why (?:is|does|do|can't|won't|doesn't)",
    r"so (?:annoying|frustrating|expensive|broken|bad|slow|terrible)",
    r"(?:hate|can't stand|sick of|tired of)",
    r"anyone know (?:a |an )",
    r"does anyone",
    r"推荐|有没有人|谁知道|太贵了|太慢了|太烂了|受不了|崩溃",
    r"broken|disaster|nightmare|insane|ridiculous|unbelievable",
    r"flaked|cancelled|ghosted|booked out",
    r"\$\d+.*(?:insane|crazy|expensive|too much|ridiculous)",
]
COMPLAINT_RE = re.compile("|".join(COMPLAINT_PATTERNS), re.IGNORECASE)

WISH_PATTERNS = [
    r"i wish",
    r"someone should",
    r"there should be",
    r"why doesn't someone",
    r"would pay for",
    r"if only",
    r"真希望|有人做一个|谁来做",
]
WISH_RE = re.compile("|".join(WISH_PATTERNS), re.IGNORECASE)


def classify_message(msg: dict) -> str:
    """Classify a message by Midas signal weight.

    Returns: 'complaint', 'wish', 'substantive', or 'daily'
    """
    text = msg["text"]

    if WISH_RE.search(text):
        return "wish"
    if COMPLAINT_RE.search(text):
        return "complaint"
    if len(text.split()) > 30:
        return "substantive"
    return "daily"


# ---------------------------------------------------------------------------
# Output formatting
# ---------------------------------------------------------------------------

def format_output(messages: list, source_format: str) -> str:
    """Format messages into Midas-ready Markdown input."""
    if not messages:
        return "# Midas Input — Chat Export\n\nNo messages found.\n"

    # Classify
    tiers = {"wish": 0, "complaint": 0, "substantive": 0, "daily": 0}
    for m in messages:
        m["tier"] = classify_message(m)
        tiers[m["tier"]] += 1

    # Unique users
    users = sorted(set(m["user"] for m in messages))

    lines = [
        "# Midas Input — Chat Export",
        "",
        f"**Source format:** {source_format}",
        f"**Messages:** {len(messages)}",
        f"**Participants:** {', '.join(users[:15])}"
        + (f" (+{len(users)-15} more)" if len(users) > 15 else ""),
        f"**Classification:** {tiers['wish']} wishes/asks, "
        f"{tiers['complaint']} complaints, "
        f"{tiers['substantive']} substantive, "
        f"{tiers['daily']} daily chat",
        "",
        "---",
        "",
    ]

    for m in messages:
        tier_tag = ""
        if m["tier"] == "wish":
            tier_tag = " 💡"
        elif m["tier"] == "complaint":
            tier_tag = " 🔴"
        elif m["tier"] == "substantive":
            tier_tag = " ⭐"

        ts_str = f"[{m['timestamp']}] " if m["timestamp"] else ""
        lines.append(f"**{ts_str}{m['user']}**{tier_tag}")
        lines.append(m["text"])
        lines.append("")

    lines.append("---")
    lines.append("")
    lines.append(
        "> Parsed by midas-skill/tools/chat_export_parser.py — "
        "feed this file to Midas with 'Midas, mine this'"
    )
    return "\n".join(lines)


# ---------------------------------------------------------------------------
# Format detection
# ---------------------------------------------------------------------------

def detect_format(filepath: str) -> str:
    """Auto-detect the chat export format."""
    p = Path(filepath)

    if p.suffix == ".json":
        with open(filepath, "r", encoding="utf-8") as f:
            first_bytes = f.read(500)
        if '"type": "message"' in first_bytes or '"messages"' in first_bytes:
            return "telegram"
        return "json_unknown"

    if p.suffix == ".csv":
        with open(filepath, "r", encoding="utf-8") as f:
            header = f.readline().lower()
        if any(w in header for w in ("nickname", "talker", "createtime", "strtime")):
            return "wechat_csv"
        if any(w in header for w in ("sender", "from", "text", "body", "message")):
            return "imessage_csv"
        return "csv_unknown"

    # Text file — check for WhatsApp patterns
    with open(filepath, "r", encoding="utf-8") as f:
        sample = f.read(2000)

    if WHATSAPP_RE.search(sample):
        return "whatsapp"

    # WeChat TXT pattern
    if re.search(r"^\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}", sample, re.MULTILINE):
        return "wechat_txt"

    return "generic_txt"


def main():
    parser = argparse.ArgumentParser(
        description="Midas Skill — Chat Export Parser. "
        "Converts chat exports into Midas-ready input.",
    )
    parser.add_argument("input", help="Chat export file (TXT, JSON, or CSV)")
    parser.add_argument("-o", "--output", help="Output file path (default: stdout)")
    parser.add_argument(
        "-f", "--format",
        choices=["auto", "whatsapp", "wechat_csv", "wechat_txt", "telegram", "imessage"],
        default="auto",
        help="Chat format (default: auto-detect)",
    )
    parser.add_argument("-p", "--person", help="Filter to a specific person's messages")
    parser.add_argument(
        "--complaints-only",
        action="store_true",
        help="Only output complaint/wish messages (high signal for Midas Lens 2)",
    )
    args = parser.parse_args()

    fmt = args.format if args.format != "auto" else detect_format(args.input)

    if fmt == "whatsapp":
        messages = parse_whatsapp(args.input)
    elif fmt == "wechat_csv":
        messages = parse_wechat_csv(args.input)
    elif fmt == "wechat_txt":
        messages = parse_wechat_txt(args.input)
    elif fmt == "telegram":
        messages = parse_telegram(args.input)
    elif fmt in ("imessage", "imessage_csv"):
        messages = parse_imessage_csv(args.input)
    else:
        # Fallback: try WhatsApp, then WeChat TXT
        messages = parse_whatsapp(args.input)
        if not messages:
            messages = parse_wechat_txt(args.input)
        if not messages:
            print(f"⚠️  Could not auto-detect format for {args.input}", file=sys.stderr)
            print("   Try specifying --format explicitly.", file=sys.stderr)
            sys.exit(1)

    # Apply filters
    if args.person:
        person_lower = args.person.lower()
        messages = [m for m in messages if person_lower in m["user"].lower()]

    if args.complaints_only:
        for m in messages:
            m["tier"] = classify_message(m)
        messages = [m for m in messages if m["tier"] in ("complaint", "wish")]

    output = format_output(messages, fmt)

    if args.output:
        Path(args.output).write_text(output, encoding="utf-8")
        print(f"✅ Parsed {len(messages)} messages → {args.output}", file=sys.stderr)
    else:
        print(output)


if __name__ == "__main__":
    main()
