#!/usr/bin/env python3
"""Automate deterministic small-chain closeout gates."""

from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import sys
from dataclasses import dataclass
from datetime import date
from pathlib import Path

from runtime_yaml import load_yaml


TIMEOUT_SEC = 30
ACTIVE_STATUSES = {"managed", "migrated"}
TASK_OPEN_RE = re.compile(r"^\s*[-*]\s+\[\s\]\s+T\d+\b", re.MULTILINE)


@dataclass
class Blocked(Exception):
    reason: str
    path: Path | str
    expected: str
    actual: object
    next_action: str


@dataclass
class Workset:
    root: Path
    feature_path: str
    feature_dir: Path
    workset_name: str
    workset_dir: Path


def emit_block(error: Blocked) -> None:
    print("decision: block")
    print(f"reason: {error.reason}")
    print(f"path: {error.path}")
    print(f"expected: {error.expected}")
    print(f"actual: {error.actual}")
    print(f"next_action: {error.next_action}")


def block(reason: str, path: Path | str, expected: str, actual: object, next_action: str) -> None:
    raise Blocked(reason, path, expected, actual, next_action)


def run_command(command: list[str], cwd: Path) -> subprocess.CompletedProcess[str]:
    try:
        return subprocess.run(
            command,
            cwd=str(cwd),
            text=True,
            capture_output=True,
            timeout=TIMEOUT_SEC,
            check=False,
        )
    except FileNotFoundError as exc:
        block("command_missing", command[0], "command exists on PATH", exc, "install the required command or rerun in a configured environment")
    except subprocess.TimeoutExpired:
        block("command_timeout", command[0], f"command completes within {TIMEOUT_SEC}s", "timeout", "inspect the command and retry")


def require_success(proc: subprocess.CompletedProcess[str], reason: str, next_action: str) -> None:
    if proc.returncode == 0:
        return
    actual = (proc.stderr or proc.stdout).strip() or f"exit {proc.returncode}"
    block(reason, proc.args[0], "exit code 0", actual, next_action)


def load_registry(root: Path) -> dict:
    path = root / "contracts" / "active-doc-scope.yaml"
    if not path.is_file():
        block("registry_missing", path, "active-doc-scope registry", "missing", "create or restore the registry")
    data = load_yaml(path)
    if data.get("version") != 2:
        block("registry_invalid", path, "version: 2", data.get("version"), "migrate registry to version 2")
    return data


def entry_status(entry: dict) -> str | None:
    return entry.get("management_status") or entry.get("status")


def load_workset(root: Path, feature: str) -> Workset:
    entries = []
    for entry in load_registry(root).get("scope_entries", []):
        if entry.get("feature_path") == feature and entry_status(entry) in ACTIVE_STATUSES:
            entries.append(entry)
    if len(entries) != 1:
        block("active_feature_not_found", "contracts/active-doc-scope.yaml", "exactly one active feature entry", len(entries), "register or recover the managed feature")

    entry = entries[0]
    workset_name = entry.get("primary_workset_relpath")
    if not isinstance(workset_name, str) or not workset_name:
        block("workset_missing", "contracts/active-doc-scope.yaml", "primary_workset_relpath", workset_name, "add the active workset path")

    feature_dir = root / feature
    workset_dir = feature_dir / workset_name
    if not workset_dir.is_dir():
        block("workset_unreachable", workset_dir, "reachable active workset", "missing", "restore the workset or update the registry")
    return Workset(root, feature, feature_dir, workset_name, workset_dir)


def required_file(workset: Workset, name: str) -> Path:
    path = workset.workset_dir / name
    if not path.is_file():
        block("artifact_missing", path, f"{name} exists", "missing", f"restore {name} before closeout")
    return path


def ensure_task_plan_consistency(workset: Workset) -> None:
    checker = workset.root / "tools" / "community" / "check_task_plan_consistency.py"
    proc = run_command([sys.executable, str(checker), str(required_file(workset, "tasks.md")), str(required_file(workset, "plan.md"))], workset.root)
    require_success(proc, "task_plan_mismatch", "repair tasks.md or plan.md")


def ensure_tasks_complete(workset: Workset) -> None:
    tasks = required_file(workset, "tasks.md")
    text = tasks.read_text(encoding="utf-8")
    if TASK_OPEN_RE.search(text):
        block("incomplete_tasks", tasks, "all task checkboxes are [x]", "open task found", "finish tasks before closeout")


def section(text: str, heading: str) -> str:
    match = re.search(rf"^##\s+{re.escape(heading)}\s*$", text, re.MULTILINE)
    if not match:
        return ""
    rest = text[match.end() :]
    next_heading = re.search(r"^##\s+", rest, re.MULTILINE)
    return rest[: next_heading.start()] if next_heading else rest


def ensure_verify_passed(workset: Workset) -> None:
    report = required_file(workset, "verify-change-report.md")
    text = report.read_text(encoding="utf-8")
    if "PASS" not in section(text, "Status"):
        block("verify_change_not_passed", report, "Status PASS", section(text, "Status").strip(), "run verify-change and fix CRITICAL findings")
    critical = section(text, "CRITICAL").strip().lower()
    if not re.search(r"(^|\n)\s*[-*]\s*none\s*($|\n)", critical):
        block("critical_findings_present", report, "CRITICAL none", critical, "fix CRITICAL findings before closeout")


def ensure_closeout_ready(workset: Workset) -> None:
    required_file(workset, "design.md")
    required_file(workset, "verify-change-report.md")
    ensure_task_plan_consistency(workset)
    ensure_tasks_complete(workset)
    ensure_verify_passed(workset)


def state_path(workset: Workset) -> Path:
    return workset.workset_dir / "closeout-state.json"


def read_state(workset: Workset) -> dict:
    path = state_path(workset)
    if not path.is_file():
        return {}
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        block("closeout_state_invalid", path, "parseable JSON", exc, "repair or remove closeout-state.json")


def write_state(workset: Workset, payload: dict) -> None:
    state_path(workset).write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def feature_name(workset: Workset) -> str:
    return workset.feature_path.rstrip("/").split("/")[-1]


def create_pr_body(workset: Workset) -> Path:
    body = workset.workset_dir / ".closeout-pr-body.md"
    body.write_text(
        "\n".join(
            [
                "## Summary",
                f"- Automated small-chain closeout for `{workset.feature_path}`.",
                "- verify-change passed with no CRITICAL findings.",
                "",
                "## Test Plan",
                "- See the active workset verification evidence.",
                "",
            ]
        ),
        encoding="utf-8",
    )
    return body


def current_branch(root: Path) -> str:
    proc = run_command(["git", "branch", "--show-current"], root)
    require_success(proc, "branch_detect_failed", "run from a named git branch")
    branch = proc.stdout.strip()
    if not branch:
        block("branch_detached", root, "named branch", "detached HEAD", "switch to a feature branch before creating a PR")
    return branch


def push_branch(workset: Workset, branch: str, target_branch: str) -> None:
    if branch == target_branch:
        block("target_branch_pr_forbidden", workset.root, f"current branch is not {target_branch}", branch, "switch to a feature branch before creating a PR")
    push = run_command(["git", "push", "-u", "origin", branch], workset.root)
    require_success(push, "branch_push_failed", "push the feature branch before creating a PR")


def create_pr(workset: Workset, target_branch: str) -> int:
    ensure_closeout_ready(workset)
    branch = current_branch(workset.root)
    push_branch(workset, branch, target_branch)
    body = create_pr_body(workset)
    title = f"Small-chain closeout: {feature_name(workset)}"
    try:
        create = run_command(
            [
                "gh",
                "pr",
                "create",
                "--title",
                title,
                "--body-file",
                str(body),
                "--head",
                branch,
                "--base",
                target_branch,
            ],
            workset.root,
        )
        require_success(create, "pr_create_failed", "fix GitHub CLI state or create the PR manually")
        pr_url = create.stdout.strip().splitlines()[-1] if create.stdout.strip() else ""
        if not pr_url:
            block("pr_url_missing", "gh pr create", "PR URL in stdout", create.stdout, "inspect gh output and retry")
        merge = run_command(["gh", "pr", "merge", "--auto", "--squash", pr_url], workset.root)
        require_success(merge, "auto_merge_failed", "enable repository auto-merge or resolve branch protection requirements")
        write_state(workset, {"pr_url": pr_url, "state": "wait_for_merge"})
        print("decision: wait_for_merge")
        print(f"pr_url: {pr_url}")
        return 0
    finally:
        body.unlink(missing_ok=True)


def pr_is_merged(workset: Workset, assume_merged: bool) -> bool:
    if assume_merged:
        return True
    pr_url = read_state(workset).get("pr_url")
    if not isinstance(pr_url, str) or not pr_url:
        block("pr_state_missing", state_path(workset), "closeout-state.json with pr_url", "missing", "run create-pr first or pass --merged after external verification")
    proc = run_command(["gh", "pr", "view", pr_url, "--json", "state", "--jq", ".state"], workset.root)
    require_success(proc, "pr_view_failed", "fix GitHub CLI state or pass verified merge evidence")
    return proc.stdout.strip() == "MERGED"


def append_changelog(workset: Workset, archive_ref: str) -> None:
    changelog = workset.feature_dir / "CHANGELOG.md"
    if not changelog.exists():
        changelog.write_text("# Changelog\n", encoding="utf-8")
    with changelog.open("a", encoding="utf-8") as handle:
        handle.write(f"\n## {date.today().isoformat()}\n\n")
        handle.write(f"- Small-chain closeout automation archived `{workset.workset_name}` to `{archive_ref}`.\n")


def archive_ref_for(workset: Workset) -> str:
    return f"docs/archive/{feature_name(workset)}/{workset.workset_name}"


def archive_worklog(workset: Workset, archive_dir: Path) -> None:
    worklog = workset.feature_dir / "worklog.md"
    if not worklog.is_file():
        return
    prefix = f"{workset.workset_name}/"
    lines = []
    for line in worklog.read_text(encoding="utf-8").splitlines():
        for field in ("scope_ref", "state_ref", "next_ref"):
            marker = f"- {field}: {prefix}"
            if line.startswith(marker):
                line = f"- {field}: {line.removeprefix(marker)}"
                break
        lines.append(line)
    (archive_dir / "worklog.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def archive_workset(workset: Workset, assume_merged: bool) -> int:
    ensure_closeout_ready(workset)
    if not pr_is_merged(workset, assume_merged):
        block("pr_not_merged", state_path(workset), "PR state MERGED", "not merged", "wait for CI and branch protection to merge the PR")
    archive_ref = archive_ref_for(workset)
    archive_dir = workset.root / archive_ref
    if archive_dir.exists():
        block("archive_exists", archive_dir, "archive destination unused", "exists", "inspect existing archive before retrying")
    archive_dir.parent.mkdir(parents=True, exist_ok=True)
    shutil.move(str(workset.workset_dir), str(archive_dir))
    archive_worklog(workset, archive_dir)
    append_changelog(workset, archive_ref)
    update = run_command(
        [
            sys.executable,
            str(workset.root / "tools" / "community" / "update_active_doc_scope.py"),
            "--repo-root",
            str(workset.root),
            "archive",
            "--feature",
            workset.feature_path,
            "--archive-ref",
            archive_ref,
            "--archived-at",
            date.today().isoformat(),
        ],
        workset.root,
    )
    require_success(update, "scope_archive_update_failed", "repair active-doc-scope archive lifecycle")
    validate = run_command([sys.executable, str(workset.root / "tools" / "community" / "validate_context_contract.py"), "--repo-root", str(workset.root)], workset.root)
    require_success(validate, "context_validation_failed", "repair archived context refs")
    print("decision: done")
    print(f"archived_to: {archive_ref}")
    return 0


def status(workset: Workset) -> int:
    ensure_closeout_ready(workset)
    state = read_state(workset)
    if not state.get("pr_url"):
        print("decision: create_pr")
        return 0
    print("decision: wait_for_merge")
    print(f"pr_url: {state['pr_url']}")
    return 0


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)
    for name in ("status", "create-pr", "archive"):
        command = subparsers.add_parser(name)
        command.add_argument("--repo-root", type=Path, required=True)
        command.add_argument("--feature", required=True)
        command.add_argument("--target-branch", default="main")
    subparsers.choices["archive"].add_argument("--merged", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        root = args.repo_root.resolve()
        workset = load_workset(root, args.feature)
        if args.command == "status":
            return status(workset)
        if args.command == "create-pr":
            return create_pr(workset, args.target_branch)
        if args.command == "archive":
            return archive_workset(workset, args.merged)
        raise ValueError(f"unknown command: {args.command}")
    except Blocked as error:
        emit_block(error)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
