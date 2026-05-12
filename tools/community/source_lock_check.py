#!/usr/bin/env python3
from __future__ import annotations

import re
import sys
from pathlib import Path

try:
    import sync_canonical_from_upstream as sync  # type: ignore
except ModuleNotFoundError:
    from tools.community import sync_canonical_from_upstream as sync


ROOT = Path(__file__).resolve().parents[2]
LOCK = ROOT / "community" / "SOURCES.yaml"
BOUNDARY = ROOT / "contracts" / "superpowers-boundary.yaml"
EXPECTED_REPOS = {
    "anthropic_skills": "https://github.com/anthropics/skills",
    "superpowers": "https://github.com/obra/superpowers",
    "vercel_skills": "https://github.com/vercel-labs/skills",
    "vercel_agent_browser": "https://github.com/vercel-labs/agent-browser",
    "alchaincyf_darwin_skill": "https://github.com/alchaincyf/darwin-skill",
    "nextlevelbuilder_ui_ux_pro_max": "https://github.com/nextlevelbuilder/ui-ux-pro-max-skill",
    "panniantong_agent_reach": "https://github.com/panniantong/agent-reach",
    "skills_sh_bb_browser": "https://github.com/epiral/bb-browser",
    "skills_sh_humanizer_zh": "https://github.com/op7418/Humanizer-zh",
    "skills_sh_notebooklm": "https://github.com/PleasePrompto/notebooklm-skill",
    "skills_sh_self_improving_agent": "https://github.com/zhaono1/agent-playbook",
    "persona_colleague_skill": "https://github.com/titanwings/colleague-skill",
    "persona_nuwa_skill": "https://github.com/alchaincyf/nuwa-skill",
    "persona_yourself_skill": "https://github.com/notdog1998/yourself-skill",
    "persona_midas_skill": "https://github.com/hermesnest/midas-skill",
}


def fail(message: str) -> None:
    print(f"[FAIL] {message}", file=sys.stderr)
    raise SystemExit(1)


def require_pattern(text: str, pattern: str, message: str) -> None:
    if not re.search(pattern, text, flags=re.MULTILINE):
        fail(message)


def extract_source_block(text: str, source_name: str) -> str:
    pattern = re.compile(
        rf"^  {re.escape(source_name)}:\n(?P<body>(?:^    .*(?:\n|$)|^      .*(?:\n|$))*)",
        flags=re.MULTILINE,
    )
    m = pattern.search(text)
    if not m:
        fail(f"SOURCES.yaml 缺少 source 节点: {source_name}")
    return m.group("body")


def require_nonempty_list(block: str, key: str, source_name: str) -> None:
    if not re.search(
        rf"^    {re.escape(key)}:\s*$\n(?:^      - .*(?:\n|$))+",
        block,
        flags=re.MULTILINE,
    ):
        fail(f"SOURCES.yaml 中 {source_name}.{key} 缺失或为空列表")


def validate_source(text: str, source_name: str, expected_repo: str) -> None:
    block = extract_source_block(text, source_name)
    require_pattern(
        block,
        rf"^    repo: {re.escape(expected_repo)}$",
        f"SOURCES.yaml 中 {source_name}.repo 不匹配预期: {expected_repo}",
    )
    require_pattern(block, r"^    ref: \S.+$", f"SOURCES.yaml 中 {source_name}.ref 缺失或为空")
    require_pattern(
        block,
        r"^    captured_at: \d{4}-\d{2}-\d{2}$",
        f"SOURCES.yaml 中 {source_name}.captured_at 格式错误",
    )
    require_nonempty_list(block, "scope", source_name)
    require_nonempty_list(block, "notes", source_name)


def validate_source_names(text: str) -> None:
    names = re.findall(r"^  ([A-Za-z0-9_]+):\s*$", text, flags=re.MULTILINE)
    expected = sorted(EXPECTED_REPOS)
    if sorted(names) != expected:
        fail(f"SOURCES.yaml source 集合不匹配，expected={expected}, actual={sorted(names)}")


def validate_superpowers_lock(text: str) -> None:
    block = extract_source_block(text, "superpowers")
    require_pattern(
        block,
        r"^    ref: f2cbfbefebbfef77321e4c9abc9e949826bea9d7$",
        "Superpowers ref 必须锁定到已确认官方 HEAD",
    )
    require_pattern(
        block,
        r"^    scope:\s*$\n^      - community/superpowers/skills$",
        "Superpowers scope 必须只覆盖 community/superpowers/skills",
    )
    forbidden = ("overlay", "adapter", "local-only", "source header")
    lowered = block.lower()
    if not all(term in lowered for term in forbidden):
        fail("Superpowers notes 必须显式禁止 overlay/adapter/local-only/source header")


def _extract_top_list(text: str, key: str) -> list[str]:
    m = re.search(
        rf"^{re.escape(key)}:\s*$\n(?P<items>(?:^  - .*(?:\n|$))+)",
        text,
        flags=re.MULTILINE,
    )
    if not m:
        fail(f"boundary contract 缺少列表: {key}")
    return [line.strip()[2:] for line in m.group("items").splitlines()]


def _require_existing_target(text: str, key: str, *, directory: bool = False) -> None:
    m = re.search(rf"^  {re.escape(key)}: (?P<value>\S.+)$", text, flags=re.MULTILINE)
    if not m:
        fail(f"boundary contract 缺少 canonical_targets.{key}")
    target = ROOT / m.group("value")
    if directory:
        if not target.is_dir():
            fail(f"boundary contract 指向缺失目录: {m.group('value')}")
    elif not target.is_file():
        fail(f"boundary contract 指向缺失文件: {m.group('value')}")


def validate_boundary_contract(path: Path) -> None:
    if not path.is_file():
        fail(f"缺少 boundary contract 文件: {path}")

    text = path.read_text(encoding="utf-8")
    require_pattern(text, r"^version: 2$", "boundary contract version 必须为 2")
    require_pattern(
        text,
        r"^target_state: superpowers_official_full_mirror$",
        "boundary contract target_state 必须是官方全量纯镜像",
    )
    require_pattern(
        text,
        r"^  community_superpowers: official_third_party_mirror$",
        "boundary contract runtime_roles.community_superpowers 不正确",
    )
    require_pattern(
        text,
        r"^  standard_chain: first_party_runtime$",
        "boundary contract runtime_roles.standard_chain 不正确",
    )
    _require_existing_target(text, "source_lock")
    _require_existing_target(text, "mirror_root", directory=True)
    _require_existing_target(text, "first_party_chain_contract")

    require_pattern(text, r"^official_skill_count: 14$", "boundary contract official_skill_count 必须为 14")
    skills = _extract_top_list(text, "official_skills")
    expected = sorted(sync.OFFICIAL_SUPERPOWERS_SKILLS)
    if sorted(skills) != expected:
        fail(f"boundary contract official_skills 不匹配，expected={expected}, actual={sorted(skills)}")
    require_pattern(
        text,
        r"^  superpowers_agent_adapters_allowed: false$",
        "boundary contract 必须禁止 Superpowers agent adapters",
    )


def main(argv: list[str]) -> None:
    if len(argv) > 2:
        fail("用法: source_lock_check.py [<SOURCES.yaml 路径>]")

    lock_path = Path(argv[1]) if len(argv) == 2 else LOCK
    if not lock_path.is_file():
        fail(f"缺少 source lock 文件: {lock_path}")

    text = lock_path.read_text(encoding="utf-8")
    require_pattern(text, r"^sources:\s*$", "SOURCES.yaml 缺少顶层 sources 节点")
    validate_source_names(text)
    for source_name, expected_repo in EXPECTED_REPOS.items():
        validate_source(text, source_name, expected_repo)
    validate_superpowers_lock(text)

    if len(argv) == 1:
        validate_boundary_contract(BOUNDARY)

    print("[PASS] source lock valid")


if __name__ == "__main__":
    main(sys.argv)
