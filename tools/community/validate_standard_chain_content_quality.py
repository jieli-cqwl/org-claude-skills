#!/usr/bin/env python3
"""Validate standard-chain skill prose quality and noise migration audits."""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass
from pathlib import Path

from runtime_yaml import load_yaml

LAYERS = {
    "HARD-GATE",
    "Protocol",
    "Why",
    "How",
    "Script Contract",
    "Failure Routing",
    "Reference Link",
    "Output Contract",
}
LAYER_ALIASES = {
    "hard-gate": "HARD-GATE",
    "hard gate": "HARD-GATE",
    "protocol": "Protocol",
    "why": "Why",
    "how": "How",
    "script contract": "Script Contract",
    "failure routing": "Failure Routing",
    "reference link": "Reference Link",
    "output contract": "Output Contract",
}
MIGRATION_ACTIONS = {"script", "contract", "reference", "projection", "archive", "delete"}
REQUIRED_AUDIT_FIELDS = {
    "source_file",
    "source_anchor",
    "content_layer",
    "migration_action",
    "destination_ref",
    "consumer",
    "reason",
    "verification_ref",
}
NORMATIVE_RE = re.compile(
    r"\b(must|shall|required|requires|need to|needs to|must not|cannot)\b|"
    r"(必须|不得|禁止|不能|需要|应当)",
    re.IGNORECASE,
)
HOW_CONCRETE_RE = re.compile(
    r"(`?\b(?:bash|python3?|node|npm|pnpm|uv|rg|jq|curl|git)\b)|"
    r"(--[a-z0-9][a-z0-9-]*)|"
    r"([A-Za-z0-9_.-]+/[A-Za-z0-9_./-]+\.(?:md|json|py|sh|ya?ml|ts|tsx|js|jsx|txt))|"
    r"(\b[A-Za-z_][A-Za-z0-9_]*(?:_id|_ref|_refs|_path|_status|_result|_field)\b)|"
    r"(\b(?:completion condition|success criterion|exit condition)\b|完成条件|完成标准|验收口径)",
    re.IGNORECASE,
)
SOURCE_TRUTH_RE = re.compile(
    r"source[- ]of[- ]truth|truth lives|truth is|真源|唯一来源|权威来源",
    re.IGNORECASE,
)
FAILURE_ACTION_RE = re.compile(
    r"\b(fail(?:ure|s|ed)?|block(?:ed)?|reject(?:ed)?|stop)\b|阻塞|失败|拒绝|停止",
    re.IGNORECASE,
)
OWNER_RE = re.compile(
    r"\b(owner|next action|next_action|continuation|handoff target)\b|"
    r"负责人|归属|下一步|继续条件"
)
VAGUE_RE = re.compile(
    r"\b(as appropriate|when needed|if needed|etc\.|and so on|things|stuff|somehow)\b|"
    r"适当|必要时|按需|等等|相关内容|处理一下|视情况",
    re.IGNORECASE,
)
ACTION_RE = re.compile(
    r"\b(handle|update|fix|process|continue|move|migrate|clean|ensure|do)\b|"
    r"处理|更新|修复|继续|迁移|清理|确保",
    re.IGNORECASE,
)


@dataclass(frozen=True)
class Issue:
    path: Path
    line: int
    code: str
    message: str

    def format(self) -> str:
        location = f"{self.path}:{self.line}" if self.line else str(self.path)
        return f"{location}: {self.code}: {self.message}"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    parser.add_argument("--skill", type=Path, action="append", default=[])
    parser.add_argument("--audit", type=Path, action="append", default=[])
    parser.add_argument("--active-standard-chain", action="store_true")
    parser.add_argument("--list-targets", action="store_true")
    return parser.parse_args()


def normalize_heading(line: str) -> str | None:
    match = re.match(r"^#{2,6}\s+(.+?)\s*$", line)
    if not match:
        return None
    heading = match.group(1).strip().strip("`")
    return LAYER_ALIASES.get(re.sub(r"\s+", " ", heading.lower()))


def iter_layer_lines(path: Path) -> dict[str, list[tuple[int, str]]]:
    sections: dict[str, list[tuple[int, str]]] = {layer: [] for layer in LAYERS}
    current: str | None = None
    for line_no, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        layer = normalize_heading(line)
        if layer is not None:
            current = layer
            continue
        if current is not None:
            sections[current].append((line_no, line))
    return sections


def paragraph_text(lines: list[tuple[int, str]]) -> list[tuple[int, str]]:
    paragraphs: list[tuple[int, str]] = []
    start = 0
    current: list[str] = []
    for line_no, line in lines:
        text = line.strip()
        if not text:
            if current:
                paragraphs.append((start, " ".join(current)))
                current = []
            continue
        if not current:
            start = line_no
        current.append(text)
    if current:
        paragraphs.append((start, " ".join(current)))
    return paragraphs


def validate_required_layers(path: Path, sections: dict[str, list[tuple[int, str]]]) -> list[Issue]:
    issues = []
    for layer in sorted(LAYERS):
        if not sections[layer]:
            issues.append(Issue(path, 0, "missing_content_layer", f"missing {layer} section"))
    return issues


def validate_why(path: Path, lines: list[tuple[int, str]]) -> list[Issue]:
    issues = []
    for line_no, line in lines:
        if NORMATIVE_RE.search(line):
            issues.append(
                Issue(path, line_no, "hidden_must_in_why", "Why layer contains normative action wording")
            )
    return issues


def validate_how(path: Path, lines: list[tuple[int, str]]) -> list[Issue]:
    issues = []
    for line_no, line in lines:
        if HOW_CONCRETE_RE.search(line):
            issues.append(
                Issue(
                    path,
                    line_no,
                    "how_concrete_instruction",
                    "How layer contains a concrete command, file, field, or completion condition",
                )
            )
    return issues


def validate_failure_routing(path: Path, lines: list[tuple[int, str]]) -> list[Issue]:
    issues = []
    for line_no, text in paragraph_text(lines):
        if FAILURE_ACTION_RE.search(text) and not OWNER_RE.search(text):
            issues.append(
                Issue(path, line_no, "unowned_failure_statement", "failure routing statement lacks owner or next action")
            )
    return issues


def validate_vague_actions(path: Path) -> list[Issue]:
    issues = []
    for line_no, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        if VAGUE_RE.search(line) and ACTION_RE.search(line):
            issues.append(
                Issue(path, line_no, "vague_ambiguous_action", "vague action wording is ambiguous")
            )
    return issues


def normalize_source_truth_claim(line: str) -> str | None:
    if not SOURCE_TRUTH_RE.search(line):
        return None
    lowered = line.lower()
    negative_re = (
        r"\b(not|never|no|isn't|aren't|wasn't|weren't|don't|doesn't|didn't|can't|cannot)\b"
        r".{0,30}(source[- ]of[- ]truth|truth)"
        r"|不是.{0,8}(真源|唯一来源)"
    )
    if re.search(negative_re, lowered):
        return None
    text = re.sub(r"`[^`]+`", "", line)
    text = re.sub(r"[^A-Za-z0-9\u4e00-\u9fff]+", " ", text).strip().lower()
    return text or None


def validate_source_truth(path: Path) -> list[Issue]:
    seen: dict[str, int] = {}
    issues = []
    for line_no, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        claim = normalize_source_truth_claim(line)
        if claim is None:
            continue
        if claim in seen:
            issues.append(
                Issue(path, line_no, "repeated_source_of_truth", "duplicate source-of-truth claim")
            )
        else:
            seen[claim] = line_no
    return issues


def validate_skill(path: Path) -> list[Issue]:
    if not path.is_file():
        return [Issue(path, 0, "missing_skill_file", "skill file does not exist")]
    sections = iter_layer_lines(path)
    issues = validate_required_layers(path, sections)
    issues.extend(validate_why(path, sections["Why"]))
    issues.extend(validate_how(path, sections["How"]))
    issues.extend(validate_failure_routing(path, sections["Failure Routing"]))
    issues.extend(validate_source_truth(path))
    issues.extend(validate_vague_actions(path))
    return issues


def load_audit(path: Path) -> tuple[dict, list[Issue]]:
    if not path.is_file():
        return {}, [Issue(path, 0, "missing_audit_file", "audit file does not exist")]
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        return {}, [Issue(path, error.lineno, "invalid_audit_json", error.msg)]
    if not isinstance(payload, dict):
        return {}, [Issue(path, 0, "invalid_audit_shape", "audit root must be an object")]
    return payload, []


def validate_audit_entry(path: Path, entry: object, index: int) -> list[Issue]:
    if not isinstance(entry, dict):
        return [Issue(path, 0, "invalid_audit_entry", f"entry {index} must be an object")]
    issues = []
    for field in sorted(REQUIRED_AUDIT_FIELDS):
        value = entry.get(field)
        if not isinstance(value, str) or not value.strip():
            issues.append(Issue(path, 0, "missing_audit_field", f"entry {index} missing string field {field}"))
    layer = entry.get("content_layer")
    action = entry.get("migration_action")
    if layer not in LAYERS:
        issues.append(Issue(path, 0, "invalid_content_layer", f"entry {index} has invalid layer"))
    if action not in MIGRATION_ACTIONS:
        issues.append(Issue(path, 0, "invalid_migration_action", f"entry {index} has invalid action"))
    if action == "delete" and (
        not str(entry.get("reason", "")).strip()
        or not str(entry.get("verification_ref", "")).strip()
    ):
        issues.append(
            Issue(path, 0, "delete_without_reason_or_verification", f"entry {index} delete lacks proof")
        )
    return issues


def validate_touched_skills(path: Path, payload: dict, entries: list[object]) -> list[Issue]:
    touched = payload.get("touched_skills", [])
    if not isinstance(touched, list) or not touched:
        return [Issue(path, 0, "invalid_touched_skills", "touched_skills must be a non-empty list")]
    entry_sources = {
        source
        for entry in entries
        if isinstance(entry, dict)
        for source in [entry.get("source_file")]
        if isinstance(source, str) and source.strip()
    }
    issues = []
    touched_set = set()
    for skill in touched:
        if not isinstance(skill, str) or not skill.strip():
            issues.append(Issue(path, 0, "invalid_touched_skill", "touched skill must be a path string"))
            continue
        touched_set.add(skill)
        if skill not in entry_sources:
            issues.append(Issue(path, 0, "touched_skill_without_audit", f"{skill} has no audit entry"))
    for source in sorted(entry_sources - touched_set):
        issues.append(Issue(path, 0, "audit_entry_without_touched_skill", f"{source} is not listed in touched_skills"))
    return issues


def validate_audit(path: Path) -> list[Issue]:
    payload, issues = load_audit(path)
    if issues:
        return issues
    entries = payload.get("entries")
    if not isinstance(entries, list) or not entries:
        return [Issue(path, 0, "missing_audit_entries", "audit must contain entries")]
    issues = validate_touched_skills(path, payload, entries)
    for index, entry in enumerate(entries, start=1):
        issues.extend(validate_audit_entry(path, entry, index))
    return issues


def active_standard_chain_skills(repo_root: Path) -> list[Path]:
    contract = repo_root / "contracts" / "standard-chain.yaml"
    if not contract.is_file():
        raise FileNotFoundError(contract)
    data = load_yaml(contract)
    chain = data.get("chain", []) if isinstance(data, dict) else []
    names = [
        item["name"]
        for item in chain
        if isinstance(item, dict)
        and isinstance(item.get("name"), str)
        and item.get("position") == "main"
    ]
    return [repo_root / "shared" / "skills" / name / "SKILL.md" for name in names]


def emit_issues(issues: list[Issue]) -> None:
    for issue in issues:
        print(issue.format(), file=sys.stderr)


def main() -> int:
    args = parse_args()
    repo_root = args.repo_root.resolve()
    skill_paths = list(args.skill)
    audit_paths = list(args.audit)
    if args.active_standard_chain:
        active_paths = active_standard_chain_skills(repo_root)
        if args.list_targets:
            for path in active_paths:
                print(path.relative_to(repo_root))
            return 0
        skill_paths.extend(active_paths)
    if not skill_paths and not audit_paths:
        print("no skill or audit targets provided", file=sys.stderr)
        return 2

    issues: list[Issue] = []
    for path in skill_paths:
        issues.extend(validate_skill(path.resolve()))
    for path in audit_paths:
        issues.extend(validate_audit(path.resolve()))
    if issues:
        emit_issues(issues)
        return 1
    print("[PASS] standard-chain content quality")
    return 0


if __name__ == "__main__":
    sys.exit(main())
