#!/usr/bin/env python3
"""Render human-facing design projections from a validated design.json."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any


def load_json_object(path: Path, label: str) -> dict[str, Any]:
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise SystemExit(f"{label} not found: {path}") from exc
    except OSError as exc:
        raise SystemExit(f"{label} cannot be read: {path}: {exc}") from exc
    except json.JSONDecodeError as exc:
        raise SystemExit(f"{label} must be JSON: {exc}") from exc
    if not isinstance(payload, dict):
        raise SystemExit(f"{label} must contain a JSON object")
    return payload


def require_confirmed_design(payload: dict[str, Any]) -> None:
    confirmation = payload.get("final_confirmation")
    if not isinstance(confirmation, dict) or confirmation.get("status") != "confirmed":
        raise SystemExit("design.final_confirmation.status must be confirmed")


def ensure_parent(path: Path) -> None:
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
    except OSError as exc:
        raise SystemExit(f"cannot create output directory for {path}: {exc}") from exc


def write_text_file(path: Path, content: str) -> None:
    ensure_parent(path)
    try:
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
        ("input", "Input And Runtime Facts", [
            "$.input_analysis",
            "$.runtime_facts",
            "$.constraint_inheritance_confirmation",
        ], [
            object_line("Baseline", payload.get("input_analysis"), "$.input_analysis"),
            *bullet_list(payload.get("runtime_facts"), "$.runtime_facts"),
            object_line(
                "Constraint inheritance",
                payload.get("constraint_inheritance_confirmation"),
                "$.constraint_inheritance_confirmation",
            ),
        ]),
        ("co_creation", "Co-Creation Closure", ["$.co_creation_summary"], [
            *bullet_list(payload.get("co_creation_summary"), "$.co_creation_summary"),
        ]),
        ("decisions", "Key Decisions", ["$.key_decisions", "$.option_analysis"], [
            *bullet_list(payload.get("key_decisions"), "$.key_decisions"),
            *bullet_list(payload.get("option_analysis"), "$.option_analysis"),
        ]),
        ("boundary", "Boundary And Interfaces", [
            "$.modules",
            "$.data_architecture",
            "$.cross_cutting_concerns",
            "$.interfaces",
            "$.interface_boundary",
            "$.unit_coverage",
        ], [
            *bullet_list(payload.get("modules"), "$.modules"),
            object_line("Data architecture", payload.get("data_architecture"), "$.data_architecture"),
            *bullet_list(payload.get("cross_cutting_concerns"), "$.cross_cutting_concerns"),
            *bullet_list(payload.get("interfaces"), "$.interfaces"),
            *bullet_list(payload.get("interface_boundary"), "$.interface_boundary"),
            *bullet_list(payload.get("unit_coverage"), "$.unit_coverage"),
        ]),
        ("quality", "Quality, Migration, Verification", [
            "$.quality_attributes",
            "$.migration_plan",
            "$.verification_plan",
            "$.rollback_plan",
            "$.verification_mapping",
        ], [
            *bullet_list(payload.get("quality_attributes"), "$.quality_attributes"),
            *bullet_list(payload.get("migration_plan"), "$.migration_plan"),
            *bullet_list(payload.get("verification_plan"), "$.verification_plan"),
            *bullet_list(payload.get("verification_mapping"), "$.verification_mapping"),
            *bullet_list(payload.get("rollback_plan"), "$.rollback_plan"),
        ]),
        ("handoff", "Risk And Handoff", [
            "$.risks",
            "$.risk_response",
            "$.impact_scope",
            "$.planning_constraints",
            "$.product_handoff",
            "$.final_confirmation",
        ], [
            *bullet_list(payload.get("risks"), "$.risks"),
            *bullet_list(payload.get("risk_response"), "$.risk_response"),
            *bullet_list(payload.get("impact_scope"), "$.impact_scope"),
            *bullet_list(payload.get("planning_constraints"), "$.planning_constraints"),
            object_line("Product handoff", payload.get("product_handoff"), "$.product_handoff"),
            object_line("Final confirmation", payload.get("final_confirmation"), "$.final_confirmation"),
        ]),
    ]
    manifest = [
        {"section_id": section_id, "title": title, "json_pointers": pointers}
        for section_id, title, pointers, _ in sections
    ]
    header = [
        "# Design Projection",
        "",
        "Generated from validated canonical `design.json`. This view is not a runtime source of truth.",
        "",
    ]
    content = header + [section(title, body) for _, title, _, body in sections]
    return "\n".join(content).rstrip() + "\n", manifest


def manifest_path_for(output_path: Path) -> Path:
    name = output_path.name
    if name.endswith(".projection.md"):
        return output_path.with_name(name.replace(".projection.md", ".projection-manifest.json"))
    return output_path.with_suffix(output_path.suffix + ".manifest.json")


def write_design_projection(payload: dict[str, Any], output_path: Path) -> dict[str, Any]:
    markdown, sections = render_design_markdown(payload)
    manifest_path = manifest_path_for(output_path)
    write_text_file(output_path, markdown)
    write_text_file(
        manifest_path,
        json.dumps(
            {
                "source": "design.json",
                "projection": str(output_path),
                "sections": sections,
            },
            ensure_ascii=False,
            indent=2,
            sort_keys=True,
        )
        + "\n",
    )
    return {
        "design_projection": str(output_path),
        "projection_manifest": str(manifest_path),
        "section_count": len(sections),
    }


def options_by_decision(payload: dict[str, Any]) -> dict[str, list[dict[str, Any]]]:
    options = payload.get("option_analysis")
    grouped: dict[str, list[dict[str, Any]]] = {}
    if not isinstance(options, list):
        return grouped
    for option in options:
        if not isinstance(option, dict) or not option.get("decision_ref"):
            continue
        grouped.setdefault(str(option["decision_ref"]), []).append(option)
    return grouped


def table_row(cells: list[Any]) -> str:
    return "| " + " | ".join(one_line(cell).replace("|", "\\|") for cell in cells) + " |"


def render_option_table(options: list[dict[str, Any]]) -> list[str]:
    rows = [
        table_row(["Option", "Verdict", "Tradeoff", "Fact refs"]),
        "| --- | --- | --- | --- |",
    ]
    for option in options:
        rows.append(
            table_row([
                option.get("option_id"),
                option.get("verdict"),
                option.get("tradeoff"),
                option.get("fact_refs"),
            ])
        )
    return rows


def render_adr(decision: dict[str, Any], options: list[dict[str, Any]], constraints: Any, index: int) -> str:
    decision_id = one_line(decision.get("decision_id")) or f"D-{index:03d}"
    title = one_line(decision.get("summary")) or decision_id
    selected = next(
        (option for option in options if option.get("option_id") == decision.get("option_ref")),
        None,
    )
    selected_summary = one_line(selected.get("summary")) if selected else one_line(decision.get("option_ref"))
    tradeoff = one_line(selected.get("tradeoff")) if selected else ""
    fact_refs = decision.get("fact_refs") if isinstance(decision.get("fact_refs"), list) else []
    constraint_lines = bullet_list(constraints, "$.planning_constraints")
    return "\n".join(
        [
            f"### ADR-{index:03d}: {title[:80]}",
            "",
            f"Decision: {decision_id}",
            "Status: Accepted",
            f"Selected Option: {selected_summary}",
            f"Reason: {tradeoff}",
            f"User Confirmation: {one_line(decision.get('user_confirmation'))}",
            f"Evidence Refs: {', '.join(map(one_line, fact_refs))}",
            "",
            "## Alternatives",
            "",
            *render_option_table(options),
            "",
            "## Implementation Constraints",
            "",
            *constraint_lines,
            "",
            f"Source: `$.key_decisions[{index - 1}]`",
            "",
        ]
    )


def write_adrs(payload: dict[str, Any], output_dir: Path) -> list[str]:
    decisions = payload.get("key_decisions")
    if not isinstance(decisions, list):
        raise SystemExit("design.key_decisions must be an array")
    grouped_options = options_by_decision(payload)
    constraints = payload.get("planning_constraints")
    outputs: list[str] = []
    for index, decision in enumerate(decisions, start=1):
        if not isinstance(decision, dict):
            continue
        decision_id_raw = one_line(decision.get("decision_id")) or f"D-{index:03d}"
        decision_options = grouped_options.get(decision_id_raw, [])
        path = output_dir / f"ADR-{index:03d}.md"
        write_text_file(path, render_adr(decision, decision_options, constraints, index))
        outputs.append(str(path))
    return outputs


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(
        description="Render design projection files from a validated design.json."
    )
    parser.add_argument("--design", required=True, help="Path to validated phase design.json.")
    parser.add_argument("--design-output", help="Path for views/design.projection.md.")
    parser.add_argument("--adr-dir", help="Directory for generated ADR markdown files.")
    args = parser.parse_args(argv)

    if not args.design_output and not args.adr_dir:
        raise SystemExit("provide --design-output, --adr-dir, or both")

    design_path = Path(args.design)
    payload = load_json_object(design_path, "design file")
    require_confirmed_design(payload)

    result: dict[str, Any] = {"status": "PASS", "design": str(design_path)}
    if args.design_output:
        result.update(write_design_projection(payload, Path(args.design_output)))
    if args.adr_dir:
        outputs = write_adrs(payload, Path(args.adr_dir))
        result["adr_outputs"] = outputs
        result["adr_count"] = len(outputs)
    print(json.dumps(result, ensure_ascii=False, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
