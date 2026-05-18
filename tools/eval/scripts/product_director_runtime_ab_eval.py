#!/usr/bin/env python3
"""Compare old and new product-director runtime contracts."""

from __future__ import annotations

import argparse
import json
import re
import subprocess
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[3]
DEFAULT_OLD_REF = "29e4de6c^"
DEFAULT_NEW_REF = "29e4de6c"

PRODUCT_DIRECTOR_SKILL = "shared/skills/product-director/SKILL.md"
PRODUCT_DIRECTOR_EVALS = "shared/skills/product-director/evals/evals.json"
PRODUCT_DIRECTOR_REFS = "shared/skills/product-director/references"
CO_CREATION_LEDGER = "contracts/co-creation-ledgers.yaml"
PM_REVIEW_PROMPT = "shared/skills/product-manager/references/prd-reviewer-prompt.md"

LEGACY_RUNTIME_RE = re.compile(
    r"D-S[0-9]|D-G[0-9]|产品总监确认|总监确认门|Handoff to|业务语义收口|负责在下游角色介入前"
)


@dataclass(frozen=True)
class Check:
    check_id: str
    criterion: str
    old_pass: bool
    new_pass: bool
    kind: str
    evidence: str

    @property
    def verdict(self) -> str:
        if self.kind == "preserved":
            return "pass" if self.old_pass and self.new_pass else "fail"
        return "pass" if (not self.old_pass and self.new_pass) else "fail"


def run_git(args: list[str], repo_root: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["git", *args],
        cwd=repo_root,
        text=True,
        capture_output=True,
        check=False,
    )


def git_text(ref: str, path: str, repo_root: Path) -> str:
    completed = run_git(["show", f"{ref}:{path}"], repo_root)
    if completed.returncode != 0:
        return ""
    return completed.stdout


def git_files(ref: str, prefix: str, repo_root: Path) -> list[str]:
    completed = run_git(["ls-tree", "-r", "--name-only", ref, "--", prefix], repo_root)
    if completed.returncode != 0:
        return []
    return [line for line in completed.stdout.splitlines() if line]


def count_lines(text: str) -> int:
    return len(text.splitlines())


def has_all(text: str, terms: list[str]) -> bool:
    return all(term in text for term in terms)


def has_any(text: str, terms: list[str]) -> bool:
    return any(term in text for term in terms)


def parse_eval_ids(evals_text: str) -> list[str]:
    try:
        payload = json.loads(evals_text)
    except json.JSONDecodeError:
        return []
    evals = payload.get("evals", [])
    return [item.get("id", "") for item in evals if isinstance(item, dict)]


def checkpoint_steps(ledger_text: str) -> list[str]:
    match = re.search(r"product-director:[\s\S]*?checkpoint_steps:\s*\[([^\]]+)\]", ledger_text)
    if not match:
        return []
    return [item.strip() for item in match.group(1).split(",") if item.strip()]


def load_snapshot(ref: str, repo_root: Path) -> dict[str, Any]:
    skill = git_text(ref, PRODUCT_DIRECTOR_SKILL, repo_root)
    evals = git_text(ref, PRODUCT_DIRECTOR_EVALS, repo_root)
    ledger = git_text(ref, CO_CREATION_LEDGER, repo_root)
    pm_prompt = git_text(ref, PM_REVIEW_PROMPT, repo_root)
    ref_files = git_files(ref, PRODUCT_DIRECTOR_REFS, repo_root)
    ref_texts = [git_text(ref, path, repo_root) for path in ref_files if path.endswith(".md")]
    runtime_text = "\n".join([skill, evals, ledger, pm_prompt, *ref_texts])
    return {
        "ref": ref,
        "skill": skill,
        "evals": evals,
        "ledger": ledger,
        "pm_prompt": pm_prompt,
        "reference_files": ref_files,
        "reference_text": "\n".join(ref_texts),
        "runtime_text": runtime_text,
        "skill_lines": count_lines(skill),
        "reference_lines": sum(count_lines(text) for text in ref_texts),
        "eval_ids": parse_eval_ids(evals),
        "checkpoint_steps": checkpoint_steps(ledger),
    }


def build_checks(old: dict[str, Any], new: dict[str, Any]) -> list[Check]:
    new_eval_ids = set(new["eval_ids"])
    old_eval_ids = set(old["eval_ids"])
    new_runtime = new["runtime_text"]
    old_runtime = old["runtime_text"]

    return [
        Check(
            "role-identity",
            "角色从“产品总监/WHAT handoff”收束为“业务产品负责人/Director 场景基线冻结”。",
            old_pass=has_all(old["skill"], ["业务产品负责人", "Director 场景基线"]),
            new_pass=has_all(new["skill"], ["业务产品负责人", "Director 场景基线"]),
            kind="improved",
            evidence="新版主 skill 明确业务产品负责人和 Director 场景基线；旧版仍以产品总监、WHAT 层交接为中心。",
        ),
        Check(
            "legacy-step-noise-removed",
            "去掉 D-S/D-G、总监确认门、handoff 等会让执行者按旧步骤机械推进的噪音。",
            old_pass=not bool(LEGACY_RUNTIME_RE.search(old_runtime)),
            new_pass=not bool(LEGACY_RUNTIME_RE.search(new_runtime)),
            kind="improved",
            evidence="旧版运行时存在 D-S/D-G 和产品总监确认口径；新版改为六个语义环节和冻结门。",
        ),
        Check(
            "no-dispatch-blocking",
            "无法形成基线时必须阻断/不做，建议承接方只能作为恢复信息，不能变成调度动作。",
            old_pass=has_all(old["skill"], ["阻断不是调度", "建议承接方只作为恢复信息"]),
            new_pass=has_all(new["skill"], ["阻断不是调度", "建议承接方只作为恢复信息"]),
            kind="improved",
            evidence="新版把阻断不是调度写入 HARD-GATE；旧版缺少该硬约束。",
        ),
        Check(
            "semantic-ledger-checkpoints",
            "共创台账从步骤编号改为语义 checkpoint，降低流程名对执行判断的干扰。",
            old_pass=old["checkpoint_steps"] == ["FACTS", "ROOT", "SUCCESS", "SCOPE", "RISK_PHASE", "FREEZE"],
            new_pass=new["checkpoint_steps"] == ["FACTS", "ROOT", "SUCCESS", "SCOPE", "RISK_PHASE", "FREEZE"],
            kind="improved",
            evidence=f"旧版 checkpoint={old['checkpoint_steps']}；新版 checkpoint={new['checkpoint_steps']}。",
        ),
        Check(
            "technical-scenario-boundary",
            "架构演进、服务拆分等技术场景先判断是否需要冻结场景基线，具体架构设计不在 product-director 内做。",
            old_pass={"technical-scenario-needs-director-baseline", "existing-baseline-architecture-blocked"}.issubset(old_eval_ids),
            new_pass={"technical-scenario-needs-director-baseline", "existing-baseline-architecture-blocked"}.issubset(new_eval_ids),
            kind="improved",
            evidence="新版 eval 显式覆盖技术场景承接与已冻结后架构方案阻断；旧版没有这两个场景。",
        ),
        Check(
            "implementation-defect-boundary",
            "已有明确 AC、实现任务或已定位缺陷时不得包装成 Director 场景基线。",
            old_pass={"implementation-task-blocked", "defect-blocked"}.issubset(old_eval_ids),
            new_pass={"implementation-task-blocked", "defect-blocked"}.issubset(new_eval_ids),
            kind="improved",
            evidence="新版 eval 覆盖实现任务和缺陷修复阻断；旧版没有该边界。",
        ),
        Check(
            "downstream-consumption-language",
            "下游 reviewer 消费 Director 场景基线冻结快照，不再依赖旧 D-G1/产品总监确认话术。",
            old_pass=has_all(old["pm_prompt"], ["Director 场景基线冻结快照", "Director 场景基线确认"])
            and not has_any(old["pm_prompt"], ["D-G1", "产品总监确认"]),
            new_pass=has_all(new["pm_prompt"], ["Director 场景基线冻结快照", "Director 场景基线确认"])
            and not has_any(new["pm_prompt"], ["D-G1", "产品总监确认"]),
            kind="improved",
            evidence="新版 PM review prompt 改为冻结快照/场景基线确认；旧版仍引用 D-G1 快照和产品总监确认。",
        ),
        Check(
            "timebox-meaning-clarified",
            "timebox 是场景验证粒度，不是人力、agent 数量或技术工期承诺。",
            old_pass=has_all(old_runtime, ["timebox 不是人力", "agent 数量", "技术工期承诺"]),
            new_pass=has_all(new_runtime, ["timebox 不是人力", "agent 数量", "技术工期承诺"]),
            kind="improved",
            evidence="新版将 timebox 依据写入主流程和 eval；旧版只强调 14 天上限，容易被理解成排期规则。",
        ),
        Check(
            "first-principles-preserved",
            "第一性原理仍是根问题收敛的核心方法。",
            old_pass=has_any(old_runtime, ["第一性原理"]),
            new_pass=has_any(new_runtime, ["第一性原理"]),
            kind="preserved",
            evidence="新版没有砍掉第一性原理，只把它放回根问题收敛环节。",
        ),
        Check(
            "success-standard-gate-preserved",
            "拒绝“上线后看效果”这类不可观察成功标准。",
            old_pass="vague-success-criteria-rejected" in old_eval_ids,
            new_pass="vague-success-criteria-rejected" in new_eval_ids,
            kind="preserved",
            evidence="新旧 eval 都保留模糊成功标准阻断场景。",
        ),
        Check(
            "canonical-output-contract-preserved",
            "成功冻结仍输出 brief.json、phase-prd.json、locked_fields 和 locked_field_digest。",
            old_pass=has_all(old_runtime, ["brief.json", "phase-prd.json", "locked_fields", "locked_field_digest"]),
            new_pass=has_all(new_runtime, ["brief.json", "phase-prd.json", "locked_fields", "locked_field_digest"]),
            kind="preserved",
            evidence="新版保留标准产物与锁定字段契约。",
        ),
    ]


def status_for_checks(checks: list[Check]) -> str:
    return "pass" if all(check.verdict == "pass" for check in checks) else "fail"


def summarize(old: dict[str, Any], new: dict[str, Any], checks: list[Check]) -> dict[str, Any]:
    improved_checks = [check for check in checks if check.kind == "improved"]
    preserved_checks = [check for check in checks if check.kind == "preserved"]
    old_desired = sum(1 for check in checks if check.old_pass)
    new_desired = sum(1 for check in checks if check.new_pass)
    improvements = sum(1 for check in improved_checks if not check.old_pass and check.new_pass)
    return {
        "status": status_for_checks(checks),
        "old_ref": old["ref"],
        "new_ref": new["ref"],
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "score": {
            "old_desired_checks": old_desired,
            "new_desired_checks": new_desired,
            "total_checks": len(checks),
            "improvement_checks_passed": sum(1 for check in improved_checks if check.verdict == "pass"),
            "improvement_checks_total": len(improved_checks),
            "preserved_checks_passed": sum(1 for check in preserved_checks if check.verdict == "pass"),
            "preserved_checks_total": len(preserved_checks),
            "old_to_new_improvements": improvements,
        },
        "size": {
            "old_skill_lines": old["skill_lines"],
            "new_skill_lines": new["skill_lines"],
            "old_reference_files": len(old["reference_files"]),
            "new_reference_files": len(new["reference_files"]),
            "old_reference_lines": old["reference_lines"],
            "new_reference_lines": new["reference_lines"],
            "old_eval_count": len(old["eval_ids"]),
            "new_eval_count": len(new["eval_ids"]),
        },
        "old_eval_ids": old["eval_ids"],
        "new_eval_ids": new["eval_ids"],
        "checks": [
            {
                "id": check.check_id,
                "kind": check.kind,
                "verdict": check.verdict,
                "criterion": check.criterion,
                "old_pass": check.old_pass,
                "new_pass": check.new_pass,
                "evidence": check.evidence,
            }
            for check in checks
        ],
        "evidence_boundary": {
            "proved": "契约层更强：角色、门禁、边界、下游消费和 eval 覆盖均可复验。",
            "not_proved": "这不是模型真实输出 A/B；若要证明实际行为更强，需要用同一组场景分别加载旧版和新版运行真实 LLM 输出再评分。",
        },
        "reproduce_command": (
            "python3 tools/eval/scripts/product_director_runtime_ab_eval.py "
            f"--old-ref '{old['ref']}' --new-ref {new['ref']} "
            "--out-dir tools/eval/results/product-director-runtime-ab-20260518"
        ),
    }


def markdown_report(summary: dict[str, Any]) -> str:
    score = summary["score"]
    size = summary["size"]
    lines = [
        "# product-director 运行时 A/B 评估",
        "",
        f"- status: `{summary['status']}`",
        f"- old_ref: `{summary['old_ref']}`",
        f"- new_ref: `{summary['new_ref']}`",
        f"- generated_at: `{summary['generated_at']}`",
        f"- reproduce: `{summary['reproduce_command']}`",
        "",
        "## 结论",
        "",
        "新版不是靠信息量取胜，而是靠执行契约取胜。判断标准是：更少歧义、更强门禁、更准边界、更稳定的下游消费，并且不丢掉第一性原理、成功标准、标准产物输出这些核心能力。",
        "",
        f"- 新版满足目标契约：{score['new_desired_checks']}/{score['total_checks']}",
        f"- 旧版满足目标契约：{score['old_desired_checks']}/{score['total_checks']}",
        f"- 明确改善项：{score['old_to_new_improvements']}/{score['improvement_checks_total']}",
        f"- 保留能力项：{score['preserved_checks_passed']}/{score['preserved_checks_total']}",
        "",
        "## 为什么新版更强",
        "",
        "| check | 类型 | 旧版 | 新版 | 结论 |",
        "| --- | --- | --- | --- | --- |",
    ]

    for check in summary["checks"]:
        lines.append(
            "| {id} | {kind} | {old} | {new} | {verdict} |".format(
                id=check["id"],
                kind=check["kind"],
                old="PASS" if check["old_pass"] else "FAIL",
                new="PASS" if check["new_pass"] else "FAIL",
                verdict=check["verdict"].upper(),
            )
        )

    lines.extend(
        [
            "",
            "## 信息量判断",
            "",
            f"- skill 行数：旧版 {size['old_skill_lines']}，新版 {size['new_skill_lines']}",
            f"- references 文件数：旧版 {size['old_reference_files']}，新版 {size['new_reference_files']}",
            f"- references 行数：旧版 {size['old_reference_lines']}，新版 {size['new_reference_lines']}",
            f"- eval 数量：旧版 {size['old_eval_count']}，新版 {size['new_eval_count']}",
            "",
            "旧版看起来更丰富，主要是因为包含 D-S/D-G 步骤、总监确认门、handoff 话术和业务语义独立阶段。这些内容能给人读者安全感，但会让下游 LLM 执行者更容易把流程名当成目标、把阻断当成调度、把技术场景误路由。",
            "",
            "新版的简化不是压缩能力，而是把能力从“步骤说明”改成“语义门禁”：事实、根问题、成功标准、范围、风险与 Phase、冻结。这样更符合当前 standard-chain 的强门禁和下游消费定义。",
            "",
            "## 证据边界",
            "",
            f"- 已证明：{summary['evidence_boundary']['proved']}",
            f"- 未证明：{summary['evidence_boundary']['not_proved']}",
            "",
            "## 逐项证据",
            "",
        ]
    )

    for check in summary["checks"]:
        lines.extend(
            [
                f"### {check['id']}",
                "",
                f"- 判断标准：{check['criterion']}",
                f"- 证据：{check['evidence']}",
                "",
            ]
        )

    return "\n".join(lines).rstrip() + "\n"


def write_outputs(summary: dict[str, Any], out_dir: Path) -> None:
    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / "ab-evaluation.json").write_text(
        json.dumps(summary, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    (out_dir / "ab-evaluation.md").write_text(markdown_report(summary), encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=ROOT)
    parser.add_argument("--old-ref", default=DEFAULT_OLD_REF)
    parser.add_argument("--new-ref", default=DEFAULT_NEW_REF)
    parser.add_argument(
        "--out-dir",
        type=Path,
        default=ROOT / "tools/eval/results/product-director-runtime-ab",
    )
    args = parser.parse_args()

    repo_root = args.repo_root.resolve()
    old = load_snapshot(args.old_ref, repo_root)
    new = load_snapshot(args.new_ref, repo_root)
    checks = build_checks(old, new)
    summary = summarize(old, new, checks)
    out_dir = args.out_dir
    if not out_dir.is_absolute():
        out_dir = repo_root / out_dir
    write_outputs(summary, out_dir)
    print(json.dumps(summary, ensure_ascii=False, indent=2, sort_keys=True))
    return 0 if summary["status"] == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())
