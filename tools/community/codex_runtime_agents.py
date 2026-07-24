"""Managed Codex agent configuration writer."""

from __future__ import annotations

from pathlib import Path

from codex_runtime_common import toml_string
from codex_runtime_features import remove_removed_feature_flags
from codex_runtime_toml import (
    key_line_index,
    matching_section_bounds,
    read_toml_lines,
    remove_key_from_sections,
    section_bounds,
    set_toml_key,
    strip_toml_comment,
    write_toml_lines,
)

LEGACY_MANAGED_AGENT_SETTINGS = {
    "max_threads": "6",
    "max_depth": "1",
    "job_max_runtime_seconds": "1800",
}

MANAGED_AGENT_ROLES = [
    (
        "consistency-auditor",
        "仅 delivery-owner 标准链路 Task Packet 授权调度：跨工件一致性旁路审计，输出 advisory-only owner action",
        "./agents/consistency-auditor.toml",
    ),
    ("developer", "仅 delivery-owner 标准链路 Task Packet 授权调度：TDD驱动开发执行，完成任务并自验证", "./agents/developer.toml"),
    ("fixer", "仅 delivery-owner 标准链路 Task Packet 授权调度：故障根因分析与最小修复", "./agents/fixer.toml"),
    ("verifier", "仅 delivery-owner 标准链路 Task Packet 授权调度：Task级AC覆盖与代码质量验收", "./agents/verifier.toml"),
    ("qa", "仅 delivery-owner 标准链路 Task Packet 授权调度：用户视角功能验收，独立给出PASS/FAIL", "./agents/qa.toml"),
]
MANAGED_AGENT_ROLE_NAMES = {role for role, _, _ in MANAGED_AGENT_ROLES}
RETIRED_AGENT_ROLE_NAMES = {
    "code-reviewer",
    "codex-doc-reviewer",
    "designer",
    "generic-code-reviewer",
    "tech-lead",
    "test-designer",
}
INHERITED_AGENT_CONFIG_KEYS = ("model", "model_reasoning_effort")


def agent_section_role(section: str) -> str | None:
    prefix = "agents."
    if not section.startswith(prefix):
        return None
    role = section.removeprefix(prefix)
    if "." in role:
        return None
    return role


def remove_retired_agent_sections(lines: list[str]) -> None:
    for start, end in reversed(
        matching_section_bounds(lines, lambda section: agent_section_role(section) in RETIRED_AGENT_ROLE_NAMES)
    ):
        del lines[start:end]


def remove_legacy_managed_agent_settings(lines: list[str]) -> None:
    """Remove the complete tuning fingerprint written by older installers."""
    start, end = section_bounds(lines, "agents")
    if start is None or end is None:
        return

    for key, expected_value in LEGACY_MANAGED_AGENT_SETTINGS.items():
        idx = key_line_index(lines, start, end, key)
        if idx is None:
            return
        actual_value = strip_toml_comment(lines[idx]).split("=", 1)[1].strip()
        if actual_value != expected_value:
            return

    for key in LEGACY_MANAGED_AGENT_SETTINGS:
        remove_key_from_sections(lines, lambda section: section == "agents", key)


def ensure_codex_agent_config(config_path: Path) -> None:
    """Install managed Codex agent config while pruning retired feature flags."""
    lines = read_toml_lines(config_path)

    set_toml_key(lines, "features", "multi_agent", "true")
    remove_removed_feature_flags(lines)
    remove_retired_agent_sections(lines)
    remove_legacy_managed_agent_settings(lines)
    for key in INHERITED_AGENT_CONFIG_KEYS:
        remove_key_from_sections(lines, lambda section: agent_section_role(section) in MANAGED_AGENT_ROLE_NAMES, key)

    for role, description, config_file in MANAGED_AGENT_ROLES:
        section = f"agents.{role}"
        set_toml_key(lines, section, "description", toml_string(description))
        set_toml_key(lines, section, "config_file", toml_string(config_file))

    write_toml_lines(config_path, lines)
