#!/usr/bin/env python3
"""
Midas Skill — Evolution Manager

Manages the evolution/evolution.jsonl log — Midas's cumulative memory.

Provides:
  - append: Add a new evolution entry
  - list:   List all tracked opportunities with current confidence
  - show:   Show the full history of a specific opportunity
  - stats:  Print summary statistics across all runs
  - decay:  Apply confidence decay to stale opportunities (no new evidence in 30 days)
  - golden: List all opportunities currently at 70%+ confidence (GOLDEN)

Usage:
    python evolution_manager.py <command> [--evolution-dir <path>]

Examples:
    # Show all GOLDEN opportunities
    python evolution_manager.py golden

    # List all opportunities sorted by confidence
    python evolution_manager.py list

    # Show the full evidence chain for opportunity opp-001
    python evolution_manager.py show opp-001

    # Print summary stats
    python evolution_manager.py stats

    # Apply confidence decay to stale opportunities
    python evolution_manager.py decay

    # Append a new entry from stdin (JSON)
    echo '{"timestamp":"...","input_type":"slack",...}' | python evolution_manager.py append
"""

import argparse
import json
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path


DEFAULT_EVOLUTION_DIR = "evolution"
EVOLUTION_FILE = "evolution.jsonl"
DECAY_DAYS = 30
DECAY_AMOUNT = 0.10  # Drop 10 percentage points after 30 days with no new evidence
GOLDEN_THRESHOLD = 0.70


def get_evolution_path(evolution_dir: str) -> Path:
    """Resolve the path to evolution.jsonl."""
    return Path(evolution_dir) / EVOLUTION_FILE


def load_entries(evolution_dir: str) -> list:
    """Load all entries from evolution.jsonl."""
    path = get_evolution_path(evolution_dir)
    if not path.exists():
        return []
    entries = []
    with open(path, "r", encoding="utf-8") as f:
        for line_num, line in enumerate(f, 1):
            line = line.strip()
            if not line:
                continue
            try:
                entries.append(json.loads(line))
            except json.JSONDecodeError as e:
                print(
                    f"⚠️  Skipping malformed line {line_num}: {e}",
                    file=sys.stderr,
                )
    return entries


def save_entries(evolution_dir: str, entries: list):
    """Write all entries back to evolution.jsonl."""
    path = get_evolution_path(evolution_dir)
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        for entry in entries:
            f.write(json.dumps(entry, ensure_ascii=False) + "\n")


def append_entry(evolution_dir: str, entry: dict):
    """Append a single entry to evolution.jsonl."""
    path = get_evolution_path(evolution_dir)
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "a", encoding="utf-8") as f:
        f.write(json.dumps(entry, ensure_ascii=False) + "\n")


# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------

def cmd_append(args):
    """Append a new evolution entry from stdin or file."""
    if args.file:
        with open(args.file, "r", encoding="utf-8") as f:
            data = f.read()
    else:
        data = sys.stdin.read()

    try:
        entry = json.loads(data)
    except json.JSONDecodeError as e:
        print(f"❌ Invalid JSON: {e}", file=sys.stderr)
        sys.exit(1)

    # Validate required fields
    required = ["timestamp", "input_type"]
    missing = [f for f in required if f not in entry]
    if missing:
        print(f"❌ Missing required fields: {', '.join(missing)}", file=sys.stderr)
        sys.exit(1)

    append_entry(args.evolution_dir, entry)
    opp_count = len(entry.get("opportunities", []))
    print(
        f"✅ Appended entry: {entry['input_type']} at {entry['timestamp']} "
        f"({opp_count} opportunities)",
    )


def cmd_list(args):
    """List all tracked opportunities with latest confidence."""
    entries = load_entries(args.evolution_dir)
    if not entries:
        print("No evolution entries found.")
        return

    # Build latest state per opportunity
    opportunities = {}
    for entry in entries:
        for opp in entry.get("opportunities", []):
            opp_id = opp.get("id", "unknown")
            opportunities[opp_id] = {
                "id": opp_id,
                "title": opp.get("title", "untitled"),
                "confidence": opp.get("confidence", 0),
                "lens": opp.get("lens", ""),
                "effort": opp.get("effort", ""),
                "upside": opp.get("upside", ""),
                "last_updated": entry.get("timestamp", ""),
                "pattern_match": opp.get("pattern_match", ""),
                "golden": opp.get("confidence", 0) >= GOLDEN_THRESHOLD,
            }

    # Sort by confidence descending
    sorted_opps = sorted(
        opportunities.values(), key=lambda o: o["confidence"], reverse=True
    )

    print(f"{'ID':<10} {'Conf':>5} {'Flag':>6} {'Title':<50} {'Last Updated':<22}")
    print("-" * 95)
    for o in sorted_opps:
        flag = "🏆 GOLD" if o["golden"] else ""
        conf = f"{o['confidence']:.0%}"
        print(f"{o['id']:<10} {conf:>5} {flag:>6} {o['title']:<50} {o['last_updated']:<22}")


def cmd_show(args):
    """Show the full history of a specific opportunity."""
    entries = load_entries(args.evolution_dir)
    opp_id = args.opportunity_id

    history = []
    for entry in entries:
        for opp in entry.get("opportunities", []):
            if opp.get("id") == opp_id:
                history.append({
                    "timestamp": entry.get("timestamp", ""),
                    "input_type": entry.get("input_type", ""),
                    **opp,
                })

    if not history:
        print(f"No history found for opportunity '{opp_id}'.")
        return

    latest = history[-1]
    print(f"# Opportunity: {latest.get('title', opp_id)}")
    print(f"**ID:** {opp_id}")
    print(f"**Current confidence:** {latest.get('confidence', 0):.0%}")
    print(f"**Lens:** {latest.get('lens', 'unknown')}")
    print(f"**Effort:** {latest.get('effort', 'unknown')}")
    print(f"**Upside:** {latest.get('upside', 'unknown')}")
    print(f"**Pattern match:** {latest.get('pattern_match', 'none')}")
    print(f"**Next action:** {latest.get('next_action', 'none')}")
    print()
    print("## Evidence Chain")
    print()

    all_evidence = []
    for h in history:
        for e in h.get("evidence", []):
            if e not in all_evidence:
                all_evidence.append(e)
    for i, e in enumerate(all_evidence, 1):
        print(f"{i}. {e}")

    print()
    print("## Confidence History")
    print()
    print(f"{'Timestamp':<22} {'Input Type':<20} {'Confidence':>10} {'Change':>10}")
    print("-" * 65)
    for h in history:
        conf = f"{h.get('confidence', 0):.0%}"
        change = h.get("confidence_change", "")
        print(f"{h['timestamp']:<22} {h['input_type']:<20} {conf:>10} {change:>10}")


def cmd_stats(args):
    """Print summary statistics across all evolution runs."""
    entries = load_entries(args.evolution_dir)
    if not entries:
        print("No evolution entries found.")
        return

    total_runs = len(entries)
    total_signals = sum(e.get("signals_extracted", 0) for e in entries)
    total_cross_refs = sum(e.get("cross_references_found", 0) for e in entries)

    # Count unique opportunities
    opp_ids = set()
    golden_ids = set()
    for entry in entries:
        for opp in entry.get("opportunities", []):
            oid = opp.get("id", "unknown")
            opp_ids.add(oid)
            if opp.get("confidence", 0) >= GOLDEN_THRESHOLD or opp.get("golden"):
                golden_ids.add(oid)

    # Input type distribution
    input_types = {}
    for entry in entries:
        it = entry.get("input_type", "unknown")
        input_types[it] = input_types.get(it, 0) + 1

    # Time span
    timestamps = []
    for entry in entries:
        ts = entry.get("timestamp", "")
        if ts:
            timestamps.append(ts)

    print("# Midas Evolution Stats")
    print()
    print(f"**Total runs:** {total_runs}")
    print(f"**Total signals extracted:** {total_signals}")
    print(f"**Total cross-references:** {total_cross_refs}")
    print(f"**Unique opportunities tracked:** {len(opp_ids)}")
    print(f"**GOLDEN opportunities (70%+):** {len(golden_ids)}")
    if timestamps:
        print(f"**First run:** {min(timestamps)}")
        print(f"**Latest run:** {max(timestamps)}")
    print()
    print("## Input Type Distribution")
    print()
    for it, count in sorted(input_types.items(), key=lambda x: -x[1]):
        print(f"- {it}: {count} runs")
    if golden_ids:
        print()
        print("## GOLDEN Opportunities")
        print()
        for gid in sorted(golden_ids):
            print(f"- {gid}")


def cmd_golden(args):
    """List all GOLDEN opportunities (70%+ confidence)."""
    entries = load_entries(args.evolution_dir)
    if not entries:
        print("No evolution entries found.")
        return

    # Get latest confidence for each opportunity
    latest = {}
    for entry in entries:
        for opp in entry.get("opportunities", []):
            oid = opp.get("id", "unknown")
            latest[oid] = {
                "title": opp.get("title", "untitled"),
                "confidence": opp.get("confidence", 0),
                "next_action": opp.get("next_action", ""),
                "pattern_match": opp.get("pattern_match", ""),
                "last_updated": entry.get("timestamp", ""),
            }

    golden = {
        k: v for k, v in latest.items()
        if v["confidence"] >= GOLDEN_THRESHOLD
    }

    if not golden:
        print("No GOLDEN opportunities (70%+) found yet.")
        print("Keep feeding Midas varied inputs to build conviction.")
        return

    print(f"# 🏆 GOLDEN Opportunities ({len(golden)} found)")
    print()
    for oid, opp in sorted(golden.items(), key=lambda x: -x[1]["confidence"]):
        print(f"## {oid} — {opp['title']}")
        print(f"**Confidence:** {opp['confidence']:.0%}")
        print(f"**Pattern match:** {opp['pattern_match']}")
        print(f"**Next action:** {opp['next_action']}")
        print(f"**Last updated:** {opp['last_updated']}")
        print()


def cmd_decay(args):
    """Apply confidence decay to stale opportunities.

    Any opportunity with no new evidence for DECAY_DAYS loses DECAY_AMOUNT
    from its confidence score. Creates a new evolution entry to record the decay.
    """
    entries = load_entries(args.evolution_dir)
    if not entries:
        print("No evolution entries found.")
        return

    now = datetime.now(tz=timezone.utc)
    cutoff = now - timedelta(days=DECAY_DAYS)

    # Find last-updated time for each opportunity
    last_seen = {}
    latest_state = {}
    for entry in entries:
        entry_ts = entry.get("timestamp", "")
        for opp in entry.get("opportunities", []):
            oid = opp.get("id", "unknown")
            last_seen[oid] = entry_ts
            latest_state[oid] = dict(opp)

    # Find opportunities that need decay
    decayed = []
    for oid, ts_str in last_seen.items():
        try:
            ts = datetime.fromisoformat(ts_str.replace("Z", "+00:00"))
        except (ValueError, AttributeError):
            continue
        if ts < cutoff:
            old_conf = latest_state[oid].get("confidence", 0)
            new_conf = max(0, old_conf - DECAY_AMOUNT)
            if new_conf != old_conf:
                decayed.append({
                    **latest_state[oid],
                    "confidence": round(new_conf, 2),
                    "confidence_change": f"-{DECAY_AMOUNT:.0%}",
                })

    if not decayed:
        print("No opportunities need decay. All have recent evidence.")
        return

    # Append decay entry
    decay_entry = {
        "timestamp": now.isoformat(),
        "input_type": "decay_adjustment",
        "input_summary": f"Confidence decay applied to {len(decayed)} stale opportunities (>{DECAY_DAYS} days without new evidence)",
        "signals_extracted": 0,
        "cross_references_found": 0,
        "new_opportunities": 0,
        "updated_opportunities": len(decayed),
        "opportunities": decayed,
    }
    append_entry(args.evolution_dir, decay_entry)

    print(f"📉 Applied confidence decay to {len(decayed)} opportunities:")
    for opp in decayed:
        print(f"   {opp['id']}: {opp['confidence']:.0%} ({opp['confidence_change']})")


def main():
    parser = argparse.ArgumentParser(
        description="Midas Skill — Evolution Manager. "
        "Manage the cumulative evolution.jsonl log.",
    )
    parser.add_argument(
        "--evolution-dir",
        default=DEFAULT_EVOLUTION_DIR,
        help=f"Path to evolution directory (default: {DEFAULT_EVOLUTION_DIR})",
    )

    subparsers = parser.add_subparsers(dest="command", required=True)

    # append
    p_append = subparsers.add_parser("append", help="Append a new entry")
    p_append.add_argument("--file", help="Read entry from file instead of stdin")

    # list
    subparsers.add_parser("list", help="List all opportunities with latest confidence")

    # show
    p_show = subparsers.add_parser("show", help="Show full history of an opportunity")
    p_show.add_argument("opportunity_id", help="Opportunity ID (e.g. opp-001)")

    # stats
    subparsers.add_parser("stats", help="Print summary statistics")

    # golden
    subparsers.add_parser("golden", help="List GOLDEN opportunities (70%+)")

    # decay
    subparsers.add_parser("decay", help="Apply confidence decay to stale opportunities")

    args = parser.parse_args()

    commands = {
        "append": cmd_append,
        "list": cmd_list,
        "show": cmd_show,
        "stats": cmd_stats,
        "golden": cmd_golden,
        "decay": cmd_decay,
    }
    commands[args.command](args)


if __name__ == "__main__":
    main()
