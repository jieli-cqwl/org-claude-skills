# Standard-chain Manual-first Content Readiness Evaluation Design

## Decision Summary

本设计回答一个前置问题：在投入自动化、正式行为评测或真实产品开发之前，现有 `standard-chain` 的内容是否已经足以指导合格 Agent 正确完成工作。

已确认的决策：

- 基于现有 `standard-chain` 评估，不另起一套理想流程。
- 采用“逐角色内容门禁 + 增量影子回放”，不直接跑完整链后再猜根因。
- 先人工跑通评估方法，再判断哪些稳定动作值得自动化。
- 产品与技术设计是业务方和 Agent 的共创阶段；执行阶段由 Agent 承担。
- 内容正确性、内容可执行性、工程约束一致性和行为效果分层判断，不相互冒充证据。
- 第一轮使用 `qft-tenants` 的“已占用房登记后续租客 + PC 办理入住复核”历史需求。
- 业务不变量与用户可观察结果是 Oracle；历史代码和测试只是实现证据，不是必须复刻的答案。
- 相同输入下允许不同表达和合理方案，但不允许关键决策无依据分叉；事实不足时必须进入同类询问、停止或退回路径。

本设计批准后只进入评估实施计划，不授权修改任何 Skill、启动真实产品开发、提交 `qft-tenants` 代码或宣布全链可投入生产。

## Goal

建立一套可复核的人工内容门禁，先判断当前 `product-director -> product-manager -> design -> test-design -> tech-lead -> delivery-owner` 在一个冻结复杂案例上是否存在内容阻断，并证明这套评估方法是否值得扩展到更完整的场景覆盖。单案例不直接签发无范围限定的行为评测准入。

最终要回答的不是“这些文档看起来是否专业”，而是：

> 给定声明范围内的输入、工具和业务决策，一个合格 Agent 能否从当前内容中确定下一步、事实真源、权限边界、产物、证据和失败去向，并把下游可直接消费的结果交出去。

## Proposed Capability Effectiveness Standard

本节是后续 `skill-quality-audit` 正式对齐的待批准能力标准，不是自带效力的 `confirmation_evidence`。用户审阅本设计并明确批准后，必须另建一份不可变批准记录，记录实际批准事件、设计 commit、能力 ID、Oracle atom ID 和接受范围。每个角色 alignment 的 `confirmation_evidence` 必须指向该批准记录的当前文件行，不能引用“批准即确认”一类预埋条件句。

批准记录只记录用户已经作出的决定，不重新要求用户审批评估术语。角色能力 ID 固定为：

| Capability ID | Role | Case-bounded Target Capability |
| --- | --- | --- |
| `SC-CAP-PD-001` | product-director | 把历史需求线索收敛为经确认的 WHY、成功标准、投入边界、范围和非目标，不进入产品或技术 HOW |
| `SC-CAP-PM-001` | product-manager | 把 Director 基线细化为可消费的业务对象、状态、规则、权限、异常、AC 和 UNIT，不改写锁定 WHY |
| `SC-CAP-DES-001` | design | 基于冻结产品事实与变更前代码提出并冻结可实施方案，不发明业务语义或把历史实现当唯一答案 |
| `SC-CAP-TD-001` | test-design | 把产品和设计基线转成可观察测试义务、typed gap、跨 UNIT 责任和证据要求 |
| `SC-CAP-TL-001` | tech-lead | 把冻结基线转成版本化计划、任务、依赖、批次和验证责任，并在目标漂移时停止 |
| `SC-CAP-DO-001` | delivery-owner | 在隔离影子状态中验证 intake、调度契约、证据新鲜度、失败回路、签署和禁止真实提交 |

### Real Task Scenario

一名掌握业务真相与价值决策的业务负责人，与一组 Agent 在已有产品和代码库中完成一个中等复杂、跨产品与技术层的功能需求：

- 涉及真实业务流程、对象、状态、权限和异常路径。
- 涉及 PC UI、API、领域逻辑、数据查询和副作用隔离。
- 产品与技术设计需要人机共创，不能让 Agent 私自补业务语义。
- 执行阶段由 Agent 完成，并在事实冲突、目标变化或证据失效时主动停止、反馈和回退。

### Success Criteria

1. 每个角色的关键指令都能还原为可执行决策，不依赖隐藏经验或口头补充。
2. 两个独立执行 Agent 在相同输入下不会出现无依据的关键决策分叉。
3. 输入不足、事实冲突或权限不属于当前角色时，Agent 能识别缺口并进入正确的询问、停止或退回路径。
4. 产品与设计阶段能提出真正改变决策的问题，并把业务负责人保留在业务语义、价值取舍、外部约束和风险接受的位置。
5. 当前角色产物能被下游直接消费；下游不需要猜字段语义、补全隐藏事实或依赖聊天记忆。
6. Skill、引用资料、Schema、脚本、Harness、运行时入口和下游消费者对关键约束没有冲突。
7. 影子回放结果不违反用户确认的业务不变量和用户可观察结果。
8. 全链只有在真实轨道未使用 Oracle 修补产物时，才能进入 `CASE_REPLAY_PASS`。

### Failure Modes

- Skill 写得流畅，但编码了错误的业务过程或错误的角色边界。
- 关键条件使用“必要时”“合理”“完整”等词，却没有可观察判据。
- 示例被 Agent 当成强制规则、默认值或穷举集合。
- 同一约束在 Skill、Schema、Harness 或下游消费者中含义不同。
- Agent 把推断当事实、替用户做价值决策或在缺信息时继续推进。
- 上游产物形式完整，但下游必须靠口头补充才能执行。
- 两个 Agent 恰好做出同一个错误决定，却因为结果一致被误判为通过。
- 历史实现被提前泄露给执行 Agent，回放退化成复述答案。
- 上游失败污染后续角色，导致无法定位缺陷所有者。
- 静态检查或一次成功回放被夸大成真实团队和生产交付能力。

### Unacceptable Risks

- 错误产品基线或错误技术设计被确认并向下游传播。
- Agent 静默扩大范围、改变业务规则或覆盖用户决策权。
- 目标或验收变化后继续使用旧计划、旧任务或旧证明。
- Harness 允许内容明确禁止的状态迁移，或禁止内容要求的正确路径。
- 评估过程写入活动 standard-chain 状态、修改目标 Skill、改动 `qft-tenants` 或产生真实提交。
- 使用受污染或不可复核的回放证据给出通过结论。

### Evidence Requirements

- 当前内容、运行时和消费者的 `path:line` 证据。
- 冻结的案例输入、Oracle、代码基线和历史变更引用。
- 两个独立执行结果及其实际读取的来源声明。
- 决策分叉、Oracle 对照、下游消费和 Harness 对齐记录。
- P0/P1 候选的主张拆解、反证检查和严重性校准。
- Schema、验证器或项目命令的实际输出；未执行的检查不得记为通过。

## First-principles Model

Skill 不是更长的 Prompt。对本评估而言，它是：

```text
决策内容 + 上下文路由 + 操作契约 + 确定性约束 + 失败恢复协议
```

自然语言无法保证每个字只有一种解释。评估目标是让所有会改变触发、决策、权限、状态、产物、验证和回退的语义具有唯一或显式允许的解释；不影响行为的表达差异可以存在。

### Responsibility Boundary

| Owner | Must Own | Must Not Be Used As A Substitute For |
| --- | --- | --- |
| LLM content | 业务语义理解、事实缺口发现、方案形成、受约束判断、结果综合 | 确定性状态校验、权限强制、格式完整性 |
| Harness | 调用边界、Schema、状态迁移、权限、证据绑定、可机械验证的不变量 | 错误或缺失的业务语义 |
| Business user | 目标、业务真相、价值取舍、外部约束、风险接受、基线变更 | Agent 应完成的资料整理、技术核验和流程操作 |

能机械检查的关键规则如果只存在于自然语言中，属于工程分层风险；Harness 恰好拦住一次错误，也不能反向证明内容正确。

## Scope

### Primary Role Gates

按以下顺序评估：

1. `product-director`
2. `product-manager`
3. `design`
4. `test-design`
5. `tech-lead`
6. `delivery-owner`

### Dependency Surfaces

`delivery-owner` 消费或调度的 `developer`、`verify`、`review`、`qa`、`fix`、`consistency-audit` 和提交接口作为依赖面检查。第一轮不对这些角色分别签发独立团队可用性结论；只有当其契约影响 `delivery-owner` 的内容可执行性或交付闭环时才进入发现。

### Content Package

每个主角色的评估对象不是孤立的 `SKILL.md`，而是：

1. 入口契约：描述、触发与不触发条件、前置状态、必需输入。
2. 决策正文：主 Skill 及执行时必须读取的规则和参考资料。
3. 产物契约：模板、Schema、字段语义、状态变化和下游消费者。
4. 执行约束：脚本、验证器、Hook、Harness、权限与运行时表面。
5. 当前证据：测试、Eval、Fixture、生命周期记录及其有效边界。

历史报告和 Skill 自述只能生成待验证主张，不能证明当前能力。

### Non-goals

- 不修改目标 Skill、Schema、脚本、测试、契约或运行时入口。
- 不创建或修改 `contracts/active-doc-scope.yaml`。
- 不把影子产物注册为活动 standard-chain 真源。
- 不执行真实开发、真实修复、真实提交或外部系统操作。
- 不在第一轮做多模型、多温度、多样本统计或 with-skill/without-skill 基准。
- 不优化 Skill 触发描述。
- 不用通用模板、行数、章节数量或某个优秀 Skill 的文风判断质量。
- 不把 `CASE_REPLAY_PASS` 表述成 team-ready、production-ready、full-chain-ready 或无范围限定的行为评测准入。

## Existing-path Decision

当前仓库已经有 `shared/skills/skill-quality-audit`。它负责单个 Skill 的正式内容审计、能力标准对齐、内容行为审计、证据等级、发现校准和修复交接。

本设计不复制一套竞争的评分体系：

- 每个主角色的内容审计复用 `skill-quality-audit`；静态证据先形成基线，回放后再用新增证据完成正式报告。
- 本设计新增的是跨角色的案例冻结、受控信息隔离、独立回放、分叉归因、下游消费和全链结论协议。
- `skill-creator` 的 with-skill/without-skill、量化断言和评审 Viewer 留到内容门禁通过后的行为评测阶段。

这条边界防止“审计工具重做一遍”和“内容尚未可信就急着跑模型分数”两种浪费。

## Minimum Evaluation Unit

关键内容按决策原子评估：

```text
触发条件
-> 依据的事实与真源
-> 决策所有者
-> 必须、允许或禁止的动作
-> 状态或产物变化
-> 完成证据
-> 失败、冲突或缺信息去向
-> 下游消费者
```

### Sentence Classification

每个有意义的句子先分类为：

- Trigger
- Action
- Condition
- Gate
- Output
- Evidence
- Reference Route
- Failure Handling
- Necessary Why
- Example

解释和示例不得暗中引入规范性要求。无法归类且没有消费者、阻错作用或输出作用的内容记为注意力噪音候选，不因“写得专业”而保留。

### Traceability

每个关键决策原子必须能追到：

```text
原始内容 -> 决策原子 -> 产物字段或状态 -> 下游消费者 -> 验证或 Harness
```

缺失环节意味着该规则无法证明被执行或消费。

## Historical Case Contract

### Case Identity

- Case ID: `QFT-QMI-PC-001`
- Name: 已占用房登记后续租客 + PC 办理入住复核
- Shape: 已有产品、中等复杂、跨 PC UI / API / 领域 / 数据 / 副作用 / 回归测试

### Proposed Business Oracle Atoms

以下 atom 是待用户批准的第一轮业务 Oracle。批准记录必须逐项列出接受状态和 `business_confirmation_ref`；没有批准记录的 atom 只能是候选，不能进入正式 Oracle。若真实业务记忆与已批准 atom 冲突，按 Rebaseline 规则版本化 Oracle。

| Atom ID | Business Invariant | Observable Assertion | Scope And Exclusion | Historical Support Boundary |
| --- | --- | --- | --- | --- |
| `QFT-INV-001` | 已占用房允许登记租期不重叠的下一任或后续租客 | 不重叠提交成功；任一日期落入同房间有效租客闭区间时拒绝，包括一方结束日等于另一方开始日 | 只覆盖 PC 发起和后端最终判定；页面预检不能代替服务端提交时校验 | 历史代码和测试只支持可行性与旧系统字段映射，不定义业务真相 |
| `QFT-INV-002` | 后续租客保持待搬入语义，不提前替换当前租客 | 登记成功后新租客可独立识别，房间当前租客、当前占用判断和当前租客展示不变 | 不强制复刻 `is_delete=-2`；它是历史实现映射，不是唯一技术方案 | 结果提交可证明一种状态实现 |
| `QFT-INV-003` | 待搬入登记不得提前取得当前房间资源权益 | 登记成功后不得为新租客执行门锁密码、梯控、设备租客关系、水电起算和当前租客清理计划 | 不禁止与“登记记录本身”绑定且不改变当前资源的必要数据 | 后端副作用隔离测试提供实现证据 |
| `QFT-INV-004` | 登记后的目标租客必须可从租客维度找回 | 租客合同列表刷新、筛选或搜索后可找到本次租客；从该租客记录进入详情仍显示同一目标租客 | 无列表权限时不要求入口；房间详情仍可展示当前租客 | PC 列表、路由和查询变更只提供支持证据 |
| `QFT-INV-005` | PC 办理入住复核使用用户选中的目标租客 | 从待搬入租客记录发起复核时携带明确租客标识；标识缺失或与房间不匹配时 fail closed，不回退为房间当前租客 | 普通房间入口未指定目标租客时保持旧路径 | PC review context 测试提供支持证据 |
| `QFT-INV-006` | 同房间冲突并发不能产生双成功或失败残留 | 两个租期冲突请求并发提交时最多一个成功；失败请求不新增业务数据、不发送消息、不触发外部动作 | 不要求特定锁、事务或幂等实现 | 后端并发、保存和副作用测试提供支持证据 |
| `QFT-INV-007` | 三种租赁模式共享待搬入隔离结果 | 集中式、整租、合租均满足 `QFT-INV-002`、`QFT-INV-003` 和 `QFT-INV-006` | 模式特有字段和既有差异不要求统一 | 三种模式的历史测试只证明现有实现覆盖 |
| `QFT-INV-008` | 空房登记旧行为不能回归 | 保存时房间无当前租客则继续产生当前租客和当前资源的原有完整登记结果 | 不借本需求重设计空房登记 | 历史回归测试与变更前基线提供支持证据 |

### Evidence Boundary

`qft-tenants` 当前“将搬入”文档包含后续扩展和未闭合范围，且晚于部分历史实现，不能整体当作历史需求或 Oracle。以下引用只作为候选事实和实现证据入口：

- 业务证据候选：`qft-tenants@a387e1403d9bcf4a2b3816749054c88fd3b01f31:docs/feature--将搬入--0629/登记租客闭环/登记租客闭环--PRD.md`，文件 SHA-256 为 `bb451b968112296dc03d78659d85792a1e1d0300881c805653244244b151aacf`。只有被 Oracle atom 明确引用的行摘录可以进入候选证据。
- PC 变更前基线：`qft-app@380e2458502a5b46751afa366f8f8535c4590eed`。
- PC 结果快照：`qft-app@fda108fbc4978cd41e60ddc4cc197cb93e973065`。
- PC 变更锚点：`4963626adb7d514d26dfcab22b027ba1eb29e9dc`、`fda108fbc4978cd41e60ddc4cc197cb93e973065`。
- 后端变更前基线：`qft-all@377ec4801a79f73649c22496c837e32d677bf5fd`。
- 后端结果快照：`qft-all@e34b45255f14c680edbd1630357d96a10a8b2982`。
- 后端变更锚点：`f3240c69799cc794f3048d7d00d71bd06e42b821`、`da4a4ca22f87edb162c9834c77f7d20eac64e79f`、`e34b45255f14c680edbd1630357d96a10a8b2982`。

后端基线到结果快照之间含中间提交。案例准入必须逐提交或逐路径标记 `relevant`、`supporting`、`unrelated`；未标记的中间变化不得进入 Oracle，也不得让执行 Agent看到。历史代码证明一种可行实现，不限制 Agent 提出更好的等价设计。

### Explicit Exclusions

- 不把整个“将搬入”项目作为第一轮范围。
- 不把 Android、iOS、鸿蒙和 H5 完整覆盖作为本案例通过条件。
- 不把当前 PRD 中无法从冻结历史变更证明的短信、后续扩展或未闭合清单自动纳入 Oracle。
- 不要求实现文件、类名、代码组织或具体技术方案与历史提交一致。

## Evidence Workspace

### Approval Recording Gate

用户审阅书面设计并明确批准后、写实施计划前，创建并提交唯一批准记录：

`docs/superpowers/specs/2026-07-14--standard-chain-manual-content-readiness-evaluation--approval-record.md`

该记录必须包含用户实际批准原文、批准时间、已批准 design commit、六个 Capability ID、八个 Oracle Atom ID 和任何排除项。它是后续 formal alignment 的唯一人工确认真源；评估工作区只保存引用，不复制批准正文。若用户要求修改设计，旧记录失效，修改后的 design 必须重新批准。

正式回放使用一个单一证据根目录：

`tools/eval/results/standard-chain-content-readiness-2026-07-14-QFT-QMI-PC-001/`

目录结构固定为：

```text
run.json
case/
  confirmation-ref.json
  input-manifest.json
  oracle-manifest.json
  source-classification.json
roles/
  <role>/
    surface.json
    decision-atoms.json
    content-audit-alignment.json
    content-audit-report.json
    content-audit-summary.md
    executor-a/
    executor-b/
    divergence-review.json
    oracle-review.json
    downstream-consumption.json
    role-verdict.json
bridges/
shadow-phase/
  artifact-registry.json
  delivery-state.json
  artifacts/
chain-verdict.json
summary.md
```

只保存引用、摘要、必要摘录、摘要哈希和生成产物，不复制完整代码库或制造第二份业务真源。`run.json` 和 artifact manifest 必须把所有影子产物标为 `evaluation_only`；canonical artifact 本体保持现有 Schema，不强塞未声明字段。影子状态只能写入该证据根目录，不得注册到活动文档目录或 `contracts/active-doc-scope.yaml`。

`run.json` 是评估运行状态真源；`summary.md` 只是人类阅读投影。

## Controlled Information Isolation

共享文件系统不能提供安全级双盲。因此本设计使用“受控信息隔离”，不宣称密码学或进程级盲测。

### Isolation Evidence Level

每个 replay attempt 在开始前必须记录一种隔离等级：

| Level | Required Mechanism | Allowed Claim |
| --- | --- | --- |
| `ENFORCED` | 执行环境只挂载 allowlist 输入，读取禁区在机制上不可达 | 可支持独立推导和 case-bounded pass |
| `OBSERVED` | 可信运行器完整记录所有文件、提交和工具读取，审查者能检查无禁区访问 | 无污染时可支持 case-bounded pass |
| `DECLARED_ONLY` | 只有 Agent 自报读取来源，无可信完整访问日志 | 只能形成诊断信号，不得支持 `CONTENT_PASS` 或 chain pass |

新 Agent、`fork_turns="none"`、独立目录和自报来源只是隔离卫生措施，不会自动把等级提升为 `OBSERVED`。实施计划必须先证明所选运行器能达到哪个等级；做不到 `ENFORCED` 或 `OBSERVED` 时，本轮允许完成静态审计和诊断回放，但全局状态只能是 `BLOCKED_ISOLATION`。

### Executor Visibility

执行 Agent 只能被任务包授权读取：

- 当前角色的内容包；
- 该角色在真实时点应获得的上游投影；
- 冻结的变更前代码视图；
- 用户在当前共创节点给出的回答。

执行 Agent 不得读取 Oracle manifest、历史结果提交、另一执行 Agent 的输出或审查结果。执行任务使用新 Agent、`fork_turns="none"` 和显式允许引用，减少本对话与历史答案污染。

### Reviewer Visibility

Oracle 审查者在两个执行结果完成后读取：

- 两份执行结果；
- 用户确认的业务不变量；
- 历史差异与测试证据；
- 当前 Skill、契约和下游消费者。

### Contamination Rule

执行结果必须声明实际读取的文件、提交和命令。`OBSERVED` 还必须附可信访问日志。发现读取 Oracle、结果快照、另一执行结果或未授权历史材料时，当前 attempt 标记 `VOID_CONTAMINATED` 并由新 Agent 重跑；不得转成角色通过、失败或警告。

同一 lane 最多允许初始 attempt 加两次新 Agent 重跑。三次均受污染时，全局进入 `INCONCLUSIVE_CONTAMINATED`。`VOID_CONTAMINATED` 是 attempt 状态，不是角色 verdict，也不能错误归因成 Skill 缺陷。

## Per-role Evaluation Protocol

### Step 0: Case Admission

1. 冻结业务不变量、范围、排除项、输入基线和结果证据。
2. 分类历史提交和路径，排除无关变化。
3. 验证所有引用可读取，记录仓库和提交哈希。
4. 冻结当前 `org-claude-skills` revision、每个角色内容包摘要和运行时契约摘要；内容变化会使受影响结果失效。
5. 对可变业务文档记录相关行摘录和文件摘要，不以未冻结工作树作为稳定证据。
6. 构造变更前只读代码视图。
7. 若准入阶段发现业务 Oracle 冲突，请求用户裁决；技术证据冲突由评估负责人先查证。回放后新出现的业务冲突按 Rebaseline 规则处理。

案例未准入时，任何角色不得开始回放。

### Step 1: Pre-audit And Static Content Gate

按 `skill-quality-audit` 建立并验证角色能力对齐，完成静态范围和风险基线：

- 能力标准来自本设计和角色在标准链中的真实消费者。
- 收集完整内容包和运行时表面。
- 提取并追踪关键决策原子。
- 检查 Instruction Hygiene、Attention Economy、Behavior Induction、Capability Effectiveness 和 Runtime Integration。
- P0/P1 候选必须经过主张拆解、当前证据反证和严重性校准。

静态证据已经证明 P0、无法检查核心表面或内容无法产生可执行输入时，真实轨道停止；诊断轨道可继续，但必须使用显式 Oracle Bridge。此时的静态基线不是最终角色报告，不能提前给出 `CONTENT_PASS`。

### Step 2: Independent Multi-turn Execution

两个新执行 Agent 分别进入独立多轮 lane，接收完全相同的起始任务包和内容版本。共创角色必须遵守当前 Skill 的逐轮提问规则，不得为了评测方便一次性倾倒问卷。

评估负责人作为历史案例的 Business Proxy，只能从已批准 Oracle 中按事实键回答当前 Agent 实际提出的问题：

- 不主动补充未被询问的事实；
- 不透露历史技术实现、结果提交或另一 lane 的问题；
- Oracle 没有答案时只返回 `unknown`；
- 缺失事实属于业务权力且会改变结果时，才中断并请求用户；
- 两个 lane 可以形成不同对话顺序，但收到的同一业务事实必须一致。

每个 Agent 完成当前角色时必须输出：

- 已确认事实及真源；
- 推断、假设、未知和冲突；
- 需要用户决定的问题；
- 当前角色可自行完成的判断；
- 候选方案、推荐和取舍依据；
- 对应的 evaluation-only 标准产物；
- 继续、停止或退回结论；
- 逐轮问题、回答和状态变化记录；
- 实际读取来源声明。

用户只回答真正属于业务权力的问题，不替 Agent 整理资料、补流程或做普通技术核验。

### Step 3: Divergence Adjudication

| Divergence | Classification |
| --- | --- |
| 不同表达、等价语义 | Allowed variation |
| 不同合理方案，Skill 明确允许且依据充分 | Allowed trade-off |
| 事实不足，双方进入同类询问、停止或退回 | Correct uncertainty handling |
| Skill 明确但一方违反 | Model behavior signal |
| 内容存在两个合理关键解释 | Content ambiguity |
| 双方一致但违反业务 Oracle | Content or shared reasoning defect |
| 双方进入不同权限、状态或交接路径 | High-risk divergence |

模型行为信号不自动升级为内容缺陷；内容歧义也不能因为某个 Agent 恰好选对而被掩盖。

### Step 4: Oracle Review

审查者只比较：

- 业务不变量和用户可观察结果；
- 必要的产品、状态、权限和副作用边界；
- 历史实现揭示但 Skill 输入未提供的事实缺口；
- 历史实现中的妥协、缺陷或非唯一技术选择。

不得按文件名、类名、代码结构或与历史实现的表面相似度评分。

### Step 5: Downstream Consumption

下一角色只接收上游 evaluation-only 产物和正式声明的引用，不接收聊天摘要或审查者口头解释。检查它是否能：

- 定位单一真源；
- 区分已确认、候选和未知；
- 确认权限与当前状态；
- 开始自己的职责或正确退回；
- 不重复发明上游事实。

需要审查者口头补充即判定交接缺陷。

### Step 6: Final Content Audit

把独立执行、分叉归因、Oracle 对照和下游消费证据并入当前角色的 `content_behavior_audit`，完成正式 `skill-quality-audit` 报告并运行 alignment/report validator。报告必须保留单案例和影子执行的证据边界，不得把它们升级成一般团队可用性证明。

### Step 7: Role Verdict

角色只允许：

- `CONTENT_PASS`
- `CONTENT_FAIL`
- `BLOCKED_ORACLE`
- `BLOCKED_EVIDENCE`
- `BLOCKED_ISOLATION`

不使用含糊的 `conditional pass`。非阻塞优化项可以记录，但不能掩盖关键路径缺陷。

每个 verdict 必须声明：

- `verdict_scope: case_bounded_content_readiness`
- `case_id: QFT-QMI-PC-001`
- 当前 Skill 包版本和内容摘要
- 是否依赖 Oracle Bridge

`CONTENT_PASS` 只证明当前角色在本案例和已确认能力标准内未发现内容阻断，可以进入更广的内容覆盖检查；不证明该 Skill 的全部场景已经 team-ready，也不直接授权正式行为评测。

## Authentic And Diagnostic Tracks

### Authentic Track

真实轨道只使用当前 Skill 产生并通过门禁的产物。任一角色 `CONTENT_FAIL` 或 `BLOCKED_*` 时，真实轨道停止。单个 `VOID_CONTAMINATED` attempt 先按重跑规则处理；超过上限才停止整条轨道。

### Diagnostic Track

为了继续检查后续角色，评估负责人可以创建 `oracle-bridge`：

- 明确列出修正了哪些缺失或错误事实；
- 引用对应 Oracle；
- 标记污染范围和依赖角色；
- 不伪装成上游真实输出。

所有依赖 Bridge 的后续结果只能定位后续内容问题，不能计入端到端通过。

## Role-specific Human Checkpoints

| Role | Human Decision |
| --- | --- |
| product-director | 根问题、目标、成功标准、投入边界、范围与非目标 |
| product-manager | 产品语义、规则冲突、可观察验收和产品交付接受 |
| design | 业务事实确认、外部约束、质量优先级、关键风险和最终方案选择 |
| test-design | 仅在验收语义或风险接受缺失时参与 |
| tech-lead | 接受计划版本与影响业务交付节奏的取舍 |
| delivery-owner | 接受残余风险和影子交付结论；不得授权真实提交 |

上表定义真实使用时的人类权力，不要求业务负责人充当影子回放操作员。历史回放默认由已批准 Oracle 代理已发生的业务决定；只有 Oracle 缺失、互相冲突，或出现会改变业务结果的新价值取舍时才请求用户。

如果 Skill 把普通资料整理、代码事实核验、测试设计或工程判断转嫁给用户，记录为角色边界缺陷。

## Delivery-owner Shadow Boundary

`delivery-owner` 的核心职责包含真实调度和证据闭环，而本阶段禁止实现和提交。因此第一轮采用“交付证据演练”，不是实时交付：

1. 在证据根目录建立隔离 `shadow-phase`，写入现有 Schema 可验证的 Artifact Registry、Delivery State、计划、任务和运行证据；不得使用活动 Registry 或 State。
2. Case Admission 必须先证明当前 validator 和 preflight 能显式指向该 shadow phase；若只能解析活动状态，停止并记录 `HARNESS_MISMATCH`，不能伪造通过。
3. 使用前序角色生成的 evaluation-only 计划和任务，运行真实 intake 和 baseline consistency preflight。
4. 冻结历史差异和测试结果只能作为待检查目标。Developer、Verifier、Review、QA 和 Consistency Auditor 证据必须由对应影子 owner 在只读目标上产出；stated-fact fixture 只能测试明确标记的单一路径，不能冒充 owner-produced 全闭环证据。
5. 允许 `delivery-owner` 更新 shadow Registry 和 State，检查其能否正确形成任务包、处理失败回路、识别过期证据和生成签署投影。
6. 所有 `/commit` 动作必须停留在 `would_dispatch` 投影，不得执行。

`delivery_owner_coverage` 只允许 `FULL_SHADOW_CONTRACT` 或 `INTAKE_ONLY`。前者要求上述 shadow Registry/State 和 owner-produced 证据闭环全部可验证，才有资格获得 case-bounded `CONTENT_PASS`；后者只能证明 intake、拒绝或单一 fixture 路径，必须阻断 `CASE_REPLAY_PASS`。

即使达到 `FULL_SHADOW_CONTRACT`，它也只能评估内容和状态契约是否可执行，不能证明真实代码修改、修复循环、外部 QA 或提交能力。后者必须进入正式行为评测和受控真实试点。

## Defect Classification

发现按根因而不是症状归类：

- `CONTENT_WRONG`: 内容编码了错误目标、流程、权限或结果。
- `CONTENT_AMBIGUOUS`: 关键语义存在多个合理解释。
- `CONTENT_MISSING`: 决策所需条件、动作、证据、失败或交接缺失。
- `CONTENT_NOISE`: 无消费者、重复、冲突或削弱注意力的内容。
- `REFERENCE_ROUTING_GAP`: 引用时机或提取目标不清楚。
- `HANDOFF_GAP`: 下游不能无口头补充地消费。
- `HARNESS_MISMATCH`: 内容与 Schema、脚本、Hook、权限或状态机冲突。
- `MODEL_BEHAVIOR_SIGNAL`: 内容明确但某次 Agent 未遵循，留给行为评测。
- `ORACLE_GAP`: 业务真相或历史证据不足，不能归罪于 Skill。
- `HISTORICAL_IMPLEMENTATION_DEFECT`: 历史结果违反当前业务 Oracle。

P0/P1 只保留经过反证检查且影响安全使用、输出正确性、验证或下游闭环的发现。纯措辞和美观问题不得虚高严重性。

## Pass Gates

### Role `CONTENT_PASS`

必须同时满足：

1. `skill-quality-audit` 正式报告与对齐产物验证通过。
2. 无未关闭 P0/P1，Instruction Contract、Content Behavior Induction 和 Runtime Integration 不低于现有 `fit` 门槛。
3. 关键决策原子可追溯，没有隐藏前提或互相矛盾的强制语义。
4. 两个独立执行结果没有无依据关键分叉。
5. 结果不违反业务 Oracle；允许的技术差异有明确依据。
6. 下游可直接消费，不依赖聊天记忆、审查者补充或 Oracle Bridge。
7. 内容与确定性约束没有未解决的关键冲突。
8. 决定性 replay attempt 的隔离等级是 `ENFORCED` 或已审查无禁区访问的 `OBSERVED`。
9. `delivery-owner` 还必须满足 `delivery_owner_coverage: FULL_SHADOW_CONTRACT`。

P2/P3 可以存在，但必须证明不改变关键决策、状态、权限、产物、验证和回退结果。

正式审计总 verdict 如果仅因多样本行为证据或真实现场证据尚未执行而是 `conditional`，不自动阻断本案例的 `CONTENT_PASS`；若 `conditional` 来自 P1、指令契约、内容行为、运行时或交接缺陷，则必须阻断。`unfit` 或 `blocked` 不得与 `CONTENT_PASS` 并存。

### Chain `CASE_REPLAY_PASS`

必须同时满足：

1. 六个主角色均为 `CONTENT_PASS`。
2. 真实轨道从 Director 输入到 Delivery Owner 影子结论未使用任何 Oracle Bridge。
3. 用户参与只发生在声明的人类决策点。
4. 全链一致性审计未发现真源漂移、权限越界、状态矛盾或证据过期。
5. 证据运行可由另一审查者从 `run.json` 和引用重新检查。
6. 每个决定性 replay attempt 的隔离等级是 `ENFORCED` 或已审查无禁区访问的 `OBSERVED`。

该状态只意味着“当前冻结案例没有发现阻断，且评估方法可以扩展”，不意味着 Agent 团队已经可投入使用。

### Broader Content Coverage Gate

签发无 case 限定的 `READY_FOR_BEHAVIOR_EVAL` 前，必须另行：

1. 定义目标需求空间的场景覆盖分母，至少覆盖正常正向链路、上游事实缺失或冲突、目标/范围/AC 变更、下游证据失效和相邻流程不应触发五类风险。
2. 增加至少一个业务 Oracle 独立、需求形态正交的真实历史案例。
3. 证明首案例发现的评估方法没有只适配租客登记领域。
4. 汇总 case-bounded 结果与现有角色交互 Eval，但不得用角色局部绿灯替代完整链证据。

本设计只授权首案例和方法验证，不签发 `READY_FOR_BEHAVIOR_EVAL`。

### Global States

- `REPAIR_REQUIRED`: 至少一个当前内容或 Harness 缺陷阻断真实轨道。
- `BLOCKED_ORACLE`: 业务真相不足，无法判断正确行为。
- `BLOCKED_EVIDENCE`: 必需文件、提交、测试或运行时表面不可验证。
- `BLOCKED_ISOLATION`: 运行器只能提供 `DECLARED_ONLY`，无法证明执行 Agent 未读取 Oracle。
- `INCONCLUSIVE_CONTAMINATED`: 同一 lane 三次 attempt 均受污染，当前结果不可判定。
- `CASE_REPLAY_PASS`: 当前 case-bounded 真实轨道通过，可进入更广内容覆盖检查。

## Rebaseline And Error Handling

- 用户修正业务不变量：创建新版 Oracle，失效所有受影响的下游结果并从所有者角色重跑。
- 历史实现与业务 Oracle 冲突：记录历史实现缺陷，不要求 Skill 复刻。
- Skill 与 Harness 冲突：真实轨道停止；不能选择“方便的一边”。
- 执行 Agent 读取禁区：当前结果作废，使用新 Agent 重跑。
- 某次 Agent 违反明确指令：记录行为信号；只有内容本身允许错误解释时才记内容缺陷。
- 下游发现上游缺口：回到上游所有者；不得在下游静默补丁。
- 用户给出新的目标、范围、AC、设计或任务：按当前 standard-chain 所有权路由并要求新鲜证据。

## Evaluation Sequence

```text
Design approval
-> Case admission and Oracle freeze
-> product-director static gate + replay + handoff
-> product-manager static gate + replay + handoff
-> design static gate + replay + handoff
-> test-design static gate + replay + handoff
-> tech-lead static gate + replay + handoff
-> delivery-owner static gate + evidence rehearsal
-> full-chain consistency audit
-> REPAIR_REQUIRED / BLOCKED_* / INCONCLUSIVE_CONTAMINATED / CASE_REPLAY_PASS
```

真实轨道失败后，诊断轨道可以继续完成剩余角色检查，但最终状态仍是 `REPAIR_REQUIRED` 或 `BLOCKED_*`。

## Verification Plan

### Design Artifact Verification

本设计文档提交前：

- 扫描 `TODO`、`TBD`、占位符和互相冲突的结论。
- 检查所有引用路径和提交存在。
- 检查范围、Oracle、通过门禁和完成声明相互一致。
- 运行仓库 quick gate；若失败，区分本次文档变更与存量问题。
- 检查 `git diff` 只包含本设计文档。

### Future Evaluation Verification

实施阶段必须验证：

- Case manifest、Oracle manifest、role verdict 和 chain verdict 的结构完整性。
- 每个正式 `skill-quality-audit` alignment/report validator 通过。
- P0/P1 当前文件证据可重新打开并匹配。
- 决策原子到下游消费者的引用可达。
- 两个执行 Agent 的起始输入摘要哈希一致；多轮 Business Proxy 对同一事实键的回答一致。
- 受污染结果不会进入聚合结论。
- Bridge 依赖、`DECLARED_ONLY` 隔离或未关闭污染 attempt 会阻止 `CASE_REPLAY_PASS`。
- `qft-tenants` 工作区无任何评估产生的修改或提交。

未实际执行的验证保持 `unknown`，不得写成 PASS。

## Risks And Trade-offs

- 单历史案例能发现内容缺陷，但不能估计稳定成功率；因此只能进入更广内容覆盖检查，不能直接进入正式行为评测。
- 共享文件系统的受控隔离不是强盲；污染声明和新 Agent 只能降低风险，不能消除风险。
- 双 Agent 和逐角色审查成本高，但能把 Skill 缺陷、模型失误、Oracle 缺口和历史实现问题分开。
- 静态审计复用现有 `skill-quality-audit`，减少重复机制；如果它自身阻碍本目标，应先记录审计工具缺陷，不能悄悄绕过。
- 严格真实轨道可能很早停止；诊断 Bridge 保留后续检查能力，但绝不能拿来拼装假绿全链。
- 当前案例后半程依赖历史证据演练，无法证明真实交付调度。这是刻意保留的证据边界，不是遗漏。

## Implementation Boundary

用户批准本设计并提交 Approval Recording Gate 规定的批准记录后，下一步只能调用 `writing-plans` 生成实施计划。计划应优先完成：

1. 建立证据工作区和最小 JSON 契约。
2. 冻结 `QFT-QMI-PC-001` 案例、Oracle 和代码视图。
3. 用 `product-director` 跑通一次完整角色门禁，验证方法本身。
4. 方法无致命缺陷后按角色顺序扩展，失败时保留真实/诊断双轨。
5. 首案例结论形成后，先决定修 Skill 还是扩大内容覆盖；只有通过 Broader Content Coverage Gate 后才设计正式行为评测或受控试点。

实施计划不得自动升级为 Skill 修复计划。评估发现必须先形成可审查结论，修复属于后续独立设计与计划。
