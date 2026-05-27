"""Markdown projection rendering helpers for design artifacts."""

from __future__ import annotations

import json
from typing import Any


def one_line(value: Any) -> str:
    if value is None:
        return ""
    if isinstance(value, str):
        return " ".join(value.split())
    if isinstance(value, (int, float, bool)):
        return str(value)
    return " ".join(json.dumps(value, ensure_ascii=False, sort_keys=True).split())


def source_pointer(pointer: str, index: int) -> str:
    return f"{pointer}[{index}]"


def bullet_list(items: Any, pointer: str) -> list[str]:
    if not isinstance(items, list) or not items:
        return [f"- None recorded. Source: `{pointer}`"]
    return [
        f"- {one_line(item)} Source: `{source_pointer(pointer, index)}`"
        for index, item in enumerate(items)
    ]


def object_line(label: str, value: Any, pointer: str) -> str:
    return f"- {label}: {one_line(value)} Source: `{pointer}`"


def section(title: str, body: list[str]) -> str:
    return "\n".join([f"## {title}", "", *body, ""])


def render_design_markdown(payload: dict[str, Any]) -> tuple[str, list[dict[str, Any]]]:
    sections: list[tuple[str, str, list[str], list[str]]] = [
        (
            "input",
            "背景、证据与约束",
            [
                "$.input_analysis",
                "$.runtime_facts",
                "$.constraint_inheritance_confirmation",
            ],
            [
                object_line(
                    "产品基线", payload.get("input_analysis"), "$.input_analysis"
                ),
                *bullet_list(payload.get("runtime_facts"), "$.runtime_facts"),
                object_line(
                    "约束继承",
                    payload.get("constraint_inheritance_confirmation"),
                    "$.constraint_inheritance_confirmation",
                ),
            ],
        ),
        (
            "co_creation_summary",
            "协作确认",
            ["$.co_creation_summary"],
            [
                *bullet_list(
                    payload.get("co_creation_summary"),
                    "$.co_creation_summary",
                )
            ],
        ),
        (
            "decisions",
            "关键决策与取舍",
            ["$.key_decisions", "$.option_analysis"],
            [
                *bullet_list(payload.get("key_decisions"), "$.key_decisions"),
                *bullet_list(payload.get("option_analysis"), "$.option_analysis"),
            ],
        ),
        (
            "boundary",
            "边界与接口",
            [
                "$.modules",
                "$.data_architecture",
                "$.cross_cutting_concerns",
                "$.interfaces",
                "$.interface_boundary",
                "$.unit_coverage",
            ],
            [
                *bullet_list(payload.get("modules"), "$.modules"),
                object_line(
                    "数据架构", payload.get("data_architecture"), "$.data_architecture"
                ),
                *bullet_list(
                    payload.get("cross_cutting_concerns"), "$.cross_cutting_concerns"
                ),
                *bullet_list(payload.get("interfaces"), "$.interfaces"),
                *bullet_list(payload.get("interface_boundary"), "$.interface_boundary"),
                *bullet_list(payload.get("unit_coverage"), "$.unit_coverage"),
            ],
        ),
        (
            "quality",
            "质量、迁移、验证、回滚",
            [
                "$.quality_attributes",
                "$.migration_plan",
                "$.verification_plan",
                "$.rollback_plan",
                "$.verification_mapping",
            ],
            [
                *bullet_list(payload.get("quality_attributes"), "$.quality_attributes"),
                *bullet_list(payload.get("migration_plan"), "$.migration_plan"),
                *bullet_list(payload.get("verification_plan"), "$.verification_plan"),
                *bullet_list(
                    payload.get("verification_mapping"), "$.verification_mapping"
                ),
                *bullet_list(payload.get("rollback_plan"), "$.rollback_plan"),
            ],
        ),
        (
            "handoff",
            "风险与交接",
            [
                "$.risks",
                "$.risk_response",
                "$.impact_scope",
                "$.planning_constraints",
                "$.product_handoff",
                "$.final_confirmation",
            ],
            [
                *bullet_list(payload.get("risks"), "$.risks"),
                *bullet_list(payload.get("risk_response"), "$.risk_response"),
                *bullet_list(payload.get("impact_scope"), "$.impact_scope"),
                *bullet_list(
                    payload.get("planning_constraints"), "$.planning_constraints"
                ),
                object_line(
                    "产品交接", payload.get("product_handoff"), "$.product_handoff"
                ),
                object_line(
                    "最终确认",
                    payload.get("final_confirmation"),
                    "$.final_confirmation",
                ),
            ],
        ),
    ]
    manifest = [
        {"section_id": section_id, "title": title, "json_pointers": pointers}
        for section_id, title, pointers, _ in sections
    ]
    header = [
        "# Design 投影视图",
        "",
        "由已验证 `design.json` 生成。本文只提供设计说明视图，不替代 `design.json`。",
        "",
    ]
    content = header + [section(title, body) for _, title, _, body in sections]
    return "\n".join(content).rstrip() + "\n", manifest
