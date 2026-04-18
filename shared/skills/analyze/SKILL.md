---
name: analyze
user-invocable: true
description: 全链路一致性检查。Use when 需要检测 PRD→Design→Plan→Test-Cases 的跨工件漂移、遗漏和矛盾。
argument-hint: "[feature-name]"
allowed-tools: Read, Glob, Grep, Bash
---

# /analyze -- 全链路一致性检查

> ultrathink

## HARD-GATE

1. NO analysis without ALL available artifacts in docs/{feature}/ being read.
2. NO issue reported without file_path + specific content evidence.
3. NO PASS verdict when any CRITICAL issue exists.

## 角色

你是只读的全链路一致性审查员。你不修改任何文件，只检测 PRD → Design → Plan → Test-Cases 的漂移、遗漏和矛盾，输出分级报告。

## 前置条件

`docs/{feature}/` 目录必须存在。

缺少标准工件时进入 `partial` 模式：分析已存在工件，并在概览列出 `blocked/skipped` 层级与原因。

只有目录不存在，或目录内没有可识别工件（brief/prd/design/plan/tasks/test-cases/qa-report/acceptance-summary/fix-*），才输出 BLOCKED 并停止。

## 检测维度

当执行逐层检测时：
→ 读取 `references/check-matrix.md` 获取 L1（PRD→Design 5项）、L2（Design→Plan 4项）、L3（PRD→Plan 端到端追踪4项）、L4（Plan→TestCases 2项）、L5（全局术语/范围/版本/边界一致性4项）、L6（跨阶段一致性）

仅对已存在的工件对执行对应层级检测；`docs/constitution.md` 存在时纳入 L1 / L5。

## 流程

1. 扫描工件 — 先执行 `bash {{RUNTIME_HOME}}/skills/analyze/scripts/extract-artifacts.sh docs/{feature}/` 获取结构化数据，再读取 `docs/{feature}/` 下所有文件（含 `phase-{N}/unit-{N}/` 子目录），识别工件类型（brief/prd/design/plan/tasks/test-cases/qa-report/acceptance-summary/fix-*）和结构（根目录轻量包或 `phase-{N}/unit-{N}/`）。
2. 校验脚本结果 — 与实际文件扫描交叉核对；若矩阵为空、覆盖状态冲突，或未识别 `T1/T2`、`Task 1`、勾选式 AC，标为 `tool_warning`，继续人工追踪。
3. 逐层检测 — 按 `references/check-matrix.md` 执行 L1-L6。L1-L4 只在对应工件对存在时执行；缺上游或下游工件时标记 `skipped`。用户点名但关键工件缺失时标记 `blocked` 并给出缺失证据。根目录轻量包按单个分析单元处理。
4. 证据收集 — 每个问题必须引用具体文件路径和内容片段；缺失工件的 `blocked/skipped` 也必须有文件清单或缺失事实。
5. 分级判定 — CRITICAL（阻塞下游）/ WARNING（可能导致问题）/ INFO（建议改进）。缺失关键上游时输出 PARTIAL 或 BLOCKED，不得输出 PASS。
6. 输出报告 — 生成结构化报告。

## 输出

报告模板：`references/templates/consistency-report-template.md`（必填：概览含工件存在性和检测结果计数、CRITICAL/WARNING/INFO分级问题表含层级+检查项+证据、UNIT追踪矩阵含各工件覆盖率）

输出必须包含概览、分级问题表和 UNIT 追踪矩阵。

`partial` 模式概览必须额外包含：
- `mode`: `partial`
- `blocked`: 用户点名但因关键工件缺失无法判定的检查项
- `skipped`: 因工件对不存在而不适用的 L1-L6 层级
- `tool_warning`: 脚本抽取与实际文件扫描不一致时的说明

没有标准 UNIT 时，改用 `Task/AC-like` 追踪矩阵并说明原因；禁止用空矩阵替代追踪结论。

## 完成校验

- [ ] docs/{feature}/ 下所有文件已读取
- [ ] 每个问题有文件路径 + 内容证据
- [ ] 缺失工件已标记 blocked/skipped，且未误报 PASS
- [ ] 脚本输出已和实际文件扫描交叉核对
- [ ] CRITICAL/WARNING/INFO 分级正确
- [ ] 追踪矩阵覆盖所有 UNIT；无标准 UNIT 时覆盖 Task/AC-like
- [ ] 无 CRITICAL 且无 blocked 时才可报告 PASS
