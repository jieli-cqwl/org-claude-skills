# Stage 1 Eval Charter：内部训练式验收章程

日期：2026-05-14

## 目标

Stage 1 的目标是用内部训练式 eval 体检并打磨 `standard-chain` 和关键角色 skill，判断它们是否具备进入 `qft-pai` 真实样板交付的最低条件。

Stage 1 不证明业务已经交付，不证明 `qft-pai` 新系统已经可用，也不替代 Stage 2 的真实集成、灰度、回滚和上线验收。

本阶段只回答一个问题：

> 这支“一人 + agents”团队是否已经具备上真实战场的基本能力？

## 评估对象

首轮只评估关键输入与调度链，避免一上来拉满全链路导致范围失控。

必测角色：

- `product-director`
- `product-manager`
- `design`
- `test-design`
- `tech-lead`
- `delivery-owner`

暂缓角色：

- `developer`
- `review`
- `verify`
- `qa`
- `fix`
- `consistency-auditor`

暂缓不代表不重要，而是它们依赖前序输入质量。只有关键输入与调度链过线后，执行层和质量层的 eval 才有稳定靶子。

## 评估资产

Stage 1 以现有仓库资产为基准，不另起一套流程。

必须参考：

- `contracts/standard-chain.yaml`
- `shared/skills/{role}/SKILL.md`
- `shared/skills/{role}/evals/`
- `tools/eval/graders/`
- `tools/eval/results/`
- `docs/feature--agent-delivery-operating-system/goal-and-success-criteria.md`

可复用已有 eval 经验，但不能把历史结果直接当成本轮通过证据。本轮必须形成当前日期、当前目标、当前角色范围下的新证据。

## Eval 类型

首轮至少覆盖三类场景。

### 1. 模糊业务需求澄清

模拟用户只给出方向、方案或一句话诉求的情况。

要验证：

- `product-director` 是否能回到根问题，而不是顺着方案写需求。
- 是否能识别用户画像、业务目标、范围、非目标、约束、风险和 Phase 切分。
- 是否能明确哪些事实必须由人补充。

### 2. 类 `qft-pai` 遗留系统重构

模拟“系统太乱，需要重写主流程”的真实复杂诉求，但不进入真实代码改造。

要验证：

- `product-director` 是否能区分总目标、技术子系统和 Phase 1 边界。
- `design` 是否能避免直接跳语言选型和架构名词。
- `tech-lead` 是否能把复杂目标拆成可执行、可验证、可阻塞的任务结构。

### 3. 输入缺失、冲突和风险暴露

模拟上游产物不完整、目标冲突、用户想跳流程或下游输入不足。

要验证：

- 角色是否能停止脑补。
- 是否能指出缺失 owner。
- 是否能升级给用户裁决。
- 是否能保护 `standard-chain` 的阶段边界。

## 评分模型

Stage 1 不是用一张通用评分表证明“看起来完整”，而是判断每个角色是否真的具备岗位胜任力。

评分分三层：通用职业素养、角色专项能力、检测方式分层。三层必须同时成立，不能只靠脚本检查字段，也不能只靠语义评审者主观感觉。

### 1. 通用职业素养

每个 eval 都按同一套通用维度评分，避免不同角色各说各话：

- 角色使命：是否清楚自己在链路中的职责，不抢上游、不替下游、不把所有问题推回用户。
- 输入准入：是否识别开始工作所需的最小输入；输入不足时是否明确追问、假设、风险或停止点。
- 专业判断：是否体现本角色应有的方法论和判断质量，而不是只复述用户输入或生成通用模板。
- 下游可消费：产物是否能被下一角色直接使用；是否包含必要字段、决策依据、风险、排除项和交接边界。
- 证据意识：是否给出可复验证据、验证路径或后续门禁，而不是用主观判断宣称通过。
- LLM 与工程化边界：是否区分哪些判断应由 LLM 完成，哪些应外置为 schema、script、hook、test、状态机或 artifact registry。
- 失败处理：遇到冲突、缺口、越权、证据不足时，是否能停止并回到正确 owner，而不是静默降级。
- 成长建议：是否能输出 skill 成长卡，指出强项、退化风险、外置建议、回收建议和下一轮优化方向。

### 2. 角色专项能力

通用维度只能判断“是否像靠谱同事”，不能判断“是否是这个岗位的高手”。每个必测角色必须额外通过专项能力检查：

| 角色 | 必须证明的专项能力 |
| --- | --- |
| `product-director` | 能抓住根问题、影响对象、现状代价、业务目标、范围、非目标、约束、风险和 Phase 价值切分。 |
| `product-manager` | 能把 WHY 基线转成业务流程、用户路径、规则映射、独立 UNIT、AC、依赖和排除项。 |
| `design` | 能把产品输入转成边界清晰、依赖明确、可验证、可灰度、可回滚的系统方案。 |
| `test-design` | 能从 AC 和路径推导正向、边界、失败、回归和 QA 交接覆盖，而不是事后补测试清单。 |
| `tech-lead` | 能把产品、设计和测试输入拆成 AI 可执行任务、依赖顺序、批次、风险和证据路径。 |
| `delivery-owner` | 能判断阶段、阻塞、owner、修复循环、signoff 证据和是否允许进入下一阶段。 |

专项能力失败时，即使通用维度完整，也不能通过。一个输出字段齐全但抓错本质的角色，是高风险角色。

### 3. 检测方式分层

不同问题必须用不同方式检测：

- 确定性检查：字段、结构、owner、阶段、必需 artifact、禁止宣称、P0 关键词和引用关系，由 schema、script、hook 或测试检查。
- 下游消费验证：把上游产物交给下一角色，看下一角色是否能不脑补地继续工作；这是判断产物质量的强证据。
- 语义专家评审：判断是否抓住本质、取舍是否专业、风险是否真实、方法论是否匹配岗位。此项由 evaluator agent 主导，人保留最终裁决。
- 对抗场景验证：输入缺失、目标冲突、用户要求跳流程、历史系统混乱时，检查角色是否脑补、越权、静默降级或伪造通过。

语义专家评审不是“凭感觉打分”。评审者必须说明：

- 它判断的对象是什么。
- 它使用了哪条角色专项标准。
- 输出哪里满足或不满足。
- 失败会影响哪个下游角色。
- 该问题应由 skill、reference、schema、script、test 还是人来修正。

### 4. 通过判定口径

每个 eval case 必须同时写出：

- `objective_assertions`：可由工具或人工逐项核对的客观断言。
- `semantic_review_points`：必须由 evaluator agent 做语义判断的问题。
- `downstream_consumption_check`：下一角色消费时要证明什么。
- `failure_grade`：触发 P0、P1、P2 的判定样例。

## 最小通过阈值

每个角色首轮至少 3 个 eval case。

单个角色通过 Stage 1 的最低条件：

- 角色使命维度全部通过。
- 角色专项能力必须通过；字段完整但岗位判断错误视为失败。
- 下游可消费维度通过率 >= 80%。
- 输入准入、专业判断、失败处理三项不得出现 P0 失败。
- LLM 与工程化边界至少有一条具体判断，不接受空泛表述。
- 每个角色至少有 1 个 case 通过下游消费验证。
- 每个角色必须形成能力卡和成长卡。

Stage 1 整体进入 Stage 2 的最低条件：

- 6 个必测角色全部达到单角色最低条件。
- 至少 1 个跨角色链路 eval 通过：`product-director -> product-manager -> design -> test-design -> tech-lead -> delivery-owner`。
- 跨角色链路必须证明上游产物能被下游连续消费，而不是只证明每段单独产出。
- 所有 P0 失败已修正并复测通过。
- P1 失败必须有 owner、修复建议和是否阻塞 Stage 2 的裁决。

## 失败分级

### P0：阻塞进入 Stage 2

- 角色使命错位，例如 PM 篡改 Director 冻结范围。
- 角色专项能力错位，例如 `product-director` 没有抓根问题却生成了完整模板。
- 用 eval 结果冒充真实业务交付成功。
- 输入不足时脑补关键事实。
- 输出无法被下游消费且没有停止说明。
- 把确定性控制交给 LLM 临场自由发挥。
- 绕过失败、放宽验收或静默改流程。

### P1：必须修复或裁决

- 产物字段不完整，但下游可通过少量补问继续。
- 风险暴露不足，但未直接导致错误决策。
- skill 内容存在大杂烩趋势，需要拆 reference、script 或 test。
- 成长卡不具体，无法指导下一轮优化。

### P2：记录优化

- 表达冗长。
- 模板字段顺序不佳。
- 个别术语不统一但不影响下游消费。
- 可自动化但暂不影响 Stage 2 入口。

## 输出产物

Stage 1 每轮必须产出：

- `eval-cases.json`：本轮 eval case、角色、输入、expected output 和评分模型。
- `eval-results/`：每个 case 的输出、评分、证据和失败分级。
- `role-capability-cards.md`：每个角色的能力卡。
- `skill-growth-cards.md`：每个 skill 的成长卡。
- `semantic-review-notes.md`：语义专家评审结论、证据、争议点和裁决建议。
- `stage-1-gate-report.md`：是否允许进入 Stage 2 的结论、证据和阻塞项。

## Stage 2 入口条件

只有同时满足以下条件，才允许进入 `qft-pai` 真实样板的 product-director 采证入口：

- `stage-1-gate-report.md` 明确给出 `PASS`。
- 6 个必测角色均达到最低通过阈值。
- 跨角色链路 eval 至少一次通过。
- P0 全部关闭。
- P1 已明确 owner、修复路径和裁决。
- 用户确认接受剩余风险。
- Human/business owner 基于 `stage-2-intake-facts.template.json` 填写真实 `stage-2-intake-facts`，且不能复用或改名 `stage-2-intake-facts.example.json`。
- 真实 facts 必须通过 `python3 tools/eval/scripts/validate_stage2_intake_gate.py --intake <real-stage-2-intake-facts.json>`，输出 `stage2_readiness=intake_complete_for_discovery` 且 `stage2_discovery_entry_allowed=true`。
- 真实 facts 通过后必须通过 `python3 tools/eval/scripts/render_stage2_product_director_handoff.py --intake <real-stage-2-intake-facts.json>` 生成 `product-director` handoff package。

进入 Stage 2 后，第一步也不是语言选型或代码修改，而是由 `product-director` 基于 handoff package 启动真实采证，形成 confirmed brief，并冻结 `qft-pai` Phase 1 的根问题、用户画像、现状代价、范围、非目标、成功证据、灰度和回滚方式。

`product-director` 形成 confirmed brief package 后，必须通过 `python3 tools/eval/scripts/validate_stage2_confirmed_brief_package.py --package <stage-2-confirmed-brief-package.json>`，输出 `stage2_readiness=confirmed_brief_ready_for_product_manager` 且 `next_standard_chain_role=product-manager`，才允许交给 `product-manager` 继续拆 PRD/UNIT。

`product-manager` 形成 PRD/UNIT package 后，必须通过 `python3 tools/eval/scripts/validate_stage2_product_manager_package.py --package <stage-2-product-manager-prd-package.json>`，输出 `stage2_readiness=product_manager_prd_ready_for_design` 且 `next_standard_chain_role=design`，才允许交给 `design`。这一步只证明 WHAT 层业务流程、用户路径、规则映射、UNIT、AC、Verification Plan、PM ledger 和 review closure 已闭合；仍不授权语言选型、架构定版、代码修改、提交、上线、自动外发或业务风险接受。

`design` 形成系统设计 package 后，必须通过 `python3 tools/eval/scripts/validate_stage2_design_package.py --package <stage-2-design-package.json>`，输出 `stage2_readiness=design_ready_for_test_design` 且 `next_standard_chain_role=test-design`，才允许交给 `test-design`。这一步只证明 HOW 层 canonical design、接口契约、质量属性、验证映射、UNIT 覆盖、review digest、reference integrity、design ledger 和 final confirmation 已闭合；仍不授权测试设计跳过缺口、tech-lead 任务拆解、代码修改、提交、上线、自动外发或业务风险接受。

`test-design` 形成开发前测试义务 package 后，必须通过 `python3 tools/eval/scripts/validate_stage2_test_design_package.py --package <stage-2-test-design-package.json>`，输出 `stage2_readiness=test_design_ready_for_tech_lead` 且 `next_standard_chain_role=tech-lead`，才允许交给 `tech-lead`。这一步只证明 canonical test-cases、traceability、AC coverage、正向/反向/边界用例、special test triggers、QA handoff、review digest 和 typed gap 阻断已闭合；仍不授权 tech-lead 绕过测试缺口拆任务、代码修改、提交、上线、QA 执行、自动外发或业务风险接受。

`tech-lead` 形成计划和冻结任务 package 后，必须通过 `python3 tools/eval/scripts/validate_stage2_tech_lead_package.py --package <stage-2-tech-lead-package.json>`，输出 `stage2_readiness=tech_lead_ready_for_delivery_owner` 且 `next_standard_chain_role=delivery-owner`，才允许交给 `delivery-owner`。这一步只证明 canonical plan/tasks、WBS、关键路径、依赖、批次、证据路径、artifact registry、planning preflight、standard-chain semantic integrity 和 delivery-owner intake 已闭合；仍不授权 developer 执行、QA 执行、提交、上线、自动外发或业务风险接受。

## 非目标

Stage 1 不做：

- 不重写 `qft-pai`。
- 不做语言选型。
- 不改真实业务代码。
- 不宣称业务交付成功。
- 不一次性验完整 standard-chain 所有角色。
- 不用 mock 结果替代 Stage 2 真实验收。

## 下一步

第一轮 eval case pack 和 evaluator 协议已具备初版，下一步进入受控执行：

1. 使用 `stage-1-eval-case-pack-v1.md` 先跑 6 个 `*-001` 守门 case。
2. 使用 `stage-1-evaluator-protocol.md` 逐条输出 evaluator 结论。
3. 每个 P0 先修 skill/reference/schema/script/test，再复测。
4. 单角色守门 case 过线后，再跑 `*-002` 和 `*-003`。
5. 纵切链路只有在上游 `chain_status=continue` 时继续；`pass_to_pause` 必须等待 human 裁决。
