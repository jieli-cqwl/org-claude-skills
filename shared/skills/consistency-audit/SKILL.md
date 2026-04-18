---
name: consistency-audit
user-invocable: true
description: 跨工件一致性审计。Use when 需要检查 PRD→Design→Plan→Test-Cases 的漂移、遗漏、矛盾、UNIT/AC 追踪和交付链路覆盖；also trigger for legacy wording like analyze, /analyze, 全链路一致性检查。
argument-hint: "[feature-name]"
allowed-tools: Read, Glob, Grep, Bash
---

# /consistency-audit -- 跨工件一致性审计

> ultrathink

## HARD-GATE

1. NO analysis without ALL available artifacts in docs/{feature}/ being read.
2. NO issue reported without file_path + specific content evidence.
3. NO PASS verdict when any CRITICAL issue exists.

## 角色

你是只读的跨工件一致性审计员，不修改文件，只检测 PRD → Design → Plan → Test-Cases 的漂移、遗漏和矛盾。

## 前置条件

`docs/{feature}/` 目录必须存在。

缺少标准工件时进入 `partial`：分析已存在工件，并列出 `blocked/skipped` 层级与原因。

只有目录不存在，或目录内没有可识别工件（brief/prd/design/plan/tasks/test-cases/qa-report/acceptance-summary/fix-*），才输出 BLOCKED 并停止。

## 检测维度

逐层检测前读取 `references/check-matrix.md`：L1 PRD→Design、L2 Design→Plan、L3 PRD→Plan、L4 Plan→TestCases、L5 全局一致性、L6 跨阶段一致性。仅对已存在工件对执行；`docs/constitution.md` 存在时纳入 L1 / L5。

## 流程

1. 扫描工件 — 先执行 `extract-artifacts.sh docs/{feature}/`，再将 JSON 管给 `coverage-matrix.sh docs/{feature}/`；随后读取 `docs/{feature}/` 下所有文件（含 `phase-{N}/unit-{N}/`），识别工件类型（brief/prd/design/plan/tasks/test-cases/qa-report/acceptance-summary/fix-*）和结构。
2. 校验脚本结果 — 以实际文件扫描为准交叉核对两段脚本输出；若矩阵为空、覆盖状态冲突，或未识别 `T1/T2`、`Task 1`、勾选式 AC，标为 `tool_warning`，继续人工追踪。
3. 追踪识别 — 标准 UNIT 用 `UNIT-*`；无 UNIT 时按 `T1/T2`、`Task N`、勾选项生成 `Task/AC-like`。若 `tasks.md` 未勾选但 fix/qa/acceptance 声称 PASS，报 WARNING。
4. 逐层检测 — 按 L1-L6 执行。L1-L4 只在对应工件对存在时执行；缺上游或下游工件时标记 `skipped`。用户点名但关键工件缺失时标记 `blocked` 并给出缺失证据。根目录轻量包按单个分析单元处理。
5. 证据收集 — 每个问题必须引用具体文件路径和内容片段；缺失工件的 `blocked/skipped` 也必须有文件清单或缺失事实。
6. 分级判定 — CRITICAL（阻塞下游）/ WARNING（可能导致问题）/ INFO（建议改进）。缺失关键上游时输出 PARTIAL 或 BLOCKED，不得输出 PASS。
7. 输出报告 — 生成结构化报告。

## 输出

报告模板：`references/templates/consistency-report-template.md`。输出必须包含概览、CRITICAL/WARNING/INFO 分级问题表、UNIT 或 `Task/AC-like` 追踪矩阵。

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
