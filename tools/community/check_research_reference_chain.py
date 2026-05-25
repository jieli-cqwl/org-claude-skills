#!/usr/bin/env python3
"""Validate research reference/projection contracts after brainstorming-parity work."""

from __future__ import annotations

import json
import sys
from pathlib import Path


def fail(message: str) -> None:
    raise SystemExit(message)


def require_terms(path: Path, terms: list[str], label: str) -> str:
    text = path.read_text(encoding="utf-8")
    missing = [term for term in terms if term not in text]
    if missing:
        fail(f"{path.name} missing {label} terms: {', '.join(missing)}")
    return text


def check_references(reference_dir: Path) -> None:
    requirements = {
        "analysis-frameworks.md": [
            "## 使用边界",
            "## 输出合同",
            "Source Targeting",
            "Evidence Qualification",
            "Decision Package",
            "Step 2",
            "Step 4",
            "候选收敛",
            "结构化评估",
            "资料/对象",
            "弱证据",
            "不得进入深度分析",
            "不得替代 Report Self-Review",
        ],
        "deep-analysis-template.md": [
            "## 使用边界",
            "## 输出合同",
            "Source Targeting Package",
            "Evidence Qualification",
            "Judgment Calibration",
            "Step 3",
            "弱证据",
            "证据不足",
            "待验证项",
            "不得抢占",
            "轻量预判断",
        ],
        "report-presentation-framework.md": [
            "## 使用边界",
            "## 输出合同",
            "Source Targeting Package",
            "Evidence Qualification",
            "Judgment Calibration",
            "Decision Package",
            "source targeting -> evidence qualification -> judgment -> audit",
            "Report Self-Review",
            "User Confirmation Gate",
            "不是更高级版本",
        ],
    }
    for name, terms in requirements.items():
        require_terms(reference_dir / name, terms, "reference contract")

    deep_analysis = (reference_dir / "deep-analysis-template.md").read_text(
        encoding="utf-8"
    )
    if "不可省略任何必填节" in deep_analysis:
        fail("deep-analysis-template.md still forces a heavy template")


def check_projections(projection_dir: Path) -> None:
    actual = sorted(path.name for path in projection_dir.glob("*.md"))
    expected = ["research-report-template.md"]
    if actual != expected:
        fail("research projections must collapse to one template; got: " + ", ".join(actual))

    text = require_terms(
        projection_dir / "research-report-template.md",
        [
            "## 模板使用边界",
            "Source Targeting Package",
            "Evidence Qualification",
            "Judgment Calibration",
            "Decision Package",
            "## 1. 呈现模式头部",
            "### decision",
            "不是证据豁免",
            "当前判断",
            "决定性理由",
            "最大风险",
            "下一步",
            "### understanding",
            "不提前推荐",
            "这是什么",
            "核心机制",
            "适用边界",
            "### audit",
            "不是更高级版本",
            "关键论点挑战表",
            "覆盖证明摘要",
            "剩余盲区",
            "## 2. 调研模式正文",
            "### selection",
            "TOP 3",
            "淘汰项",
            "推荐",
            "次选",
            "不推荐",
            "### analysis",
            "1-3 个核心论点",
            "论点挑战总表",
            "成立/部分成立/不成立/待验证",
            "### discovery",
            "名称归一化",
            "对象类型覆盖",
            "排除",
            "翻案条件",
            "## 3. 共享审计附录",
            "Report Self-Review",
            "User Confirmation Gate",
            "The terminal state",
        ],
        "projection contract",
    )
    if "..." in text:
        fail("research-report-template.md still contains vague ellipsis placeholders")

    legacy_names = [
        "research-decision-header-template.md",
        "research-understanding-header-template.md",
        "research-audit-header-template.md",
        "research-tech-selection-template.md",
        "research-analysis-template.md",
        "research-discovery-template.md",
        "research-shared-header-template.md",
        "research-shared-audit-appendix-template.md",
    ]
    present_legacy = [name for name in legacy_names if name in text]
    if present_legacy:
        fail(
            "research-report-template.md still points to legacy split templates: "
            + ", ".join(present_legacy)
        )


def check_essence_evidence(path: Path) -> None:
    data = json.loads(path.read_text(encoding="utf-8"))
    if data.get("artifact_type") != "research-brainstorming-essence-evidence":
        fail("essence evidence artifact_type mismatch")

    required_ids = {"BE-01", "BE-02", "BE-03", "BE-04", "BE-05", "BE-06", "BE-07"}
    actual_ids = {item.get("id") for item in data.get("brainstorming_essence", [])}
    missing = sorted(required_ids - actual_ids)
    if missing:
        fail("essence evidence missing ids: " + ", ".join(missing))

    standards = data.get("success_standards", [])
    if len(standards) < 6 or any(item.get("status") != "pass" for item in standards):
        fail("essence evidence must record at least 6 passing success standards")

    all_refs = [
        ref
        for section in ("brainstorming_essence", "success_standards")
        for item in data.get(section, [])
        for ref in item.get("evidence_refs", [])
    ]
    required_fragments = [
        "shared/skills/research/SKILL.md",
        "shared/skills/research/references/",
        "shared/skills/research/projections/",
        "tests/test-research-skill-refiner-eval.sh",
    ]
    missing_refs = [
        fragment
        for fragment in required_fragments
        if not any(fragment in ref for ref in all_refs)
    ]
    if missing_refs:
        fail("essence evidence missing coverage: " + ", ".join(missing_refs))

    commands = {
        item.get("command"): item
        for item in data.get("verification_commands", [])
    }
    for command in [
        "bash tests/test-research-skill-refiner-eval.sh",
        "bash tests/test-research-skill-contract.sh",
    ]:
        if commands.get(command, {}).get("status") != "pass":
            fail(f"essence evidence missing passing command: {command}")

    broad_commands = [
        "bash tests/test-shared-skill-package-quality-baseline.sh",
        "python3 tools/community/check_test_signal_assertions.py",
        'CODEX_SKILLS_DIR="$PWD/community/anthropic/skills" bash tests/run-all.sh --quick',
    ]
    for command in broad_commands:
        item = commands.get(command)
        if item is None:
            fail(f"essence evidence missing broad verification command: {command}")
        status = item.get("status")
        if status == "pass":
            continue
        if status != "blocked_unrelated":
            fail(f"essence evidence invalid broad command status: {command}={status}")
        if "research" in item.get("blocking_scope", ""):
            fail(f"essence evidence broad command is blocked inside research: {command}")


def main(argv: list[str]) -> int:
    if len(argv) != 4:
        print(
            "usage: check_research_reference_chain.py "
            "<reference-dir> <projection-dir> <essence-result>",
            file=sys.stderr,
        )
        return 2

    reference_dir = Path(argv[1])
    projection_dir = Path(argv[2])
    essence_result = Path(argv[3])

    check_references(reference_dir)
    check_projections(projection_dir)
    check_essence_evidence(essence_result)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
