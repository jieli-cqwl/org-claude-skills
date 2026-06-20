#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import subprocess
import time
from pathlib import Path
from typing import Any

FORBIDDEN_QUICK_TAGS = {
    "full-only",
    "release-only",
    "dogfood",
    "e2e",
    "live",
    "migration",
    "install-heavy",
}
QUICK_TAG_EXEMPTIONS = {
    # Synthetic validator for redacted templates/fixtures; this does not run live or E2E dogfood.
    "product-director-real-transcript-dogfood": {"dogfood"},
}
REQUIRED_QUICK_AREAS = {
    "preflight",
    "contracts",
    "standard-chain",
    "context",
    "install-runtime",
    "hooks-manifest",
    "skill-evals",
    "runtime-surface",
    "assertion-boundary",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build and run repository gate plans.")
    parser.add_argument(
        "--repo-root", type=Path, default=Path(__file__).resolve().parents[2]
    )
    parser.add_argument(
        "--mode", choices=["preflight", "quick", "full", "release"], default="full"
    )
    parser.add_argument("--profile", default=None)
    parser.add_argument("--list", action="store_true")
    parser.add_argument("--format", choices=["text", "json"], default="text")
    parser.add_argument("--run", action="store_true")
    parser.add_argument("--profile-output", action="store_true")
    return parser.parse_args()


def load_plan(root: Path) -> dict[str, Any]:
    path = root / "tests" / "gate-plan.json"
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except OSError as exc:
        raise SystemExit(f"cannot read {path}: {exc}") from exc
    except json.JSONDecodeError as exc:
        raise SystemExit(f"{path}: invalid JSON: {exc}") from exc
    if data.get("schema_version") != 1:
        raise SystemExit(f"{path}: schema_version must be 1")
    return data


def validate_step(step: dict[str, Any]) -> None:
    for field in (
        "id",
        "command",
        "area",
        "tier",
        "tags",
        "parallel_safe",
        "timeout_sec",
    ):
        if field not in step:
            raise SystemExit(f"gate step missing {field}: {step}")
    command = step["command"]
    if (
        not isinstance(command, list)
        or not command
        or not all(isinstance(part, str) and part for part in command)
    ):
        raise SystemExit(
            f"gate step {step.get('id')} command must be a non-empty string array"
        )
    if not isinstance(step["tags"], list) or not all(
        isinstance(tag, str) and tag for tag in step["tags"]
    ):
        raise SystemExit(f"gate step {step.get('id')} tags must be a string array")
    if not isinstance(step["parallel_safe"], bool):
        raise SystemExit(f"gate step {step.get('id')} parallel_safe must be boolean")
    timeout = step["timeout_sec"]
    if not isinstance(timeout, int) or timeout <= 0:
        raise SystemExit(f"gate step {step.get('id')} timeout_sec must be positive")


def validate_quick(steps: list[dict[str, Any]]) -> None:
    areas = {step.get("area") for step in steps}
    missing = sorted(REQUIRED_QUICK_AREAS - areas)
    if missing:
        raise SystemExit(f"quick plan missing required areas: {missing}")
    for step in steps:
        exempted = QUICK_TAG_EXEMPTIONS.get(str(step.get("id")), set())
        blocked = sorted(set(step.get("tags", [])) & (FORBIDDEN_QUICK_TAGS - exempted))
        if blocked:
            raise SystemExit(
                f"quick step {step.get('id')} has forbidden tags: {blocked}"
            )
        if step.get("timeout_sec", 0) > 120:
            raise SystemExit(
                f"quick step {step.get('id')} timeout exceeds quick budget"
            )


def selected_steps(
    data: dict[str, Any], mode: str, profile: str | None
) -> list[dict[str, Any]]:
    steps = data.get("steps")
    if not isinstance(steps, list):
        raise SystemExit("gate-plan.json: steps must be a list")
    if profile:
        profiles = data.get("profiles", {})
        if profile not in profiles:
            available = ", ".join(sorted(profiles))
            raise SystemExit(
                f"unknown profile: {profile}. Available profiles: {available}"
            )
        profile_def = profiles[profile]
        areas = set(profile_def.get("areas", []))
        included_ids = set(profile_def.get("include_ids", []))
        excluded = set(profile_def.get("exclude_tags", []))
        selected = [
            step
            for step in steps
            if (step.get("area") in areas or step.get("id") in included_ids)
            and not (set(step.get("tags", [])) & excluded)
        ]
        if not selected:
            raise SystemExit(f"profile {profile} selected no steps")
        return selected
    if mode == "preflight":
        return [step for step in steps if step.get("tier") == "preflight"]
    if mode == "quick":
        selected = [
            step for step in steps if step.get("tier") in {"preflight", "quick"}
        ]
        validate_quick(selected)
        return selected
    if mode == "full":
        return [
            step for step in steps if "release-only" not in set(step.get("tags", []))
        ]
    return steps


def render_command(command: list[str], root: Path) -> str:
    if not command:
        return ""
    if len(command) >= 2 and command[1].startswith(("tests/", "tools/", "shared/")):
        return " ".join([command[0], str(root / command[1]), *command[2:]])
    return " ".join(command)


def text_plan(
    mode: str, profile: str | None, steps: list[dict[str, Any]], root: Path
) -> str:
    lines = [f"mode={mode}", f"profile={profile or ''}", f"steps={len(steps)}"]
    for index, step in enumerate(steps, start=1):
        tags = ",".join(step["tags"])
        lines.append(
            f"[{index}/{len(steps)}] {step['id']} area={step['area']} tier={step['tier']} tags={tags}"
        )
        lines.append(render_command(step["command"], root))
    return "\n".join(lines)


def json_plan(mode: str, profile: str | None, steps: list[dict[str, Any]]) -> str:
    return json.dumps(
        {"mode": mode, "profile": profile or "", "steps": steps}, ensure_ascii=False
    )


def run_steps(
    root: Path, steps: list[dict[str, Any]], profile_output: bool = False
) -> int:
    for index, step in enumerate(steps, start=1):
        print(f"[{index}/{len(steps)}] {step['id']}", flush=True)
        started_at = time.monotonic()
        try:
            result = subprocess.run(
                step["command"], cwd=root, timeout=step["timeout_sec"], check=False
            )
        except subprocess.TimeoutExpired:
            elapsed = time.monotonic() - started_at
            if profile_output:
                print(f"[profile] TIMEOUT {elapsed:.2f}s {step['id']}", flush=True)
            print(
                f"[gate-plan][ERROR] timeout after {step['timeout_sec']}s: {step['id']}",
                flush=True,
            )
            return 124
        elapsed = time.monotonic() - started_at
        if profile_output:
            status = "PASS" if result.returncode == 0 else "FAIL"
            print(f"[profile] {status} {elapsed:.2f}s {step['id']}", flush=True)
        if result.returncode != 0:
            return result.returncode
    return 0


def main() -> int:
    args = parse_args()
    root = args.repo_root.resolve()
    data = load_plan(root)
    for step in data.get("steps", []):
        validate_step(step)
    steps = selected_steps(data, args.mode, args.profile)
    if args.list:
        if args.format == "json":
            print(json_plan(args.mode, args.profile, steps))
        else:
            print(text_plan(args.mode, args.profile, steps, root))
        return 0
    if args.run:
        return run_steps(root, steps, args.profile_output)
    raise SystemExit("pass --list or --run")


if __name__ == "__main__":
    raise SystemExit(main())
