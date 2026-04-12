# 复杂链路 sub agent 最佳实践实施计划

**Goal:** 把复杂链路从“主 Agent 承担高读写噪音”改造成“主 Agent 负责裁决、sub agent 负责降噪工序”的正式仓库流程。

**Scope:** 仅覆盖 `/product`、`/design`、`/test-design`、`/tech-lead`、`/delivery-owner` 及其直接依赖的 `reference / template / completion_check / contract`。

**Verification Rule:** 所有改动都必须同时通过“文件结构检查 + completion_check + 文档一致性检查 + 样本验证”。

---

## T1 全局合同层

### 目标

先把全局 shared contract 固定下来，避免后面每个 skill 各改各的。

### 改动范围

Files:
- Modify: `/Users/lijieli/org-claude-skills/contracts/skill-chain.yaml`
- Modify: `/Users/lijieli/org-claude-skills/contracts/identifiers.yaml`
- Modify: `/Users/lijieli/org-claude-skills/shared/reference/agent-team-patterns.md`
- Create: `/Users/lijieli/org-claude-skills/shared/reference/subagent-recovery-contract.md`
- Create: `/Users/lijieli/org-claude-skills/shared/reference/context-noise-metrics.md`
- Create: `/Users/lijieli/org-claude-skills/shared/reference/templates/fact-scan-template.md`
- Create: `/Users/lijieli/org-claude-skills/shared/reference/templates/hypothesis-draft-template.md`
- Create: `/Users/lijieli/org-claude-skills/shared/reference/templates/structure-draft-template.md`
- Create: `/Users/lijieli/org-claude-skills/shared/reference/templates/synthesis-template.md`
- Create: `/Users/lijieli/org-claude-skills/shared/reference/templates/metrics-log-template.md`

### 怎么改

1. 在 `contracts/skill-chain.yaml` 为 5 个主阶段增加统一字段：
   - `subagent_policy`
   - `max_subagents`
   - `recovery_contract_ref`
   - `metrics_ref`
   - `allowed_subagent_kinds`
2. 在 `subagent-recovery-contract.md` 固定：
   - 4 类回收合同
   - schema 字段
   - `候选 / 待裁决 / 已冻结` 状态机
   - 必填/可空规则
   - 机械校验规则
3. 在 `context-noise-metrics.md` 固定：
   - `M1~M6` 定义
   - 样本边界
   - 基线规则
   - `PASS / FAIL / INCONCLUSIVE` 阶段门槛
4. 在模板目录补齐 5 个统一模板，作为所有阶段唯一模板源。

### 验收标准

- 5 个主阶段都保留 `position: main`
- 全局合同层能独立回答“sub agent 可以做什么、不能做什么、怎么量化”
- 任一阶段不需要再自定义自己的 schema 或度量口径

### 验证

Run:
```bash
rg -n "subagent_policy|max_subagents|recovery_contract_ref|metrics_ref" /Users/lijieli/org-claude-skills/contracts/skill-chain.yaml
```
Expected: 5 个主阶段都出现这 4 类字段。

Run:
```bash
rg -n "agent_kind|decision_state|M1|M6|PASS|INCONCLUSIVE" /Users/lijieli/org-claude-skills/shared/reference/subagent-recovery-contract.md /Users/lijieli/org-claude-skills/shared/reference/context-noise-metrics.md
```
Expected: schema、状态机、度量、阶段门槛都可检出。

## T2 `tech-lead`

### 目标

把 `tech-lead` 变成第一批正式支持 sub agent 的主 skill。

### 改动范围

Files:
- Modify: `/Users/lijieli/org-claude-skills/shared/skills/tech-lead/SKILL.md`
- Modify: `/Users/lijieli/org-claude-skills/shared/skills/tech-lead/references/planning-modes.md`
- Modify: `/Users/lijieli/org-claude-skills/shared/skills/tech-lead/references/decomposition-patterns.md`
- Modify: `/Users/lijieli/org-claude-skills/shared/skills/tech-lead/references/plan-reviewer-prompt.md`
- Modify: `/Users/lijieli/org-claude-skills/shared/skills/tech-lead/references/plan-product-reviewer-prompt.md`
- Modify: `/Users/lijieli/org-claude-skills/shared/skills/tech-lead/references/plan-test-reviewer-prompt.md`
- Modify: `/Users/lijieli/org-claude-skills/shared/skills/tech-lead/references/templates/plan-template.md`
- Modify: `/Users/lijieli/org-claude-skills/shared/skills/tech-lead/scripts/completion_check.sh`

### 怎么改

1. 在 `SKILL.md` 的流程区加一个新的 sub agent dispatch 段：
   - `Traceability Draft Agent`
   - `Task Decomposition Draft Agent`
   - `Evidence Field Draft Agent`
2. 明确 3 个 agent 的：
   - 触发条件
   - 固定输入
   - 固定输出
   - 主 Agent 保留职责
   - 最大数量 `= 3`
3. 在 `plan-template.md` 增加：
   - 草稿回收记录区
   - `输入边界 / 未决项 / 禁止越权项` 对照位
4. reviewer prompts 改成：
   - 不信任 agent 自报
   - 只审最终 `plan.md`
   - 若草稿泄漏进最终工件，直接报 FAIL
5. `completion_check.sh` 新增检查：
   - 最终 `plan.md` 不得残留 `draft` 标识
   - 不得存在未收敛冲突项
   - `Scope Freeze / Task / evidence` 必须来自单一冻结版本

### 验收标准

- 主 Agent 仍独占 `DESIGN_OK`、计划模式、Task 冻结、用户确认
- 3 类草稿 agent 正式进入流程合同
- completion check 能识别“草稿泄漏到最终 plan”

### 验证

Run:
```bash
rg -n "Traceability Draft Agent|Task Decomposition Draft Agent|Evidence Field Draft Agent" /Users/lijieli/org-claude-skills/shared/skills/tech-lead/SKILL.md
```
Expected: 3 类 agent 都在 `SKILL.md` 主流程中出现。

Run:
```bash
bash /Users/lijieli/org-claude-skills/shared/skills/tech-lead/scripts/completion_check.sh
```
Expected: 现有强门禁仍可运行；新增规则可被脚本解析。

## T3 `test-design`

### 目标

把 `test-design` 变成第二个正式支持结构化草稿的阶段。

### 改动范围

Files:
- Modify: `/Users/lijieli/org-claude-skills/shared/skills/test-design/SKILL.md`
- Modify: `/Users/lijieli/org-claude-skills/shared/skills/test-design/references/methodology.md`
- Modify: `/Users/lijieli/org-claude-skills/shared/skills/test-design/references/testdesign-reviewer-prompt.md`
- Modify: `/Users/lijieli/org-claude-skills/shared/skills/test-design/references/testdesign-product-reviewer-prompt.md`
- Modify: `/Users/lijieli/org-claude-skills/shared/skills/test-design/references/testdesign-arch-reviewer-prompt.md`
- Modify: `/Users/lijieli/org-claude-skills/shared/skills/test-design/scripts/completion_check.sh`

### 怎么改

1. 在 `SKILL.md` 的固定主流程里增加：
   - `Coverage Draft Agent`
   - `Equivalence Draft Agent`
   - `QA Handoff Draft Agent`
2. 写清并行与串行边界：
   - coverage / equivalence 可并行
   - QA handoff 只能在主 Agent 收敛后生成
3. 明确 `DESIGN-GAP(EQ)` 永远只由主 Agent 判定。
4. reviewer prompts 加上：
   - 只审最终 `test-cases.md`
   - 草稿不算最终证据
5. `completion_check.sh` 新增：
   - 禁止草稿矩阵直接充当最终矩阵
   - `DESIGN-GAP(EQ)` 必须来自主 Agent 结论，不得由草稿直接升级

### 验收标准

- `DESIGN-GAP(EQ)` 责任没有漂移
- coverage / equivalence / QA handoff 三类草稿有正式合同
- `test-cases.md` 仍是唯一真源

### 验证

Run:
```bash
rg -n "Coverage Draft Agent|Equivalence Draft Agent|QA Handoff Draft Agent|DESIGN-GAP\\(EQ\\)" /Users/lijieli/org-claude-skills/shared/skills/test-design/SKILL.md
```
Expected: 3 类 agent 出现，且 `DESIGN-GAP(EQ)` 仍保留主 Agent 裁决。

Run:
```bash
bash /Users/lijieli/org-claude-skills/shared/skills/test-design/scripts/completion_check.sh
```
Expected: completion check 仍可运行，且承接新规则。

## T4 `design`

### 目标

把 `design` 改造成“先事实、再候选方案、最后定稿”的主流程。

### 改动范围

Files:
- Modify: `/Users/lijieli/org-claude-skills/shared/skills/design/SKILL.md`
- Modify: `/Users/lijieli/org-claude-skills/shared/skills/design/references/runtime-fact-capture.md`
- Modify: `/Users/lijieli/org-claude-skills/shared/skills/design/references/decision-templates.md`
- Modify: `/Users/lijieli/org-claude-skills/shared/skills/design/references/adr-spec.md`
- Modify: `/Users/lijieli/org-claude-skills/shared/skills/design/references/design-reviewer-prompt.md`
- Modify: `/Users/lijieli/org-claude-skills/shared/skills/design/references/design-product-reviewer-prompt.md`
- Modify: `/Users/lijieli/org-claude-skills/shared/skills/design/references/design-test-reviewer-prompt.md`
- Modify: `/Users/lijieli/org-claude-skills/shared/skills/design/scripts/completion_check.sh`

### 怎么改

1. 在流程里加 3 个串行 agent：
   - `Runtime Fact Capture Agent`
   - `Option Draft Agent`
   - `ADR Draft Agent`
2. 明确：
   - 运行时采证只读
   - 候选方案草稿不可直接进 `design.md`
   - ADR 只能在主 Agent 收敛决策后生成
3. `runtime-fact-capture.md` 与 `decision-templates.md` 同步到 shared contract 字段。
4. reviewer prompts 改成：
   - 不审 agent 自报，只审最终 design
   - 若最终设计残留未决候选，直接 FAIL
5. `completion_check.sh` 加上：
   - 不允许多版本候选并存
   - 接口边界、回滚策略、迁移策略只能来自最终冻结内容

### 验收标准

- 最终技术裁决仍由主 Agent 独占
- 设计流程形成 `fact -> options -> final design -> ADR` 的固定顺序
- reviewer 和 completion check 都只承认最终冻结工件

### 验证

Run:
```bash
rg -n "Runtime Fact Capture Agent|Option Draft Agent|ADR Draft Agent" /Users/lijieli/org-claude-skills/shared/skills/design/SKILL.md
```
Expected: 3 个 agent 都出现在主流程中。

Run:
```bash
bash /Users/lijieli/org-claude-skills/shared/skills/design/scripts/completion_check.sh
```
Expected: design 完成校验仍可运行并承接新字段。

## T5 `product`

### 目标

在不破坏用户共创的前提下，把 `product` 的静默采集和候选问题生成交给 sub agent。

### 改动范围

Files:
- Modify: `/Users/lijieli/org-claude-skills/shared/skills/product/SKILL.md`
- Modify: `/Users/lijieli/org-claude-skills/shared/skills/product/references/conversation-guide.md`
- Modify: `/Users/lijieli/org-claude-skills/shared/skills/product/references/completeness-checklist.md`
- Modify: `/Users/lijieli/org-claude-skills/shared/skills/product/references/prd-reviewer-prompt.md`
- Modify: `/Users/lijieli/org-claude-skills/shared/skills/product/references/architect-reviewer-prompt.md`
- Modify: `/Users/lijieli/org-claude-skills/shared/skills/product/references/tester-reviewer-prompt.md`
- Modify: `/Users/lijieli/org-claude-skills/shared/skills/product/scripts/completion_check.sh`

### 怎么改

1. 在 `SKILL.md` 里把 sub agent 限定在前置静默环节：
   - `Context Scan Agent`
   - `Problem Hypothesis Agent`
2. 明确 2 个硬边界：
   - 不能向用户发关键问题
   - 不能决定范围、目标、成功标准
3. `conversation-guide.md` 增加：
   - 什么时候先静默扫描
   - 什么时候回到主 Agent 追问
4. reviewer prompts 改成：
   - 只审最终 `brief.md / prd.md / UNIT-*`
   - 不接受候选问题清单直接充当最终结论
5. `completion_check.sh` 增加：
   - `brief / prd / UNIT` 不得残留候选问题或未裁决 root problem

### 验收标准

- 用户共创和交付确认仍由主 Agent 独占
- sub agent 仅承担静默采集与候选问题生成
- `brief.md / prd.md / UNIT-*` 仍保持单一真源

### 验证

Run:
```bash
rg -n "Context Scan Agent|Problem Hypothesis Agent|交付确认|成功标准" /Users/lijieli/org-claude-skills/shared/skills/product/SKILL.md
```
Expected: 2 个 agent 出现，且关键裁决仍保留在主 Agent。

Run:
```bash
bash /Users/lijieli/org-claude-skills/shared/skills/product/scripts/completion_check.sh
```
Expected: product 完成校验仍可运行并承接新规则。

## T6 `delivery-owner`

### 目标

只在高并行执行期增加条件式汇总代理，不增加新的常驻管理层。

### 改动范围

Files:
- Modify: `/Users/lijieli/org-claude-skills/shared/skills/delivery-owner/SKILL.md`
- Modify: `/Users/lijieli/org-claude-skills/shared/skills/delivery-owner/references/dispatch-guide.md`
- Modify: `/Users/lijieli/org-claude-skills/shared/skills/delivery-owner/references/phase3-dispatch.md`
- Modify: `/Users/lijieli/org-claude-skills/shared/skills/delivery-owner/references/templates/dev-report-template.md`
- Modify: `/Users/lijieli/org-claude-skills/shared/skills/delivery-owner/references/templates/code-review-report-template.md`
- Modify: `/Users/lijieli/org-claude-skills/shared/skills/delivery-owner/references/templates/acceptance-summary-template.md`
- Modify: `/Users/lijieli/org-claude-skills/shared/skills/delivery-owner/scripts/completion_check.sh`

### 怎么改

1. 在 `SKILL.md` 明确唯一状态机：
   - `Status Synthesis Agent`
   - `Evidence Synthesis Agent`
2. 写死触发口径：
   - `plan.md` 当前批次并行 Task 数 `>= 4`
   - `BLOCKED` 计入并行数
   - 重试不重复计数
   - replan 跨批次重新计数
3. `dispatch-guide.md` 补：
   - 汇总代理输入、输出、越权边界
4. `phase3-dispatch.md` 补：
   - 汇总代理不改变 `REVIEW/QA` 强门禁，只做汇总
5. 3 个模板补：
   - 汇总字段引用位
   - 证据锚点引用位
6. `completion_check.sh` 补：
   - 当汇总代理触发时，对 summary 文件做字段和锚点校验
   - 当未触发时，不强制 summary 文件存在

### 验收标准

- `delivery-owner` 不增加常驻管理者
- 汇总代理只在高并行场景触发
- readiness、门禁、sign-off 推进责任没有漂移

### 验证

Run:
```bash
rg -n "Status Synthesis Agent|Evidence Synthesis Agent|BLOCKED|并行 Task" /Users/lijieli/org-claude-skills/shared/skills/delivery-owner/SKILL.md
```
Expected: 状态机、计数口径、两类汇总代理都在主 skill 中明确。

Run:
```bash
bash /Users/lijieli/org-claude-skills/shared/skills/delivery-owner/scripts/completion_check.sh
```
Expected: delivery-owner 完成校验仍可运行，且能区分“触发 summary / 未触发 summary”。

## T7 端到端验收

### 目标

确保这次改造不是“文档改了”，而是仓库真正获得一套可执行、可验收的降噪机制。

### 验收标准

1. 全局合同层存在且被 5 个主 skill 引用
2. 5 个主 skill 都写明：
   - 可用 sub agent
   - 主 Agent 保留职责
   - 触发条件
   - 回收件
   - 禁止越权项
3. 5 个 completion_check 都能承接新字段
4. `tech-lead` 至少完成 `3` 个正式样本验证
5. 其他阶段在回写前达到各自样本门槛

### 总验证

Run:
```bash
git diff --check
```
Expected: 无格式问题。

Run:
```bash
rg -n "Context Scan Agent|Problem Hypothesis Agent|Runtime Fact Capture Agent|Option Draft Agent|Coverage Draft Agent|Traceability Draft Agent|Status Synthesis Agent" /Users/lijieli/org-claude-skills/shared/skills
```
Expected: 所有正式支持的 agent 都在对应 skill 中可检出。

Run:
```bash
bash /Users/lijieli/org-claude-skills/shared/skills/product/scripts/completion_check.sh
bash /Users/lijieli/org-claude-skills/shared/skills/design/scripts/completion_check.sh
bash /Users/lijieli/org-claude-skills/shared/skills/test-design/scripts/completion_check.sh
bash /Users/lijieli/org-claude-skills/shared/skills/tech-lead/scripts/completion_check.sh
bash /Users/lijieli/org-claude-skills/shared/skills/delivery-owner/scripts/completion_check.sh
```
Expected: 5 个主 skill 的完成校验都能运行，且不与新合同冲突。

## 执行顺序

1. 先做 `T1`
2. 再做 `T2`
3. 再做 `T3`
4. 再做 `T4`
5. 再做 `T5`
6. 最后做 `T6`
7. 用 `T7` 收口

## Stop Conditions

出现任一项，停止继续改造并回到当前任务收敛：

- 某个 skill 的主 Agent 职责被 sub agent 接管
- completion_check 无法承接新字段
- 新增模板与 shared contract 不一致
- `M1~M6` 无法落盘或无法复算
