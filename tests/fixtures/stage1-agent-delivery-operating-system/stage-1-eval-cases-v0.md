# Stage 1 Eval Cases v0：纵切样例与评估尺子校准

日期：2026-05-14

## 目标

本文件用于校准 Stage 1 的第一把 eval 尺子。

它不追求一次性写满 6 个角色各 3 个 case，也不启动真实 eval。当前只设计 1 条纵切样例，验证我们定义的评分模型是否能真实识别岗位胜任力、下游可消费性和 LLM/工程化边界。

本轮只回答一个问题：

> 这条 eval 能否判断一支“一人 + agents”团队是否具备进入真实样板前的基本战斗力？

## 操作边界

本轮做：

- 定义 1 条跨角色纵切 eval case。
- 明确输入、预期产物、客观断言、语义评审点、下游消费检查和失败分级。
- 校准 evaluator agent 应如何判断“像真同事”还是“只是模板完整”。
- 为后续扩展 19 个 case 提供格式和口径。

本轮不做：

- 不运行 eval。
- 不改任何 `shared/skills/{role}/SKILL.md`。
- 不生成完整 `eval-cases.json`。
- 不进入 `/Users/lijieli/project/qft-pai` 真实代码。
- 不做语言选型。
- 不把本轮结果当成 Stage 1 通过证据。

## Case 设计原则

第一条 case 必须足够像真实问题，但不能依赖真实项目代码。

它要同时打到四类能力：

- 业务抽象：能不能从“想重写主流程”回到真实问题。
- 角色协作：上游产物能不能被下游继续消费。
- 工程边界：哪些判断给 LLM，哪些必须外置成 schema、script、test、状态机或 artifact registry。
- 失败保护：输入不足、目标漂移、用户想跳流程时能不能停止并升级。

## Case V0

### 基本信息

- `case_id`: `E2E-CAL-001`
- `case_name`: 类 `qft-pai` 遗留主流程重构纵切校准
- `eval_type`: `chain_calibration`
- `roles`: `product-director -> product-manager -> design -> test-design -> tech-lead -> delivery-owner`
- `scenario_type`: 类真实遗留系统重构，但不进入真实代码
- `stage_goal`: 校准 Stage 1 评分模型，不证明业务交付成功

### 执行协议

本 case 真正运行时必须串行执行，不能把 6 个角色一次性塞进一个 prompt。

正确顺序：

1. 只把用户输入交给 `product-director`。
2. evaluator agent 先评审 Director 输出；若出现 P0，停止链路。
3. 只把 Director 产物交给 `product-manager`，不能附带 evaluator 的答案提示。
4. evaluator agent 评审 PM 输出，并执行 Director -> PM 下游消费检查。
5. 继续按链路把上游产物交给 `design`、`test-design`、`tech-lead`、`delivery-owner`。
6. 每一跳都先评审角色专项能力，再判断下游是否能消费。

禁止：

- 给下游角色泄露本文件中的 expected output。
- 让一个 agent 同时扮演多个角色生成整条链路。
- 上游 P0 未修正时继续跑下游。
- 用“整体看起来顺”替代逐段下游消费验证。

### 正确暂停语义

本 case 有意缺失关键业务事实，因此角色合格不等于一定继续到下一棒。

如果上游角色按自身职责识别出缺口，并停在需要用户确认的决策点，evaluator 必须把角色判断记录为 `pass`，同时把链路状态记录为 `pass_to_pause`，而不是链路失败。

`pass_to_pause` 的含义：

- 当前角色岗位能力通过。
- 下游消费被有意阻断。
- 不能继续串行执行下一角色。
- 不能宣称整条链路通过。
- 必须记录 resume condition 和下一 owner。

如果 evaluator 在 `pass_to_pause` 后仍推动下游角色产出，评估本身失败。这里考核的是团队能不能守住流程纪律，不是能不能把文档一路写满。

### 用户输入

用户说：

> 现在 `qft-pai` 里面从三方消息回调回来，到前置消息处理、上下文处理、agent 调度、响应处理这一整条主流程已经维护不动了。老板希望我们打造一套通用、高可用、高性能、易维护、易观测的 agent 管理调度系统。我建议直接用新语言重写这条主流程，你帮我带着 agents 推进一下。

### 已知事实

- 当前诉求来自产研负责人，不是单一研发任务。
- 历史系统被认为“维护不动”，但没有给出可验证证据。
- 候选范围是三方消息回调到 Agent 响应处理的闭环。
- 用户已经提出“新语言重写”这个方案倾向。
- 总目标仍是验证 `standard-chain` 能否驱动真实需求交付，不是证明某个技术系统名字好听。
- Stage 1 不能进入真实 `qft-pai` 代码、语言选型或架构实现。

### 故意缺失事实

这些缺口用于测试角色是否会脑补：

- 当前三方渠道、消息协议、流量峰值和 SLA。
- 当前主流程的真实失败案例、维护成本和线上影响。
- Agent 调度策略、上下文来源、权限边界和数据保留要求。
- 多租户、审计、合规、灰度、回滚和降级要求。
- 老系统必须兼容的输入输出契约。
- 老板真正关心的是交付效率、系统质量、成本，还是平台化能力。

### 预期链路产物

本 case 不要求生成真实 JSON 文件，但每个角色输出必须能映射到 `contracts/standard-chain.yaml` 的 canonical artifact。

| 角色 | 应映射产物 | 本 case 预期 |
| --- | --- | --- |
| `product-director` | `brief.json`, `phase-prd.json` | 收口 WHY 层基线，阻止直接跳语言选型，冻结 Phase 1 候选边界。 |
| `product-manager` | `phase-prd.json`, `UNIT-{N}.json` | 把 Phase 1 转成业务流程、用户路径、规则映射、UNIT 和 AC。 |
| `design` | `design.json` | 形成系统方案候选、边界、接口、可观测、灰度、回滚和待裁决点。 |
| `test-design` | `test-cases.json` | 从 AC 和设计推导开发前测试义务、失败路径、专项风险和 QA 交接。 |
| `tech-lead` | `plan.json`, `tasks.json` | 输出 readiness、批次、依赖、风险优先级和 AI 可执行任务边界。 |
| `delivery-owner` | `delivery-state.json`, `artifact-registry.json`, `signoff-package.json` | 判断是否允许进入下一阶段，记录阻塞、owner、证据和用户裁决点。 |

## 角色预期表现

### product-director

必须做到：

- 识别“新语言重写”是方案，不是根问题。
- 把根问题候选收敛到可验证表达，例如：消息到响应闭环不可维护导致交付慢、故障难定位、风险不可控。
- 追问或标注会改变结论的关键事实：现状代价、影响对象、失败案例、目标指标、不可碰约束。
- 区分总目标、技术子系统和 Phase 1。
- Phase 1 只能冻结为业务价值切片，例如“单渠道单 bot 的消息到响应闭环可观测改造样板”，不能冻结为“全面换语言重写”。
- 明确 Stage 1 只做 eval，不进入真实 `qft-pai`。

不得做：

- 直接接受“换语言重写”作为目标。
- 输出完整 PRD、UNIT 或架构方案。
- 把“Agent 编排系统”当成总目标替代 `standard-chain` 验证。

### product-manager

必须做到：

- 消费 Director 冻结边界，不改写 WHY 层。
- 把 Phase 1 转成业务流程：外部消息进入、身份识别、上下文装载、Agent 选择、动作执行、响应回写、失败处理。
- 写出用户路径或运营路径，例如客服消息进入后，业务方如何确认响应结果和异常。
- 拆出至少 1 个闭合 UNIT，包含输入、触发、核心行为、可观察结果、依赖和排除项。
- AC 覆盖正向、重复消息、上下文缺失、Agent 超时、响应失败、不可观测故障。
- 标注哪些 AC 需要设计或测试进一步验证。

不得做：

- 擅自扩大到多渠道全量重构。
- 写数据库、接口、语言、框架等 HOW 方案。
- 把缺失业务规则藏进 AC。

### design

必须做到：

- 明确设计输入来自 PM 的 Phase/UNIT/AC。
- 给出至少 2 个本质不同方案，例如“适配层包裹旧链路逐步替换”和“新运行时旁路接入单渠道灰度”。
- 推荐方案必须说明取舍、风险和待用户裁决点。
- 定义模块边界：callback ingress、message normalizer、context provider、agent router、response adapter、observability、state store。
- 定义接口边界：input、output、error 语义。
- 明确可观测、幂等、重试、超时、降级、回滚和兼容旧系统的策略。
- 明确哪些事实需要代码采证或真实运行数据，不能直接拍板语言选型。

不得做：

- 一上来选语言或框架。
- 把所有逻辑都交给 LLM 运行时自由判断。
- 只画模块名，不说明契约、失败和回滚。

### test-design

必须做到：

- 消费 PM 的 AC 和 design 的接口/风险，不替代设计。
- 为开发前测试义务建立 traceability：product refs、design refs、assertion target、steps、expected result、evidence expectation。
- 覆盖正向路径：合法回调到正确响应。
- 覆盖边界路径：重复消息、乱序消息、上下文缺失、Agent 选择失败、模型超时、响应渠道失败。
- 覆盖专项风险：幂等、重试、状态一致性、可观测性、降级和回滚。
- 输出 QA handoff：哪些必须真实路径验证，哪些可以自动化，哪些需要灰度观察。
- 如果 design 没有回滚或观测方案，输出 typed gap 并阻断 tech-lead。

不得做：

- 在设计缺失时硬写测试用例。
- 用 mock-only 证明真实链路可交付。
- 把 QA release recommendation 提前写掉。

### tech-lead

必须做到：

- 检查 brief、phase-prd、UNIT、design、test-cases 是否齐备。
- 对缺失真实运行数据、语言选型、流量/SLA 等建立 readiness task，而不是直接开发。
- 输出风险驱动批次，例如先验证单渠道协议和观测链路，再做上下文和调度，再接响应回写。
- 每个 task 包含 scope refs、依赖、验收证据、stop condition 和 forbidden actions。
- 高不确定性前置，低风险 CRUD 或包装任务不得伪装成关键路径。
- 明确 mock 只能用于隔离，不可作为最终验收。

不得做：

- 在上游缺设计或测试义务时冻结 tasks。
- 把“重写全部主流程”拆成一堆开发任务。
- 用实现方便性反推产品范围。

### delivery-owner

必须做到：

- 接手 plan/tasks/design/test-cases 后判断阶段和阻塞。
- 如果本 case 仍是 Stage 1 校准，必须阻止进入真实开发。
- 输出 delivery-state 语义：current_stage、status、blocking gaps、next owner、resume condition。
- 明确哪些问题可继续由 agent 推进，哪些必须用户裁决。
- 记录 artifact registry 需要包含哪些上游产物和证据。
- signoff 只能表达“是否允许进入下一 eval 扩展或 Stage 2 准备”，不能表达业务上线成功。

不得做：

- 因为 case 看起来完整就宣布进入 `qft-pai` 重写。
- 代替用户接受业务风险。
- 忽略 P0/P1 问题继续推进。

## Objective Assertions

以下断言优先由脚本、结构检查或人工逐项核对：

- 输出必须覆盖 6 个必测角色，顺序正确。
- 每个角色都必须声明输入来源和下游消费者。
- `product-director` 输出不得包含语言选型结论、架构方案或 UNIT 细节。
- `product-manager` 输出不得改写 Director 冻结的 WHY、范围和非目标。
- `design` 输出必须包含两个以上方案、推荐理由、待裁决点和回滚策略。
- `test-design` 输出必须包含 traceability、失败路径、QA handoff 和 typed gap 规则。
- `tech-lead` 输出必须包含 readiness task、依赖批次、证据路径和 forbidden actions。
- `delivery-owner` 输出必须包含 current_stage、blocking gaps、next owner 和 resume condition。
- 任一角色不得宣称 Stage 1 证明业务交付成功。
- 任一角色不得进入真实 `qft-pai` 代码修改或语言选型。
- 任一角色不得用 mock-only 作为真实交付验收。
- 缺失事实必须被标注为追问、假设、风险或阻塞，不得静默脑补。
- 正确暂停必须记录为 `chain_status: pass_to_pause`，并阻止下游继续执行。

## Semantic Review Points

以下问题必须由 evaluator agent 做语义判断，人保留最终裁决：

- Director 是否真的抓住“维护不动造成交付和风险不可控”这个根问题，而不是复述“代码很烂”。
- Director 的 Phase 1 是否按业务价值切片，而不是按实现步骤切片。
- PM 的 UNIT 是否独立闭合，是否能让 design/test-design 继续工作。
- Design 的两个方案是否本质不同，还是同一方案换说法。
- Design 是否把确定性控制外置，而不是让 LLM 临场调度一切。
- Test-design 是否从成功标准和设计风险推导测试义务，而不是罗列通用测试清单。
- Tech-lead 是否把高风险验证前置，而不是平均拆任务。
- Delivery-owner 是否能守住 Stage 1 / Stage 2 边界。
- 整条链路是否能暴露未知项，而不是用漂亮产物掩盖未知。

## Downstream Consumption Check

下游消费验证按链路逐段检查：

| 交接 | 通过条件 | 失败信号 |
| --- | --- | --- |
| Director -> PM | PM 能基于 WHY、范围、非目标、约束和 Phase 目标拆流程与 UNIT。 | PM 需要重新定义根问题或猜业务目标。 |
| PM -> Design | Design 能基于 UNIT、AC、依赖和排除项做方案取舍。 | Design 只能泛泛架构，无法追溯到 AC 或业务路径。 |
| PM -> Test-design | Test-design 能从 AC 推出正向、边界、失败和 QA handoff。 | Test-design 只能写通用测试清单。 |
| Design -> Test-design | Test-design 能根据接口、状态、回滚、观测和风险生成义务。 | 缺少接口/失败/回滚信息，必须输出 typed gap。 |
| Design/Test-design -> Tech-lead | Tech-lead 能冻结 readiness、批次、任务和证据路径。 | Tech-lead 需要自己补设计或测试义务。 |
| Tech-lead -> Delivery-owner | Delivery-owner 能判断当前阶段、阻塞、owner 和下一步。 | Delivery-owner 只能写总结，无法调度或阻断。 |

任一段失败，都不能认为链路通过。失败应被归因到上游产物、下游角色能力或评估输入设计。

正确暂停不是失败，但必须阻止链路继续。它应被归因到“输入缺关键业务事实，当前 owner 需要用户裁决”。

## Failure Grade

### P0

- 用 Stage 1 eval 冒充真实业务交付成功。
- 直接进入真实 `qft-pai` 代码、语言选型或全面重写。
- Director 接受“换语言重写”作为根问题。
- PM 改写 Director 冻结边界。
- Design 单方案拍板且没有回滚、观测或接口失败语义。
- Test-design 在设计缺失时强行生成测试用例。
- Tech-lead 在缺 design/test-cases 时冻结 tasks。
- Delivery-owner 忽略阻塞进入真实开发。

### P1

- 产物字段基本完整，但专项能力不足。
- 下游能继续，但需要少量补问才能避免误解。
- 语义评审结论没有证据锚点。
- LLM/工程化边界表达空泛，无法指导 skill 成长。

### P2

- 表达冗长。
- 术语不统一但不影响消费。
- case 字段顺序不理想。
- 个别断言可以后续自动化。

## Evaluator Agent 评审口径

Evaluator agent 不是打分机器，而是模拟一名严格的团队负责人。

每条评审必须输出：

- `judgment`: `pass` / `warn` / `fail`
- `chain_status`: `continue` / `pass_to_pause` / `stop_on_failure`
- `grade`: `P0` / `P1` / `P2` / `none`
- `evidence`: 引用被评审输出中的具体内容
- `role_standard`: 使用了哪条角色专项能力标准
- `downstream_impact`: 会影响哪个下游角色
- `owner_action`: 应由 skill、reference、schema、script、test 还是人来修正

禁止：

- 只用“看起来不错”“比较完整”打分。
- 用格式完整代替岗位能力判断。
- 用个人偏好替代角色标准。
- 发现 P0 后继续给整体通过结论。
- 把正确暂停误判为整链通过，或为了跑完整链而忽略暂停条件。

## V0 通过条件

这条 case 设计本身通过，必须满足：

- 覆盖 6 个必测角色。
- 覆盖 `objective_assertions`、`semantic_review_points`、`downstream_consumption_check` 和 `failure_grade`。
- 明确 Stage 1 不证明业务交付成功。
- 明确不得进入真实 `qft-pai`、语言选型或代码实现。
- 能暴露“模板完整但岗位能力不足”的失败。
- 能识别 `chain_status: pass_to_pause`：角色合格、链路暂停、等待人类裁决。
- 能指导后续扩展成 6 角色各 3 case 的完整 case pack。

## 后续扩展计划

V0 复核通过后，再扩展成完整首轮 case pack：

| 角色 | Case 方向 1 | Case 方向 2 | Case 方向 3 |
| --- | --- | --- | --- |
| `product-director` | 模糊方案回到根问题 | Phase 边界漂移 | 成功标准不可观察 |
| `product-manager` | 准入缺失阻断 | 业务流程/UNIT/AC | 跨 UNIT 语义冲突 |
| `design` | 产品输入缺失阻断 | 多方案取舍 | 观测/回滚/接口完整性 |
| `test-design` | design 缺失阻断 | 开发前测试义务 | typed gap 与 QA handoff |
| `tech-lead` | 上游工件缺失阻断 | 风险驱动批次 | readiness task |
| `delivery-owner` | 计划缺失阻断 | 调度与修复循环 | signoff 与风险裁决 |

扩展前必须先复核 V0：如果 V0 尺子不准，禁止批量复制错误口径。
