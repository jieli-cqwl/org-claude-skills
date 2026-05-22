#!/usr/bin/env python3
"""Render a human-facing Product Director projection from Director JSON."""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from pathlib import Path
from typing import Any

ALLOWED_OUTPUT_ROOTS = ("docs",)


def load_json_object(path: Path, label: str) -> dict[str, Any]:
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise SystemExit(f"{label} not found: {path}") from exc
    except OSError as exc:
        raise SystemExit(f"{label} cannot be read: {path}: {exc}") from exc
    except json.JSONDecodeError as exc:
        raise SystemExit(f"{label} must be valid JSON: {exc}") from exc
    if not isinstance(payload, dict):
        raise SystemExit(f"{label} must contain a JSON object")
    return payload


def is_relative_to(path: Path, root: Path) -> bool:
    try:
        path.relative_to(root)
        return True
    except ValueError:
        return False


def assert_allowed_output(path: Path, cwd: Path, feature_dir: Path) -> None:
    resolved = path.resolve()
    tmp_root = Path(os.environ.get("TMPDIR", "/tmp")).resolve()
    allowed_roots = [
        *((cwd / root).resolve() for root in ALLOWED_OUTPUT_ROOTS),
        feature_dir.resolve(),
        tmp_root,
        Path("/tmp").resolve(),
    ]
    if not any(is_relative_to(resolved, root) for root in allowed_roots):
        allowed = ", ".join(str(root) for root in allowed_roots)
        raise SystemExit(
            f"output path is outside allowed roots: {resolved}; allowed roots: {allowed}"
        )


def write_text_file(path: Path, content: str) -> None:
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")
    except OSError as exc:
        raise SystemExit(f"cannot write output file {path}: {exc}") from exc


def one_line(value: Any) -> str:
    if value is None:
        return ""
    if isinstance(value, str):
        return " ".join(value.split())
    if isinstance(value, (int, float, bool)):
        return str(value)
    return " ".join(json.dumps(value, ensure_ascii=False, sort_keys=True).split())


def as_list(value: Any) -> list[Any]:
    return value if isinstance(value, list) else []


def md_escape(value: Any) -> str:
    return one_line(value).replace("|", "\\|")


def bullet_lines(items: Any, empty: str = "未记录") -> list[str]:
    values = [one_line(item) for item in as_list(items) if one_line(item)]
    if not values:
        return [f"- {empty}"]
    return [f"- {item}" for item in values]


def heading_slug(value: str) -> int:
    match = re.search(r"(\d+)", value)
    return int(match.group(1)) if match else 0


def discover_phase_files(feature_dir: Path) -> list[Path]:
    phase_files = sorted(
        feature_dir.glob("phase-*/phase-prd.json"),
        key=lambda path: (heading_slug(path.parent.name), path.parent.name),
    )
    if not phase_files:
        raise SystemExit(f"no phase-prd.json files found under {feature_dir}")
    return phase_files


def phase_records(feature_dir: Path) -> list[dict[str, Any]]:
    records: list[dict[str, Any]] = []
    for phase_file in discover_phase_files(feature_dir):
        source_ref = str(phase_file.relative_to(feature_dir))
        records.append(
            {
                "phase_id": phase_file.parent.name,
                "source_ref": source_ref,
                "payload": load_json_object(phase_file, source_ref),
            }
        )
    return records


def table_row(cells: list[Any]) -> str:
    return "| " + " | ".join(md_escape(cell) for cell in cells) + " |"


def render_user_profile(brief: dict[str, Any]) -> list[str]:
    profiles = [item for item in as_list(brief.get("user_profile")) if isinstance(item, dict)]
    if not profiles:
        return ["- 受影响角色：未记录", "- 触发场景：未记录", "- 当前处理方式：未记录", "- 现实代价：未记录"]
    lines: list[str] = []
    for index, profile in enumerate(profiles, start=1):
        prefix = f"画像 {index} - " if len(profiles) > 1 else ""
        lines.extend(
            [
                f"- {prefix}受影响角色：{one_line(profile.get('who')) or '未记录'}",
                f"- {prefix}触发场景：{one_line(profile.get('scenario')) or '未记录'}",
                f"- {prefix}当前处理方式：{one_line(profile.get('current_workaround')) or '未记录'}",
                f"- {prefix}现实代价：{one_line(profile.get('workaround_cost')) or '未记录'}",
            ]
        )
    return lines


def render_constraints(brief: dict[str, Any]) -> list[str]:
    constraints = [item for item in as_list(brief.get("feasibility_constraints")) if isinstance(item, dict)]
    if not constraints:
        return ["- 未记录"]
    return [
        "- "
        + "; ".join(
            part
            for part in (
                f"类型：{one_line(item.get('type'))}" if item.get("type") else "",
                f"约束：{one_line(item.get('constraint'))}" if item.get("constraint") else "",
                f"影响：{one_line(item.get('impact_scope'))}" if item.get("impact_scope") else "",
                f"处理：{one_line(item.get('handling'))}" if item.get("handling") else "",
            )
            if part
        )
        for item in constraints
    ]


def render_risks(brief: dict[str, Any]) -> list[str]:
    rows = [
        table_row(["项目", "影响", "处理方式", "状态"]),
        "| --- | --- | --- | --- |",
    ]
    risks = [item for item in as_list(brief.get("risks_and_unknowns")) if isinstance(item, dict)]
    if not risks:
        rows.append(table_row(["未记录", "", "", ""]))
        return rows
    for item in risks:
        rows.append(table_row([item.get("item"), item.get("impact"), item.get("mitigation"), item.get("status")]))
    return rows


def render_phase_plan(brief: dict[str, Any], phases: list[dict[str, Any]]) -> list[str]:
    delivery = {
        str(item.get("phase_id")): item
        for item in as_list(brief.get("delivery_plan"))
        if isinstance(item, dict) and item.get("phase_id")
    }
    rows = [
        table_row(["Phase", "目标", "时间盒"]),
        "| --- | --- | --- |",
    ]
    details: list[str] = []
    for record in phases:
        phase_id = record["phase_id"]
        phase = record["payload"]
        plan = delivery.get(phase_id, {})
        goal = plan.get("goal") or phase.get("phase_goal")
        timebox = plan.get("iteration_timebox_days")
        rows.append(table_row([phase_id, goal, f"{timebox} 天" if timebox else "未记录"]))
        details.extend(
            [
                "",
                f"### {phase_id} 详情",
                "",
                "**入口条件**",
                "",
                *bullet_lines(phase.get("entry_conditions")),
                "",
                "**出口条件**",
                "",
                *bullet_lines(phase.get("exit_conditions")),
            ]
        )
    return rows + details


def render_decision_rationale(brief: dict[str, Any]) -> list[str]:
    decisions = [item for item in as_list(brief.get("decision_rationale")) if isinstance(item, dict)]
    if not decisions:
        return ["- 未记录"]
    lines: list[str] = []
    for item in decisions:
        title = one_line(item.get("decision")) or "决策"
        lines.extend(
            [
                f"- {title}",
                f"  - 选择：{one_line(item.get('choice')) or '未记录'}",
                f"  - 理由：{one_line(item.get('rationale')) or '未记录'}",
                f"  - 排除选项：{one_line(item.get('excluded_options')) or '未记录'}",
            ]
        )
    return lines


def render_markdown(feature_dir: Path, brief: dict[str, Any], phases: list[dict[str, Any]]) -> str:
    first_plan = next(
        (item for item in as_list(brief.get("delivery_plan")) if isinstance(item, dict)),
        {},
    )
    first_goal = one_line(first_plan.get("goal")) or one_line(phases[0]["payload"].get("phase_goal"))
    root_problem = one_line(brief.get("root_problem"))
    sources = ["brief.json", *(record["source_ref"] for record in phases)]
    lines = [
        "# 产品总监基线说明书",
        "",
        "> 本文档由 `brief.json` 和 `phase-*/phase-prd.json` 生成；JSON 是唯一真源，本文档不得作为下游控制输入，也不得反向作为 runtime 真源。",
        "",
        "## 1. 一句话结论",
        "",
        f"这次先聚焦：{first_goal or '未记录'}。要解决的根问题是：{root_problem or '未记录'}",
        "",
        "## 2. 为什么现在要做",
        "",
        *render_user_profile(brief),
        f"- 直接原因：{root_problem or '未记录'}",
        "",
        "## 3. 本期成功标准",
        "",
        "**业务目标**",
        "",
        *bullet_lines(brief.get("business_goals")),
        "",
        "**投入边界**",
        "",
        f"- 投入尺度：{one_line(brief.get('appetite', {}).get('investment_scale')) or '未记录'}",
        f"- 复杂度上限：{one_line(brief.get('appetite', {}).get('complexity_ceiling')) or '未记录'}",
        f"- 优先裁剪：{one_line(brief.get('appetite', {}).get('trim_first')) or '未记录'}",
        "",
        "## 4. 本期范围",
        "",
        "### 本期做",
        "",
        *bullet_lines(brief.get("scope_boundaries")),
        "",
        "### 本期不做",
        "",
        *bullet_lines(brief.get("non_goals")),
        "",
        "### 约束",
        "",
        *render_constraints(brief),
        "",
        "## 5. 风险与未决项",
        "",
        *render_risks(brief),
        "",
        "## 6. Phase 规划",
        "",
        *render_phase_plan(brief, phases),
        "",
        "## 7. 决策理由",
        "",
        *render_decision_rationale(brief),
        "",
        "## 来源",
        "",
        "来源文件：" + "、".join(f"`{source}`" for source in sources) + "。追溯关系见 `views/product-director.projection-manifest.json`。",
    ]
    return "\n".join(lines).rstrip() + "\n"


def manifest_path_for(output_path: Path) -> Path:
    name = output_path.name
    if name.endswith(".projection.md"):
        return output_path.with_name(name.replace(".projection.md", ".projection-manifest.json"))
    return output_path.with_suffix(output_path.suffix + ".manifest.json")


def build_manifest(output_path: Path, phases: list[dict[str, Any]]) -> dict[str, Any]:
    phase_sources = [record["source_ref"] for record in phases]
    phase_pointers: list[str] = ["$.delivery_plan"]
    for record in phases:
        source = record["source_ref"]
        phase_pointers.extend([f"{source}:$.phase_goal", f"{source}:$.entry_conditions", f"{source}:$.exit_conditions"])
    sections = [
        ("one_line_conclusion", "一句话结论", ["$.root_problem", "$.delivery_plan"]),
        ("why_now", "为什么现在要做", ["$.root_problem", "$.user_profile"]),
        ("success_standard", "本期成功标准", ["$.business_goals", "$.appetite"]),
        ("scope", "本期范围", ["$.scope_boundaries", "$.non_goals", "$.feasibility_constraints"]),
        ("risks", "风险与未决项", ["$.risks_and_unknowns"]),
        ("phase_plan", "Phase 规划", phase_pointers),
        ("decision_rationale", "决策理由", ["$.decision_rationale"]),
    ]
    return {
        "source_artifact_refs": ["brief.json", *phase_sources],
        "projection": str(output_path),
        "sections": [
            {"section_id": section_id, "title": title, "json_pointers": pointers}
            for section_id, title, pointers in sections
        ],
    }


def default_output_for(feature_dir: Path) -> Path:
    return feature_dir / "views" / "product-director.projection.md"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Render a human-facing Product Director projection from Director JSON."
    )
    parser.add_argument("--feature-dir", required=True, type=Path)
    parser.add_argument("--output", type=Path)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    cwd = Path.cwd()
    feature_dir = args.feature_dir.resolve()
    output_path = (args.output or default_output_for(feature_dir)).resolve()
    assert_allowed_output(output_path, cwd, feature_dir)
    brief = load_json_object(feature_dir / "brief.json", "brief.json")
    phases = phase_records(feature_dir)
    markdown = render_markdown(feature_dir, brief, phases)
    manifest_path = manifest_path_for(output_path)
    manifest = build_manifest(output_path, phases)
    write_text_file(output_path, markdown)
    write_text_file(
        manifest_path,
        json.dumps(manifest, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
    )
    json.dump(
        {
            "status": "PASS",
            "projection": str(output_path),
            "projection_manifest": str(manifest_path),
            "phase_count": len(phases),
        },
        sys.stdout,
        ensure_ascii=False,
        indent=2,
    )
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()
