#!/usr/bin/env python3
"""Static Skill body quality audit for objective D1-D8 signals.

The checker only reports deterministic evidence. It does not replace the
semantic skill-harness review required for trigger intent, SOP adequacy, or
behavioral benefit.
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[4]
RESOURCE_CONTRACT_FIELDS = ("Trigger", "Read", "Expect", "Consume", "Evidence", "Sync")
VAGUE_TERMS = ("合理", "充分", "尽量", "适当", "保证质量", "完善", "handle reasonably", "improve quality")
ACTION_TERMS = ("读取", "判断", "执行", "输出", "验证", "停止", "Read", "Check", "Run", "Write", "Verify", "Stop")
COMPLEX_TERMS = ("SubAgent", "fork", "pipeline", "handoff", "分支", "状态", "回退", "rollback")
STRUCTURE_TERMS = ("流程图", "流程表", "状态表", "mermaid", "digraph", "graph TD", "graph LR")
GOAL_TERMS = ("目标", "Goal", "成功标准", "完成边界", "completion boundary")
CRITERIA_TERMS = ("证据", "验证", "字段", "阈值", "终止", "判据", "条件", "evidence", "criteria", "verification")


def usage() -> None:
    print("usage: check_skill_body_quality.py <skill-dir-or-SKILL.md>", file=sys.stderr)
    raise SystemExit(2)


def resolve_skill_path(raw: str) -> Path:
    path = Path(raw)
    if not path.is_absolute():
        path = (REPO_ROOT / path).resolve()
    else:
        path = path.resolve()
    if path.is_dir():
        path = path / "SKILL.md"
    try:
        path.relative_to(REPO_ROOT)
    except ValueError:
        raise SystemExit(f"[FAIL] path must be repo-local: {raw}")
    if path.name != "SKILL.md" or not path.is_file():
        raise SystemExit(f"[FAIL] missing SKILL.md: {raw}")
    return path


def repo_ref(path: Path, line: int) -> str:
    return f"{path.relative_to(REPO_ROOT).as_posix()}:{line}"


def first_line(lines: list[str], needle: str | re.Pattern[str]) -> int:
    for index, line in enumerate(lines, start=1):
        if isinstance(needle, str):
            if needle in line:
                return index
        elif needle.search(line):
            return index
    return 1


def contains_any(text: str, terms: tuple[str, ...]) -> bool:
    return any(term in text for term in terms)


def frontmatter(lines: list[str]) -> tuple[dict[str, str], int]:
    if not lines or lines[0].strip() != "---":
        return {}, 0
    data: dict[str, str] = {}
    for index, line in enumerate(lines[1:], start=2):
        if line.strip() == "---":
            return data, index
        match = re.match(r"^([A-Za-z0-9_-]+):\s*(.*)$", line)
        if match:
            data[match.group(1)] = match.group(2).strip().strip('"')
    return data, 0


def section(lines: list[str], heading_patterns: tuple[str, ...]) -> tuple[str, int]:
    start = 0
    for index, line in enumerate(lines):
        if line.startswith("## ") and any(re.search(pattern, line) for pattern in heading_patterns):
            start = index
            break
    if start == 0 and not any(re.search(pattern, lines[0] if lines else "") for pattern in heading_patterns):
        return "", 1
    end = len(lines)
    for index in range(start + 1, len(lines)):
        if lines[index].startswith("## "):
            end = index
            break
    return "\n".join(lines[start:end]), start + 1


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
) -> None:
    file_ref = repo_ref(path, line)
    findings.append(
        {
            "code": code,
            "severity": severity,
            "dimension": dimension,
            "file_ref": file_ref,
            "evidence_refs": [file_ref],
            "impact": impact,
            "recommendation": recommendation,
            "verification": f"python3 shared/skills/skill-harness/scripts/check_skill_body_quality.py {path.relative_to(REPO_ROOT).as_posix()}",
            "evidence": evidence,
        }
    )


def check_frontmatter(path: Path, lines: list[str], findings: list[dict[str, Any]]) -> int:
    meta, end_line = frontmatter(lines)
    if not meta or end_line == 0:
        add_finding(
            findings,
            code="FRONTMATTER_MISSING",
            severity="FAIL",
            dimension="D1",
            path=path,
            line=1,
            evidence="SKILL.md does not start with closed YAML frontmatter.",
            impact="Runtime cannot reliably discover or route the Skill.",
            recommendation="Add YAML frontmatter with name and description.",
        )
        return 1
    for key in ("name", "description"):
        if not meta.get(key):
            add_finding(
                findings,
                code=f"{key.upper()}_MISSING",
                severity="FAIL",
                dimension="D1",
                path=path,
                line=1,
                evidence=f"frontmatter lacks {key}.",
                impact="Runtime routing and trigger review cannot consume the Skill contract.",
                recommendation=f"Add frontmatter {key}.",
            )
    return end_line


def check_resource_contracts(path: Path, lines: list[str], findings: list[dict[str, Any]]) -> None:
    for index, line in enumerate(lines, start=1):
        if "references/" not in line:
            continue
        missing = [field for field in RESOURCE_CONTRACT_FIELDS if f"{field}:" not in line]
        if missing:
            add_finding(
                findings,
                code="PROGRESSIVE_LOADING_CONTRACT_INCOMPLETE",
                severity="WARN",
                dimension="D2",
                path=path,
                line=index,
                evidence=f"reference route is missing contract fields: {', '.join(missing)}.",
                impact="Agent may read too much, too little, or the wrong resource during execution.",
                recommendation="Bind the resource route to Trigger/Read/Expect/Consume/Evidence/Sync.",
            )
            return


def check_body_quality(path: Path, lines: list[str], findings: list[dict[str, Any]]) -> None:
    text = "\n".join(lines)
    if "## HARD-GATE" not in text:
        add_finding(
            findings,
            code="HARD_GATE_MISSING",
            severity="FAIL",
            dimension="D5",
            path=path,
            line=1,
            evidence="No ## HARD-GATE section found.",
            impact="Non-negotiable runtime limits may be missed before flexible guidance.",
            recommendation="Add a HARD-GATE section before role detail, examples, or optional background.",
        )
    if not contains_any(text, GOAL_TERMS):
        add_finding(
            findings,
            code="GOAL_CONTRACT_MISSING",
            severity="WARN",
            dimension="D5",
            path=path,
            line=1,
            evidence="No goal, success standard, or completion boundary term found.",
            impact="Reviewer cannot judge whether the Skill target is achievable or complete.",
            recommendation="State target task, exclusions, completion boundary, and proof method.",
        )
    flow_text, flow_line = section(lines, (r"流程", r"Workflow", r"Default Flow", r"固定主流程"))
    if not flow_text:
        add_finding(
            findings,
            code="WORKFLOW_MISSING",
            severity="FAIL",
            dimension="D5",
            path=path,
            line=1,
            evidence="No workflow or flow section found.",
            impact="Agent cannot follow a stable SOP from input to output.",
            recommendation="Add an ordered workflow with prerequisites, actions, outputs, and stop states.",
        )
    elif not contains_any(flow_text, ACTION_TERMS):
        add_finding(
            findings,
            code="SOP_ACTIONS_MISSING",
            severity="WARN",
            dimension="D5",
            path=path,
            line=flow_line,
            evidence="Workflow section lacks executable action verbs.",
            impact="Agent may treat principles as advice instead of executable steps.",
            recommendation="Rewrite flow steps with verbs such as read, check, run, write, verify, and stop.",
        )
    if contains_any(text, COMPLEX_TERMS) and not contains_any(text, STRUCTURE_TERMS):
        add_finding(
            findings,
            code="COMPLEX_FLOW_UNSTRUCTURED",
            severity="WARN",
            dimension="D5",
            path=path,
            line=first_line(lines, re.compile("|".join(re.escape(term) for term in COMPLEX_TERMS))),
            evidence="Complex flow terms appear without a flow diagram, flow table, or state table.",
            impact="Branching, handoff, or rollback behavior can be interpreted inconsistently.",
            recommendation="Add a flow diagram, flow table, or state table for the complex branch.",
        )
    verification_text, verification_line = section(lines, (r"完成校验", r"Verification", r"Completion Check"))
    if not verification_text:
        add_finding(
            findings,
            code="VERIFICATION_MISSING",
            severity="FAIL",
            dimension="D6",
            path=path,
            line=1,
            evidence="No completion or verification section found.",
            impact="Completion claims cannot be replayed from evidence.",
            recommendation="Add completion checks tied to outputs, commands, evals, or artifacts.",
        )
    elif not contains_any(verification_text, ("命令", "command", "evidence", "证据", "artifact", "eval")):
        add_finding(
            findings,
            code="VERIFICATION_EVIDENCE_MISSING",
            severity="WARN",
            dimension="D6",
            path=path,
            line=verification_line,
            evidence="Verification section lacks proof command, evidence, artifact, or eval wording.",
            impact="Reviewer cannot replay the quality conclusion.",
            recommendation="Tie each completion check to a proof command, artifact, evidence field, or eval.",
        )


def check_vague_instructions(path: Path, lines: list[str], findings: list[dict[str, Any]]) -> None:
    for index, line in enumerate(lines, start=1):
        if not contains_any(line, VAGUE_TERMS):
            continue
        window = "\n".join(lines[max(0, index - 2) : min(len(lines), index + 1)])
        if contains_any(window, CRITERIA_TERMS):
            continue
        add_finding(
            findings,
            code="VAGUE_INSTRUCTION_UNBOUNDED",
            severity="WARN",
            dimension="D8",
            path=path,
            line=index,
            evidence="Vague instruction lacks nearby observable criteria.",
            impact="Agent may optimize or judge quality by taste rather than contract.",
            recommendation="Bind the phrase to evidence, thresholds, fields, criteria, or stop conditions.",
        )
        return


def status_for(findings: list[dict[str, Any]]) -> str:
    severities = {finding["severity"] for finding in findings}
    if "FAIL" in severities:
        return "static_fail"
    if "WARN" in severities:
        return "static_warn"
    return "static_pass"


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        usage()
    path = resolve_skill_path(argv[1])
    lines = path.read_text(encoding="utf-8").splitlines()
    findings: list[dict[str, Any]] = []
    check_frontmatter(path, lines, findings)
    check_resource_contracts(path, lines, findings)
    check_body_quality(path, lines, findings)
    check_vague_instructions(path, lines, findings)
    result = {
        "artifact_type": "skill-body-quality-static-audit",
        "target": path.relative_to(REPO_ROOT).as_posix(),
        "status": status_for(findings),
        "finding_count": len(findings),
        "findings": findings,
    }
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 1 if result["status"] == "static_fail" else 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
