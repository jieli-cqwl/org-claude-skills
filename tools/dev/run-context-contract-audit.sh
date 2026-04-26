#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
REPO_ROOT="$BASE_DIR"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo-root)
      REPO_ROOT="$2"
      shift 2
      ;;
    -h|--help)
      cat <<'USAGE'
Usage: bash tools/dev/run-context-contract-audit.sh [--repo-root PATH]

Report long-term context-contract risks without modifying registry, worklog, or docs.
USAGE
      exit 0
      ;;
    *)
      echo "FATAL: unknown option: $1" >&2
      exit 1
      ;;
  esac
done

python3 - "$BASE_DIR" "$REPO_ROOT" <<'PY'
from __future__ import annotations

import re
import sys
from datetime import date, datetime
from pathlib import Path

base_dir = Path(sys.argv[1])
repo_root = Path(sys.argv[2]).resolve()
sys.path.insert(0, str(base_dir / "tools" / "community"))

from runtime_yaml import load_yaml


def parse_latest_worklog(path: Path) -> tuple[str, dict[str, str]]:
    lines = path.read_text(encoding="utf-8").splitlines()
    started = False
    timestamp = ""
    fields: dict[str, str] = {}
    for line in lines:
        if line.startswith("## ") and not started:
            timestamp = line.removeprefix("## ").strip()
            started = True
            continue
        if started and line.startswith("## "):
            break
        if not started:
            continue
        match = re.match(r"^-\s+([A-Za-z_]+):\s*(.*)$", line)
        if match:
            fields[match.group(1)] = match.group(2).strip()
    return timestamp, fields


def emit(risk: str, path: Path | str, detail: str) -> None:
    print(f"- risk: {risk}")
    print(f"  path: {path}")
    print(f"  detail: {detail}")


def parse_date_prefix(value: str) -> date | None:
    try:
        return datetime.strptime(value[:10], "%Y-%m-%d").date()
    except ValueError:
        return None


def main() -> int:
    registry_path = repo_root / "contracts" / "active-doc-scope.yaml"
    registry = load_yaml(registry_path)
    today = date.today()

    print("context_contract_audit:")
    emitted = False
    for entry in registry.get("scope_entries", []):
        status = entry.get("management_status") or entry.get("status")
        feature_path = entry.get("feature_path")
        if status in {"managed", "migrated"} and isinstance(feature_path, str):
            worklog = repo_root / feature_path / str(entry.get("entry_ref", "worklog.md"))
            if worklog.is_file():
                timestamp, fields = parse_latest_worklog(worklog)
                opened = parse_date_prefix(timestamp)
                if fields.get("handoff_status") == "blocked" and opened and (today - opened).days > 14:
                    emit("long_blocked", worklog.relative_to(repo_root), f"blocked_since={timestamp}")
                    emitted = True
            supporting_dir = repo_root / feature_path / "supporting"
            if supporting_dir.exists():
                count = len(list(supporting_dir.glob("*.md")))
                if count > 3:
                    emit("supporting_overuse", supporting_dir.relative_to(repo_root), f"supporting_docs={count}")
                    emitted = True
        if status == "legacy":
            archive_ref = entry.get("archive_ref")
            if not archive_ref or not (repo_root / str(archive_ref)).exists():
                emit("legacy_drift", registry_path.relative_to(repo_root), f"feature_path={feature_path}")
                emitted = True

    for waiver in (repo_root / "docs").glob("feature--*/contract-waivers.md"):
        text = waiver.read_text(encoding="utf-8")
        for expires_at in re.findall(r"expires_at:\s*(\d{4}-\d{2}-\d{2})", text):
            expires = parse_date_prefix(expires_at)
            if expires and expires < today:
                emit("expired_waiver", waiver.relative_to(repo_root), f"expires_at={expires_at}")
                emitted = True

    if not emitted:
        print("- risk: none")
        print("  detail: no report-only risks found")
    return 0


raise SystemExit(main())
PY
