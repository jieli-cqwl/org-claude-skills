#!/usr/bin/env python3
from __future__ import annotations

import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
LOCK = ROOT / "community" / "SOURCES.yaml"
EXPECTED_REPOS = {
    "anthropic_skills": "https://github.com/anthropics/skills",
    "openspec": "https://github.com/Fission-AI/OpenSpec",
    "superpowers": "https://github.com/obra/superpowers",
    "vercel_skills": "https://github.com/vercel-labs/skills",
    "vercel_agent_browser": "https://github.com/vercel-labs/agent-browser",
    "alchaincyf_darwin_skill": "https://github.com/alchaincyf/darwin-skill",
}
BOUNDARY = ROOT / "contracts" / "superpowers-boundary.yaml"


def fail(message: str) -> None:
    print(f"[FAIL] {message}", file=sys.stderr)
    raise SystemExit(1)


def extract_source_block(text: str, source_name: str) -> str:
    pattern = re.compile(
        rf"^  {re.escape(source_name)}:\n(?P<body>(?:^    .*(?:\n|$)|^      .*(?:\n|$))*)",
        flags=re.MULTILINE,
    )
    m = pattern.search(text)
    if not m:
        fail(f"SOURCES.yaml 缺少 source 节点: {source_name}")
    return m.group("body")


def require_pattern(block: str, pattern: str, message: str) -> None:
    if not re.search(pattern, block, flags=re.MULTILINE):
        fail(message)


def require_nonempty_list(block: str, key: str, source_name: str) -> None:
    m = re.search(
        rf"^    {re.escape(key)}:\s*$\n(?P<items>(?:^      - .*(?:\n|$))+)",
        block,
        flags=re.MULTILINE,
    )
    if not m:
        fail(f"SOURCES.yaml 中 {source_name}.{key} 缺失或为空列表")


def require_top_level_nonempty_list(text: str, key: str, source_name: str) -> None:
    m = re.search(
        rf"^{re.escape(key)}:\s*$\n(?P<items>(?:^  - .*(?:\n|$)|^    .*(?:\n|$))+)",
        text,
        flags=re.MULTILINE,
    )
    if not m:
        fail(f"{source_name} 中 {key} 缺失或为空列表")


def validate_source(text: str, source_name: str, expected_repo: str) -> None:
    block = extract_source_block(text, source_name)
    require_pattern(
        block,
        rf"^    repo: {re.escape(expected_repo)}$",
        f"SOURCES.yaml 中 {source_name}.repo 不匹配预期: {expected_repo}",
    )
    require_pattern(
        block,
        r"^    ref: \S.+$",
        f"SOURCES.yaml 中 {source_name}.ref 缺失或为空",
    )
    require_pattern(
        block,
        r"^    captured_at: \d{4}-\d{2}-\d{2}$",
        f"SOURCES.yaml 中 {source_name}.captured_at 格式错误",
    )
    require_nonempty_list(block, "scope", source_name)
    require_nonempty_list(block, "notes", source_name)


def extract_block(text: str, key: str) -> str:
    pattern = re.compile(
        rf"^{re.escape(key)}:\n(?P<body>(?:^  .*(?:\n|$)|^    .*(?:\n|$)|^      .*(?:\n|$))*)",
        flags=re.MULTILINE,
    )
    m = pattern.search(text)
    if not m:
        fail(f"boundary contract 缺少顶层节点: {key}")
    return m.group("body")


def validate_boundary_contract(path: Path) -> None:
    if not path.is_file():
        fail(f"缺少 boundary contract 文件: {path}")

    text = path.read_text(encoding="utf-8")
    require_pattern(text, r"^version: \d+\s*$", "boundary contract 缺少 version")
    require_pattern(text, r"^target_state: \S.+$", "boundary contract 缺少 target_state")

    runtime_roles = extract_block(text, "runtime_roles")
    for key in (
        "community_superpowers",
        "small_chain",
        "openspec",
        "community_openspec",
    ):
        require_pattern(
            runtime_roles,
            rf"^  {re.escape(key)}: \S.+$",
            f"boundary contract 缺少 runtime_roles.{key}",
        )

    canonical_targets = extract_block(text, "canonical_targets")
    for key in (
        "default_chain_contract",
        "source_lock",
        "overlay_contract",
        "runtime_entry_skill",
    ):
        m = re.search(
            rf"^  {re.escape(key)}: (?P<value>\S.+)$",
            canonical_targets,
            flags=re.MULTILINE,
        )
        if not m:
            fail(f"boundary contract 缺少 canonical_targets.{key}")
        target = ROOT / m.group("value")
        if not target.is_file():
            fail(f"boundary contract 指向缺失文件: {m.group('value')}")

    require_top_level_nonempty_list(text, "declared_forks", "boundary contract")
    for owner_source in re.findall(r"^    owner_source: (?P<value>\S.+)$", text, flags=re.MULTILINE):
        if not (ROOT / owner_source).is_file():
            fail(f"boundary contract owner_source 指向缺失文件: {owner_source}")
    require_pattern(text, r"^allowed_legacy_paths:\s*(?:\[\]|\s*$)", "boundary contract 缺少 allowed_legacy_paths")
    require_top_level_nonempty_list(text, "overlay_files", "boundary contract")

    closeout_policy = extract_block(text, "closeout_policy")
    require_pattern(closeout_policy, r"^  required_sequence:\s*$", "boundary contract 缺少 closeout_policy.required_sequence")
    for step in (
        "verification-before-completion",
        "verify-change",
        "finishing-a-development-branch",
        "archive",
    ):
        require_pattern(
            closeout_policy,
            rf"^    - {re.escape(step)}$",
            f"boundary contract closeout_policy.required_sequence 缺少步骤: {step}",
        )
    require_pattern(
        closeout_policy,
        r"^  verify_change_required_before:\s*$",
        "boundary contract 缺少 closeout_policy.verify_change_required_before",
    )
    for step in ("finishing-a-development-branch", "archive"):
        require_pattern(
            closeout_policy,
            rf"^    - {re.escape(step)}$",
            f"boundary contract closeout_policy.verify_change_required_before 缺少步骤: {step}",
        )
    require_pattern(
        closeout_policy,
        r"^  archive_requires: integrated_on_target_branch$",
        "boundary contract 缺少 closeout_policy.archive_requires",
    )


def main(argv: list[str]) -> None:
    if len(argv) > 2:
        fail("用法: source_lock_check.py [<SOURCES.yaml 路径>]")

    lock_path = Path(argv[1]) if len(argv) == 2 else LOCK
    if not lock_path.is_file():
        fail(f"缺少 source lock 文件: {lock_path}")

    text = lock_path.read_text(encoding="utf-8")

    require_pattern(text, r"^sources:\s*$", "SOURCES.yaml 缺少顶层 sources 节点")
    for source_name, expected_repo in EXPECTED_REPOS.items():
        validate_source(text, source_name, expected_repo)

    if len(argv) == 1:
        validate_boundary_contract(BOUNDARY)

    print("[PASS] source lock valid")


if __name__ == "__main__":
    main(sys.argv)
