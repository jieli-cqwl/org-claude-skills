#!/usr/bin/env python3
"""Validate delivery-owner commit handoff against signed canonical evidence and Git state."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

from normalize_canonical_artifact import ROOT, load_json


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--phase-dir", type=Path, required=True)
    parser.add_argument("--repo-root", type=Path, required=True)
    parser.add_argument("--allowed-path", action="append", default=[])
    parser.add_argument("--expected-head")
    parser.add_argument("--message", required=True)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--allow-main", action="store_true")
    return parser.parse_args()


def run_git(repo_root: Path, *args: str) -> str:
    result = subprocess.run(
        ["git", "-C", str(repo_root), *args],
        check=True,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    return result.stdout.strip()


def git_changed_paths(repo_root: Path) -> list[str]:
    output = run_git(repo_root, "status", "--short")
    paths: list[str] = []
    for line in output.splitlines():
        if not line.strip():
            continue
        path_text = line[2:].strip()
        if " -> " in path_text:
            path_text = path_text.split(" -> ", 1)[1].strip()
        paths.append(path_text)
    return sorted(paths)


def normalize_pathspec(pathspec: str) -> str:
    value = pathspec.strip().replace("\\", "/")
    if not value or value.startswith("/") or value == "." or ".." in Path(value).parts:
        raise ValueError(f"invalid allowed pathspec: {pathspec}")
    return value.rstrip("/")


def path_allowed(path: str, allowed_pathspecs: list[str]) -> bool:
    normalized = path.replace("\\", "/").strip("/")
    return any(normalized == spec or normalized.startswith(f"{spec}/") for spec in allowed_pathspecs)


def assert_canonical_readiness(phase_dir: Path) -> None:
    validator = ROOT / "tools/community/validate_standard_chain_readiness.py"
    subprocess.run(
        [sys.executable, str(validator), "--phase-dir", str(phase_dir)],
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )


def build_ref(artifact_type: str, artifact_id: str, anchor: str) -> str:
    return f"artifact://{artifact_type}/{artifact_id}@v1#{anchor}"


def validate_commit_preflight(args: argparse.Namespace) -> dict:
    repo_root = args.repo_root.resolve()
    phase_dir = args.phase_dir.resolve()
    if not repo_root.is_dir():
        raise ValueError(f"repo root does not exist: {repo_root}")
    if not phase_dir.is_dir():
        raise ValueError(f"phase dir does not exist: {phase_dir}")

    allowed_pathspecs = [normalize_pathspec(item) for item in args.allowed_path]
    if not allowed_pathspecs:
        raise ValueError("at least one --allowed-path is required")

    branch = run_git(repo_root, "branch", "--show-current")
    if branch in {"main", "master"} and not args.allow_main:
        raise ValueError("main/master branch requires --allow-main for commit preflight")
    head = run_git(repo_root, "rev-parse", "HEAD")
    if args.expected_head and head != args.expected_head:
        raise ValueError(f"HEAD drift: expected {args.expected_head}, got {head}")

    assert_canonical_readiness(phase_dir)
    signoff = load_json(phase_dir / "signoff-package.json")
    decision = load_json(phase_dir / "user-decision.json")
    if signoff.get("sign_off_status") != "SIGNED_OFF":
        raise ValueError("signoff-package.sign_off_status must be SIGNED_OFF before commit")
    if decision.get("sign_off_status") != "SIGNED_OFF":
        raise ValueError("user-decision.sign_off_status must be SIGNED_OFF before commit")
    risk_status = str(decision.get("business_risk_acceptance_status", "")).strip()
    if risk_status not in {"ACCEPTED", "NOT_REQUIRED"}:
        raise ValueError("business risk must be ACCEPTED or NOT_REQUIRED before commit")

    changed_paths = git_changed_paths(repo_root)
    if not changed_paths:
        raise ValueError("commit preflight requires at least one changed path")
    unauthorized = [path for path in changed_paths if not path_allowed(path, allowed_pathspecs)]
    if args.output:
        try:
            output_rel = args.output.resolve().relative_to(repo_root).as_posix()
        except ValueError:
            output_rel = ""
        unauthorized = [path for path in unauthorized if path != output_rel]
    if unauthorized:
        raise ValueError(f"unauthorized changed path(s): {', '.join(unauthorized)}")

    status_short = run_git(repo_root, "status", "--short")
    diff_stat = run_git(repo_root, "diff", "--stat", "--", *changed_paths)
    payload = {
        "schema_version": "1.0.0",
        "artifact_type": "commit-preflight",
        "producer": "delivery-owner",
        "decision": "allow",
        "phase_dir": str(phase_dir),
        "branch": branch,
        "head": head,
        "expected_head": args.expected_head or head,
        "commit_message": args.message,
        "allowed_pathspecs": allowed_pathspecs,
        "changed_paths": changed_paths,
        "status_short": status_short,
        "diff_stat": diff_stat,
        "signoff_ref": build_ref("signoff-package", signoff["artifact_id"], "goal-closure"),
        "user_decision_ref": build_ref("user-decision", decision["artifact_id"], "signoff-status"),
        "readiness_command": f"python3 tools/community/validate_standard_chain_readiness.py --phase-dir {phase_dir}",
    }
    return payload


def main() -> None:
    args = parse_args()
    try:
        payload = validate_commit_preflight(args)
    except (subprocess.CalledProcessError, OSError, ValueError) as exc:
        print(f"[FAIL] delivery-owner commit preflight failed: {exc}", file=sys.stderr)
        raise SystemExit(1) from exc

    output = json.dumps(payload, ensure_ascii=False, indent=2) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(output, encoding="utf-8")
    print(output, end="")


if __name__ == "__main__":
    main()
