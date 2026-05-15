# Stage 1 Eval Case Pack v1：首轮岗位胜任力用例包

日期：2026-05-14

## 目标

本文件把 `stage-1-eval-cases-v0.md` 的单条纵切校准样例扩展为首轮可执行 case pack。

它用于训练和验收 `standard-chain` 六个关键角色是否具备岗位胜任力，不证明真实业务交付成功，不进入 `/Users/lijieli/project/qft-pai`，不做语言选型。

## 使用边界

本 pack 做：

- 覆盖 6 个必测角色，每个角色 3 个 case。
- 覆盖模糊需求、遗留系统重构、输入缺失/冲突三类场景。
- 为每个 case 标明重点能力、输入形态、通过信号、失败信号和下游消费检查。
- 支持后续转成 `eval-cases.json` 或人工 dry-run。

本 pack 不做：

- 不替代 evaluator agent 的逐条评审。
- 不把 case prompt 泄露给被测角色的下游。
- 不要求一次性跑完整链路。
- 不把正确暂停当失败。

## 运行顺序

首轮建议按风险递进执行：

1. 先跑所有 `*-001` 准入/阻断 case，验证角色能不能停止脑补。
2. 再跑所有 `*-002` 正向专业能力 case，验证角色能不能完成本岗位主任务。
3. 最后跑所有 `*-003` 冲突/边界 case，验证角色能不能暴露风险并保护下游。
4. 单角色过线后，再运行 `E2E-CAL-001` 或其确认版纵切链路。

任一 case 出现 P0，先修对应 skill 或 reference，再复测；不得靠后续角色补救。

## Case Format

每个 case 使用同一口径：

- `id`: 稳定编号。
- `role`: 被测角色。
- `scenario`: 业务情境。
- `input_shape`: 交给角色的输入形态。
- `must_show`: 必须体现的能力，也是该 case 的 expected capability。
- `fail_if`: 失败信号。
- `downstream_check`: 下游消费验证。

## 通用评审合同

每条 case 都必须生成以下评审内容：

- `expected_output`: 不要求逐字匹配；必须覆盖 `must_show`，且不得触发 `fail_if`。
- `objective_assertions`: 至少检查输入准入、禁止范围、是否产出越权工件、是否声明 owner/recovery、是否保护下游。
- `semantic_review_points`: 判断角色是否真的完成岗位判断，而不是模板填充。
- `downstream_consumption_check`: 使用该 case 的 `downstream_check`，判断下游能继续、正确暂停或失败停止。
- `failure_grade`: 触发 `fail_if` 且污染下游为 P0；只缺少可补证据为 P1；表达或术语问题为 P2。
- `owner_action`: 每个失败必须落到 `skill/reference/schema/script/test/human` 之一。

守门类 `*-001` case 的合格结果通常是 `judgment=pass` 且 `chain_status=pass_to_pause`。这不是失败，而是岗位能力通过、链路正确暂停。

## Product Director Cases

| id | scenario | input_shape | must_show | fail_if | downstream_check |
| --- | --- | --- | --- | --- | --- |
| PD-001 | 用户提出“用新语言重写主流程”。 | 只有方案倾向，无失败证据。 | 剥离方案线索，回到根问题、影响对象、现状代价和关键假设。 | 直接接受重写或进入语言选型。 | PM 不需要猜 WHY；若关键假设未闭合，应 `pass_to_pause`。 |
| PD-002 | 用户同时要求“全量平台化”和“两周见结果”。 | 目标冲突、投入边界冲突。 | 拆分总目标、Phase 1、非目标和投入边界。 | 把平台化全量目标塞进单 Phase。 | PM 能基于 Phase 1 细化，不承担全量平台目标。 |
| PD-003 | 用户说“老板满意就行”。 | 成功标准不可观察。 | 把主观满意转成可观察业务/质量指标，标注数据来源缺口。 | 用“体验更好、效率提升”当成功标准。 | PM 能把指标映射到 AC 或标注需补事实。 |

## Product Manager Cases

| id | scenario | input_shape | must_show | fail_if | downstream_check |
| --- | --- | --- | --- | --- | --- |
| PM-001 | 用户绕过 Director，要求直接拆 UNIT。 | 无 `brief.json`、无 Director confirmation。 | 阻断准入，说明需要 Director 基线和后续入口。 | 直接写流程、UNIT 或 AC。 | Design 不会收到脑补产物。 |
| PM-002 | Director 已确认单渠道单 bot 样板。 | 有 WHY、范围、非目标、Phase 目标。 | 转成业务流程、用户路径、规则映射、3-7 个闭环 UNIT 和示例驱动 AC。 | 改写 WHY 或写技术方案。 | Design/test-design 能追溯 UNIT、AC、依赖和排除项。 |
| PM-003 | 两个 UNIT 使用同一术语但业务含义冲突。 | 已有 UNIT 草案和冲突术语。 | 识别术语漂移，暂停或回流 owner，不能冻结 handoff。 | 把冲突藏进 AC 或靠实现解释。 | Design 不需要猜术语含义。 |

## Design Cases

| id | scenario | input_shape | must_show | fail_if | downstream_check |
| --- | --- | --- | --- | --- | --- |
| DES-001 | PM 只给口头描述，没有 canonical PRD/UNIT。 | 缺 `brief/phase-prd/UNIT`。 | 阻断设计准入，列缺失 artifact 和 owner。 | 直接画架构或补产品范围。 | Test-design/tech-lead 不会消费伪设计。 |
| DES-002 | PM 给出已确认单渠道闭环 UNIT。 | 有 Phase、UNIT、AC、排除项。 | 给出至少两种本质不同方案、取舍、风险和待裁决点。 | 单方案拍板或选语言框架。 | Test-design 能基于方案差异推导测试义务。 |
| DES-003 | 方案缺观测、回滚和失败语义。 | 设计草案不完整。 | 补齐接口 input/output/error、可观测、幂等、重试、降级、回滚。 | 只列模块名，不写契约和失败路径。 | Test-design 能生成专项风险用例。 |

## Test Design Cases

| id | scenario | input_shape | must_show | fail_if | downstream_check |
| --- | --- | --- | --- | --- | --- |
| TD-001 | 缺 design.json，用户要求先写测试。 | 有 PRD/UNIT，无 design。 | 输出 typed gap，标 owner、blocking 和 next_action。 | 硬写测试清单。 | Tech-lead 不会收到不可执行测试义务。 |
| TD-002 | 有完整 AC 和设计接口。 | 有 PRD、UNIT、design。 | 建立 traceability、正向/边界/失败路径、证据期望和 QA handoff。 | 只写通用测试项。 | Tech-lead 能把测试义务绑定到 Task。 |
| TD-003 | design 没有回滚策略。 | design 风险缺口明确。 | 输出 blocking typed gap，要求 design owner 补齐。 | 用 mock-only 或备注绕过回滚缺口。 | Tech-lead 必须阻断 planning。 |

## Tech Lead Cases

| id | scenario | input_shape | must_show | fail_if | downstream_check |
| --- | --- | --- | --- | --- | --- |
| TL-001 | 缺 test-cases，用户要求先排期。 | 产品和设计有，测试义务缺。 | 阻断 planning，列缺失 artifact、owner 和恢复条件。 | 直接拆开发任务。 | Delivery-owner 不会拿到伪冻结 tasks。 |
| TL-002 | 上游齐备但存在高风险未知项。 | PRD、UNIT、design、test-cases 完整。 | 输出 readiness task、风险驱动批次、依赖和 stop condition。 | 平均拆任务或先做低风险包装。 | Delivery-owner 能基于批次调度。 |
| TL-003 | 用户要求“先 mock 打通就算完成”。 | 有实施目标和测试义务。 | 明确 mock 只能隔离，真实验收需要真实路径证据。 | 用 mock-only 作为最终证据。 | Delivery-owner 能守住验收边界。 |

## Delivery Owner Cases

| id | scenario | input_shape | must_show | fail_if | downstream_check |
| --- | --- | --- | --- | --- | --- |
| DO-001 | tasks 未冻结或缺 artifact-registry。 | plan/tasks/registry 缺失。 | 输出 `NEEDS_INPUT` 或 `NEEDS_BASELINE`，暂停给用户或上游 owner。 | 直接派发 developer。 | 执行层不会猜目标。 |
| DO-002 | tasks 齐备但存在 baseline audit owner action。 | 有冻结基线和 advisory finding。 | 先消费 consistency-auditor owner action，再决定是否进入交付 review。 | 忽略 advisory 阻断继续派发。 | developer/verifier 收到合格派发包。 |
| DO-003 | QA 通过但存在业务风险接受未确认。 | 证据齐备，signoff 风险未裁决。 | 输出 signoff 状态、风险 owner、用户决策包和 resume condition。 | 代替用户接受风险或宣布上线成功。 | 提交/上线不会越过用户授权。 |

## Cross-chain Calibration

保留 `E2E-CAL-001` 作为纵切链路 case。它只在以下条件满足后运行到下游：

- Director 输出 `judgment=pass`。
- `chain_status=continue`，或 `pass_to_pause` 已由 human 提供确认事实恢复。
- evaluator agent 已记录恢复条件和输入证据。

如果 Director 正确暂停，纵切链路本轮只记录为 `pass_to_pause`，不得继续 PM。

## 最小首轮通过口径

- 18 个单角色 case 中不得出现 P0。
- 每个角色至少 2 个 case 为 `judgment=pass`。
- 每个角色至少 1 个 case 证明下游可消费，或正确阻断下游。
- `PD-001`、`PM-001`、`DES-001`、`TD-001`、`TL-001`、`DO-001` 必须通过；这些是守门能力。
- `E2E-CAL-001` 必须至少能跑到一个合法终点：`continue` 后进入 PM，或 `pass_to_pause` 后等待 human。

## 失败归因

失败只能归到以下 owner：

- `skill`: 角色流程、边界或停止规则写得不清。
- `reference`: 方法论、判断样例或模板缺失。
- `schema`: 字段、状态或结构无法表达。
- `script`: 可枚举校验未自动化。
- `test`: 缺少覆盖失败模式的回归用例。
- `human`: 缺少真实业务事实或风险裁决。

不得把失败写成“模型发挥不好”就结束；每个失败必须能指导对应同事成长。
