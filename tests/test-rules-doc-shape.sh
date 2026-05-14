#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

python3 - "$ROOT" <<'PY' || fail "rules doc shape contract violated"
from __future__ import annotations

import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
rules_dir = root / "shared" / "rules"


def read(name: str) -> str:
    return (rules_dir / name).read_text(encoding="utf-8")


def require(text: str, needle: str, file_name: str) -> None:
    if needle not in text:
        raise SystemExit(f"{file_name} missing required anchor: {needle}")


def section_body(text: str, title: str, file_name: str) -> str:
    pattern = re.compile(
        rf"^##+ {re.escape(title)}\n(?P<body>.*?)(?=^##+ |\Z)",
        re.M | re.S,
    )
    match = pattern.search(text)
    if not match:
        raise SystemExit(f"{file_name} missing section: {title}")
    return match.group("body")


def require_markers(text: str, file_name: str, title: str, markers: list[str]) -> None:
    body = section_body(text, title, file_name)
    positions = []
    for marker in markers:
        index = body.find(marker)
        if index == -1:
            raise SystemExit(f"{file_name} {title} missing marker: {marker}")
        positions.append(index)
    if positions != sorted(positions):
        raise SystemExit(f"{file_name} {title} markers are out of order")
    if not re.search(r"必须|禁止|不得|只有|先.+再", body):
        raise SystemExit(f"{file_name} {title} lacks hard modal wording")


def require_not_softened(text: str, file_name: str, anchor: str) -> None:
    paragraphs = re.split(r"\n\s*\n", text)
    soft_words = ["建议", "尽量", "最好", "可以考虑", "原则上", "通常"]
    for paragraph in paragraphs:
        if anchor in paragraph:
            for word in soft_words:
                if word in paragraph:
                    raise SystemExit(
                        f"{file_name} anchor softened by {word}: {anchor}"
                    )
            return
    raise SystemExit(f"{file_name} missing required anchor: {anchor}")


def require_runtime_links(text: str, file_name: str) -> None:
    forbidden = ["$HOME/.codex", "$HOME/.claude", ".codex/", ".claude/"]
    for value in forbidden:
        if value in text:
            raise SystemExit(f"{file_name} uses non-runtime-home link: {value}")


def require_delivery_why(text: str, file_name: str) -> None:
    section_pattern = re.compile(
        r"^##+ (?P<title>.+?)\n(?P<body>.*?)(?=^##+ |\Z)",
        re.M | re.S,
    )
    blocked = [
        "模型容易",
        "导致",
        "污染",
        "藏起来",
        "假装",
        "错觉",
        "报警",
        "沉默风险",
        "不可追踪",
        "误导",
        "失控",
        "泄露",
        "偷改",
        "不是禁止",
        "团队才共享",
        "用户真正要",
    ]
    delivery_words = [
        "做对",
        "做到",
        "真实可交付",
        "可交付",
        "真实成立",
        "成立",
        "可验收",
        "可复验",
        "真实可用",
        "可接手",
        "可维护",
    ]
    correctness_words = [
        "才算",
        "程度",
        "标准",
        "证据",
        "边界",
        "状态",
        "结果",
        "路径",
    ]
    for match in section_pattern.finditer(text):
        body = match.group("body")
        why_match = re.search(
            r"Why：(?P<why>.*?)(?=\n\n核心思路：|\n\n常见坑：|\Z)",
            body,
            re.S,
        )
        if not why_match:
            continue
        why = " ".join(why_match.group("why").split())
        for word in blocked:
            if word in why:
                raise SystemExit(
                    f"{file_name} {match.group('title')} Why is risk-framed by {word}: {why}"
                )
        if not any(word in why for word in delivery_words):
            raise SystemExit(
                f"{file_name} {match.group('title')} Why lacks delivery/correctness framing: {why}"
            )
        if not any(word in why for word in correctness_words):
            raise SystemExit(
                f"{file_name} {match.group('title')} Why does not say what counts as right: {why}"
            )


iron = read("铁律.md")
require_runtime_links(iron, "铁律.md")
require_delivery_why(iron, "铁律.md")
if len(iron.splitlines()) > 70:
    raise SystemExit(f"铁律.md too verbose: {len(iron.splitlines())} lines > 70")
for title in [
    "禁止静默降级",
    "禁止伪造验收",
    "禁止绕过失败测试",
    "完成必须有证据",
    "明确状态与不确定性",
]:
    require_markers(iron, "铁律.md", title, ["Why：", "核心思路：", "常见坑："])
for anchor in [
    "同一方案、同一成功标准、同一验证口径",
    "Mock",
    "skip",
    "xfail",
    "先实现再补测试",
    "必须停止交付推进并报告用户裁决",
    "不能替代真实验收",
    "亲眼看到当前工作区的验证命令成功输出",
    "{{RUNTIME_HOME}}/reference/完成前验证.md",
    "{{RUNTIME_HOME}}/rules/代码规范.md",
]:
    require(iron, anchor, "铁律.md")
for anchor in ["必须停止交付推进并报告用户裁决", "不能替代真实验收"]:
    require_not_softened(iron, "铁律.md", anchor)
for legacy in ["## 零容忍行为", "## 常见绕过借口"]:
    if legacy in iron:
        raise SystemExit(f"铁律.md legacy bucket should be removed: {legacy}")


execution = read("执行纪律.md")
require_runtime_links(execution, "执行纪律.md")
require_delivery_why(execution, "执行纪律.md")
for title in ["目标驱动", "既有约束优先", "流程纪律", "范围纪律"]:
    require_markers(execution, "执行纪律.md", title, ["Why：", "核心思路：", "常见坑："])
for anchor in [
    "目标、操作对象、预期结果和成功标准",
    "无副作用的采证",
    "既有模式相互冲突",
    "workflow/contract",
    "{{RUNTIME_HOME}}/rules/铁律.md",
    "只处理本次目标边界内的问题",
]:
    require(execution, anchor, "执行纪律.md")
for anchor in ["workflow/contract", "只处理本次目标边界内的问题"]:
    require_not_softened(execution, "执行纪律.md", anchor)


docs = read("文档管理.md")
require_runtime_links(docs, "文档管理.md")
require_delivery_why(docs, "文档管理.md")
for title in ["命名", "同步", "归档", "活跃需求接手", "设计文档"]:
    require_markers(docs, "文档管理.md", title, ["Why：", "核心思路："])
for anchor in [
    "docs/feature--doc-governance--context-recovery",
    "contracts/active-doc-scope.yaml",
    "docs/archive/",
    "runtime files",
    "canonical JSON",
    "legacy",
    "archive_ref",
    "archived_at",
    "validate_context_contract.py",
    "recover_context.py",
    "只记录“是什么”和“为什么”",
]:
    require(docs, anchor, "文档管理.md")
for anchor in ["docs/archive/", "canonical JSON"]:
    require_not_softened(docs, "文档管理.md", anchor)


code = read("代码规范.md")
require_runtime_links(code, "代码规范.md")
require_delivery_why(code, "代码规范.md")
for title in [
    "复杂度约束",
    "注释规范",
    "错误处理规范",
    "硬编码规范",
    "死代码规范",
    "性能约束",
    "门禁落地原则",
    "复用治理规范",
]:
    require_markers(code, "代码规范.md", title, ["Why：", "核心思路："])
for anchor in [
    "函数循环复杂度（CC）<= 10",
    "文件 <= 400 行",
    "禁止空 catch 块、禁止裸 except",
    "所有外部调用（API/DB/文件 IO）必须有超时和错误处理",
    "禁止硬编码密钥/Token/密码/Secret",
    "任何缓存引入必须经用户明确同意",
    "禁止以配置名义放宽 MUST 语义",
    "新增实现前，必须先判断是否已有语义一致的候选实现",
    "最终选择不复用而新建实现时，必须在代码注释、设计文档或 PR 描述中说明原因",
]:
    require(code, anchor, "代码规范.md")
for anchor in [
    "函数循环复杂度（CC）<= 10",
    "文件 <= 400 行",
    "所有外部调用（API/DB/文件 IO）必须有超时和错误处理",
    "任何缓存引入必须经用户明确同意",
]:
    require_not_softened(code, "代码规范.md", anchor)
PY

echo "[PASS] rules doc shape"
