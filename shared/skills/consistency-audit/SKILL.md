---
name: consistency-audit
user-invocable: true
description: 跨工件一致性审计。Use when 需要只读检查 canonical JSON 交付工件之间的漂移、遗漏、矛盾、UNIT/AC/Task/test_ref 追踪和交付链路覆盖，或用户要求全链路一致性检查。
eval-type: mixed
argument-hint: "[feature-name]"
allowed-tools: Read, Glob, Grep, Bash
---

# /consistency-audit -- 跨工件一致性审计

> ultrathink

Goal: 只读审计 `docs/{feature}/` 下 canonical JSON 工件之间的追踪、一致性、漂移和缺口。Completion boundary: 产出 advisory-only `consistency-audit-result.json`，列出 PASS/PARTIAL/BLOCKED、L1-L6 层级、问题证据、owner action 和 blocked/skipped/tool_warning，不做 gate、签收、风险接受或计划冻结裁决。

## HARD-GATE

1. NO analysis without ALL available canonical artifacts in docs/{feature}/ being read.
2. NO issue reported without file_path + specific content evidence.
3. NO PASS verdict when any CRITICAL issue or blocked layer exists.
4. NO gate, sign-off, risk acceptance, or plan freeze decision from this skill.

## 角色

你是只读的跨工件一致性审计员，不修改文件，只检测 canonical 交付工件之间的漂移、遗漏和矛盾。

你可以作为旁路专家 agent 被 `tech-lead` 或 `delivery-owner` 调度，但输出只能是 advisory evidence：

- 不替代 `product-manager / design / test-design / tech-lead` 的 owner 裁决。
- 不替代 `review / qa` 的质量结论。
- 不新增交付 gate、sign-off、风险接受或放行结论。

## 前置条件

`docs/{feature}/` 目录必须存在。

读取 canonical JSON 工件：

- `brief.json`
- `phase-{N}/phase-prd.json`
- `phase-{N}/units/UNIT-*.json`
- `phase-{N}/design.json`
- `phase-{N}/plan.json`
- `phase-{N}/tasks.json`
- `phase-{N}/artifact-registry.json`
- `phase-{N}/unit-{N}/test-cases.json`
- 已存在的 runtime 工件：`developer-report.json / verify-result.json / code-review-result.json / qa-result.json / delivery-state.json / signoff-package.json`

缺少标准工件时进入 `partial`：分析已存在工件，并列出 `blocked/skipped` 层级与原因。

只有目录不存在，或目录内没有可识别工件（brief/phase-prd/unit/design/plan/tasks/artifact-registry/test-cases/runtime artifacts），才输出 BLOCKED 并停止。

## 检测维度

逐层检测前读取检查矩阵资源：Trigger: 执行 L1-L6 审计；Read: `references/check-matrix.md`；Expect: L1 brief/phase-prd/UNIT→design、L2 design→plan/tasks、L3 requirement→plan/tasks、L4 plan/tasks→test-cases、L5 全局一致性、L6 跨阶段一致性；Consume: `consistency-audit-result.json.layers[] / findings[] / trace_matrix`；Evidence: 每个问题引用 file_path、内容片段、层级和 owner action；Sync: 更新审计模板、validator 和 fixtures。L4 必须检查 `traceability_matrix`、`test_cases[].product_refs / design_refs / assertion_target`、typed gap、`qa_handoff_contract` 与 `cross_unit_obligations`；缺 product refs、design refs 或 assertion_target 视为 CRITICAL。仅对已存在工件对执行；`docs/constitution.md` 存在时纳入 L1 / L5。

## 流程

状态表：

| 状态 | 动作 | 停止/转移 |
| --- | --- | --- |
| Discover | 扫描 `docs/{feature}/` 与 active artifact registry | 目录不存在或无可识别工件则 BLOCKED |
| Extract | 运行抽取脚本并交叉核对实际 JSON | 脚本冲突标 `tool_warning`，继续人工追踪 |
| Trace | 建立 UNIT 或 Task/AC-like 追踪矩阵 | 关键工件缺失则标 blocked/skipped |
| Layer Audit | 按 L1-L6 逐层检测并收集证据 | CRITICAL 或 blocked 时不得输出 PASS |
| Report | 写 advisory-only 报告 | 缺 file_path、内容证据或 owner action 则回到 Layer Audit |

流程产物合同：每一步 output 都必须被下一步或调用方 consumer 消费，并满足 acceptance、failure_state、proof。任何缺失工件、工具冲突或证据不足都要落到 blocked/skipped/tool_warning，而不是静默通过。

1. 扫描工件 — 先执行 `extract-artifacts.sh docs/{feature}/`，再将 JSON 管给 `coverage-matrix.sh docs/{feature}/`；随后读取 `docs/{feature}/` 下所有 canonical JSON 文件（含 active `artifact-registry.json`、`phase-{N}/units/`、`phase-{N}/unit-{N}/` 和 runtime artifacts），以 active revision entries 作为当前可消费工件集合真源。
2. 校验脚本结果 — 以实际 JSON 文件扫描为准交叉核对两段脚本输出；若矩阵为空、覆盖状态冲突，或漏识别 JSON 中的 UNIT/Task/AC，标为 `tool_warning`，继续人工追踪。
3. 追踪识别 — 标准 UNIT 用 `UNIT-*`；无 UNIT 时按 `tasks.json` 和 `test-cases.json` 生成 `Task/AC-like` 追踪矩阵。
4. 逐层检测 — 按 L1-L6 执行。L1-L4 只在对应工件对存在时执行；缺上游或下游工件时标记 `skipped`。用户点名但关键工件缺失时标记 `blocked` 并给出缺失证据。
5. 证据收集 — 每个问题必须引用具体文件路径和内容片段；缺失工件的 `blocked/skipped` 也必须有文件清单或缺失事实。
6. 分级判定 — CRITICAL（阻塞下游）/ WARNING（可能导致问题）/ INFO（建议改进）。缺失关键上游时输出 PARTIAL 或 BLOCKED，不得输出 PASS。
7. 输出报告 — 生成 `consistency-audit-result.json`；Markdown 报告仅作为人类投影视图。

## 输出

运行时模板：`shared/skills/consistency-audit/templates/consistency-audit-result.template.json`。人类投影视图模板：`projections/consistency-report-template.md`。

输出必须包含概览、CRITICAL/WARNING/INFO 分级问题表、UNIT 或 `Task/AC-like` 追踪矩阵。

作为 subagent 返回时，报告必须额外写明：
- `decision_authority: advisory_only`
- `consumer`: 调用方（如 `tech-lead` 或 `delivery-owner`）
- `blocked_layers / skipped_layers / tool_warning`
- `required_owner_action`: 需要哪个 owner 决策或修复，不得写成审计 agent 已裁决

`partial` 模式概览必须额外包含：
- `mode`: `partial`
- `blocked`: 用户点名但因关键工件缺失无法判定的检查项
- `skipped`: 因工件对不存在而不适用的 L1-L6 层级
- `tool_warning`: 脚本抽取与实际文件扫描不一致时的说明

没有标准 UNIT 时，改用 `Task/AC-like` 追踪矩阵并说明原因；禁止用空矩阵替代追踪结论。

## 完成校验

- [ ] docs/{feature}/ 下所有 canonical JSON 工件已读取
- [ ] 每个问题有文件路径 + 内容证据
- [ ] 缺失工件已标记 blocked/skipped，且未误报 PASS
- [ ] 脚本输出已和实际文件扫描交叉核对
- [ ] CRITICAL/WARNING/INFO 分级正确
- [ ] 追踪矩阵覆盖所有 UNIT；无标准 UNIT 时覆盖 Task/AC-like
- [ ] L4 已核对 product/design/test traceability、typed gap、QA handoff 和 cross-unit obligations
- [ ] 无 CRITICAL 且无 blocked 时才可报告 PASS
- [ ] 报告未替代 gate、sign-off、风险接受、计划冻结或质量结论

## Context Handoff Contract

- scope registry 是 `contracts/active-doc-scope.yaml`；audit 可报告 context 漂移风险，但不更新 registry 或 `worklog.md`。
- standard-chain 的 `worklog.md.state_ref / next_ref` 必须使用 `canonical:` active artifact ref，审计时以 active `artifact-registry.json` 解析结果为准。
- audit 只报告长期 blocked、过期 waiver、supporting 滥用和 legacy 漂移，不判断进度完成。
