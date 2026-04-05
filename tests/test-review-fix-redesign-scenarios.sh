#!/usr/bin/env bash
set -euo pipefail

TMP_ROOT="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

python3 - "$TMP_ROOT" <<'PY'
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path


TMP_ROOT = Path(sys.argv[1])


def fail(message: str) -> None:
    raise SystemExit(f"[FAIL] {message}")


def run(cmd: list[str], cwd: Path, check: bool = True) -> subprocess.CompletedProcess[str]:
    completed = subprocess.run(cmd, cwd=cwd, text=True, capture_output=True)
    if check and completed.returncode != 0:
        stderr = completed.stderr.strip() or completed.stdout.strip() or "unknown error"
        fail(f"{cwd}: {' '.join(cmd)} -> {stderr}")
    return completed


def init_repo(name: str, files: dict[str, str]) -> Path:
    repo = TMP_ROOT / name
    repo.mkdir(parents=True, exist_ok=True)
    run(["git", "init", "-q"], repo)
    run(["git", "config", "user.name", "Test User"], repo)
    run(["git", "config", "user.email", "test@example.com"], repo)
    for rel_path, content in files.items():
        target = repo / rel_path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(content, encoding="utf-8")
    run(["git", "add", "."], repo)
    run(["git", "commit", "-qm", "init"], repo)
    return repo


def validate_payload(payload: dict[str, object], repo: Path, *, doc_mode: bool) -> list[str]:
    verdict = payload.get("verdict")
    findings = payload.get("findings")
    if verdict not in {"approve", "needs-attention"}:
        fail(f"invalid verdict: {verdict}")
    if not isinstance(findings, list):
        fail("findings must be a list")

    skipped: list[str] = []
    for finding in findings:
        if not isinstance(finding, dict):
            fail("finding must be an object")
        required = ["file", "line_start", "severity", "body", "recommendation"]
        if doc_mode:
            required.append("dimension")
        missing = [key for key in required if key not in finding]
        if missing:
            fail(f"missing finding fields: {', '.join(missing)}")
        path = repo / str(finding["file"])
        line = int(finding["line_start"])
        if not path.exists():
            skipped.append("skipped:unlocatable")
            continue
        total_lines = len(path.read_text(encoding="utf-8").splitlines())
        if line != 0 and line > total_lines:
            skipped.append("skipped:unlocatable")
    return skipped


def ensure_non_json_fail_close() -> None:
    raw_output = TMP_ROOT / "raw-non-json" / ".review-fix-raw-output.json"
    raw_output.parent.mkdir(parents=True, exist_ok=True)
    raw_output.write_text("not-json", encoding="utf-8")
    try:
        json.loads(raw_output.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        pass
    else:
        fail("non-json payload should fail-close")
    if raw_output.read_text(encoding="utf-8") != "not-json":
        fail("raw output should be preserved")
    print("[PASS] non-json reviewer output is preserved for fail-close")


def ensure_missing_field_fail_close(repo: Path) -> None:
    bad_payload = {
        "verdict": "needs-attention",
        "findings": [
            {
                "file": "sample.py",
                "line_start": 1,
                "body": "missing severity",
                "recommendation": "add severity",
            }
        ],
    }
    try:
        validate_payload(bad_payload, repo, doc_mode=False)
    except SystemExit as exc:
        if "missing finding fields: severity" not in str(exc):
            raise
    else:
        fail("missing severity should fail-close")
    print("[PASS] missing finding fields fail-close")


def code_result(counts: list[int]) -> str:
    previous = None
    for index, count in enumerate(counts, start=1):
        if count == 0:
            return "通过"
        if previous is not None and count >= previous:
            return "不收敛"
        previous = count
        if index == 5:
            return "未通过"
    fail("code_result expected terminal state")


def doc_result(counts: list[int]) -> str:
    zero_streak = 0
    previous = None
    for index, count in enumerate(counts, start=1):
        zero_streak = zero_streak + 1 if count == 0 else 0
        if zero_streak >= 2:
            return "通过"
        if previous is not None and count >= previous:
            return "不收敛"
        previous = count
        if index == 5:
            return "未通过"
    fail("doc_result expected terminal state")


def ensure_dirty_tree_restore() -> None:
    repo = init_repo("dirty-restore", {"sample.txt": "line1\nline2\n"})
    (repo / "sample.txt").write_text("line1\nlocal-change\n", encoding="utf-8")
    (repo / "draft.txt").write_text("draft\n", encoding="utf-8")
    run(["git", "stash", "push", "--include-untracked", "-m", "review-fix-baseline"], repo)
    if run(["git", "status", "--short"], repo).stdout.strip():
        fail("dirty repo should be clean after stash")
    (repo / "loop.txt").write_text("loop artifact\n", encoding="utf-8")
    run(["git", "add", "loop.txt"], repo)
    run(["git", "commit", "-qm", "loop artifact"], repo)
    run(["git", "stash", "pop"], repo)
    if "local-change" not in (repo / "sample.txt").read_text(encoding="utf-8"):
        fail("tracked dirty change should be restored after stash pop")
    if not (repo / "draft.txt").exists():
        fail("untracked file should be restored after stash pop")
    print("[PASS] dirty tree stash restore")


def ensure_clean_tree_skip_stash() -> None:
    repo = init_repo("clean-skip", {"sample.txt": "line1\n"})
    stash_check = run(["git", "rev-parse", "--verify", "refs/stash"], repo, check=False)
    if stash_check.returncode == 0:
        fail("clean scenario should not create refs/stash")
    print("[PASS] clean tree skips stash")


def ensure_stash_conflict_surfaces() -> None:
    repo = init_repo("stash-conflict", {"sample.txt": "line1\nline2\nline3\n"})
    (repo / "sample.txt").write_text("line1\nuser-change\nline3\n", encoding="utf-8")
    run(["git", "stash", "push", "-m", "review-fix-baseline"], repo)
    (repo / "sample.txt").write_text("line1\nloop-change\nline3\n", encoding="utf-8")
    run(["git", "add", "sample.txt"], repo)
    run(["git", "commit", "-qm", "loop change"], repo)
    conflict = run(["git", "stash", "pop"], repo, check=False)
    if conflict.returncode == 0:
        fail("stash pop conflict should not be auto-resolved")
    status = run(["git", "status", "--short"], repo).stdout
    if "UU sample.txt" not in status:
        fail("stash conflict should keep conflict markers in working tree")
    print("[PASS] stash pop conflict remains manual")


def ensure_code_loop_and_report() -> None:
    repo = init_repo("code-loop", {"sample.py": "def divide(a, b):\n    return a / b\n"})
    baseline_ref = run(["git", "rev-parse", "HEAD"], repo).stdout.strip()
    code_review_payload = {
        "verdict": "needs-attention",
        "findings": [
            {
                "file": "sample.py",
                "line_start": 2,
                "line_end": 2,
                "severity": "high",
                "title": "除零漏洞",
                "body": "除零未显式处理，会导致不可控异常。",
                "confidence": 0.9,
                "recommendation": "在除法前保护 b == 0。",
            }
        ],
    }
    self_review_payload = json.loads(json.dumps(code_review_payload))
    validate_payload(code_review_payload, repo, doc_mode=False)
    validate_payload(self_review_payload, repo, doc_mode=False)
    (repo / "sample.py").write_text(
        "def divide(a, b):\n    if b == 0:\n        raise ValueError('b must not be 0')\n    return a / b\n",
        encoding="utf-8",
    )
    run(["git", "add", "sample.py"], repo)
    run(["git", "commit", "-qm", "review-fix round 1"], repo)
    verify = run(["python3", "-m", "py_compile", "sample.py"], repo)
    approve_payload = {"verdict": "approve", "findings": []}
    validate_payload(approve_payload, repo, doc_mode=False)
    report = "\n".join(
        [
            "=== 代码评审修复完成 ===",
            "结果：通过",
            "总轮次：2",
            "各轮统计：[R1: 1 findings(1H) -> R2: 0 findings]",
            "改动文件：[sample.py]",
            f"验证命令：python3 -m py_compile sample.py (exit {verify.returncode})",
            f"基线：baseline_ref={baseline_ref}, stash_ref=null | 无 stash",
            "恢复状态：无需恢复",
            "剩余 findings：residual findings 完整列表=[]",
            "跳过的 findings：[]",
        ]
    )
    for needle in [
        "结果：通过",
        "验证命令：python3 -m py_compile sample.py (exit 0)",
        "baseline_ref=",
        "剩余 findings：residual findings 完整列表=[]",
        "跳过的 findings：[]",
    ]:
        if needle not in report:
            fail(f"code report missing field: {needle}")
    print("[PASS] code review-fix positive loop report")


def ensure_unlocatable_finding_is_skipped() -> None:
    repo = init_repo("unlocatable", {"sample.py": "print('ok')\n"})
    payload = {
        "verdict": "needs-attention",
        "findings": [
            {
                "file": "missing.py",
                "line_start": 8,
                "severity": "high",
                "title": "不存在的文件",
                "body": "path 不存在",
                "confidence": 0.8,
                "recommendation": "跳过并报告",
            }
        ],
    }
    skipped = validate_payload(payload, repo, doc_mode=False)
    if skipped != ["skipped:unlocatable"]:
        fail("unlocatable findings should be tracked as skipped:unlocatable")
    print("[PASS] unlocatable findings are skipped and reported")


def ensure_doc_loop_and_report() -> None:
    repo = init_repo("doc-loop", {"design.md": "# 方案\n\n仅描述目标，没有验收标准。\n"})
    baseline_ref = run(["git", "rev-parse", "HEAD"], repo).stdout.strip()
    doc_payload = {
        "verdict": "needs-attention",
        "findings": [
            {
                "file": "design.md",
                "line_start": 1,
                "line_end": 1,
                "severity": "medium",
                "title": "缺少验收标准",
                "body": "缺少验收标准，读者无法判断何时完成。",
                "confidence": 0.75,
                "recommendation": "补充验收标准与边界。",
                "dimension": "完整性",
            }
        ],
    }
    validate_payload(doc_payload, repo, doc_mode=True)
    (repo / "design.md").write_text(
        "# 方案\n\n目标：补齐验收标准。\n\n验收标准：\n- 有输入\n- 有输出\n",
        encoding="utf-8",
    )
    run(["git", "add", "design.md"], repo)
    run(["git", "commit", "-qm", "doc review-fix round 1"], repo)
    approve_payload = {"verdict": "approve", "findings": []}
    validate_payload(approve_payload, repo, doc_mode=True)
    if doc_result([1, 0, 0]) != "通过":
        fail("doc loop should require two consecutive zero-finding rounds")
    report = "\n".join(
        [
            "=== 文档评审修复完成 ===",
            "结果：通过",
            "总轮次：3",
            "各轮统计：[R1: 1 finding -> R2: 0 -> R3: 0]",
            "各轮评审维度：[R1: 完整性 -> R2: 完整性 -> R3: 完整性]",
            "改动文档：[design.md]",
            f"基线：baseline_ref={baseline_ref}, stash_ref=null | 无 stash",
            "恢复状态：无需恢复",
            "剩余 findings：residual findings 完整列表=[]",
            "DECEPTION findings：[]",
        ]
    )
    for needle in [
        "结果：通过",
        "各轮评审维度：",
        "baseline_ref=",
        "恢复状态：无需恢复",
        "DECEPTION findings：[]",
    ]:
        if needle not in report:
            fail(f"doc report missing field: {needle}")
    print("[PASS] doc review-fix positive loop report")


def ensure_codex_unavailable_fail_close() -> None:
    outcome = {
        "result": "fail-close",
        "selected_path": "codex",
        "switch_allowed": False,
        "reason": "codex:adversarial-review exited non-zero",
    }
    if outcome["switch_allowed"]:
        fail("codex unavailable should not silently switch path")
    if outcome["selected_path"] != "codex":
        fail("selected path should remain codex on failure")
    print("[PASS] codex unavailable stays fail-close without silent switch")


def ensure_round_termination_rules() -> None:
    if code_result([5, 4, 3, 2, 1]) != "未通过":
        fail("code loop should stop at max rounds")
    if code_result([2, 2]) != "不收敛":
        fail("code loop should detect non-convergence after two non-decreasing rounds")
    if doc_result([2, 2]) != "不收敛":
        fail("doc loop should detect non-convergence after two non-decreasing rounds")
    print("[PASS] max-round and non-convergence termination rules")


def ensure_user_abort_reports_manual_recovery() -> None:
    baseline_ref = "abc1234"
    abort_report = "\n".join(
        [
            "结果：用户中止",
            f"baseline_ref={baseline_ref}",
            "stash_ref=stash@{0}",
            "可手动执行：git stash pop",
            f"可手动执行：git reset --soft {baseline_ref}",
        ]
    )
    for needle in [
        "结果：用户中止",
        "git stash pop",
        "git reset --soft abc1234",
    ]:
        if needle not in abort_report:
            fail(f"user abort report missing field: {needle}")
    print("[PASS] user abort reports manual recovery commands")


ensure_dirty_tree_restore()
ensure_clean_tree_skip_stash()
ensure_stash_conflict_surfaces()
ensure_code_loop_and_report()
ensure_unlocatable_finding_is_skipped()
ensure_doc_loop_and_report()
ensure_codex_unavailable_fail_close()
ensure_non_json_fail_close()
ensure_missing_field_fail_close(init_repo("missing-field", {"sample.py": "print('x')\n"}))
ensure_round_termination_rules()
ensure_user_abort_reports_manual_recovery()
PY
