# 派发与修复指南

> 引用者：delivery-owner SKILL.md Phase 2

Trigger: Use when delivery-owner dispatches Phase 2 work, reviews Task status, handles drift, or coordinates developer/verifier/fixer loops.
Read: `plan.json`, `tasks.json`, `design.json`, `developer-report.json`, `verify-result.json`, current `delivery-state.json`, and active Task file scope.
Expect: Dispatch prompts carry complete scope, evidence refs, constraints, SubAgent input/output contracts, drift controls, and replan recovery fields.
Consume: Developer, verifier, fixer, `delivery-state.json`, and delivery-owner merge/readiness decisions consume this guide.
Evidence: `tests/test-delivery-owner-phase3-contract.sh`, `tests/test-delivery-owner-replay-contract.sh`, and rollout gate tests assert the fields this guide defines.
Sync: Update this file with `SKILL.md` Phase 2, `dev-report-template.md`, `plan-template.md`, and completion gate runtime checks.

## 派发 prompt 质量要点

| 要素 | 必须包含 | 常见遗漏 |
|------|---------|---------|
| 上下文 | design_ref 中的模块职责和接口约束 | 只给 AC 不给设计上下文，developer 自行理解导致偏差 |
| 文件范围 | 所有待修改/新建文件路径 + 现有文件的当前作用 | 只给文件名不说明当前内容，developer 需自行探索 |
| AC | 逐条列出，包含输入→输出格式 | 只给标题级 AC，缺少具体断言 |
| 约束 | 不可修改的文件、必须兼容的现有接口 | 未声明边界，developer 越界修改 |
| test_ref | 对应的测试用例编号及预期测试策略 | 遗漏 test_ref 导致 developer 自行决定测试范围 |

## SubAgent Handoff 合同

输入字段：

| task | scope | input_refs | required_context | excluded_context | allowed_tools | expected_output | acceptance_basis |
|------|-------|------------|------------------|------------------|---------------|-----------------|------------------|
| developer | Task ID + file scope | plan/task/design/test-case refs | AC、接口约束、真实依赖、TDD 要求 | 未冻结草稿、边界外文件、用户未确认范围 | Task 所需读写与测试工具 | developer-report.json + RED/GREEN 证据 + proving output | Task AC + test_ref + plan scope |
| verifier | Task ID + verification phase | developer-report.json + changed files | SPEC/2A/2B/2C 检查口径 | 新需求、未声明重构、验收外假设 | Read/Grep/Bash 测试命令 | verify-result.json + ISSUE/OK 结论 | plan AC + Skill 质量门禁 |
| fixer | issue id + allowed files | review/qa/fix evidence refs | 根因、失败轮次、上一轮方案 | 未关联问题、边界外文件 | 最小修复工具 | fix evidence + rerun command output | issue close criteria + regression scope |

输出字段：

| scope | consumer | evidence | uncertainty | blockers | output_contract | acceptance_basis | decision_required | next_step |
|-------|----------|----------|-------------|----------|-----------------|------------------|-------------------|-----------|
| Task execution | delivery-owner | RED/GREEN、proving output、changed files | 未覆盖边界、Mock 边界、环境限制 | BLOCKED/ISSUE 列表 | developer-report.json | Task AC + test_ref | 是否进入 verifier 或修复 | verify / fix / block |
| Task verification | delivery-owner | SPEC/2A/2B/2C 结果与命令输出 | 证据缺口、复现限制 | ISSUE 列表 | verify-result.json | Skill DoD + plan scope | 是否回 developer/fix | continue / fix / block |
| Review/QA fix | review 或 qa | issue close evidence + regression command | 剩余风险、影响面扩展 | 未关闭 issue | fix artifact + updated reports | issue close criteria | 是否重跑对应门禁 | rerun gate / escalate |

## Delivery Kickoff 包

派发前必须先确认：`scope_freeze`、共享文件、真实依赖、`preflight-evidence`、risk owner、QA handoff readiness、回退路径。
缺任一项都不能进入 developer 派发；需要由 `delivery-owner` 先补齐或暂停升级。

## 运行态协议

| 字段 | Producer | 刷新时机 | 过期判定 | 说明 |
|------|----------|----------|----------|------|
| `last_observed_at` | `delivery-owner` | 每次派发、接手、升级、进入签收前 | 早于最近一次 proving / 全量测试 / fix 工件即视为 stale | 当前判断对应的最新观察时间 |
| `runtime_snapshot` | `delivery-owner` | 每次状态变化后刷新 | 与当前 Task / 门禁状态不一致即视为 stale | 用一句话说明当前执行态、门禁态和风险态 |
| `active_blocker` | `delivery-owner` | 出现或解除阻塞时刷新 | 已解除但仍保留旧阻塞即视为 stale | 没有阻塞时必须显式写 `无` |
| `blocker_owner` | `delivery-owner` | `active_blocker` 变化时同步刷新 | 阻塞 owner 与当前阻塞不一致即视为 stale | 仅在存在阻塞时填写真实 owner；无阻塞时写 `无` |
| `takeover_note` | `delivery-owner` | 主 Agent 接手、转交、升级时刷新 | 动作变化但备注未更新即视为 stale | 说明当前由谁跟进、为什么接手、下一步是什么 |
| `decision_basis` | `delivery-owner` | 每次裁决 `CONTINUE / ESCALATE / REPLAN / BLOCK` 或进入签收前刷新 | 不能回链到当前锚点证据即视为 stale | 至少包含一个当前锚点引用，解释为什么做出当前判断 |

## 编排协议

| 字段 | Producer | 刷新时机 | 过期判定 | 说明 |
|------|----------|----------|----------|------|
| `dispatch_mode` | `delivery-owner` | 确认串行/并行/探索批次时 | 实际执行模式变化但字段未更新即视为 stale | 只允许 `SERIAL / PARALLEL / EXPLORE_BATCH` |
| `current_batch` | `delivery-owner` | 切换批次、切回串行、进入探索批次时 | 当前活跃批次变化但字段未更新即视为 stale | 串行写 `SERIAL`，并行写 `Batch-N`，探索批次写 `Explore-Batch-N` |
| `batch_unlock_condition` | `delivery-owner` | 派发当前批次时 | 解锁条件变化但字段未更新即视为 stale | 说明当前批次何时可以解锁下一步 |
| `merge_readiness` | `delivery-owner` | 批次完成度或共享文件冲突状态变化时 | merge 状态变化但字段未更新即视为 stale | 只允许 `READY / PENDING / BLOCKED` |
| `next_action` | `delivery-owner` | 每次控制动作变化时 | 下一动作与门禁/批次状态不一致即视为 stale | 只允许 `REQUEST_REVIEW / WAIT_BATCH / ESCALATE / REPLAN_REQUEST / HOLD` |
| `plan_version_ref` | `delivery-owner` | kickoff 完成、replan 生效后 | 指向的版本不是当前消费版本即视为 stale | 必须引用当前消费的 `artifact://plan/{feature}.phase-{N}.plan@plan-vX#plan-version` |
| `plan_version_value` | `delivery-owner` | kickoff 完成、replan 生效后 | 与当前消费 plan artifact 的 `plan_version` 不一致即视为 stale | 必须显式写出当前消费版本，如 `v1 / v2` |

## REPLAN 恢复协议

当 `control_action=REPLAN` 时，执行记录必须补齐以下字段，缺任一项都不得继续派发或复用旧结论：

| 字段 | Producer | 说明 |
|------|----------|------|
| `replan_request` | `delivery-owner` | 指向触发 replan 的请求或修订记录锚点 |
| `batch_freeze_reason` | `delivery-owner` | 说明当前 batch 为什么必须冻结 |
| `unlock_resolution` | `delivery-owner` | 说明重新解锁后当前允许继续的批次/范围 |
| `plan_version_ref` | `delivery-owner / qa / verify` | 必须切到新的 `artifact://plan/{feature}.phase-{N}.plan@plan-vX#plan-version`；旧版本不得继续作为消费基线 |
| `plan_version_value` | `delivery-owner / qa / verify` | 必须与当前消费 plan artifact 的 `plan_version` 一致；旧值不得继续保留 |

- `qa-result.json` 必须记录当前消费的 `plan_version_ref`。
- `verify` 只能基于当前 `plan_version_ref` 验收 Task；若 `REPLAN` 后仍引用旧版本，视为无效结论。
- 旧批次若已冻结，只能保留为历史记录，不得继续被视为“当前可执行批次”。

## 每 Task 完整循环

派发开发```
Agent(subagent_type: "developer", prompt: Task 需求 + AC + 文件范围 + design_ref + test_ref)
```
Developer 执行：test-first 实现 → self-review → 返回报告（含 TDD 证据索引 RED/GREEN commit SHA）。
失败 >2 次 → BLOCKED。

Spec Review（verify Phase 1）```
Agent(subagent_type: "verifier", prompt: "执行 Phase 1: 验收 Task-N AC 覆盖。AC 列表: [...] Developer 报告: [...] 文件范围: [...]")
```
→ `SPEC_OK` / `SPEC_ISSUE`

Quality Review（verify Phase 2，SPEC_OK 后执行）串行 3 次独立检查：
```
Agent(subagent_type: "verifier", scope=Phase2A) → TDD 证据 + 虚假实现检测 → 2A_OK / 2A_ISSUE
Agent(subagent_type: "verifier", scope=Phase2B) → 静默失败 + 硬编码检测 → 2B_OK / 2B_ISSUE
Agent(subagent_type: "verifier", scope=Phase2C) → 代码规范 + 测试有效性 → 2C_OK / 2C_ISSUE
```
汇总：全部 OK → 产出 dev-report → Phase 3 / 任一 ISSUE → 修复循环

术语：
- `ISSUE`：来自 `verify` 的 Task 内验收问题
- `FAIL`：来自 `review` 或 `qa` 报告的独立失败项
- 默认流转：`verify ISSUE -> developer`；`review/qa FAIL -> fix`
- 稳定编号：`review/qa` 的 ISSUE/FAIL 必须有稳定 issue id，供 `waivers.md` 与修复轮次追踪

## 修复循环判断

- 给 `developer` 的修复 prompt 必须附：ISSUE 原文、对应检查组、限制修改范围；若为 AC/设计理解偏差，补充 AC 上下文或 `design_ref` 原文
- 命中任一条件即升级 `fix`：同一 ISSUE 连续 2 轮未清除 / 根因不清需重做定位 / 问题跨 Task 边界或需回归影响分析 / 上一轮方案已证明无效
- 给 `fix` 的修复 prompt 必须附：FAIL 或 ISSUE 证据、失败轮次、上一轮方案为何失效、回归影响范围
- `fix` 后仍失败，或同一问题累计 3 轮未关闭 → 高概率是 Plan/Design 层面问题，标记 BLOCKED 并回看上游文档

## 偏差治理触发器与动作

| 触发器 | 必做动作 | Owner |
|--------|---------|-------|
| `COMPLEXITY_DRIFT` / `SHARED_FILES_EXPANSION` | 记录影响面，必要时升级验证强度 | `delivery-owner` |
| `INTERFACE_TWEAK` | 允许继续，但必须在报告承接并要求 code-review 复核 | `developer -> delivery-owner` |
| `INTERFACE_BREAK` / 范围漂移 | 立即暂停，升级 `tech-lead / user` | `delivery-owner` |
| `DEPENDENCY_DRIFT` / 环境变化 | 暂停当前 Task，回到 readiness 或 replan | `delivery-owner` |
| `NON_CONVERGENCE` / `BLOCKED_ACCUMULATION` | 从 `CONTINUE` 升级到 `ESCALATE / REPLAN / BLOCK` | `delivery-owner` |

在 `Scope Freeze` 内，`delivery-owner` 可以重排批次、优先级和回归范围；超出 `Scope Freeze` 的变动必须回到 `tech-lead / user`。

## 并行执行（worktree 隔离）

按轮次派发，每轮内 Task 并行启动：
1. 每 Task → `Agent(subagent_type: "developer", isolation: "worktree", run_in_background: true)`
2. 等待本轮全部完成
3. 每 Task: 审查循环（Spec Review → Quality Review → 修复）
4. 按 Task 编号顺序逐个 merge（`git merge --no-ff`）
   - 冲突处理：shared_files 已声明 → 手动解决；未声明 → BLOCKED 报告用户
5. 全量测试：PASS → 下一轮 / FAIL → 定位失败 Task → 修复 → 重测
6. 清理已 merge 的 worktree
