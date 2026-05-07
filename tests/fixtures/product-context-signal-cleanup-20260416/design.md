# Product Context Signal Cleanup Design

## 背景

产品运行时角色已经拆成 `/product-director` 与 `/product-manager`。当前剩余问题不是角色拆分方向错误，而是复杂度仍散落在模板、SKILL、gate、schema、eval 和 reference 多处，导致 LLM 上下文噪音、语义多源漂移和证据链偏弱。

## 设计原则

- LLM 只读影响下一步判断的高信号内容。
- 模板只定义输出结构与必要证据字段，不承载流程讲解、权限解释或状态机推理。
- 严谨性由工程机制承担，包括 gate、schema、machine contract、eval 和 fresh proving。
- 允许 Director 与 Manager 各自目录自包含；可枚举字段进入 machine contract，按需方法和编排规则进入对应 reference。
- “更强”只能由当前版本的中立证据证明，不能靠文案自证。
- 运行态上下文只保留会改变执行行为、输出格式、边界判断或失败处理的内容；作者视角、自述和自然关系复述通过门禁禁止进入 skill 消费路径。

## 目标状态

### 工件分层

| 层 | 职责 | 不承担 |
|---|---|---|
| `template` | 章节、表头、占位符、必要证据字段 | 流程讲解、权限解释、长说明 |
| `SKILL.md` | 角色边界、执行流程、何时读取 reference、何时停下 | 具体模板表格细节、产物路径清单 |
| `completion_check` | 可执行门禁和一致性校验 | 解释型方法论 |
| `contracts/*.yaml` | 可复用机器合同 | 人类叙事说明 |
| `eval/results` | 当前证据 | 自证式宣传语 |

### 角色边界

- Director 只产出根问题、目标、范围、业务规则、约束事实、设计决策候选、Phase 目标和边界、Director 确认。
- Manager 只在 Director handoff 后补 UNIT、AC、MVP 闭环、review、交付确认和执行映射。
- Director 模板不得出现 UNIT 优先级、UNIT 依赖、交付确认、review 状态机。

### Machine Contract 与 Reference 分层

Director lock schema、review 最小可执行字段、Phase 可锁字段进入 machine contract。Gate 和测试消费 machine contract，减少章节名、字段名和 allowlist 的手工复制。评审编排、TeamCreate 协作团队、循环上限与收敛规则由 `product-manager/references/review-orchestration.md` 承载，并由 parity gate 防回退。产物路径、模板来源、锁文件和写入边界由各角色的 `references/output.md` 承载。

### 证据标准

既有历史 benchmark 只能作为参考，不能承载无保留证明结论。新证据必须满足：

- 场景与评分不预设 split 术语。
- 评分至少包含语义 judge 或结构化 rubric，不只靠关键词正则。
- blind comparison 随机 A/B 顺序，不取 best-of-N 作为唯一代表。
- gate test 校验当前 HEAD 可重跑或明确标注 smoke 边界。

## 非目标

- 不回滚 `/product-director` 与 `/product-manager` 角色拆分。
- 不重新引入单体产品 runtime skill。
- 不为了消除重复而恢复第三层共享 runtime 目录。
- 不把所有过程记录塞回 `brief.md`。
- 不把 review 闭环证据误删为“模板噪音”。

## 成功判定

- product 模板明显变薄，且 rule-like 行数受 gate 限制。
- Director 模板不再包含 Manager-only 章节或字段。
- Review 模板保留评审闭环证据字段：最终结论、审查汇总、问题台账、收敛轮次、用户裁决和未决阻断；编排规则仍由 SKILL / gate / schema 承担。
- Lock schema 与 review 字段有机器可读真源。
- 产品思维框架、警示信号、TeamCreate 协作团队评审、`max10轮` 和收敛/阻断规则必须由当前 reference 承载，并由测试验证引用关系。
- `## 产出` 只保留 output reference 引用；产物细节由 `references/output.md` 承载。
- D-S1 的 `Context Scan Agent` / `Problem Hypothesis Agent`、Director / Manager gate 回退图、reviewer prompt 的 `Findings` 与承接目标必须由运行态文件直接承载，并由上下文信号质量门禁防回退。
- Product evidence 文档不再用散文自证“更强”，只保留 scorecard 与证据边界。
