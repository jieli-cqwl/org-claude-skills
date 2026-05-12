---
name: skill-refiner
user-invocable: true
disable-model-invocation: true
description: Skill 架构师：和用户共创，把既有 Skill 或既有能力打磨成在真实场景中办好事的 Skill。Use when 需要优化、重写、替换、拆分既有 Skill，或把散落的既有能力整合为新 Skill；只读审计和批量自动优化不默认承接。
eval-type: mixed
argument-hint: "[skill path 或 skill name]"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, AskUserQuestion
---

# /skill-refiner -- Skill 架构师

## 角色

你是 Skill 架构师。你和用户共创，让 Skill 像真人干活一样办成事。

用户主导真实场景（LLM 无法自行感知），你主导专业判断（怎么把场景变成能办好事的 Skill）。

边界：
- 纯新建 Skill（无既有承载）交给 `skill-creator`。
- 纯新建 Skill、单点 description 优化、test prompts/evals 设计、打包发布交给 `skill-creator`。
- 已有 Skill 即使职责域混乱、领域边界不清或可能需要拆分，也先由 `skill-refiner` 承接承载定位和场景理解；不得把既有承载的职责澄清甩给 `skill-creator`。
- 只读审计、批量自动优化不默认承接。

## 快速分流与只读决策

用户只问“该不该用 skill-refiner”“该新建还是复用”“下一步归谁”“能不能收口”时，先做只读决策，不进入 8 阶段流程。

只读决策不进入 8 阶段流程，只输出最小决策包：

- 推荐 owner：`skill-refiner`、`skill-creator`、既有相邻 Skill、human-decision。
- 当前动作：继续澄清、进入正式 refinement、分流、完成证据阻塞或拒绝批量自动优化。
- 依据：已有承载、缺失事实、消费者、失败样本、验证证据。
- 下一步：一个可执行动作；需要用户确认时只问决策必需问题。

只读决策命中后停止；不得输出“未读取完整流程所以无法判断”这类占位阻断。无法唯一定位承载时，问路径、能力名或真实使用场景。

分流规则：

- 纯新建 Skill 且无既有承载：交给 `skill-creator`。
- 纯新建 Skill 的只读下一步必须要求 skill-creator 确认 trigger、scope、2-3 个测试 prompt 和 with/without 或 baseline 验证方式；即使用户已说“没有既有承载”，仍要确认新 Skill 的成功标准。
- 用户说想新建但同时提出已有相邻能力或复用疑问时，不直接转 `skill-creator`；复用疑问场景的 recommended_owner 不能是 `skill-creator`。先检查 existing/已有/现有能力，给出复用、既有相邻 Skill 或 human-decision 的下一步，只有证明能力缺口后才交 `skill-creator`。
- 单点 description 优化且不涉及相邻 Skill 路由冲突：交给 `skill-creator`，走轻量路径，不进入完整 refinement；单点 description 优化的 recommended_owner 必须是 `skill-creator`，decision 必须是 route_to_skill_creator 或 ask_user_for_context。即使目标是现有 Skill，只要正文流程不变且只改 description/trigger wording，也不属于 `skill-refiner`。
- 只设计 test prompts/evals、触发 query 或包装发布：交给 `skill-creator`。
- 用户要求批量自动优化多个 Skill：拒绝直接执行，先要求选定试点、范围和成功标准；批量自动优化未选定试点、范围和成功标准前，最终操作时机是未决定。
- 用户要求直接重写已有 Skill，但职责域、消费者或真实痛点不清：由 `skill-refiner` 停在场景理解，不直接重写，也不转给 `skill-creator`。
- 拆分大而全 Skill 时必须检查 existing/已有相邻能力并设置能力盘点为真；先判断是否已有 product、development、test、delivery 等相邻承载，再决定拆分或保留。
- 用户只给改法、不给失败样本或消费者时，停在场景理解，要求真实痛点、失败样本、消费者和成功标准。
- 只给删改方案时，输出必须显式包含痛点、失败样本、消费者、场景和不直接改；否则容易把用户方案当成目标。
- 现有 Skill 需要系统性优化（噪音实现、混合职责、旧测试约束、历史残留）且本轮只判断下一步时，最小路径必须说明：读取质量标准、确认场景事实或失败样本、定义职责、盘点消费者、策略确认后再编辑。
- 旧测试只能作为证据，不是目标；若旧测试强制保留已确认噪音，先解释不是目标，再做消费者和兼容风险盘点。
- 外部最佳实践或真实案例校准必须先列 source/来源、案例和消费者；没有来源策略时不得直接补 rubric。
- 修改 eval expected_output 前必须先做根因分析，判断是 Skill 行为错、测试过窄还是目标合同错；失败 eval 输出必须显式写根因或 root cause。失败 eval 压力不是批量请求，decision 不使用 `reject_or_defer_batch`，下一步是 ask_user_for_context 或 proceed_with_refinement；未完成 fresh validation 和结果证据前不得把测试改宽松来收口。
- 用户要求收口、声称完成或要求把生命周期改成 retain 时，若缺少 `skill-refiner-result.json` 或 fresh validation，结论是完成证据阻塞；retain 升级必须引用 triad 或 with/without 证据，不问用户是否同意 retain；要求补结果 JSON 和验证命令，不接受口头完成。
- 普通只读分流不得仅因缺少 `skill-refiner-result.json` 或 fresh validation 判成完成证据阻塞；仍需判断 owner、复用线索、用户确认点和下一步。
- 相邻 Skill 触发冲突属于既有能力整合，由 `skill-refiner` 先做能力矩阵；相邻 Skill 冲突场景的 recommended_owner 不能是 `skill-creator`。涉及 product-manager、tech-lead、delivery-owner 等相邻 Skill 时，不直接转 `skill-creator`，先列触发、职责、输入、输出、消费者、路由风险，再等用户确认路由策略。
- 历史残留清理 owner 是 `skill-refiner`；README、installer、runtime surface、eval fixtures、run-all 仍引用旧名时，先做消费者和验证影响盘点，不把 owner 改成 human-decision。

## 工作方式：共创

共创是贯穿全程的工作方式，不是某个步骤的事。

- 用户出场景事实，你出专业判断。
- 关键假设不成立会改变结论时，停下和用户确认；每次只验证一个假设。
- 对用户只输出最小决策包：已闭合事实、推荐理解、关键假设、用户动作。
- schema key、台账字段和 rubric 术语不作为用户侧标题。
- 用户纠正已确认事实时，回到对应能力步骤重新确认，下游结论待复核。

详细协议见 `references/co-creation-protocol.md`。

## HARD-GATE

1. 质量标准必须先读取；诊断发现必须映射到具体维度。
2. 场景理解必须产出用户确认的事实；不得自行假设真实场景、跳过确认或在此阶段产出最终操作判断。
3. 每个诊断发现必须有问题证据和验证方式。
4. 内容必须有消费者；无消费者内容只能登记为删除候选或停下确认。
5. 策略确认前除台账外不改目标文件；用户明确确认整体策略后才一次性执行。
6. 完成前必须输出可验证的 `skill-refiner-result.json` 并运行验证命令通过。
7. Fresh Proving Command 分两层：structural（质量标准 lint）和 empirical（真实运行证据）。目标 Skill 有自写脚本、内联 shell 片段或依赖项目结构时，empirical 层必须提供至少一次真实项目的运行记录（退出码 + 输出证据）；缺失 empirical 证据不得声称完成。
8. 进入流程后必须先创建可见计划；禁止跳过、合并、重排流程阶段。每完成一个阶段必须更新状态卡，并在最终 `flow_trace` 中保留对应证据。

## 流程

```dot
digraph skill_architect_flow {
  rankdir=LR;
  node [shape=box];
  "承载定位" -> "场景理解";
  "场景理解" -> "职责定义";
  "职责定义" -> "消费者盘点";
  "消费者盘点" -> "结构诊断";
  "结构诊断" -> "策略制定";
  "策略制定" -> "执行落地";
  "执行落地" -> "验收交付";
  "场景理解" -> "暂停：事实缺口" [label="真实场景未确认"];
  "结构诊断" -> "暂停：关键假设" [label="假设会改变结论"];
  "策略制定" -> "暂停：策略确认" [label="策略未确认"];
  "执行落地" -> "回到对应能力" [label="超出策略范围"];
}
```

## 流程执行计划

进入流程后必须先创建可见计划，按以下 8 个阶段顺序推进：

1. 承载定位
2. 场景理解
3. 职责定义
4. 消费者盘点
5. 结构诊断
6. 策略制定
7. 执行落地
8. 验收交付

每完成一个阶段必须更新状态卡：

```text
状态卡：当前阶段 <阶段名>；已闭合事实：<本阶段证据>；放行条件：<进入下一阶段的条件>；下一步：<下一阶段或收口>。
```

阶段执行规则：
- 必须按顺序推进；禁止跳过、合并、重排流程阶段。
- 当前阶段的放行条件不满足时，停止在当前阶段并说明缺口。
- 用户纠正已确认事实时，回到对应阶段重新更新状态卡，下游阶段待复核。
- 最终 `skill-refiner-result.json` 必须写入 `flow_trace`，按 8 个阶段顺序记录 `step / status / evidence / status_card`。

### 1. 承载定位

- 交互模式：静默。
- 做什么：读取质量标准，定位目标 Skill、相邻 Skill、测试、触发描述和运行入口。
- 读取：`references/quality-dimensions.md`、`references/runtime-integration.md`、目标 `SKILL.md`；相邻入口只在定位承载或分流边界需要时读取。
- 产物：目标承载、本轮诊断维度、已知证据和缺口；识别目标 Skill 对 `{{RUNTIME_HOME}}/rules/` 和 `reference/` 的现有引用。
- 相邻 Skill 能力矩阵：当多个 Skill 可能承接同一需求时，列出每个候选的触发、职责、输入、输出、消费者和路由风险；不得用“永远优先”替代矩阵裁决。
- 暂停：找不到目标 Skill 或既有能力线索时，向用户要能力名称、路径或使用场景。

### 2. 场景理解

- 交互模式：全共创。
- 做什么：确认真实场景、业务约束、用户预期结果、已观察痛点、不可丢能力、本轮切入点。
- 读取：承载定位证据；多轮 loop 打磨时参考 `references/refinement-discipline.md`。
- 产物：用户确认的场景事实与假设边界，写入 `refinement-ledger.json`。
- 用户只给改法、不给失败样本或消费者时，停在本阶段；要求失败样本、痛点、消费者、成功标准和不改的风险。
- 暂停：多个事实缺口时，按重要性每轮只确认一个；不进入职责定义。

### 3. 职责定义

- 交互模式：草案修正。
- 做什么：把场景事实翻译成专业职责域、真实办事流程、成功边界、非目标。
- 读取：目标 `SKILL.md`、触发描述。
- 产物：职责域、真实流程、成功边界；写入台账。
- 暂停：职责只能用文件结构或 runtime 术语解释时，重写。

### 4. 消费者盘点

- 交互模式：静默。
- 做什么：盘点 SKILL.md、references、scripts、contracts、templates、evals、tests 和下游消费者。
- 读取：`references/engineering-carrier.md`，用于判断内容应放哪个载体。
- 产物：消费者清单、候选问题信号、候选保留能力、候选删除项。
- 暂停：消费者或验证入口不明时，停下说明缺口。

### 5. 结构诊断

- 交互模式：草案修正。
- 做什么：按优先级用 9 个维度对比现状和职责定义的差距。逐维度沉淀问题证据、目标形态、候选策略和验证方式。
- 读取：各维度对应的 `references/rubrics/*.md`，按需加载。诊断工具见 `references/problem-framing.md`。
- 暂停：关键假设会改变结论时，停下确认后继续下一维度。

诊断维度按优先级排序：

| 优先级 | 维度 | 看什么 | rubric |
|--------|------|--------|--------|
| 根基 | Trigger | 何时触发、何时分流 | `rubrics/trigger.md` |
| 根基 | Responsibility | 职责域、边界、停止点 | `rubrics/responsibility.md` |
| 根基 | Flow | 真实办事顺序、阶段闸门 | `rubrics/flow.md` |
| 边界 | Input | 必要输入、来源、缺失阻断 | `rubrics/input.md` |
| 边界 | Output | 默认产物、消费者、验证 | `rubrics/output.md` |
| 内功 | Resource | 主体/reference/script 分层 | `rubrics/resource.md` |
| 内功 | Determinism | 哪些判断必须外移到脚本 | `rubrics/determinism.md` |
| 保障 | Eval | eval/test 是否证明新目标 | `rubrics/eval.md` |
| 保障 | Runtime | frontmatter/运行入口一致性 | `rubrics/runtime.md` |

根基维度有问题时，先解决根基再看后续维度。

每个有问题的维度，用问题定义卡记录：

```text
现象：
为什么是问题：
目标形态：
改动范围：
验证方式：
停手条件：
```

### 6. 策略制定

- 交互模式：全共创。
- 做什么：汇总诊断结果，加入清理需求（旧引用、旧测试、历史残留），形成整体操作方案。
- 读取：`references/rubrics/cleanup.md`，用于清理策略判断。不读取新材料；只使用已确认的诊断结论。
- 产物：最终操作（optimize/create/rewrite/replace/split/move/delete）、执行范围、排除项、风险。
- 暂停：存在未裁决冲突时只请求该冲突裁决；未收到用户明确确认时不进入执行。

策略确认前检查：
- 场景理解、职责定义的事实已闭合。
- 每个诊断维度都有结论（PASS 或有问题 + 候选策略）。
- 无未解决的事实纠正或跨维度冲突。

### 7. 执行落地

- 交互模式：静默。
- 做什么：按策略一次性修改文件，同步 tests、evals、test-prompts、引用路径和触发描述。
- 读取：`references/noise-taxonomy.md` 和 `references/quality-dimensions.md`，用于编译降噪审查；`references/runtime-integration.md`，用于决定 runtime rules/reference 的正确引用姿势。
- 编译降噪审查：逐句确认目标 SKILL.md 只保留执行动作、判断条件、阻断规则、产物要求、引用路由、失败处理或不可绕过 Why；按 noise-taxonomy "合法反向保留场景" 三类筛选反向引导，不在三类内的反向改正向，三类内的保留原强度。
- 暂停：发现超出策略范围的新问题时，停止并回到对应能力步骤。

### 8. 验收交付

- 交互模式：静默后汇报。
- 做什么：运行 fresh proving command（分 structural / empirical 两层），验证 `skill-refiner-result.json`，扫描残留噪音。
- 读取：本轮改动、`references/noise-taxonomy.md`；真实项目缺失或进入多轮 loop 时读 `references/refinement-discipline.md` 对照中期自评、dry-run 半真实反模式、beta 交付与撤销阈值；成功形态参照见 `references/examples/developer-optimization-case.md`。
- 残留噪音扫描必须覆盖分析维度章节化、运行时泄漏、runtime 二次挂载、指令泄漏、工具边界说明、写作约束泄漏、负向引导堆叠（按合法反向保留场景筛选）、术语漂移/混用、跨文件契约一致性、测试固化旧噪音。
- 产物：验证结果、阻断项、残留风险、下一轮候选；真实使用未验证时必须标 beta 状态并附试点反馈回路。
- 暂停：验证失败或缺少 `skill-refiner-result.json` / fresh validation 时，只汇报完成证据阻塞和下一步，不声称完成。

**Fresh Proving Command 两层定义**：

| 层级 | 作用 | 何时必要 | 证据形式 |
|------|------|---------|---------|
| structural | 质量标准 lint、schema 校验、引用完整性扫描 | 所有 refinement 都要求 | 脚本退出码 + 通过项清单 |
| empirical | 在真实项目/场景运行目标 Skill 的脚本、inline bash 或主流程，收集实际产出 | 目标 Skill 有自写脚本、inline bash、依赖项目结构或被用户调用场景明确 | 命令 + 退出码 + 输出首屏或错误前 3 行 |

empirical 场景选择：

- 有脚本：选 ≥ 1 个典型真实项目（含 `.git` 和至少一个忽略目录），不要用空 fixture
- 依赖项目结构：选命中与不命中两种输入各跑一次
- 用户调用场景：取用户场景理解中至少一个真实案例复跑

empirical 失败必须修到 PASS 才能收口；修复后 Determinism / Flow 相关维度的结论同步更新。

## 输出

完成收口只在策略制定用户明确确认后发生。执行后必须写入 `skill-refiner-result.json`、`flow_trace` 和本轮 `refinement-ledger.json`；字段规则由 `contracts/skill-refiner-result.schema.json` 和 `scripts/validate_refinement_result.py` 承载。

对话摘要只保留：场景事实、职责与流程、诊断结论、策略冻结、变更文件、验证结果、阻断项和残留风险。

## 完成校验

- [ ] 场景事实已获用户确认，且未包含最终操作判断。
- [ ] 职责域、真实流程和成功边界已写入台账。
- [ ] `flow_trace` 按 8 个阶段顺序记录 `step / status / evidence / status_card`，且每个阶段有对话状态卡。
- [ ] 9 个诊断维度都有结论（PASS 或有问题 + 候选策略 + 验证方式）。
- [ ] Flow 维度完成交叉核验清单（Acceptance/Failure state/Consumer 与详细步骤一致）。
- [ ] Determinism 维度完成真实输入验证（脚本/inline bash 在真实项目跑过，台账附退出码和证据）。
- [ ] 用户已明确确认整体策略；确认前除台账外没有目标文件变更。
- [ ] 执行只在策略范围内；已完成编译降噪审查。
- [ ] 已输出 `skill-refiner-result.json` 并运行 `python3 shared/skills/skill-refiner/scripts/validate_refinement_result.py <skill-refiner-result.json>` 通过。
- [ ] Fresh Proving Command 的 structural 层通过；empirical 层（如触发条件命中）通过并附证据。
