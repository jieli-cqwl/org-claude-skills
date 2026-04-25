#!/usr/bin/env python3
"""
Midas Skill — Browser History Parser

Extracts browsing history from Chrome, Firefox, or Safari's local SQLite
databases and formats it for Midas signal extraction.

Produces a summarized Markdown report with:
  - Top visited domains (frequency)
  - Top search queries (extracted from Google/Bing/DuckDuckGo URLs)
  - YouTube watch history (extracted from youtube.com/watch URLs)
  - Daily browsing pattern (URLs per day)
  - Full URL list with timestamps

Usage:
    python browser_history_parser.py [--browser <chrome|firefox|safari|auto>]
                                     [--days <N>]
                                     [--output <output_path>]
                                     [--top <N>]

Examples:
    # Auto-detect browser and parse last 7 days
    python browser_history_parser.py --days 7

    # Parse Chrome specifically, last 14 days, top 20 domains
    python browser_history_parser.py --browser chrome --days 14 --top 20

    # Output to file for Midas input
    python browser_history_parser.py --days 7 -o midas_browsing_input.md

Notes:
    - Reads COPIES of browser databases to avoid locking issues.
    - Does NOT transmit any data. Everything stays local.
    - Close the browser before running for most accurate results.
"""

import argparse
import os
import platform
import re
import shutil
import sqlite3
import sys
import tempfile
from collections import Counter
from datetime import datetime, timedelta, timezone
from pathlib import Path
from urllib.parse import parse_qs, unquote, urlparse


# ---------------------------------------------------------------------------
# Browser database locations
# ---------------------------------------------------------------------------

def get_chrome_history_path() -> str:
    """Return the path to Chrome's History SQLite database."""
    system = platform.system()
    home = Path.home()
    if system == "Darwin":
        return str(home / "Library/Application Support/Google/Chrome/Default/History")
    elif system == "Linux":
        return str(home / ".config/google-chrome/Default/History")
    elif system == "Windows":
        return str(home / r"AppData\Local\Google\Chrome\User Data\Default\History")
    return ""


def get_firefox_history_path() -> str:
    """Return the path to Firefox's places.sqlite database."""
    system = platform.system()
    home = Path.home()
    if system == "Darwin":
        profiles_dir = home / "Library/Application Support/Firefox/Profiles"
    elif system == "Linux":
        profiles_dir = home / ".mozilla/firefox"
    elif system == "Windows":
        profiles_dir = home / r"AppData\Roaming\Mozilla\Firefox\Profiles"
    else:
        return ""

    if not profiles_dir.exists():
        return ""

    # Find the default profile (ends with .default-release or .default)
    for profile in sorted(profiles_dir.iterdir(), reverse=True):
        places = profile / "places.sqlite"
        if places.exists():
            return str(places)
    return ""


def get_safari_history_path() -> str:
    """Return the path to Safari's History.db database."""
    if platform.system() != "Darwin":
        return ""
    return str(Path.home() / "Library/Safari/History.db")


def detect_browser() -> tuple:
    """Auto-detect available browser and return (name, db_path)."""
    for name, getter in [
        ("chrome", get_chrome_history_path),
        ("firefox", get_firefox_history_path),
        ("safari", get_safari_history_path),
    ]:
        path = getter()
        if path and Path(path).exists():
            return name, path
    return None, None


# ---------------------------------------------------------------------------
# Database reading (copy first to avoid lock conflicts)
# ---------------------------------------------------------------------------

def copy_db(db_path: str) -> str:
    """Copy the database to a temp file to avoid SQLite locking issues."""
    tmp = tempfile.NamedTemporaryFile(suffix=".sqlite", delete=False)
    tmp.close()
    shutil.copy2(db_path, tmp.name)
    # Also copy WAL and SHM if they exist (Chrome uses WAL mode)
    for ext in ("-wal", "-shm"):
        wal = db_path + ext
        if os.path.exists(wal):
            shutil.copy2(wal, tmp.name + ext)
    return tmp.name


def read_chrome_history(db_path: str, days: int) -> list:
    """Read Chrome history from its SQLite database.

    Chrome stores timestamps as microseconds since 1601-01-01 (Windows epoch).
    """
    tmp_path = copy_db(db_path)
    try:
        conn = sqlite3.connect(tmp_path)
        # Chrome epoch: microseconds since 1601-01-01
        # Unix epoch offset: 11644473600 seconds
        cutoff_unix = (datetime.now(tz=timezone.utc) - timedelta(days=days)).timestamp()
        cutoff_chrome = int((cutoff_unix + 11644473600) * 1_000_000)

        cursor = conn.execute(
            "SELECT url, title, visit_count, last_visit_time "
            "FROM urls WHERE last_visit_time > ? "
            "ORDER BY last_visit_time DESC",
            (cutoff_chrome,),
        )
        rows = []
        for url, title, visit_count, last_visit in cursor.fetchall():
            ts_unix = (last_visit / 1_000_000) - 11644473600
            rows.append({
                "url": url,
                "title": title or "",
                "visit_count": visit_count,
                "timestamp": datetime.fromtimestamp(ts_unix, tz=timezone.utc),
            })
        conn.close()
        return rows
    finally:
        os.unlink(tmp_path)
        for ext in ("-wal", "-shm"):
            p = tmp_path + ext
            if os.path.exists(p):
                os.unlink(p)


def read_firefox_history(db_path: str, days: int) -> list:
    """Read Firefox history from places.sqlite.

    Firefox stores timestamps as microseconds since Unix epoch.
    """
    tmp_path = copy_db(db_path)
    try:
        conn = sqlite3.connect(tmp_path)
        cutoff = int(
            (datetime.now(tz=timezone.utc) - timedelta(days=days)).timestamp()
            * 1_000_000
        )
        cursor = conn.execute(
            "SELECT p.url, p.title, p.visit_count, p.last_visit_date "
            "FROM moz_places p "
            "WHERE p.last_visit_date > ? "
            "ORDER BY p.last_visit_date DESC",
            (cutoff,),
        )
        rows = []
        for url, title, visit_count, last_visit in cursor.fetchall():
            ts = datetime.fromtimestamp(last_visit / 1_000_000, tz=timezone.utc)
            rows.append({
                "url": url,
                "title": title or "",
                "visit_count": visit_count or 1,
                "timestamp": ts,
            })
        conn.close()
        return rows
    finally:
        os.unlink(tmp_path)


def read_safari_history(db_path: str, days: int) -> list:
    """Read Safari history from History.db.

    Safari stores timestamps as seconds since 2001-01-01 (Core Data epoch).
    """
    tmp_path = copy_db(db_path)
    try:
        conn = sqlite3.connect(tmp_path)
        # Core Data epoch offset: 978307200 seconds from Unix epoch
        cutoff_unix = (datetime.now(tz=timezone.utc) - timedelta(days=days)).timestamp()
        cutoff_safari = cutoff_unix - 978307200

        cursor = conn.execute(
            "SELECT hi.url, hv.title, hv.visit_time "
            "FROM history_items hi "
            "JOIN history_visits hv ON hi.id = hv.history_item "
            "WHERE hv.visit_time > ? "
            "ORDER BY hv.visit_time DESC",
            (cutoff_safari,),
        )
        rows = []
        for url, title, visit_time in cursor.fetchall():
            ts = datetime.fromtimestamp(visit_time + 978307200, tz=timezone.utc)
            rows.append({
                "url": url,
                "title": title or "",
                "visit_count": 1,
                "timestamp": ts,
            })
        conn.close()
        return rows
    finally:
        os.unlink(tmp_path)


# ---------------------------------------------------------------------------
# URL analysis
# ---------------------------------------------------------------------------

def extract_search_query(url: str) -> str:
    """Extract the search query from a search engine URL, if present."""
    parsed = urlparse(url)
    host = parsed.hostname or ""

    search_params = {
        "google": "q",
        "bing": "q",
        "duckduckgo": "q",
        "baidu": "wd",
        "yahoo": "p",
    }

    for engine, param in search_params.items():
        if engine in host:
            qs = parse_qs(parsed.query)
            if param in qs:
                return unquote(qs[param][0])
    return ""


def extract_youtube_title(entry: dict) -> str:
    """Extract YouTube video title from a history entry."""
    parsed = urlparse(entry["url"])
    if "youtube.com" in (parsed.hostname or "") and "/watch" in parsed.path:
        title = entry["title"]
        # Strip " - YouTube" suffix
        title = re.sub(r"\s*[-–—]\s*YouTube\s*$", "", title)
        return title
    return ""


def extract_domain(url: str) -> str:
    """Extract the base domain from a URL."""
    parsed = urlparse(url)
    host = parsed.hostname or ""
    # Remove www. prefix
    if host.startswith("www."):
        host = host[4:]
    return host


# ---------------------------------------------------------------------------
# Output formatting
# ---------------------------------------------------------------------------

def format_output(entries: list, browser: str, days: int, top_n: int) -> str:
    """Format browsing history into Midas-ready Markdown input."""
    if not entries:
        return "# Midas Input — Browser History\n\nNo browsing history found.\n"

    # Analysis
    domains = Counter()
    search_queries = []
    youtube_videos = []
    daily_counts = Counter()

    for e in entries:
        domain = extract_domain(e["url"])
        if domain:
            domains[domain] += e.get("visit_count", 1)

        query = extract_search_query(e["url"])
        if query:
            search_queries.append(query)

        yt_title = extract_youtube_title(e)
        if yt_title:
            youtube_videos.append(yt_title)

        day = e["timestamp"].strftime("%Y-%m-%d (%A)")
        daily_counts[day] += 1

    # Deduplicate and count search queries
    query_counts = Counter(q.lower() for q in search_queries)

    lines = [
        "# Midas Input — Browser History",
        "",
        f"**Browser:** {browser}",
        f"**Time window:** last {days} days",
        f"**Total entries:** {len(entries)}",
        f"**Unique domains:** {len(domains)}",
        f"**Search queries:** {len(search_queries)}",
        f"**YouTube videos:** {len(youtube_videos)}",
        "",
        "---",
        "",
    ]

    # Top domains
    lines.append(f"## Top {top_n} Domains")
    lines.append("")
    lines.append("| # | Domain | Visits |")
    lines.append("|---|--------|--------|")
    for i, (domain, count) in enumerate(domains.most_common(top_n), 1):
        lines.append(f"| {i} | {domain} | {count} |")
    lines.append("")

    # Search queries
    if query_counts:
        lines.append(f"## Top Search Queries")
        lines.append("")
        lines.append("| # | Query | Count |")
        lines.append("|---|-------|-------|")
        for i, (query, count) in enumerate(query_counts.most_common(top_n), 1):
            lines.append(f"| {i} | {query} | {count} |")
        lines.append("")

    # YouTube videos
    if youtube_videos:
        lines.append(f"## YouTube Watch History ({len(youtube_videos)} videos)")
        lines.append("")
        for title in youtube_videos:
            lines.append(f"- {title}")
        lines.append("")

    # Daily pattern
    lines.append("## Daily Browsing Pattern")
    lines.append("")
    lines.append("| Day | Entries |")
    lines.append("|-----|---------|")
    for day in sorted(daily_counts.keys()):
        lines.append(f"| {day} | {daily_counts[day]} |")
    lines.append("")

    lines.append("---")
    lines.append("")
    lines.append(
        "> Parsed by midas-skill/tools/browser_history_parser.py — "
        "feed this file to Midas with 'Midas, mine this'"
    )
    lines.append("")
    lines.append(
        "> **Privacy note:** This file was generated locally from a copy "
        "of your browser's SQLite database. No data was transmitted anywhere."
    )
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(
        description="Midas Skill — Browser History Parser. "
        "Extracts local browsing history for Midas signal extraction.",
    )
    parser.add_argument(
        "-b", "--browser",
        choices=["auto", "chrome", "firefox", "safari"],
        default="auto",
        help="Browser to read from (default: auto-detect)",
    )
    parser.add_argument(
        "-d", "--days", type=int, default=7,
        help="Number of days of history to parse (default: 7)",
    )
    parser.add_argument("-o", "--output", help="Output file path (default: stdout)")
    parser.add_argument(
        "--top", type=int, default=15,
        help="Number of top domains/queries to show (default: 15)",
    )
    args = parser.parse_args()

    # Find the browser database
    if args.browser == "auto":
        browser, db_path = detect_browser()
        if not browser:
            print(
                "⚠️  Could not auto-detect any browser history database.\n"
                "   Try specifying --browser chrome|firefox|safari explicitly.",
                file=sys.stderr,
            )
            sys.exit(1)
    else:
        browser = args.browser
        getter = {
            "chrome": get_chrome_history_path,
            "firefox": get_firefox_history_path,
            "safari": get_safari_history_path,
        }[browser]
        db_path = getter()
        if not db_path or not Path(db_path).exists():
            print(
                f"⚠️  {browser.title()} history database not found at expected path.\n"
                f"   Expected: {db_path or '(not available on this OS)'}",
                file=sys.stderr,
            )
            sys.exit(1)

    print(f"📖 Reading {browser.title()} history (last {args.days} days)...", file=sys.stderr)

    # Read history
    reader = {
        "chrome": read_chrome_history,
        "firefox": read_firefox_history,
        "safari": read_safari_history,
    }[browser]

    try:
        entries = reader(db_path, args.days)
    except Exception as e:
        print(
            f"⚠️  Error reading {browser} history: {e}\n"
            f"   Try closing {browser.title()} first, then re-run.",
            file=sys.stderr,
        )
        sys.exit(1)

    output = format_output(entries, browser, args.days, args.top)

    if args.output:
        Path(args.output).write_text(output, encoding="utf-8")
        print(f"✅ Parsed {len(entries)} entries → {args.output}", file=sys.stderr)
    else:
        print(output)


if __name__ == "__main__":
    main()
