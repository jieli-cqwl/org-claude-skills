# test-design 独立职责必要性调研报告

> 调研模式：analysis
> 呈现模式：decision

## 这次要回答的问题
- 核心问题：`shared/skills/test-design` 在当前 standard-chain 中是否值得保留为独立角色，而不是并入 `design / tech-lead / developer / qa`。
- 调研目的：为后续和用户共创 role/contract 收敛提供判断框架、边界定义和偏差诊断。
- 交叉视角：1）真人团队里产品/架构设计后，测试同步把测试用例整理成开发自测与测试冒烟验收的共享标准；2）软件工程 / 项目管理 / 测试分析与测试设计实践；3）社区常见做法与角色边界。
- 当前读者：standard-chain 流程 owner、skill owner、contract/gate owner。

## 当前判断
- 当前结论：建议保留，但必须收窄为“开发前测试义务冻结 + 设计可测试性缺口裁决 + QA handoff owner”。
- 是否建议现在采取动作：是。
- 一句话判断：在当前 standard-chain 里，`test-design` 的独立价值不在“多写一份测试文档”，而在“在 planning 前，用独立于架构设计、任务拆分、代码实现和提测验收的视角，冻结一份可被 developer 自测与 QA 验收共同消费的测试真源”。

## 决定性理由
| 理由 | 为什么关键 | 证据指向 |
|------|-----------|---------|
| 前置时点独立 | `test-cases.json` 在 `tech-lead` 前产出，直接影响计划拆分，而不是实现后补救 | E1, E2, E5 |
| 视角独立 | `design` 关注 HOW 架构，`tech-lead` 关注任务拆分，`developer` 关注实现，`qa` 关注独立执行与 release recommendation；测试义务若由这些角色“顺手补”都会被本角色目标污染 | E2, E3, E4, E5, E6, X1 |
| 多消费者复用 | 同一份 `test-cases.json` 同时被 `tech-lead / developer / qa / delivery-owner` 消费，属于共享验收尺子，而不是单人笔记 | E1, E7, E8 |
| 当前链路已把它定义成 owner | `qa` 被明确禁止自定义测试义务；缺失 QA handoff 时要回退给 `test-design`，说明它在当前合同里不是可选角色 | E3, E9 |

## 最大风险与保留意见
- 最大风险：如果 `test-design` 继续把 QA 阶段编排、release readiness closure 之类内容也一并冻结，它会从“前置测试义务 owner”膨胀成“半个 QA / 半个 delivery-owner”。
- 不适用场景：如果未来 `design.json` 本身就能稳定承载可执行示例、测试条件和 QA handoff，且 `tech-lead`/`qa` 对独立 `test-cases.json` 不再产生行为变化，则独立角色价值会下降。
- 翻案条件：出现一轮真实 pilot 证明“去掉独立 `test-design` 后，设计缺口发现率、developer 自测质量、QA reopen 率都不变或更好”，且 contract/gate 没有新增复杂度。

## 建议动作
- 现在该做什么：保留 `test-design`，但按“测试分析/测试设计 owner”重定义职责边界，不再把它当第二个 `design` 或提前替 `qa` 做执行编排。
- 采纳前必须补的验证：
  1. 加厚 canonical `test-cases.json` schema/template，让它真的能承载“可执行测试标准”；
  2. 解决 UNIT 级产物与跨 UNIT 旅程测试之间的粒度错位；
  3. 做一轮 shadow pilot，比对“保留独立 test-design”与“并入 tech-lead”两种链路的 reopen / replan / late design-gap 指标。
- 若不行动的代价：角色名看似独立，但 machine contract 仍然偏薄，最终会退化成“流程里多一个步骤、却没有多一份真实判断”。

## 拆解对象概览
- 对象类型：项目方法 / 角色边界 / skill 治理。
- 原始观点：`test-design` 只有在承担其他角色不适合顺手替代的独立职责时，才值得保留为单独 skill。
- 需要回答的问题：
  1. 独立价值判断框架是什么；
  2. 若保留，最佳角色定义、输入输出、上下游边界是什么；
  3. 若不保留，最合理并入哪个 skill，代价是什么；
  4. 当前 `shared/skills/test-design` 的关键偏差是什么。

## 核心判断依据

### 1. `test-design` 的独立价值判断框架

把一个角色保不保留，不先看“文档是否好看”，而看它是否同时通过以下 5 个判断维度：

| 维度 | 要问的问题 | 通过意味着什么 | 当前 `test-design` 判断 |
|------|-----------|---------------|------------------------|
| 前置时点 | 这个判断是否必须发生在 planning / coding / QA 之前？ | 晚了就只能补救，不能作为前置标准 | 通过 |
| 视角去偏 | 如果交给设计 owner、计划 owner、实现 owner 或验收 owner，会不会重写验收尺子？ | 需要独立视角防止“自己给自己出题” | 通过 |
| 多消费者复用 | 这份输出是否同时改变多个下游角色行为？ | 说明它是共享合同，不是个人草稿 | 通过 |
| 缺口回流 | 是否需要从“可测试性/可验证性”视角把问题回打给上游？ | 说明它不是执行细节，而是上游闭环的一环 | 通过 |
| 机器可裁决 | 这份输出是否值得被 schema/gate/test 固化成真源？ | 说明它不是可有可无的说明文档 | 部分通过 |

结论：当前 `test-design` 在前 4 个维度都成立，第 5 个维度只“部分成立”——不是角色不值得保留，而是当前 contract 还不够厚，尚未完全承载它声称的价值。

### 2. 为什么在当前 standard-chain 里它不是其他角色可顺手替代的

| 角色 | 该角色当前主责 | 为什么不能顺手替代 `test-design` |
|------|---------------|------------------------------|
| `design` | 冻结模块边界、接口契约、质量属性、迁移/验证/回滚方案 | `design` 负责 HOW 层决策，不负责 AC 级正例/反例/边界、排除项验证、QA stage obligation 的细化；如果由它兼做，设计工件会被测试细节淹没 |
| `tech-lead` | 评审设计，拆 `plan.json / tasks.json`，冻结 Task 追踪链与证明命令 | `tech-lead` 是计划 owner；若同时定义测试真源，会自然偏向“任务可拆”而不是“义务可证伪”，设计缺口也更容易被吞进计划 |
| `developer` | 按 Task 做 TDD，实现并自测 | `developer` 必须消费既定 AC/test_ref 做 RED→GREEN；若反过来由它定义 canonical 测试义务，就会把实现偏好写成验收标准 |
| `qa` | 基于真实运行路径做独立执行、风险判断和 release recommendation | `qa` 是独立执行与放行判断 owner，不应同时决定“该测什么”；当前 QA hard-gate 也明确禁止自己猜测义务 |

这与真人团队常见实践并不矛盾。Scrum 把 verification 与 increment 质量放在整个 Scrum Team / Developers 责任内，但同时强调团队内部自管理分工，而不是新增组织外包角色；因此“保留团队内测试设计 owner”与 whole-team quality 并不冲突。BDD 的官方表述强调 shared understanding、concrete examples 与 executable specification，这与“先冻结共享测试标准，再由开发与验收共同消费”的做法一致。放回当前 standard-chain，上述三类视角汇成同一个判断：`test-design` 应该是团队内、开发前、面向多消费者的测试义务 owner，而不是第二个 `design`，也不是提前执行 `qa`。

### 2.1 三类视角的汇总结论

| 视角 | 最强支持点 | 最强挑战点 | 当前判定 |
|------|-----------|-----------|---------|
| 真人团队协作 | 产品/架构冻结后，测试把用例整理成开发自测与测试冒烟共享标准，能减少“各自脑补验收口径” | 也可能由 tech lead 或 senior dev 顺手写掉，不必单设角色 | 只有当这份标准会被多个下游角色复用且能回打 design gap 时，独立 owner 才成立 |
| 软件工程 / 测试设计实践 | Scrum 支持团队内自管理分工；BDD 支持用 shared examples / executable specification 冻结共享标准 | whole-team quality 容易被误读成“谁都可以定义测试义务” | 不冲突。共同负责质量，不等于取消测试义务 owner |
| 社区常见角色边界 | `design → test-design → tech-lead → developer / qa` 让“定义义务”和“执行义务”分层 | 角色过多会膨胀流程，若 contract 太薄会变成形式步骤 | 当前仓库只有在 `test-cases.json` 真能改变 `tech-lead / developer / qa` 行为时，保留才有意义 |

结论回到用户给定判断标准：是否存在 design / tech-lead / developer / qa 无法顺手替代的独立职责。当前答案是“有”，但这个独立职责不是“多写一份可读文档”，而是“在 planning 前冻结共享测试义务，并对 design 的可测试性缺口做独立裁决”。

### 2.2 对当前 shared/skills/test-design 的独立价值判断框架

把是否保留 `shared/skills/test-design` 收敛成一个可复用判定框架：

| 判断维度 | 通过标准 | 不通过信号 | 当前判断 |
|---------|---------|-----------|---------|
| 时点必要性 | 不在 planning 前冻结就只能事后补救 | 放到 tech-lead / developer / qa 也不影响后续行为 | 通过 |
| 角色独立性 | 由 design / planning / implementation / execution owner 兼任会扭曲测试义务 | 任一上游 owner 顺手做也不会带偏 | 通过 |
| 多消费者复用性 | 同一份输出被 `tech-lead / developer / qa / delivery-owner` 消费 | 只是单个角色的工作笔记 | 通过 |
| 缺口回流能力 | 能把 `DESIGN-GAP / DESIGN-GAP(EQ)` 在开发前回流给 design | 缺口只能在实现或提测阶段暴露 | 通过 |
| 合同厚度 | schema / template / gate 能稳定承载和校验该职责 | 角色说得重，machine contract 却很薄 | 部分通过 |

因此，独立价值是否成立，不看“test-design 文档是否更好读”，而看它是否同时满足：前置、独立、共享、可回流、可裁决。当前前四项成立，第五项只部分成立。问题不在“该不该保留角色”，而在“当前 contract 是否配得上这个角色”。

### 3. 若保留，最合理的角色定义、输入输出与边界

#### 3.1 推荐角色定义
`test-design` 最合理的定义是：

> 开发前测试分析 / 测试设计 owner。负责把 `brief + phase-prd + UNIT + design` 转成可复用的测试义务真源，供 `tech-lead` 拆计划、`developer` 做自测、`qa` 做独立执行；并从可测试性视角识别真实设计缺口并回流上游。

#### 3.2 推荐输入 / 输出

| 项目 | 推荐定义 |
|------|---------|
| 核心输入 | `brief.json`、`phase-prd.json`、`UNIT-*.json`、`design.json` |
| 核心输出 | `unit-{N}/test-cases.json` |
| 输出中的必须保留面 | `ac_coverage_matrix`、`equivalence_matrix`、`test_cases`、`qa_handoff_contract`、`design_gap_report`、`special_test_triggers` |
| 输出中的推荐强化面 | 每条 test case 的前置条件、输入/操作、期望结果、断言点、关联 AC / scope / design ref |

#### 3.3 应当承担的独立职责
1. 冻结 AC 级正例 / 反例 / 边界与排除项验证义务。
2. 冻结从设计到测试的映射：哪些 `design_ref / manager_vp_ref / scope_item_id` 必须被验证。
3. 识别真实 `DESIGN-GAP / DESIGN-GAP(EQ)`，并把问题回流给 `design`，而不是静默下沉到计划或开发。
4. 冻结 QA handoff 的最小合同：
   - 必测义务是什么；
   - 触发源是什么；
   - 哪些场景 `browser_required`；
   - QA 至少需要拿到什么证据。

#### 3.4 不应承担的职责
1. 不重做架构设计，不决定模块/接口/迁移方案。
2. 不拆 Task，不写 `proving_command`，不决定并行策略。
3. 不产出 release recommendation，不替 QA 做独立风险判断。
4. 不把“完整 QA 执行编排”提前写死成自己的主职责。

### 4. 若不保留，最合理并入哪个 skill，代价是什么

| 并入候选 | 适配度 | 主要代价 | 结论 |
|---------|-------|---------|------|
| `tech-lead` | 最高 | 计划 owner 兼任测试真源 owner，容易把“义务设计”降成“任务拆分附属品”；设计缺口会更晚暴露；QA handoff 更容易变成 planning 副产物 | 最可行，但代价明确 |
| `design` | 中 | 架构决策与可执行测试细节混在一份工件里，`design.json` 会明显变重；设计 reviewer 也要背测试细节 | 不优先 |
| `qa` | 低 | 太晚；失去开发前自测/计划基线作用；QA 独立性反而变差 | 不建议 |
| `developer` | 极低 | 实现者定义自己的验收标准，直接破坏独立性 | 不成立 |

结论：如果一定要合并，最合理的并入对象是 `tech-lead`，因为它与 `test-cases.json` 的消费关系最近；但这本质上意味着你接受“放弃独立测试设计视角，换少一个 phase”。

### 5. 对当前 `shared/skills/test-design` 的关键偏差诊断

#### 偏差 1：canonical contract 比角色承诺薄很多
当前 `SKILL.md` 把 `test-design` 描述成“开发自测与 QA 验收的直接标准”，但当前 canonical schema/template 对关键字段要求明显偏薄：
- `contracts/canonical/schemas/planning/test-cases.schema.json` 中，`test_cases[]` 只强制 `case_id + title`；
- `equivalence_matrix[]` 只强制 `class`；
- `design_gap_report.gaps[]` 只要求是 object array，没有稳定结构；
- `contracts/canonical/templates/planning/test-cases.template.json` 里的样例也仍停留在极简 shape。

这意味着当前机器真源并不能稳定承载“前置条件 / 输入操作 / 期望结果 / 断言目标 / 关联 AC / scope / design ref”这些真正可执行的测试设计信息。独立角色的价值在说明层很强，在 contract 层却被削弱了。

#### 偏差 2：词汇与枚举存在语义漂移
`shared/skills/test-design/projections/test-cases-template.md` 把 AC 覆盖状态写成 `COVERED / PARTIAL / DESIGN-GAP`，而 schema 的 `unit_coverage_view.coverage_status` 枚举是 `COVERED / UNCOVERED / DESIGN_GAP`。这会导致：
- 人看模板和机看 schema 不一致；
- `PARTIAL` 到底是不是合法状态不清楚；
- `DESIGN-GAP` 与 `DESIGN_GAP` 存在命名漂移。

这类漂移会直接削弱 `test-design` 作为稳定真源的可信度，尤其是在 projection 被人类当成运行口径时。

#### 偏差 3：当前 gate 与 fixture 把 QA handoff 推向“执行编排”而不只是“义务冻结”
当前问题不只在 `SKILL.md` 文案，还落到了 gate / fixture：
- `shared/skills/test-design/scripts/completion_check.sh` 明确要求 `qa_handoff_contract` 覆盖 `QA_A / QA_B / QA_C / QA_D` 四个阶段；
- `tests/fixtures/standard-chain-pilots/login-homepage-pilot/phase-1/unit-1/test-cases.json` 里直接把 `release readiness closure` 写进 `qa_handoff_contract`；
- `shared/skills/test-design/projections/test-cases-template.md` 也把阶段义务写得接近完整执行编排。

这会让 `test-design` 从“冻结该测什么、何时必须浏览器执行、至少要拿到什么证据”膨胀成“提前替 QA 和 delivery-owner 编排怎么测、测到哪一步才算收口”。

更合理的边界应是：
- `test-design` 冻结最小必测义务与执行模式门槛；
- `qa` 负责独立执行、风险加测与最终 release recommendation；
- `delivery-owner` 负责交付期收口与阶段编排。

#### 偏差 4：UNIT 级产物和跨 UNIT 旅程义务之间存在粒度错位
当前 `test-design` 输出是 `unit-{N}/test-cases.json`，而 `qa` 明确支持通过 `test_cases_refs` 组合多 UNIT 义务执行 `QA_B / QA_C / QA_D`。这说明系统已经承认会出现跨 UNIT 旅程、跨步骤状态流转和 phase 级回归义务，但 `test-design` 仍只有 UNIT 级真源承载位。

现在的做法可以工作，但职责上会出现一个结构性问题：
- `test-design` 需要定义一部分跨 UNIT 旅程；
- 但它缺少 phase-level test-design artifact 来稳定承载这类旅程；
- 最终只能让 `qa` 在执行期再聚合，这会削弱“开发前冻结共享标准”的目标。

这说明当前粒度设计还没完全对齐它的职责模型。

#### 偏差 5：archive 与现行 fixture 之间存在历史漂移，说明角色边界仍在收敛中
归档中的旧 `docs/archive/login-homepage-pilot/phase-1/unit-1/test-cases.json` 甚至缺少当前 schema 已要求的 `positive_case_refs / negative_case_refs / boundary_case_refs` 与 `review_round / convergence_evidence`。这不应作为当前真源，但它说明一件事：`test-design` 的 contract 近几轮仍在快速演化，角色边界还没有完全稳定下来。

因此，对当前 `shared/skills/test-design` 的治理判断不应是“角色已成熟，只需修修文案”，而应是“角色方向大体成立，但 contract / gate / fixture / projection 仍需一起收口”。

## 吸收建议

### 可以直接吸收
| 论点/做法 | 适用条件 | 如何吸收 |
|-----------|---------|---------|
| 保留独立 `test-design` | 仍需要 `developer` 自测与 `qa` 验收共用一份测试真源 | 继续保持 `design → test-design → tech-lead` 顺序 |
| `test-design` 拥有 `TC` / `qa_handoff_contract` / `DESIGN-GAP` authority | 仍沿用 canonical artifact + gate | 保留 `TC` authority 和 QA 缺失义务时回退 `test-design` 的规则 |
| `test-design` 必须在 planning 前完成 | 仍需要它改变 `tech-lead` 行为 | 保留 `tech-lead` 对 `test-cases.json` 的必需输入关系 |

### 改写后吸收
| 原始做法 | 改写后的做法 | 改写原因 |
|---------|-------------|---------|
| 冻结完整 QA_A-D 编排 | 只冻结最小必测义务、触发条件、`browser_required` 门槛和证据预期；详细执行计划交给 `qa` | 防止侵入 QA 独立性 |
| 用很薄的 schema 承载“直接标准” | 把 `test_cases` / `equivalence_matrix` / `design_gap_report` 加厚为可执行合同 | 让 machine truth 真正配得上角色价值 |
| 用 UNIT 级产物同时承载 phase 级旅程 | 为跨 UNIT 旅程补 phase-level aggregation 或稳定聚合规则 | 消除粒度错位 |

### 不采纳
| 论点/做法 | 不采纳理由 |
|-----------|-----------|
| 把 `test-design` 并入 `developer` 或 `qa` | 会直接破坏独立视角，且时点过晚 |
| 让 `design` 或 `tech-lead` 顺手补测试义务但不改 contract | 只会把职责漂移藏起来，不会真的减少复杂度 |

## 落地行动项
- P0：重写 `test-design` 的角色定义，明确它是“开发前测试义务 owner”，不是第二个 `design`，也不是提前替 `qa` 编排全部执行阶段。
- P0：加厚 `contracts/canonical/templates/planning/test-cases.template.json` 与 `contracts/canonical/schemas/planning/test-cases.schema.json`：
  - `test_cases[]` 至少要求 `unit_ref / ac_refs / scope_item_ref / case_type / preconditions / action / expected_result / assertion_target`；
  - `equivalence_matrix[]` 至少要求 `related_ac_refs / mapped_case_refs / invariant / status`；
  - `design_gap_report.gaps[]` 至少要求 `gap_type / blocking_ref / owner / next_action`。
- P0：统一 `coverage_status` 与 `DESIGN-GAP` 词汇表，消除 projection / schema / gate 漂移。
- P1：把 phase 级跨 UNIT 旅程测试从 UNIT 工件中拆出聚合承载方式，或补一层 phase-level test-design projection/contract。
- P1：做 shadow pilot：同一需求分别走“保留独立 test-design”和“并入 tech-lead”两条链，比较 `late design-gap`、`developer self-test drift`、`QA reopen`、`replan` 成本。

## 审计附录

### 论点挑战总表
| 论点 | 最强支持证据 | 最强反方挑战 | 当前判定 | 对我们的启示 |
|------|-------------|-------------|---------|-------------|
| `test-design` 应保留为独立角色 | 当前链路把它放在 `design` 与 `tech-lead` 之间，且 `qa` 被禁止自定义义务 | Scrum 强调 whole-team quality，似乎不必单独设角色 | 成立 | 保留“角色内 owner”，但不要误解成“团队外 QA 部门” |
| `test-design` 的核心价值是 developer/QA 共用标准 | `tech-lead / developer / qa` 都消费 `test-cases.json` | 当前 canonical schema 太薄，尚未完全证明“直接标准” | 成立，但 contract 偏薄 | 先加厚 contract，再谈角色稳定性 |
| 若合并，最佳去向是 `tech-lead` | 位置最近、消费最直接 | 计划 owner 会污染测试真源 | 部分成立 | 这是“最不坏”的合并，不是“无成本”的合并 |
| 当前实现已经处在最佳边界 | 已有 gate、identifier authority、QA handoff contract | QA orchestration 扩张、schema 偏薄、粒度错位仍明显 | 不成立 | 保留角色，不等于认可当前实现边界 |

### 独立挑战记录
| 挑战点 | challenger 质疑 | 原结论回应 | 是否调整 |
|--------|----------------|-----------|---------|
| whole-team quality 是否否定独立 `test-design` | Scrum 说 Developers/Team 对质量与 verification 负责，似乎不需要单独角色 | 不矛盾。这里保留的是“团队内测试设计合同 owner”，不是把质量外包；因此保留角色但反对把它做成组织孤岛 | 是 |
| 是否可以直接并入 `tech-lead` | 计划与测试都在开发前，合并后 phase 更少 | 可以，但代价是失去独立测试视角，并把 design-gap 暴露时点后移；因此判为“最不坏合并候选”，不是首选 | 是 |
| 当前 `qa_handoff_contract` 越详细越好吗 | 详细能减少 QA 猜测 | 详细到“完整阶段编排”会侵入 QA；应冻结最小必测义务，而不是提前替 QA 做整套执行方案 | 是 |
| 现在 schema 已有 gate，是否足够证明角色价值 | 已有 completion_check 和 contract tests | 不够。当前 gate 主要证明字段存在，不足以证明 test case 可执行 | 是 |

### 检索路径与覆盖证明
- 名称归一化：`test-design` / `test design` / `test-designer` / `测试设计` / `qa_handoff_contract` / `test-cases.json`。
- 已查对象类型：skill 定义、contracts、schema、template、hook/completion gate、fixture、历史设计文档、历史 research-report、外部流程/测试实践资料。
- 已查 discovery 入口：仓库代码搜索、`shared/skills/*`、`contracts/*`、`tests/*`、`docs/archive/*`、外部官方/准官方资料。
- 已排除候选：
  - 并入 `developer`：实现偏差过强，排除；
  - 并入 `qa`：时点过晚，排除；
  - “whole-team quality = 不需要测试设计 owner”：概念不成立，排除。
- 剩余盲区：
  - 还没有 fresh multi-unit live pilot；
  - 外部一手资料里，对 `test analysis / test design` 的术语定义本轮仍缺少可直接引用的 glossary / syllabus 正文；
  - 尚未量化比较“合并 vs 保留”两条链路的真实 reopen、replan、late design-gap 成本；
  - Martin Fowler 相关 acceptance test 页面本轮未成功抓到有效正文，因此没有把它作为硬证据使用。

### 项目上下文
- 技术栈：这是一个以 `SKILL.md + canonical JSON contract + completion gate + contract tests` 驱动的流程型仓库。
- 已有相关实现：当前 standard-chain 把主链固定为 `product-director → product-manager → design → test-design → tech-lead → delivery-owner → developer / verify / review / qa`，且 `TC` authority 已分配给 `test-design`。
- 约束条件：
  1. 不能靠口头说明证明角色价值，必须落到 artifact/gate/test；
  2. 用户判断标准不是“人类可读性”，而是“独立职责是否真实存在”；
  3. 设计、计划、实现、验收的 owner 分责已在当前链路中明确存在。

### 证据索引
- E1. `contracts/standard-chain.yaml`（2026-04-28 读取）
- E2. `shared/skills/test-design/SKILL.md`（2026-04-28 读取）
- E3. `shared/skills/qa/SKILL.md`（2026-04-28 读取）
- E4. `shared/skills/design/SKILL.md`（2026-04-28 读取）
- E5. `shared/skills/tech-lead/SKILL.md`（2026-04-28 读取）
- E6. `shared/skills/developer/SKILL.md`（2026-04-28 读取）
- E7. `contracts/identifiers.yaml`（2026-04-28 读取）
- E8. `shared/runtime/standard-chain-catalog.json`（2026-04-28 读取）
- E9. `docs/standard-chain-flow-optimization/2026-04-27-preflight-noise-regression/design.md`（2026-04-28 读取）
- E10. `tests/test-design-skill-governance-redesign.sh`（2026-04-28 读取）
- E11. `contracts/canonical/templates/planning/test-cases.template.json`（2026-04-28 读取）
- E12. `contracts/canonical/schemas/planning/test-cases.schema.json`（2026-04-28 读取）
- E13. `shared/skills/test-design/scripts/completion_check.sh`（2026-04-28 读取）
- E14. `shared/skills/test-design/projections/test-cases-template.md`（2026-04-28 读取）
- E15. `tests/fixtures/standard-chain-pilots/login-homepage-pilot/phase-1/unit-1/test-cases.json`（2026-04-28 读取）
- E16. `docs/archive/login-homepage-pilot/phase-1/unit-1/test-cases.json`（2026-04-28 读取，仅用于说明历史漂移，不作为现行真源）
- E17. `tests/test-standard-chain-foundation-registry.sh`（2026-04-28 读取）
- E18. `tests/test-qa-browser-gate-contract.sh`（2026-04-28 读取）
- E19. `shared/skills/test-design/references/methodology.md`（2026-04-28 读取）
- X1. Scrum Guide 2020 — https://scrumguides.org/scrum-guide.html （2026-04-28 抓取）
- X2. Cucumber BDD Docs — https://cucumber.io/docs/bdd/ （2026-04-28 抓取）
- X3. ISTQB Glossary / CTFL 入口页（仅确认术语入口存在，未拿到可引用定义正文）— https://glossary.istqb.org/ （2026-04-28 抓取）
- X4. ISTQB Foundation Level certifications page（仅高层范围，未直接给出术语定义）— https://www.istqb.org/certifications/certified-tester-foundation-level （2026-04-28 抓取）
