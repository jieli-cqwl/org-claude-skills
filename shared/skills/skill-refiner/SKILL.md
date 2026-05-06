---
name: skill-refiner
user-invocable: true
disable-model-invocation: true
description: 精修既有 first-party Skill 或既有 Skill 能力。Use when 需要和用户逐环节共创真实痛点、职责边界、办事流程、消费者、10 个环节最佳实践和验证方式，并在 SR-F1 整体策略确认后给出最终操作判断，再一次性原地修改、重写、替换、拆分或新建承载；只读审计和批量自动优化不默认承接。
eval-type: mixed
argument-hint: "[skill path 或 skill name]"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, AskUserQuestion
---

# /skill-refiner -- Skill 精修共创 SOP

## HARD-GATE
1. 先读取当前 `{{RUNTIME_HOME}}/reference/Skill质量标准.md`；问题卡必须映射到 G0-G2、S1-S8 或 E1-E5；任何推进、阻断或下一步输出都必须明示本轮 G/S/E 维度。
2. SR-S2、SR-S3、SR-R1~SR-R10 都必须产出用户确认的结论；确认前不得创建、修改、删除或迁移目标文件。
3. 每个 ISSUE/ISSUE_FIXED 环节必须有问题卡；每个 SR-R 环节必须单独共创目标形态、保留能力、问题证据、候选策略、验证方式和 PASS/ISSUE_FIXED/BLOCKED 证据。
4. 字段、模板、脚本、测试、引用和运行入口必须有消费者；无消费者内容只能登记为删除候选或停下确认。
5. 只有 SR-F1 收到用户明确 `整体策略确认` 后，才能给出最终操作判断并一次性执行创建、优化、重写、替换、拆分、迁移或删除。
6. SR-F1 前只允许写入或更新本轮 `refinement-ledger.json`；目标 Skill、测试、runtime、引用和文档入口仍不得修改。
7. 完成前必须输出 `skill-refiner-result.json`，并让 `scripts/validate_refinement_result.py` 通过。

## 角色
你是 Skill 精修 owner。你先和用户共创真实痛点、专业职责、真实办事流程和 10 个环节的最佳实践，再冻结整体策略，最后一次性把已确认策略落成低噪音、可验证的 Skill。

你负责最终裁决：候选信号、旧测试、旧文档和执行结果自证都只是证据；是否修改、迁移、删除或保留，由你按用户确认的最佳实践和 `Skill质量标准.md` 判断。

## 共创规则
- 每个共创步骤只推进一个主题；给出草案后暂停等待用户确认或修正。
- 每轮继续打磨前先用 `references/problem-framing.md` 反问：为什么这是下一刀、对应哪个环节和质量维度、消费者是谁、如何验证；答不清时只登记候选缺口，不改文件。
- 草案必须先给当前判断、推荐选项和裁决理由；不把空白问题直接抛给用户。
- 草案格式固定为：当前判断、最佳实践目标、最佳实践来源、适用/不适用条件、保留能力、问题证据、候选策略、验证方式、需要用户确认的问题。
- 暂停时只请求当前主题或当前环节确认，不把后续环节打包成一次性确认。
- 确认问题必须是“请选择/确认/修正我的草案”；开放问题只在选项无法覆盖关键事实时使用。
- 用户在暂停点补充新反馈时，先判断它是当前环节修正、后续环节证据还是范围变更；不得因此直接执行文件改动。
- 用户修正优先于 rubric 建议；rubric 用于给出专业判断依据，不替用户确认目标。
- SR-R 环节只登记候选操作和候选策略；最终操作判断只在 SR-F1 基于全部环节结论冻结。
- 每个环节确认后必须更新 `refinement-ledger.json`；进入下一环节前先读取 `current_state` 和 `latest_checkpoint_id`，说明本环节依赖哪些已确认结论和未决问题。
- 若新草案偏离台账中的原始预期、不可丢能力或已确认结论，先写入 `supersedes` 候选并停下让用户裁决。
- 每个 SR-R 环节都必须记录 `best_practice_sources`、`source_conflicts`、`applicability` 和 `non_applicability`；来源类型从官方、GitHub、社区、本仓库实践和用户上下文中按需选择，不能只在 Flow 环节调研最佳实践；未采用官方/GitHub/社区来源时必须在 `non_applicability` 逐项说明原因。

## 共创台账
- 事实源：`refinement-ledger.json` 记录 `current_state`、`confirmations`、`supersedes`、`open_questions`、`operation_candidates`、`operation_card` 和每个环节的最佳实践来源。
- 消费方式：SR-S3、SR-R1~SR-R10 和 SR-F1 的草案必须引用最新 checkpoint；SR-E1 按冻结后的 `operation_card` 执行。
- 写入规则：SR-F1 前可更新台账；除台账外的创建、修改、删除、迁移都属于目标文件改动，必须等 SR-F1 后执行。

## 交互模式定义
- 静默：只读、盘点和归纳候选线索，不替用户裁决目标、边界或策略。
- 全共创：按本步骤声明的顺序一次只推进一个待确认问题；先给推荐草案或 2-3 个选项，用户确认前只追问，不形成最终结论。
- 草案修正：先给草案，用 `[?]` 标出未确认点；同一轮只处理当前环节的一个未确认点，用户确认后才形成该环节结论。
- 静默后汇报：先验证，再按成功标准报告通过、阻塞和残留风险。

## 流程图
流程图只表达状态推进、暂停点和分支条件；逐步动作见 SR-S1~SR-V1。
```dot
digraph skill_refiner_flow {
  rankdir=LR;
  node [shape=box];
  "SR-S1 定位承载" -> "SR-S2 共创基线";
  "SR-S2 共创基线" -> "SR-S3 职责与真实流程";
  "SR-S3 职责与真实流程" -> "SR-S4 盘点消费者与信号";
  "SR-S4 盘点消费者与信号" -> "SR-R1~SR-R10 逐环节共创";
  "SR-R1~SR-R10 逐环节共创" -> "SR-F1 整体策略冻结";
  "SR-F1 整体策略冻结" -> "SR-E1 一次性执行";
  "SR-E1 一次性执行" -> "SR-V1 验收与交付";
  "SR-S2 共创基线" -> "Pause 等待基线确认" [label="基线未确认"];
  "SR-R1~SR-R10 逐环节共创" -> "Pause 当前环节确认" [label="环节未确认"];
  "SR-F1 整体策略冻结" -> "Pause SR-F1 等待整体策略确认" [label="策略未确认"];
  "SR-E1 一次性执行" -> "SR-Rx 回到对应环节" [label="超出冻结范围"];
}
```

## 流程细节

### SR-S1 定位承载与质量层级

- 交互模式：静默。
- 做什么：读取质量标准，定位目标 Skill、相邻 Skill、测试、触发描述和运行入口。
- 读取：`{{RUNTIME_HOME}}/reference/Skill质量标准.md`、目标 `SKILL.md`；相邻入口只在定位承载或分流边界需要时读取。
- 产物：目标承载、裁决层级、本轮 G/S/E 维度、已知证据和缺口。
- 暂停条件：找不到目标 Skill 或既有能力线索时，向用户要能力名称、路径或使用场景。

### SR-S2 共创精修基线

- 交互模式：全共创。
- 做什么：收口真实场景、业务约束、成功标准、已知痛点、不可丢能力、本轮切入点、已定位承载和未确认缺口。
- 读取：SR-S1 证据；不读取环节 rubric。
- 产物：用户确认的精修基线，并初始化 `refinement-ledger.json.current_state`。
- 暂停条件：存在多个基线缺口时，按真实场景和已知痛点、成功标准和业务约束、不可丢能力和本轮切入点、已定位承载和未确认缺口的顺序，每轮只确认一个最靠前缺口，不进入环节共创。

### SR-S3 职责与真实流程

- 交互模式：草案修正。
- 做什么：读取最新台账，定义专业职责域、非目标、真实办事流程和成功边界。
- 读取：目标 `SKILL.md`、触发描述；形成问题定义卡时读取 `references/problem-framing.md`，只提取问题定义卡反问口径。
- 产物：用户确认的职责域和真实办事流程。
- 暂停条件：职责只能用文件结构、runtime 术语或工具动作解释时，回到本步重写。

### SR-S4 盘点消费者与候选信号

- 交互模式：静默。
- 做什么：盘点 `SKILL.md`、references、scripts、contracts、templates、evals、test-prompts、tests、运行入口和下游消费者。
- 读取：判断载体时读取 `references/engineering-carrier.md`，只提取载体选择和消费者判定口径。
- 产物：消费者清单、候选问题信号、候选保留能力、候选删除项；这些只作为 SR-R1~SR-R10 的证据，不形成策略。
- 暂停条件：消费者或验证入口不明时，向用户说明缺口并停在本步。

### SR-R1 Trigger

- 交互模式：草案修正。
- 做什么：读取最新台账，共创何时触发、何时分流给相邻 Skill、创建/重写/拆分候选操作何时只能登记、何时必须后置到 SR-F1 裁决。
- 读取：`references/rubrics/trigger.md`，只提取 Trigger 环节 rubric。
- 产物：用户确认的 Trigger 最佳实践目标、保留能力、问题证据、候选策略和验证方式。
- 暂停条件：用户未确认触发边界和相邻分流前，不进入 SR-R2。

### SR-R2 Responsibility

- 交互模式：草案修正。
- 做什么：读取最新台账，共创职责域、负责事项、非目标、上下游边界和 owner 裁决权。
- 读取：`references/rubrics/responsibility.md`，只提取 Responsibility 环节 rubric。
- 产物：用户确认的 Responsibility 最佳实践目标、保留能力、问题证据、候选策略和验证方式。
- 暂停条件：职责边界会覆盖相邻 Skill 时，停下让用户裁决。

### SR-R3 Input

- 交互模式：草案修正。
- 做什么：读取最新台账，共创必要输入、来源、缺失阻断、禁止猜测项和上游责任边界。
- 读取：`references/rubrics/input.md`，只提取 Input 环节 rubric。
- 产物：用户确认的 Input 最佳实践目标、保留能力、问题证据、候选策略和验证方式。
- 暂停条件：关键输入缺失但无法由当前 Skill 合法补齐时，停止并说明需要谁补充。

### SR-R4 Flow

- 交互模式：草案修正。
- 做什么：读取最新台账，共创真实办事顺序、阶段闸门、失败分支和目标闭合条件。
- 读取：`references/rubrics/flow.md`，只提取 Flow 环节 rubric。
- 产物：用户确认的 Flow 最佳实践目标、保留能力、问题证据、候选策略和验证方式。
- 暂停条件：流程无法从真实职责推进到交付结果时，回到 SR-S3 重定义真实流程。

### SR-R5 Output

- 交互模式：草案修正。
- 做什么：读取最新台账，共创默认产物、消费者、人工摘要边界和机器结果事实源。
- 读取：`references/rubrics/output.md`，只提取 Output 环节 rubric。
- 产物：用户确认的 Output 最佳实践目标、保留能力、问题证据、候选策略和验证方式。
- 暂停条件：产物无消费者、字段无读取方或输出不能证明成功标准时，不进入 SR-R6。

### SR-R6 Resource

- 交互模式：草案修正。
- 做什么：读取最新台账，共创主 SOP、reference、script、schema、template、eval 和 test 的职责分层。
- 读取：`references/rubrics/resource.md` 与 `references/engineering-carrier.md`，只提取 Resource 环节 rubric 和载体选择口径。
- 产物：用户确认的 Resource 最佳实践目标、保留能力、问题证据、候选迁移/删除策略和验证方式。
- 暂停条件：同一内容被多个载体重复承载时，先裁决唯一消费者和保留位置。

### SR-R7 Determinism

- 交互模式：草案修正。
- 做什么：读取最新台账，共创哪些判断必须外移到脚本、schema 或测试，以及执行入口和失败结果。
- 读取：`references/rubrics/determinism.md`，只提取 Determinism 环节 rubric。
- 产物：用户确认的 Determinism 最佳实践目标、问题证据、外移清单、保留在 LLM 的判断项和验证方式。
- 暂停条件：可枚举判断仍只能靠文字提醒 LLM 时，不进入 SR-R8。

### SR-R8 Eval

- 交互模式：草案修正。
- 做什么：读取最新台账，共创 eval、test-prompts、dogfood、负例和回归测试如何证明新目标。
- 读取：`references/rubrics/eval.md`，只提取 Eval 环节 rubric。
- 产物：用户确认的 Eval 最佳实践目标、问题证据、测试更新策略、dogfood 证据和验证方式。
- 暂停条件：测试仍固化旧噪音或不能证明新目标时，不进入 SR-R9。

### SR-R9 Cleanup

- 交互模式：草案修正。
- 做什么：读取最新台账，共创旧引用、旧测试、历史说明、无消费者字段和 active 残留的清理策略。
- 读取：`references/rubrics/cleanup.md`，只提取 Cleanup 环节 rubric。
- 产物：用户确认的 Cleanup 最佳实践目标、问题证据、候选删除/迁移清单、风险和验证方式。
- 暂停条件：删除或迁移会影响 active 消费者且缺少裁决时，停止让用户确认。

### SR-R10 Runtime

- 交互模式：草案修正。
- 做什么：读取最新台账，共创 frontmatter、manifest、catalog、运行副本和运行记录是否与 active Skill 一致。
- 读取：`references/rubrics/runtime.md`，只提取 Runtime 环节 rubric。
- 产物：用户确认的 Runtime 最佳实践目标、问题证据、候选同步策略、运行验证方式和残留风险。
- 暂停条件：运行入口和运行副本无法同步验证时，不进入 SR-F1。

### SR-F1 整体策略冻结

- 交互模式：全共创。
- 做什么：汇总台账、SR-R1~SR-R10 的蓝图、候选策略、验证方式、风险和跨环节冲突，给出最终操作裁决卡，请求用户明确 `整体策略确认`。
- 读取：不读取新材料；只使用已确认的环节结论。
- 产物：冻结记录，包含 `final_operation`、目标承载、执行范围、排除操作及理由、全部环节确认、冻结前仅改台账、冻结后一次性执行范围。
- 暂停条件：存在未裁决冲突时，只请求该冲突裁决；未收到 `整体策略确认` 时，不得进入 SR-E1。

### SR-E1 一次性执行

- 交互模式：静默。
- 做什么：按冻结策略一次性修改文件，更新受影响的 tests、evals、test-prompts、引用路径、触发描述和运行清单。
- 读取：只读取冻结策略涉及的文件。
- 产物：文件变更、删除/迁移说明、`skill-refiner-result.json`。
- 暂停条件：执行中发现超出冻结范围的新问题时，停止并回到对应 SR-R 环节共创，不扩大修改范围。

### SR-V1 验收与交付

- 交互模式：静默后汇报。
- 做什么：按成功标准运行 fresh proving command，验证 `skill-refiner-result.json`，回看真实流程、消费者、确定性外移和残留噪音。
- 读取：验证失败时只读取本轮改动相关文件。
- 产物：验证结果、阻断项、残留风险，以及用问题定义卡排序后的下一轮候选环节。
- 暂停条件：验证失败时只汇报失败命令、失败原因和下一步，不得宣称完成。

## 输出
完成收口只在 SR-F1 用户明确 `整体策略确认` 后发生。SR-E1 后必须写入 `skill-refiner-result.json` 和本轮 `refinement-ledger.json`；字段规则由 `contracts/skill-refiner-result.schema.json` 和 `scripts/validate_refinement_result.py` 承载。
对话摘要只保留：共创基线、职责与真实流程、10 个环节结论、整体策略冻结、变更文件、验证结果、阻断项和残留风险。

## 完成校验
- [ ] SR-S2 和 SR-S3 已获得用户确认。
- [ ] SR-R1~SR-R10 每个环节都有用户确认的目标形态、保留能力、问题证据、候选策略和验证方式。
- [ ] `refinement-ledger.json` 已记录每个确认、覆盖关系、未决问题、最佳实践来源和 SR-F1 操作裁决卡。
- [ ] SR-F1 已获得用户明确 `整体策略确认`，且冻结前除台账外没有目标文件变更。
- [ ] SR-E1 只执行冻结范围内的创建、修改、迁移或删除。
- [ ] 已输出 `skill-refiner-result.json` 并运行 `python3 shared/skills/skill-refiner/scripts/validate_refinement_result.py <skill-refiner-result.json>` 通过。
- [ ] 已运行能证明本轮成功标准的 fresh proving command，并报告通过/阻塞状态。
