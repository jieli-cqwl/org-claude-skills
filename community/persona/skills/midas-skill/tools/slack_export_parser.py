#!/usr/bin/env python3
"""
Midas Skill — Slack Export Parser

Parses Slack workspace exports (JSON) or copy-pasted Slack logs (TXT)
into a clean, normalized Markdown format suitable for Midas signal extraction.

Supports:
  - Slack workspace export format (JSON with users.json + channel dirs)
  - Single-channel JSON files
  - Plain text copy-paste from Slack (auto-detected)

Usage:
    python slack_export_parser.py <input_path> [--output <output_path>]
                                               [--channel <channel_name>]
                                               [--user <username>]
                                               [--days <N>]

Examples:
    # Parse a full Slack export directory
    python slack_export_parser.py ~/Downloads/my-slack-export/

    # Parse a single channel JSON file
    python slack_export_parser.py general.json --output midas_input.md

    # Parse copy-pasted text
    python slack_export_parser.py slack_paste.txt

    # Filter to a specific user's messages only
    python slack_export_parser.py export/ --user marcus.chen --days 7
"""

import argparse
import json
import os
import re
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path


def load_users(export_dir: str) -> dict:
    """Load the users.json lookup table from a Slack export directory."""
    users_file = Path(export_dir) / "users.json"
    if not users_file.exists():
        return {}
    with open(users_file, "r", encoding="utf-8") as f:
        users = json.load(f)
    return {
        u["id"]: u.get("real_name") or u.get("name", u["id"])
        for u in users
    }


def parse_slack_json(filepath: str, users: dict = None) -> list:
    """Parse a single Slack channel JSON file into message dicts.

    Returns list of {timestamp, user, text, channel, thread_ts}.
    """
    users = users or {}
    with open(filepath, "r", encoding="utf-8") as f:
        raw = json.load(f)

    messages = []
    for msg in raw:
        if msg.get("subtype") in ("channel_join", "channel_leave", "bot_message"):
            continue
        text = msg.get("text", "").strip()
        if not text:
            continue

        # Resolve <@U12345> user mentions
        text = re.sub(
            r"<@(U[A-Z0-9]+)>",
            lambda m: f"@{users.get(m.group(1), m.group(1))}",
            text,
        )
        # Strip Slack link formatting <http://url|label> -> label or url
        text = re.sub(r"<(https?://[^|>]+)\|([^>]+)>", r"\2", text)
        text = re.sub(r"<(https?://[^>]+)>", r"\1", text)

        ts = float(msg.get("ts", 0))
        user_id = msg.get("user", "unknown")
        messages.append({
            "timestamp": datetime.fromtimestamp(ts, tz=timezone.utc),
            "user": users.get(user_id, user_id),
            "text": text,
            "channel": Path(filepath).stem,
            "thread_ts": msg.get("thread_ts"),
        })
    return messages


def parse_slack_text(filepath: str) -> list:
    """Parse copy-pasted Slack text into message dicts.

    Expected patterns:
      [Mon 10:14 AM] Marcus Chen
      message text here

    or:
      **[Tue 2:47 PM] Sarah Okonkwo**
      message text
    """
    with open(filepath, "r", encoding="utf-8") as f:
        content = f.read()

    # Pattern: optional markdown bold, bracket with day/time, then name
    header_re = re.compile(
        r"^\*{0,2}\[([A-Za-z]{3}\s+\d{1,2}:\d{2}\s*[APap][Mm])\]\s+"
        r"(.+?)\*{0,2}\s*$",
        re.MULTILINE,
    )

    messages = []
    splits = list(header_re.finditer(content))

    for i, match in enumerate(splits):
        start = match.end()
        end = splits[i + 1].start() if i + 1 < len(splits) else len(content)
        text = content[start:end].strip()
        if not text:
            continue
        messages.append({
            "timestamp": None,
            "user": match.group(2).strip(),
            "text": text,
            "channel": "pasted",
            "thread_ts": None,
        })
    return messages


def parse_export_directory(export_dir: str) -> list:
    """Parse a full Slack workspace export directory.

    Structure: export_dir/channel_name/YYYY-MM-DD.json
    """
    export_path = Path(export_dir)
    users = load_users(export_dir)
    all_messages = []

    for channel_dir in sorted(export_path.iterdir()):
        if not channel_dir.is_dir() or channel_dir.name.startswith("."):
            continue
        for json_file in sorted(channel_dir.glob("*.json")):
            msgs = parse_slack_json(str(json_file), users)
            for m in msgs:
                m["channel"] = channel_dir.name
            all_messages.extend(msgs)

    return all_messages


def classify_message(msg: dict) -> str:
    """Classify a message by weight tier (following colleague-skill's pattern).

    Returns: 'substantive', 'decision', or 'daily'
    """
    text = msg["text"]
    word_count = len(text.split())

    # Tier 1: substantive (long messages with real content)
    if word_count > 40:
        return "substantive"

    # Tier 2: decision indicators
    decision_keywords = [
        "budget", "cost", "price", "spend", "pay", "invest",
        "hire", "fire", "ship", "launch", "deadline", "blocker",
        "approve", "reject", "decide", "recommend", "proposal",
        "anyone know", "does anyone", "i wish", "someone should",
        "we need", "how much", "why is", "broken", "disaster",
    ]
    text_lower = text.lower()
    if any(kw in text_lower for kw in decision_keywords):
        return "decision"

    # Tier 3: daily chat (style reference, low signal weight)
    return "daily"


def filter_messages(
    messages: list,
    channel: str = None,
    user: str = None,
    days: int = None,
) -> list:
    """Filter messages by channel, user, and/or recency."""
    filtered = messages

    if channel:
        filtered = [m for m in filtered if m["channel"] == channel]

    if user:
        user_lower = user.lower()
        filtered = [
            m for m in filtered
            if user_lower in m["user"].lower()
        ]

    if days and any(m["timestamp"] for m in filtered):
        cutoff = datetime.now(tz=timezone.utc) - timedelta(days=days)
        filtered = [
            m for m in filtered
            if m["timestamp"] is None or m["timestamp"] >= cutoff
        ]

    return filtered


def format_output(messages: list) -> str:
    """Format messages into Midas-ready Markdown input."""
    if not messages:
        return "# Midas Input — Slack Export\n\nNo messages found matching filters.\n"

    # Group by channel
    channels = {}
    for m in messages:
        ch = m["channel"]
        if ch not in channels:
            channels[ch] = []
        channels[ch].append(m)

    # Classify and count
    tiers = {"substantive": 0, "decision": 0, "daily": 0}
    for m in messages:
        m["tier"] = classify_message(m)
        tiers[m["tier"]] += 1

    lines = [
        "# Midas Input — Slack Export",
        "",
        f"**Messages:** {len(messages)}",
        f"**Channels:** {', '.join(sorted(channels.keys()))}",
        f"**Classification:** {tiers['substantive']} substantive, "
        f"{tiers['decision']} decision-related, {tiers['daily']} daily chat",
        "",
        "---",
        "",
    ]

    for ch_name, ch_msgs in sorted(channels.items()):
        lines.append(f"## #{ch_name}")
        lines.append("")
        for m in ch_msgs:
            ts_str = ""
            if m["timestamp"]:
                ts_str = m["timestamp"].strftime("[%a %I:%M %p] ")
            tier_tag = ""
            if m["tier"] == "substantive":
                tier_tag = " ⭐"
            elif m["tier"] == "decision":
                tier_tag = " 💰"
            lines.append(f"**{ts_str}{m['user']}**{tier_tag}")
            lines.append(m["text"])
            lines.append("")
        lines.append("---")
        lines.append("")

    lines.append(
        "> Parsed by midas-skill/tools/slack_export_parser.py — "
        "feed this file to Midas with 'Midas, mine this'"
    )
    return "\n".join(lines)


def detect_input_type(path: str) -> str:
    """Detect whether input is a directory, JSON file, or text file."""
    p = Path(path)
    if p.is_dir():
        return "directory"
    if p.suffix == ".json":
        return "json"
    return "text"


def main():
    parser = argparse.ArgumentParser(
        description="Midas Skill — Slack Export Parser. "
        "Converts Slack exports into Midas-ready input.",
    )
    parser.add_argument("input", help="Slack export directory, JSON file, or text file")
    parser.add_argument("-o", "--output", help="Output file path (default: stdout)")
    parser.add_argument("-c", "--channel", help="Filter to a specific channel")
    parser.add_argument("-u", "--user", help="Filter to a specific user")
    parser.add_argument("-d", "--days", type=int, help="Only include messages from last N days")
    args = parser.parse_args()

    input_type = detect_input_type(args.input)

    if input_type == "directory":
        messages = parse_export_directory(args.input)
    elif input_type == "json":
        messages = parse_slack_json(args.input)
    else:
        messages = parse_slack_text(args.input)

    messages = filter_messages(messages, args.channel, args.user, args.days)
    output = format_output(messages)

    if args.output:
        Path(args.output).write_text(output, encoding="utf-8")
        print(
            f"✅ Parsed {len(messages)} messages → {args.output}",
            file=sys.stderr,
        )
    else:
        print(output)


if __name__ == "__main__":
    main()
