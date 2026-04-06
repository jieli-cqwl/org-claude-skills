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

`docs/{feature}/` 目录必须存在，且至少包含 `prd.md`。

## 检测维度

当执行逐层检测时：
→ 读取 `references/check-matrix.md` 获取 L1（PRD→Design 5项）、L2（Design→Plan 4项）、L3（PRD→Plan 端到端追踪4项）、L4（Plan→TestCases 2项）、L5（全局术语/范围/版本/边界一致性4项）、L6（跨阶段一致性）

仅对已存在的工件对执行对应层级检测；`docs/constitution.md` 存在时纳入 L1 / L5。

## 流程

1. 扫描工件 — 先执行 `bash {{RUNTIME_HOME}}/skills/analyze/scripts/extract-artifacts.sh docs/{feature}/` 获取结构化数据，再读取 `docs/{feature}/` 下所有文件（含 `phase-{N}/unit-{N}/` 子目录），识别存在的工件类型（prd/design/plan/test-cases）和目录结构（`phase-{N}/unit-{N}/`）。
2. 逐层检测 — 按 `references/check-matrix.md`（同上）执行 L1-L5，对相邻工件和端到端追踪逐项检查。L1-L4 在每个 `phase-{N}/unit-{N}/` 内执行，L5 + L6 做跨阶段一致性检查。
3. 证据收集 — 每个问题必须引用具体文件路径和内容片段作为证据。
4. 分级判定 — 按严重程度分级：CRITICAL（阻塞下游）/ WARNING（可能导致问题）/ INFO（建议改进）。
5. 输出报告 — 生成结构化报告。

## 输出

报告模板：`references/templates/consistency-report-template.md`（必填：概览含工件存在性和检测结果计数、CRITICAL/WARNING/INFO分级问题表含层级+检查项+证据、UNIT追踪矩阵含各工件覆盖率）

输出必须包含概览、分级问题表和 UNIT 追踪矩阵。

## 完成校验

- [ ] docs/{feature}/ 下所有文件已读取
- [ ] 每个问题有文件路径 + 内容证据
- [ ] CRITICAL/WARNING/INFO 分级正确
- [ ] 追踪矩阵覆盖所有 UNIT
- [ ] 无 CRITICAL 问题时报告结论为 PASS
