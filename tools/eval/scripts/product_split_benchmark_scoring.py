#!/usr/bin/env python3
"""Scoring helpers for the product split benchmark."""

from __future__ import annotations

import json
import re
from pathlib import Path

RUBRIC_TERMS = [
    "PRD",
    "根问题",
    "目标",
    "范围",
    "阶段边界",
    "Phase",
    "下一步",
    "确认",
    "收敛",
    "冻结",
    "方案",
    "需求",
    "成功标准",
    "最小业务闭环",
    "基线",
    "上游",
    "细化",
    "改写",
    "迁移候选",
    "产品",
    "架构",
    "测试",
    "PASS",
    "确认轮",
    "重审",
    "ASK_USER",
    "BLOCKED",
    "R13",
    "PR-C1",
    "价值",
    "最小闭环",
    "实现步骤",
    "切分",
    "放行",
]

HOLLOW_MARKERS = [
    "关键词占位",
    "无判断",
    "无证据",
    "无可执行内容",
]

ACTIONABLE_PATTERNS = [
    r"因为|所以|原因|风险|避免",
    r"建议|应当|需要|先[^。；，]*再",
    r"确认[^。；，]*后|冻结[^。；，]*后",
    r"输出|产出|交付|验收|标准",
]


def is_keyword_stuffed(response_text: str) -> bool:
    """Detect marker-free rubric keyword stuffing without concrete prose."""

    lowered = response_text.lower()
    counts = {
        term: len(re.findall(re.escape(term.lower()), lowered))
        for term in RUBRIC_TERMS
        if term.lower() in lowered
    }
    if not counts:
        return False
    total_hits = sum(counts.values())
    repeated_hits = sum(count - 1 for count in counts.values() if count > 1)
    max_count = max(counts.values())
    dense_segments = 0
    for segment in re.split(r"[。；，、,;.!?\n]+", lowered):
        segment_hits = sum(
            len(re.findall(re.escape(term.lower()), segment))
            for term in RUBRIC_TERMS
            if term.lower() in segment
        )
        if segment_hits >= 6 and len(segment.strip()) <= 80:
            dense_segments += 1
    repeated_stuffing = total_hits >= 18 and repeated_hits >= 8 and max_count >= 3
    low_repeat_stuffing = total_hits >= 14 and len(counts) >= 12 and dense_segments >= 1
    distributed_stuffing = total_hits >= 18 and len(counts) >= 16 and len(response_text.strip()) <= 260
    return repeated_stuffing or low_repeat_stuffing or distributed_stuffing


def write_json(path: Path, payload: object) -> None:
    """Write JSON with stable benchmark formatting."""

    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n")


def extract_evidence(text: str, pattern: str) -> str:
    """Return a short evidence snippet for a matched expectation."""

    match = re.search(pattern, text, flags=re.IGNORECASE | re.MULTILINE | re.DOTALL)
    if not match:
        return "未找到匹配片段"
    start = max(match.start() - 30, 0)
    end = min(match.end() + 30, len(text))
    return text[start:end].replace("\n", " ").strip()[:180]


def rubric_terms(criterion: str) -> list[str]:
    """Find benchmark-specific terms that make an outcome criterion concrete."""

    return [term for term in RUBRIC_TERMS if term.lower() in criterion.lower()]


def grade_rubric_item(criterion: str, response_text: str) -> dict:
    """Grade one outcome criterion with term coverage and non-hollow evidence."""

    terms = rubric_terms(criterion)
    matched = [term for term in terms if term.lower() in response_text.lower()]
    required = min(2, len(terms)) if terms else 1
    hollow = any(marker in response_text for marker in HOLLOW_MARKERS)
    keyword_stuffed = is_keyword_stuffed(response_text)
    actionable_hits = sum(1 for pattern in ACTIONABLE_PATTERNS if re.search(pattern, response_text))
    passed = len(matched) >= required and len(response_text.strip()) >= 120 and actionable_hits >= 2 and not hollow and not keyword_stuffed
    evidence = "、".join(matched[:4]) if matched else "未覆盖关键结果词"
    if hollow:
        evidence = "命中空洞输出标记"
    elif keyword_stuffed:
        evidence = "命中关键词堆砌模式"
    elif actionable_hits < 2:
        evidence = "缺少可执行判断或因果说明"
    return {
        "criterion": criterion,
        "passed": passed,
        "matched_terms": matched,
        "evidence": evidence,
    }


def grade_run(eval_item: dict, response_text: str, run_dir: Path, duration_seconds: float, return_code: int) -> None:
    """Emit a skill-creator-compatible grading.json for one benchmark run."""

    expectations = []
    keyword_passed = 0
    for expectation in eval_item["expectations"]:
        pattern = expectation["pattern"]
        is_pass = bool(re.search(pattern, response_text, flags=re.IGNORECASE | re.MULTILINE | re.DOTALL))
        keyword_passed += int(is_pass)
        expectations.append({"text": expectation["text"], "passed": is_pass, "evidence": extract_evidence(response_text, pattern)})

    rubric_rows = [
        grade_rubric_item(str(criterion), response_text)
        for criterion in eval_item.get("outcome_rubric", [])
    ]
    rubric_passed = sum(1 for row in rubric_rows if row["passed"])
    passed = keyword_passed + rubric_passed
    total = len(expectations) + len(rubric_rows)
    grading = {
        "grading_mode": "outcome_rubric_plus_keyword_smoke",
        "rubric_type": eval_item.get("rubric_type", "keyword_smoke"),
        "outcome_rubric": eval_item.get("outcome_rubric", []),
        "rubric_evaluations": rubric_rows,
        "expectations": expectations,
        "summary": {"passed": passed, "failed": total - passed, "total": total, "pass_rate": round((passed / total) if total else 0.0, 4)},
        "execution_metrics": {"total_tool_calls": 0, "errors_encountered": 0 if return_code == 0 else 1, "output_chars": len(response_text)},
        "timing": {"total_duration_seconds": round(duration_seconds, 1)},
        "user_notes_summary": {"uncertainties": [], "needs_review": [], "workarounds": []},
    }
    write_json(run_dir / "grading.json", grading)
