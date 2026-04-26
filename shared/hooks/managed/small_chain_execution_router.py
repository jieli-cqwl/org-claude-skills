#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import re
import subprocess
import sys
from pathlib import Path


def runtime_home() -> Path:
    current = Path(__file__).resolve()
    candidates = [current.parents[2]]
    if len(current.parents) > 3:
        candidates.append(current.parents[3])
    for candidate in candidates:
        if (candidate / "tools" / "community" / "small_chain_execution_router.py").is_file():
            return candidate
    return candidates[0]


RUNTIME_HOME = runtime_home()
TOOLS_DIR = RUNTIME_HOME / "tools" / "community"
ROUTER = TOOLS_DIR / "small_chain_execution_router.py"
ROUTER_TIMEOUT_SEC = 30

if str(TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR))

from runtime_yaml import load_yaml  # noqa: E402


def load_payload() -> dict:
    text = sys.stdin.read()
    if not text.strip():
        return {}
    try:
        payload = json.loads(text)
    except Exception:
        return {}
    return payload if isinstance(payload, dict) else {}


def payload_cwd(payload: dict) -> Path:
    cwd = payload.get("cwd")
    if isinstance(cwd, str) and cwd:
        return Path(cwd)
    return Path(os.getcwd())


def git_root(cwd: Path) -> Path | None:
    try:
        proc = subprocess.run(
            ["git", "-C", str(cwd), "rev-parse", "--show-toplevel"],
            text=True,
            capture_output=True,
            timeout=2,
        )
    except Exception:
        return None
    if proc.returncode != 0:
        return None
    value = proc.stdout.strip()
    return Path(value) if value else None


def find_context_root(cwd: Path) -> Path:
    root = git_root(cwd)
    if root is not None:
        return root
    resolved = cwd.resolve()
    for candidate in (resolved, *resolved.parents):
        if (candidate / "contracts" / "active-doc-scope.yaml").is_file():
            return candidate
    return resolved


def is_participating_repo(root: Path) -> bool:
    return (root / "contracts" / "active-doc-scope.yaml").is_file()


def emit_allow() -> int:
    print("{}")
    return 0


def emit_stop(reason: str) -> int:
    cleaned = reason.strip() or "small-chain execution routing requires attention."
    print(
        json.dumps(
            {
                "continue": False,
                "stopReason": cleaned,
                "systemMessage": cleaned,
            },
            ensure_ascii=False,
        )
    )
    return 0


def load_active_small_chains(root: Path) -> list[tuple[str, str]]:
    registry = load_yaml(root / "contracts" / "active-doc-scope.yaml")
    entries: list[tuple[str, str]] = []
    for entry in registry.get("scope_entries", []):
        if entry.get("mode") != "small-chain":
            continue
        if entry.get("management_status") not in {"managed", "migrated"}:
            continue
        feature_path = entry.get("feature_path")
        workset = entry.get("primary_workset_relpath")
        if isinstance(feature_path, str) and isinstance(workset, str):
            entries.append((feature_path, workset))
    return entries


def is_relative_to(path: Path, parent: Path) -> bool:
    try:
        path.resolve().relative_to(parent.resolve())
    except ValueError:
        return False
    return True


def parse_latest_worklog(path: Path) -> dict[str, str]:
    lines = path.read_text(encoding="utf-8").splitlines()
    start = next((idx for idx, line in enumerate(lines) if line.startswith("## ")), None)
    if start is None:
        return {}
    fields: dict[str, str] = {}
    for line in lines[start + 1 :]:
        if line.startswith("## "):
            break
        match = re.match(r"^-\s+([A-Za-z_]+):\s*(.*)$", line)
        if match:
            fields[match.group(1)] = match.group(2).strip()
    return fields


def should_route(root: Path, feature_path: str, workset: str) -> bool:
    feature_dir = root / feature_path
    worklog = feature_dir / "worklog.md"
    if not worklog.is_file():
        return False
    fields = parse_latest_worklog(worklog)
    return fields.get("mode") == "small-chain" and fields.get("stage") == "plan"


def select_active_small_chain(root: Path, cwd: Path) -> tuple[str, str] | None:
    entries = load_active_small_chains(root)
    if not entries:
        return None
    cwd_matches = [entry for entry in entries if is_relative_to(cwd, root / entry[0])]
    if cwd_matches:
        return cwd_matches[0]
    plan_entries = [entry for entry in entries if should_route(root, entry[0], entry[1])]
    if len(plan_entries) > 1:
        refs = ", ".join(f"{feature}/{workset}" for feature, workset in plan_entries)
        raise ValueError(f"ambiguous small-chain plan worksets: {refs}")
    return plan_entries[0] if plan_entries else None


def parse_router_output(stdout: str, fallback: str) -> dict:
    for raw in reversed(stdout.splitlines()):
        try:
            value = json.loads(raw)
        except Exception:
            continue
        if isinstance(value, dict):
            return value
    return {"decision": "blocked", "reason": fallback}


def router_message(route: dict) -> str:
    decision = route.get("decision")
    reason = route.get("reason")
    route_ref = f"{route.get('feature_path')}/{route.get('workset')}/execution-route.json"
    if decision == "blocked":
        return f"small-chain execution routing blocked: {reason}. Inspect {route_ref} before continuing."
    if decision == "parallel":
        return f"small-chain execution route ready: decision=parallel. Continue with parallel-subagent-development using {route_ref}."
    if decision == "serial":
        return f"small-chain execution route ready: decision=serial. Continue with using-git-worktrees then subagent-driven-development using {route_ref}."
    return f"small-chain execution routing returned unknown decision: {decision}."


def main() -> int:
    payload = load_payload()
    cwd = payload_cwd(payload)
    root = find_context_root(cwd)
    if not is_participating_repo(root):
        return emit_allow()
    try:
        active = select_active_small_chain(root, cwd)
    except ValueError as exc:
        return emit_stop(str(exc))
    if active is None:
        return emit_allow()
    feature_path, workset = active
    if not should_route(root, feature_path, workset):
        return emit_allow()
    if not ROUTER.is_file():
        return emit_stop("small-chain execution router runtime file missing.")
    try:
        proc = subprocess.run(
            [
                sys.executable,
                str(ROUTER),
                "--repo-root",
                str(root),
                "--feature-path",
                feature_path,
                "--workset",
                workset,
            ],
            text=True,
            capture_output=True,
            timeout=ROUTER_TIMEOUT_SEC,
        )
    except subprocess.TimeoutExpired:
        return emit_stop("small-chain execution router timed out.")
    route = parse_router_output(proc.stdout, (proc.stderr or "router failed").strip())
    return emit_stop(router_message(route))


if __name__ == "__main__":
    raise SystemExit(main())
