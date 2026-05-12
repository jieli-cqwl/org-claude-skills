"""Managed Codex agent configuration writer."""

from __future__ import annotations

from pathlib import Path

from codex_runtime_common import toml_string
from codex_runtime_features import remove_removed_feature_flags
from codex_runtime_toml import read_toml_lines, set_toml_key, write_toml_lines

AGENT_GLOBAL_SETTINGS = {
    "max_threads": "6",
    "max_depth": "1",
    "job_max_runtime_seconds": "1800",
}

MANAGED_AGENT_ROLES = [
    (
        "code-reviewer",
        "对抗性代码审查，输出客观证据与PASS/FAIL",
        "./agents/code-reviewer.toml",
    ),
    (
        "generic-code-reviewer",
        "通用代码审查，输出strengths/issues/assessment",
        "./agents/generic-code-reviewer.toml",
    ),
    ("designer", "架构设计与方案权衡，对齐需求边界", "./agents/designer.toml"),
    (
        "tech-lead",
        "制定 WBS 实施计划，明确关键路径、依赖批次和证据路径",
        "./agents/tech-lead.toml",
    ),
    ("developer", "TDD驱动开发执行，完成任务并自验证", "./agents/developer.toml"),
    (
        "test-designer",
        "需求驱动的测试方案与测试用例设计",
        "./agents/test-designer.toml",
    ),
    ("fixer", "故障根因分析与最小修复", "./agents/fixer.toml"),
    ("verifier", "Task级AC覆盖与代码质量验收", "./agents/verifier.toml"),
    ("qa", "用户视角功能验收，独立给出PASS/FAIL", "./agents/qa.toml"),
]


def ensure_codex_agent_config(config_path: Path) -> None:
    """Install managed Codex agent config while pruning retired feature flags."""
    lines = read_toml_lines(config_path)

    set_toml_key(lines, "features", "multi_agent", "true")
    remove_removed_feature_flags(lines)

    for key, value in AGENT_GLOBAL_SETTINGS.items():
        set_toml_key(lines, "agents", key, value, before="agents.")

    for role, description, config_file in MANAGED_AGENT_ROLES:
        section = f"agents.{role}"
        set_toml_key(lines, section, "description", toml_string(description))
        set_toml_key(lines, section, "config_file", toml_string(config_file))

    write_toml_lines(config_path, lines)
