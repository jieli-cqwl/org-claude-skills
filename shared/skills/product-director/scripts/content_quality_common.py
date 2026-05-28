from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Any

MAX_DIMENSION_SCORE = 2


def terms(value: str) -> tuple[str, ...]:
    return tuple(value.split("|"))


FORBIDDEN_BRIEF_FIELDS = terms(
    "unit_index|acceptance_criteria|design_decisions|non_functional_requirements|"
    "business_flows|user_paths|rule_mappings|semantic_draft|"
    "business_semantics_draft|semantics_gaps|review_conclusion|"
    "issue_ledger|delivery_confirmation"
)
FORBIDDEN_PHASE_FIELDS = terms(
    "unit_index|review_conclusion|issue_ledger|business_flows|user_paths|"
    "rule_mappings|unit_priority_order|semantic_draft|business_semantics_draft|"
    "semantics_gaps|design_decision_candidates"
)
CAUSE_TERMS = terms("because|causing|由于|因为|导致|源于|造成|使得|来自")
COST_TERMS = terms(
    "causing|cost|miss|delay|slow|rework|成本|延迟|遗漏|返工|漏跟进|超时|等待|重复"
)
TIME_TERMS = ("day", "week", "month", "window", "天", "周", "月", "周期")
TARGET_TERMS = (
    "zero",
    "reduce",
    "increase",
    "from",
    "to",
    "低于",
    "达到",
    "从",
    "降到",
    "提升",
    "降低",
    "消除",
    "缩短",
    "以内",
)
ENTRY_GATE_TERMS = ("director baseline confirmed", "gate", "passed", "确认门", "门禁")
EXIT_PLANNING_TERMS = terms(
    "timebox|10-day|complete design|complete development|"
    "acceptance criteria| ac |完成设计|完成开发"
)
DOWNSTREAM_RISK_TERMS = ("downstream execution risk", "下游执行风险")
GENERIC_SUMMARY_TERMS = (" confirmed for ", "已确认完成", "完成确认")
NOISE_TERMS = (
    "tbd",
    "todo",
    "待补",
    "待定",
    "anything vague",
    "make the process better",
)
REPEATED_TOKEN_RE = re.compile(r"\b([a-z]{3,})\s+\1\b")


def load_json(path: Path) -> dict[str, Any]:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise SystemExit(f"{path}: file not found") from exc
    except json.JSONDecodeError as exc:
        raise SystemExit(f"{path}: invalid JSON: {exc}") from exc
    if not isinstance(data, dict):
        raise SystemExit(f"{path}: artifact must be a JSON object")
    return data


def as_list(value: Any) -> list[Any]:
    return value if isinstance(value, list) else []


def text_of(value: Any) -> str:
    if isinstance(value, str):
        return value
    if isinstance(value, list):
        return " ".join(text_of(item) for item in value)
    if isinstance(value, dict):
        return " ".join(text_of(item) for item in value.values())
    return ""


def lower_text(value: Any) -> str:
    return text_of(value).lower()


def has_any(text: str, terms: tuple[str, ...]) -> bool:
    return any(term in text for term in terms)


def has_number(text: str) -> bool:
    return bool(re.search(r"\d", text))


def dimension(
    dimension_id: str,
    checks: list[bool],
    evidence: list[str],
    issues: list[str],
    *,
    must_fail: bool = False,
) -> dict[str, Any]:
    passed = sum(1 for item in checks if item)
    score = MAX_DIMENSION_SCORE if passed == len(checks) else 1 if passed else 0
    if must_fail:
        score = 0
    return {
        "id": dimension_id,
        "score": score,
        "max_score": MAX_DIMENSION_SCORE,
        "evidence": evidence,
        "issues": issues,
        "must_fail": must_fail or bool(issues),
    }
