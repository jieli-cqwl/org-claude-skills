#!/usr/bin/env python3
"""Package-level Skill quality audit for detection fixtures and smoke checks."""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any

import check_skill_body_quality as body
from skill_quality_common import base_finding


TRIGGER_TERMS = (
    "Use when",
    "use when",
    "用于",
    "当用户",
    "用户",
    "需要",
    "要求",
    "Manual-only",
    "Invoke",
)
WORKFLOW_OUTPUT_TERMS = (
    "output",
    "Output",
    "输出",
    "产物",
    "artifact",
    "Artifact",
    "consumer",
    "consume",
    "消费",
    "消费者",
)
ARTIFACT_SECTION_TERMS = (r"Output", r"Artifact", r"输出", r"产物")
ARTIFACT_CONTRACT_TERMS = (
    "path",
    "路径",
    "format",
    "格式",
    "schema",
    "validator",
    "template",
    "consumer",
    "消费者",
    "stdout",
    "JSON",
)
RETAIN_STATUS_PREFIXES = ("completed", "pilot_empirical", "retain_gate")


def add_finding(
    findings: list[dict[str, Any]],
    *,
    code: str,
    severity: str,
    dimension: str,
    path: Path,
    line: int,
    evidence: str,
    impact: str,
    recommendation: str,
    false_positive_guard: str,
) -> None:
    findings.append(
        base_finding(
            code=code,
            severity=severity,
            dimension=dimension,
            path=path,
            line=line,
            evidence=evidence,
            impact=impact,
            recommendation=recommendation,
            verification=(
                "python3 tools/skill_quality/check_skill_package_quality.py "
                f"{path.parent.relative_to(body.REPO_ROOT).as_posix()}"
            ),
            false_positive_guard=false_positive_guard,
        )
    )


def body_findings(path: Path, lines: list[str]) -> list[dict[str, Any]]:
    findings: list[dict[str, Any]] = []
    body.check_frontmatter(path, lines, findings)
    body.check_resource_contracts(path, lines, findings)
    body.check_body_quality(path, lines, findings)
    body.check_vague_instructions(path, lines, findings)
    for finding in findings:
        finding.setdefault(
            "false_positive_guard",
            "Semantic review may downgrade static signal with direct evidence.",
        )
    return findings


def frontmatter_line(lines: list[str], key: str) -> int:
    prefix = f"{key}:"
    for index, line in enumerate(lines, start=1):
        if line.startswith(prefix):
            return index
    return 1


def check_trigger_contract(
    path: Path, lines: list[str], findings: list[dict[str, Any]]
) -> None:
    meta, _ = body.frontmatter(lines)
    description = meta.get("description", "")
    if len(description) >= 24 and body.contains_any(description, TRIGGER_TERMS):
        return
    add_finding(
        findings,
        code="TRIGGER_CONTRACT_TOO_WEAK",
        severity="WARN",
        dimension="S1",
        path=path,
        line=frontmatter_line(lines, "description"),
        evidence="description does not state concrete user intent or trigger boundary.",
        impact="Runtime may under-trigger, over-trigger, or route adjacent Skill tasks incorrectly.",
        recommendation="Rewrite description with user phrases, use cases, non-goals, or manual invocation boundary.",
        false_positive_guard="Manual-only skills pass when they explicitly state manual invocation or invoke syntax.",
    )


def check_workflow_product_contract(
    path: Path, lines: list[str], findings: list[dict[str, Any]]
) -> None:
    flow_text, flow_line = body.section(
        lines, (r"流程", r"Workflow", r"Default Flow", r"固定主流程")
    )
    if not flow_text or body.contains_any(flow_text, WORKFLOW_OUTPUT_TERMS):
        return
    add_finding(
        findings,
        code="WORKFLOW_OUTPUT_CONTRACT_MISSING",
        severity="WARN",
        dimension="S3",
        path=path,
        line=flow_line,
        evidence="workflow has actions but no explicit output, artifact, or consumer wording.",
        impact="Steps may execute but fail to produce a definition-equivalent product for the next step.",
        recommendation="Add step-level output, consumer, acceptance, failure_state, and proof fields.",
        false_positive_guard="Single-step instruction-only Skills can pass when completion evidence is explicit elsewhere.",
    )


def check_artifact_contract(
    path: Path, lines: list[str], findings: list[dict[str, Any]]
) -> None:
    artifact_text, artifact_line = body.section(lines, ARTIFACT_SECTION_TERMS)
    if not artifact_text or body.contains_any(artifact_text, ARTIFACT_CONTRACT_TERMS):
        return
    add_finding(
        findings,
        code="ARTIFACT_CONTRACT_MISSING",
        severity="WARN",
        dimension="S6",
        path=path,
        line=artifact_line,
        evidence="artifact/output section lacks path, format, consumer, schema, template, or validation wording.",
        impact="Downstream users or machines cannot reliably consume or verify the produced artifact.",
        recommendation="State artifact path, format, consumer, and validation method; use schema/template/validator for field contracts.",
        false_positive_guard="Purely conversational Skills need not define files when no artifact is claimed.",
    )


def load_effectiveness_review(review_path: Path) -> dict[str, Any] | None:
    if not review_path.is_file():
        return None
    try:
        data = json.loads(review_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise SystemExit(f"{review_path}: invalid JSON: {exc}") from exc
    if not isinstance(data, dict):
        raise SystemExit(f"{review_path}: effectiveness review must be an object")
    return data


def review_line(review_path: Path, key: str) -> int:
    lines = review_path.read_text(encoding="utf-8").splitlines()
    return body.first_line(lines, f'"{key}"')


def completed_status(block: dict[str, Any]) -> bool:
    status = str(block.get("measurement_status") or "")
    return status.startswith(RETAIN_STATUS_PREFIXES)


def check_retain_gate(
    review_path: Path, review: dict[str, Any], findings: list[dict[str, Any]]
) -> None:
    if review.get("decision") != "retain":
        return
    uplift = review.get("capability_uplift")
    if isinstance(uplift, dict):
        with_avg = uplift.get("with_avg")
        uplift_value = uplift.get("uplift")
        if (
            not completed_status(uplift)
            or not isinstance(with_avg, (int, float))
            or not isinstance(uplift_value, (int, float))
            or with_avg < 4.0
            or uplift_value < 1.0
        ):
            add_finding(
                findings,
                code="RETAIN_UPLIFT_GATE_UNMET",
                severity="FAIL",
                dimension="E3",
                path=review_path,
                line=review_line(review_path, "capability_uplift"),
                evidence="retain requires completed capability uplift with with_avg >= 4.0 and uplift >= 1.0.",
                impact="Low-gain or unmeasured Skills can be incorrectly retained as best practice.",
                recommendation="Change decision to optimize or rerun empirical evals until retain gates are met.",
                false_positive_guard="Applies only when capability_uplift evidence is present or the eval type requires it.",
            )
    preference = review.get("encoded_preference")
    if isinstance(preference, dict):
        fidelity = preference.get("fidelity")
        if (
            not completed_status(preference)
            or not isinstance(fidelity, (int, float))
            or fidelity < 0.8
        ):
            add_finding(
                findings,
                code="RETAIN_FIDELITY_GATE_UNMET",
                severity="FAIL",
                dimension="E2",
                path=review_path,
                line=review_line(review_path, "encoded_preference"),
                evidence="retain requires completed encoded preference fidelity >= 0.80.",
                impact="A Skill can be retained without proving it preserves required preferences.",
                recommendation="Change decision to optimize or complete fidelity grading before retain.",
                false_positive_guard="Applies only when encoded_preference evidence is present or the eval type requires it.",
            )


def check_effectiveness_review(
    skill_path: Path, findings: list[dict[str, Any]]
) -> None:
    review_path = skill_path.parent / "evals" / "lifecycle-review.json"
    review = load_effectiveness_review(review_path)
    if review is None:
        return
    check_retain_gate(review_path, review, findings)


def status_for(findings: list[dict[str, Any]]) -> str:
    severities = {finding["severity"] for finding in findings}
    if "FAIL" in severities:
        return "static_fail"
    if "WARN" in severities:
        return "static_warn"
    return "static_pass"


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print(
            "usage: check_skill_package_quality.py <skill-dir-or-SKILL.md>",
            file=sys.stderr,
        )
        return 2
    skill_path = body.resolve_skill_path(argv[1])
    lines = skill_path.read_text(encoding="utf-8").splitlines()
    findings = body_findings(skill_path, lines)
    check_trigger_contract(skill_path, lines, findings)
    check_workflow_product_contract(skill_path, lines, findings)
    check_artifact_contract(skill_path, lines, findings)
    check_effectiveness_review(skill_path, findings)
    result = {
        "artifact_type": "skill-quality-package-audit",
        "target": skill_path.relative_to(body.REPO_ROOT).as_posix(),
        "status": status_for(findings),
        "finding_count": len(findings),
        "findings": findings,
    }
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 1 if result["status"] == "static_fail" else 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
