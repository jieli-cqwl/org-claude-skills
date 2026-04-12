# 派发与修复指南

> 引用者：delivery-owner SKILL.md Phase 2
> 唯一模板源：`{{RUNTIME_HOME}}/reference/templates/synthesis-template.md`

## 派发 prompt 质量要点

| 要素 | 必须包含 | 常见遗漏 |
|------|---------|---------|
| 上下文 | design_ref 中的模块职责和接口约束 | 只给 AC 不给设计上下文，developer 自行理解导致偏差 |
| 文件范围 | 所有待修改/新建文件路径 + 现有文件的当前作用 | 只给文件名不说明当前内容，developer 需自行探索 |
| AC | 逐条列出，包含输入→输出格式 | 只给标题级 AC，缺少具体断言 |
| 约束 | 不可修改的文件、必须兼容的现有接口 | 未声明边界，developer 越界修改 |
| test_ref | 对应的测试用例编号及预期测试策略 | 遗漏 test_ref 导致 developer 自行决定测试范围 |

## Delivery Kickoff 包

派发前必须先确认：`scope_freeze`、共享文件、真实依赖、`preflight-evidence`、risk owner、QA handoff readiness、回退路径。
缺任一项都不能进入 developer 派发；需要由 `delivery-owner` 先补齐或暂停升级。

## 汇总代理使用规则

当且仅当当前批次并行 Task 数 `>= 4` 时，允许启用汇总代理；它们只能汇总既有状态和证据，不能替代主 Agent 的裁决职责。

- `Status Synthesis Agent`
  - 输入：`plan.md` 当前批次、Task 状态、`BLOCKED` 列表、升级信号、批次顺序
  - 输出：`delivery-status-summary.md`
  - 越权边界：不能改变 readiness、不能创建新的 `REVIEW/QA` 结论、不能替代 sign-off
- `Evidence Synthesis Agent`
  - 输入：`dev-report.md`、`code-review-report.md`、`qa-report.md`、`plan.md`
  - 输出：`evidence-summary.md`
  - 越权边界：只能引用现有报告锚点，不能新增风险接受、放行或 Gate 结论

计数口径：

- `plan.md` 当前批次并行 Task 数 = 当前批次内未进入终态的 Task 数
- 终态只允许 `DONE`、`CANCELED`
- `BLOCKED` 计入并行 Task 数
- 同一 `Task ID` 的重试不重复计数
- replan 跨批次后重新计数
- 两个汇总代理同一时刻只能有一个
- `Status Synthesis Agent` 结束或被停止后，才允许进入 `Evidence Synthesis Agent`

重入规则：

- `Status Synthesis Agent` 只允许按当前批次状态重算，不得携带旧批次计数
- `Evidence Synthesis Agent` 若源报告变化，可把旧 summary 标记为 `STALE`，并仅允许重跑 `1` 次
- 超过 `1` 次重跑仍发生内容变化时，必须升级给主 Agent 裁决

回收件必须使用统一的汇总字段与证据锚点占位：

- `输入边界`
- `当前判断`
- `证据锚点`
- `未决项`
- `禁止越权项`
- `汇总文件引用`
- `重入规则`

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
