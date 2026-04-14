## 输入分析

REVIEW: PLAN_ISSUE

本轮评审对象：

- [design.md](/Users/lijieli/org-claude-skills/docs/standard-chain-contract-foundation/2026-04-14-contract-foundation/design.md)
- [tasks.md](/Users/lijieli/org-claude-skills/docs/standard-chain-contract-foundation/2026-04-14-contract-foundation/tasks.md)
- [plan.md](/Users/lijieli/org-claude-skills/docs/standard-chain-contract-foundation/2026-04-14-contract-foundation/plan.md)

本轮采用 Agent Team 并行评审，维度如下：

- D1 合同与架构边界
- D2 对抗式运行时 / 恢复 / 切换
- D3 tasks / plan 可执行性与验证性
- D4 design -> tasks -> plan 一致性与验收闭环

## 评审结论

当前 `writing-plans` 产物还不能直接进入实施。问题不在“还缺点细节”，而在若按现状开工，后续实现会被迫在运行时 contract、replay profile、cutover scope 这些关键位置继续拍板，破坏这轮计划应有的冻结边界。

## 确认后的正式问题

### 1. `chain_registry_digest` 没有绑定完整 registry bundle

证据：

- [design.md](/Users/lijieli/org-claude-skills/docs/standard-chain-contract-foundation/2026-04-14-contract-foundation/design.md:299)
- [tasks.md](/Users/lijieli/org-claude-skills/docs/standard-chain-contract-foundation/2026-04-14-contract-foundation/tasks.md:72)
- [plan.md](/Users/lijieli/org-claude-skills/docs/standard-chain-contract-foundation/2026-04-14-contract-foundation/plan.md:116)

复核结论：

- 属实
- 当前 plan 只把四个 registry 文件纳入 digest，没有把 `registry-bundle.yaml` 及其 `chain_version -> bundle` 映射纳入指纹，和 design 的版本语义冻结冲突

### 2. `artifact-registry` 的 append-only 与 active FINALIZED 合同没有被计划承接完整

证据：

- [design.md](/Users/lijieli/org-claude-skills/docs/standard-chain-contract-foundation/2026-04-14-contract-foundation/design.md:743)
- [tasks.md](/Users/lijieli/org-claude-skills/docs/standard-chain-contract-foundation/2026-04-14-contract-foundation/tasks.md:79)
- [plan.md](/Users/lijieli/org-claude-skills/docs/standard-chain-contract-foundation/2026-04-14-contract-foundation/plan.md:298)
- [plan.md](/Users/lijieli/org-claude-skills/docs/standard-chain-contract-foundation/2026-04-14-contract-foundation/plan.md:319)

复核结论：

- 属实
- 当前 plan 同时存在两个缺口：
  - resolver 只跳过 `QUARANTINED`，没有强制 `active_for_consumption=true` 的 entry 必须是 `FINALIZED`
  - `append_revision()` 以整表替换实现“新 revision”，和 design 要求的 append-only revision 冲突

### 3. `BLOCKED -> 恢复` 只有进入，没有退出和 replay 闭环

证据：

- [design.md](/Users/lijieli/org-claude-skills/docs/standard-chain-contract-foundation/2026-04-14-contract-foundation/design.md:912)
- [tasks.md](/Users/lijieli/org-claude-skills/docs/standard-chain-contract-foundation/2026-04-14-contract-foundation/tasks.md:79)
- [plan.md](/Users/lijieli/org-claude-skills/docs/standard-chain-contract-foundation/2026-04-14-contract-foundation/plan.md:339)

复核结论：

- 属实
- 当前 plan 只规划了 `enter_blocked`，没有 `leave_blocked / resume_blocked`、解阻字段、fixture 和 replay 断言

### 4. `authority proof` 与 `REPLAN` 后旧决策失效被削成了字段存在校验

证据：

- [design.md](/Users/lijieli/org-claude-skills/docs/standard-chain-contract-foundation/2026-04-14-contract-foundation/design.md:644)
- [tasks.md](/Users/lijieli/org-claude-skills/docs/standard-chain-contract-foundation/2026-04-14-contract-foundation/tasks.md:93)
- [plan.md](/Users/lijieli/org-claude-skills/docs/standard-chain-contract-foundation/2026-04-14-contract-foundation/plan.md:514)

复核结论：

- 属实
- 当前 plan 缺少 `decision_source -> proof_type` 约束、payload digest 绑定、proof freshness、actor/proof 对齐、supersede 重认证、`SCRIPT` 最终落盘禁止与 `REPLAN` 后 stale decision fail

### 5. projection / replay 的合同真源还藏在实现里

证据：

- [design.md](/Users/lijieli/org-claude-skills/docs/standard-chain-contract-foundation/2026-04-14-contract-foundation/design.md:1077)
- [design.md](/Users/lijieli/org-claude-skills/docs/standard-chain-contract-foundation/2026-04-14-contract-foundation/design.md:1099)
- [tasks.md](/Users/lijieli/org-claude-skills/docs/standard-chain-contract-foundation/2026-04-14-contract-foundation/tasks.md:99)
- [plan.md](/Users/lijieli/org-claude-skills/docs/standard-chain-contract-foundation/2026-04-14-contract-foundation/plan.md:587)
- [plan.md](/Users/lijieli/org-claude-skills/docs/standard-chain-contract-foundation/2026-04-14-contract-foundation/plan.md:623)

复核结论：

- 属实
- 当前 plan 有两个结构性缺口：
  - `shared/runtime/projection-views.json` 没有显式 `section-source` 映射
  - replay profile 仍是工具内嵌 dict，没有显式 runtime contract 文件，也没把特殊 profile 和 replay oracle record 落成 fixture / assertion

### 6. `unit-task` 作用域工件被压成了 unit 级路径

证据：

- [design.md](/Users/lijieli/org-claude-skills/docs/standard-chain-contract-foundation/2026-04-14-contract-foundation/design.md:426)
- [tasks.md](/Users/lijieli/org-claude-skills/docs/standard-chain-contract-foundation/2026-04-14-contract-foundation/tasks.md:76)
- [plan.md](/Users/lijieli/org-claude-skills/docs/standard-chain-contract-foundation/2026-04-14-contract-foundation/plan.md:15)

复核结论：

- 属实
- `developer-report.json` 与 `verify-result.json` 的 scope 是 `unit-task`，但当前 workspace layout 和 golden pilot 只给了 unit 级单文件路径，多 task unit 会直接撞路径

### 7. T6 cutover scope 和验证面都没收干净

证据：

- [design.md](/Users/lijieli/org-claude-skills/docs/standard-chain-contract-foundation/2026-04-14-contract-foundation/design.md:1232)
- [design.md](/Users/lijieli/org-claude-skills/docs/standard-chain-contract-foundation/2026-04-14-contract-foundation/design.md:1299)
- [tasks.md](/Users/lijieli/org-claude-skills/docs/standard-chain-contract-foundation/2026-04-14-contract-foundation/tasks.md:106)
- [plan.md](/Users/lijieli/org-claude-skills/docs/standard-chain-contract-foundation/2026-04-14-contract-foundation/plan.md:677)
- [plan.md](/Users/lijieli/org-claude-skills/docs/standard-chain-contract-foundation/2026-04-14-contract-foundation/plan.md:788)

复核结论：

- 属实
- 当前 T6 同时有三类问题：
  - 漏掉真实 runtime consumers：`shared/protocols/phase-selection-protocol.md`、`shared/skills/product/references/phase-splitting-guide.md`、`shared/agents/*`、`tests/test-phase-context-resolution.sh`
  - skill 模板直接内嵌 JSON skeleton，重新制造 `contracts/canonical/` 之外的第二份合同真源
  - 宣称会修改的 gate tests 没进入 T6 验证命令和 Definition of Done

## 排除项

- `WS1 -> WS6` 到 `T1 -> T6` 的主映射关系成立，不是本轮 blocker
- `V1 Freeze` 的 artifact 集合与 milestone 切分没有新增正式矛盾

## 修复方向

本轮修复必须联动完成以下 6 个面：

1. digest / bundle / catalog
2. runtime registry / active FINALIZED / append-only revision
3. `BLOCKED -> 恢复`
4. authority proof / stale decision
5. projection / replay / readiness gate
6. T6 consumer replacement / test surface / single source of truth

## 当前结论

- 结论：先修 `tasks.md` 与 `plan.md`
- 修完后必须重新提交并行 review
