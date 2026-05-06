#!/usr/bin/env python3
"""Static Skill body quality audit for objective gate and quality signals.

The checker only reports deterministic evidence. It does not replace semantic
review for trigger intent, SOP adequacy, or behavioral benefit.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from typing import Any

from skill_quality_common import (
    NAME_RE,
    REPO_ROOT,
    base_finding,
    contains_xml_tag,
    resolve_skill_path,
)

FindingSpec = tuple[str, str, str, str, str]


def terms(value: str) -> tuple[str, ...]:
    return tuple(value.split("|"))


RESOURCE_CONTRACT_FIELDS = terms("Trigger|Read|Expect|Consume|Evidence|Sync")
SOP_ROUTE_TERMS = terms("按需读取|用于|形成|检查|记录")
RESOURCE_READ_TERMS = terms("读取|Read|read")
RESOURCE_EXTRACT_TERMS = terms("只提取|only extract|extract only")
RESOURCE_PURPOSE_TERMS = terms("for|用于|获取|形成|检查|记录|规则|方法|口径|生成")
HARD_GATE_TERMS = terms("## HARD-GATE|## 停手边界|## 准入边界|## 边界")
FLOW_HEADING_PATTERNS = (
    r"流程",
    r"Workflow",
    r"Default Flow",
    r"固定主流程",
    r"办事流程",
)
VERIFICATION_HEADING_PATTERNS = (
    r"完成校验",
    r"Verification",
    r"Completion Check",
    r"完成证据",
    r"收口",
)
VAGUE_TERMS = terms(
    "合理|充分|尽量|适当|保证质量|完善|handle reasonably|improve quality"
)
ACTION_TERMS = terms("读取|判断|执行|输出|验证|停止|Read|Check|Run|Write|Verify|Stop")
COMPLEX_TERMS = terms(
    "TeamCreate|SubAgent|fork|pipeline|handoff|Parallel Review|协作团队|分支|状态|回退|rollback"
)
STRUCTURE_TERMS = terms("流程图|流程表|状态表|mermaid|digraph|graph TD|graph LR")
GOAL_TERMS = terms("目标|Goal|成功标准|完成边界|completion boundary")
CRITERIA_TERMS = terms(
    "证据|验证|字段|阈值|终止|判据|条件|evidence|criteria|verification"
)
VERIFICATION_TERMS = terms("命令|command|evidence|证据|artifact|eval")
SPEC_ROWS = """
FRONTMATTER_MISSING	FAIL	G0	SKILL.md does not start with closed YAML frontmatter.	Runtime cannot reliably discover or route the Skill.	Add YAML frontmatter with name and description.
NAME_INVALID	FAIL	G0	frontmatter name must be 1-64 lowercase letters/numbers/hyphens, match the parent directory, and avoid XML tags.	Cross-runtime discovery and API upload can reject or misroute the Skill.	Rename the skill directory and frontmatter name to the same valid kebab-case identifier.
DESCRIPTION_INVALID	FAIL	G0	frontmatter description must be non-empty, <= 1024 characters, and avoid XML tags.	Runtime trigger metadata can be rejected or interpreted as unsafe markup.	Rewrite description as plain text with what the skill does and when to use it.
HARD_GATE_MISSING	FAIL	S3	No stop-boundary or hard-gate section found.	Non-negotiable runtime limits may be missed before flexible guidance.	Add a stop-boundary or hard-gate section before role detail, examples, or optional background.
GOAL_CONTRACT_MISSING	WARN	S2	No goal, success standard, or completion boundary term found.	Reviewer cannot judge whether the Skill target is achievable or complete.	State target task, exclusions, completion boundary, and proof method.
WORKFLOW_MISSING	FAIL	S3	No workflow or flow section found.	Agent cannot follow a stable SOP from input to output.	Add an ordered workflow with prerequisites, actions, outputs, and stop states.
SOP_ACTIONS_MISSING	WARN	S3	Workflow section lacks executable action verbs.	Agent may treat principles as advice instead of executable steps.	Rewrite flow steps with verbs such as read, check, run, write, verify, and stop.
COMPLEX_FLOW_UNSTRUCTURED	WARN	S3	Complex flow terms appear without a flow diagram, flow table, or state table.	Branching, handoff, or rollback behavior can be interpreted inconsistently.	Add a flow diagram, flow table, or state table for the complex branch.
VERIFICATION_MISSING	FAIL	S7	No completion or verification section found.	Completion claims cannot be replayed from evidence.	Add completion checks tied to outputs, commands, evals, or artifacts.
VERIFICATION_EVIDENCE_MISSING	WARN	S7	Verification section lacks proof command, evidence, artifact, or eval wording.	Reviewer cannot replay the quality conclusion.	Tie each completion check to a proof command, artifact, evidence field, or eval.
VAGUE_INSTRUCTION_UNBOUNDED	WARN	S3	Vague instruction lacks nearby observable criteria.	Agent may optimize or judge quality by taste rather than contract.	Bind the phrase to evidence, thresholds, fields, criteria, or stop conditions.
""".strip()
SPECS: dict[str, FindingSpec] = {
    parts[0]: (parts[1], parts[2], parts[3], parts[4], parts[5])
    for parts in (row.split("\t") for row in SPEC_ROWS.splitlines())
}


def usage() -> None:
    print("usage: check_skill_body_quality.py <skill-dir-or-SKILL.md>", file=sys.stderr)
    raise SystemExit(2)


def first_line(lines: list[str], needle: str | re.Pattern[str]) -> int:
    for index, line in enumerate(lines, start=1):
        if isinstance(needle, str) and needle in line:
            return index
        if not isinstance(needle, str) and needle.search(line):
            return index
    return 1


def contains_any(text: str, search_terms: tuple[str, ...]) -> bool:
    return any(term in text for term in search_terms)


def emit(findings: list[dict[str, Any]], path: Path, line: int, code: str) -> None:
    severity, dimension, evidence, impact, recommendation = SPECS[code]
    verification = f"python3 tools/skill_quality/check_skill_body_quality.py {path.relative_to(REPO_ROOT).as_posix()}"
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
            verification=verification,
        )
    )


def emit_custom(
    findings: list[dict[str, Any]], path: Path, line: int, code: str, spec: FindingSpec
) -> None:
    severity, dimension, evidence, impact, recommendation = spec
    verification = f"python3 tools/skill_quality/check_skill_body_quality.py {path.relative_to(REPO_ROOT).as_posix()}"
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
            verification=verification,
        )
    )


def resource_paths_from_line(line: str) -> list[str]:
    return [
        value
        for value in re.findall(r"`([^`]*(?:references|resources)/[^`]*)`", line)
        if "references/" in value or "resources/" in value
    ]


def resource_file_ref(raw_ref: str) -> str:
    return raw_ref.split("#", 1)[0]


def resource_path_for(skill_path: Path, raw_ref: str) -> Path:
    path = Path(resource_file_ref(raw_ref))
    return (
        path.resolve() if path.is_absolute() else (skill_path.parent / path).resolve()
    )


def is_template_route(raw_ref: str) -> bool:
    return "/references/templates/" in f"/{raw_ref}"


def resource_is_repo_file(skill_path: Path, raw_ref: str) -> bool:
    if is_template_route(raw_ref):
        return True
    resource_path = resource_path_for(skill_path, raw_ref)
    try:
        resource_path.relative_to(REPO_ROOT)
    except ValueError:
        return False
    return resource_path.is_file()


def external_resource_contract_complete(skill_path: Path, raw_ref: str) -> bool:
    if not resource_is_repo_file(skill_path, raw_ref):
        return False
    if is_template_route(raw_ref):
        return True
    header = "\n".join(
        resource_path_for(skill_path, raw_ref)
        .read_text(encoding="utf-8")
        .splitlines()[:12]
    )
    return all(f"{field}:" in header for field in RESOURCE_CONTRACT_FIELDS)


def resource_route_contract_complete(path: Path, line: str) -> bool:
    refs = resource_paths_from_line(line)
    if not refs:
        return all(f"{field}:" in line for field in RESOURCE_CONTRACT_FIELDS)
    if all(f"{field}:" in line for field in RESOURCE_CONTRACT_FIELDS):
        return True
    if contains_any(line, RESOURCE_READ_TERMS) and contains_any(
        line, RESOURCE_EXTRACT_TERMS
    ):
        return all(resource_is_repo_file(path, ref) for ref in refs)
    if "按需读取" in line and any(term in line for term in SOP_ROUTE_TERMS):
        return True
    if contains_any(line, RESOURCE_READ_TERMS) and contains_any(
        line, RESOURCE_PURPOSE_TERMS
    ):
        return all(resource_is_repo_file(path, ref) for ref in refs)
    return all(external_resource_contract_complete(path, ref) for ref in refs)


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
        if line.startswith("## ") and any(
            re.search(pattern, line) for pattern in heading_patterns
        ):
            start = index
            break
    if start == 0 and not any(
        re.search(pattern, lines[0] if lines else "") for pattern in heading_patterns
    ):
        return "", 1
    end = next(
        (
            index
            for index in range(start + 1, len(lines))
            if lines[index].startswith("## ")
        ),
        len(lines),
    )
    return "\n".join(lines[start:end]), start + 1


def check_frontmatter(
    path: Path, lines: list[str], findings: list[dict[str, Any]]
) -> None:
    meta, end_line = frontmatter(lines)
    if not meta or end_line == 0:
        emit(findings, path, 1, "FRONTMATTER_MISSING")
        return
    for key in ("name", "description"):
        if not meta.get(key):
            emit_custom(
                findings,
                path,
                1,
                f"{key.upper()}_MISSING",
                (
                    "FAIL",
                    "G0",
                    f"frontmatter lacks {key}.",
                    "Runtime routing and trigger review cannot consume the Skill contract.",
                    f"Add frontmatter {key}.",
                ),
            )
    name = meta.get("name", "")
    expected = path.parent.name
    if name and (
        not NAME_RE.fullmatch(name)
        or "--" in name
        or name != expected
        or contains_xml_tag(name)
    ):
        emit(findings, path, first_line(lines, "name:"), "NAME_INVALID")
    description = meta.get("description", "")
    if description and (len(description) > 1024 or contains_xml_tag(description)):
        emit(findings, path, first_line(lines, "description:"), "DESCRIPTION_INVALID")


def check_resource_contracts(
    path: Path, lines: list[str], findings: list[dict[str, Any]]
) -> None:
    for index, line in enumerate(lines, start=1):
        if "references/" not in line and "resources/" not in line:
            continue
        if resource_route_contract_complete(path, line):
            continue
        missing = [
            field for field in RESOURCE_CONTRACT_FIELDS if f"{field}:" not in line
        ]
        emit_custom(
            findings,
            path,
            index,
            "PROGRESSIVE_LOADING_CONTRACT_INCOMPLETE",
            (
                "WARN",
                "S4",
                f"reference route is missing contract fields: {', '.join(missing)}.",
                "Agent may read too much, too little, or the wrong resource during execution.",
                "Bind the resource route to concise SOP wording with load timing, purpose, output, consumer, and verification value.",
            ),
        )
        return


def check_body_quality(
    path: Path, lines: list[str], findings: list[dict[str, Any]]
) -> None:
    text = "\n".join(lines)
    if not contains_any(text, HARD_GATE_TERMS):
        emit(findings, path, 1, "HARD_GATE_MISSING")
    if not contains_any(text, GOAL_TERMS):
        emit(findings, path, 1, "GOAL_CONTRACT_MISSING")
    flow_text, flow_line = section(lines, FLOW_HEADING_PATTERNS)
    if not flow_text:
        emit(findings, path, 1, "WORKFLOW_MISSING")
    elif not contains_any(flow_text, ACTION_TERMS):
        emit(findings, path, flow_line, "SOP_ACTIONS_MISSING")
    if contains_any(text, COMPLEX_TERMS) and not contains_any(text, STRUCTURE_TERMS):
        pattern = re.compile("|".join(re.escape(term) for term in COMPLEX_TERMS))
        emit(findings, path, first_line(lines, pattern), "COMPLEX_FLOW_UNSTRUCTURED")
    verification_text, verification_line = section(lines, VERIFICATION_HEADING_PATTERNS)
    if not verification_text:
        emit(findings, path, 1, "VERIFICATION_MISSING")
    elif not contains_any(verification_text, VERIFICATION_TERMS):
        emit(findings, path, verification_line, "VERIFICATION_EVIDENCE_MISSING")


def check_vague_instructions(
    path: Path, lines: list[str], findings: list[dict[str, Any]]
) -> None:
    for index, line in enumerate(lines, start=1):
        if not contains_any(line, VAGUE_TERMS):
            continue
        window = "\n".join(lines[max(0, index - 2) : min(len(lines), index + 1)])
        if contains_any(window, CRITERIA_TERMS):
            continue
        emit(findings, path, index, "VAGUE_INSTRUCTION_UNBOUNDED")
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
