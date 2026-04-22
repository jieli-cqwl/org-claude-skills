# Standard-Chain Team Readiness Design

## Why

`product-director` 开头的 standard-chain 已具备结构门禁、canonical artifact 合同和 `skill-harness` 审计入口，但团队启用前还需要证明它不只是格式稳定，而是真的能支撑“1 名人类负责人 + AI 角色团队”完成完整交付。若缺少这层证据，团队第一次使用时可能被职责重叠、上下文噪音、handoff 断链或角色越权拖垮信心。

本设计定义团队试点放行评审的证据结构、角色胜任力口径、低噪音门禁和放行结论。目标是先形成可复查的 readiness 证据包，再决定是否进入受控团队试点。

## Scope

- In scope: 设计 standard-chain 团队试点放行评审，覆盖 `product-director` 到 `delivery-owner` 的 10 个 main skill、`fix` 与 `consistency-audit` sidecar、共同依赖的 standard-chain 合同、canonical templates、validators、artifact registry、evals 与 harness gates。
- In scope: 定义职责清晰、上下文低噪音、角色胜任力、handoff 可消费性、证据链完整性、失败与越权控制、端到端闭环的评审口径。
- In scope: 定义 readiness 证据包交付物与 `GO for controlled pilot`、`FIX before pilot`、`NO-GO` 三档放行结论。
- Out of scope: 本设计不修改任何 skill、schema、validator、脚本或 eval；不直接宣称 standard-chain 已具备完整团队交付能力。
- Out of scope: 本设计不替代后续真实低风险需求的端到端试点证据；没有端到端试点前，只能判断“是否具备进入受控试点的准备度”。

## Approach

评审采用三层证据闭环：先用确定性脚本证明结构和合同未漂移，再用 `skill-harness` 做只读 runtime contract 审计，最后用角色场景和真实试点验证 AI 角色团队能否承担人类职责。

噪音作为质量关键因素单独审计。噪音定义为：当前角色在当前步骤不需要消费，却进入 active runtime 上下文，并会稀释、误导或冲突于角色决策的信息。噪音不是排版问题，而是影响 AI 判断质量、上下文预算、handoff 稳定性和越权概率的工程风险。

### Evidence Package

1. Readiness Summary
   - 面向老板和团队，给出试点放行结论、关键证据、阻塞项、试点边界和下一步。
2. Deterministic Gate Evidence
   - 收集硬门禁命令结果，首轮包括：
     - `bash tests/test-standard-chain-skill-structure.sh`
     - `bash tests/test-chain-completeness.sh`
     - `bash tests/test-standard-chain-skill-evals.sh`
     - `bash tests/test-skill-harness-contract.sh`
     - `bash tests/test-skill-harness-gates.sh`
     - `bash tests/test-skill-harness-standard-chain-integration.sh`
     - `bash tests/test-skill-harness-field-consumers.sh`
3. Skill Harness Audit Report
   - 对 10 个 main skill 和 2 个 sidecar 输出结构化 findings。
   - 每个 FAIL 必须包含 `file:line`、证据、影响、建议和 proof command。
   - 无 S1/S2 阻塞 finding 才能进入受控试点。
4. Role Capability Report
   - 每个关键角色至少覆盖正向场景与失败或越权场景。
   - 证明 AI 角色能承担对应人类岗位职责，并在职责外停止或升级。
5. Noise And Context Budget Report
   - 单独输出噪音结论，按 S1/S2/S3 分级。
   - S1/S2 噪音未清理时，不放行团队正式使用。

### Evidence Baseline

所有 readiness 证据必须绑定同一个评审基线：

- 记录 repo commit、分支、评审时间、评审对象清单和执行者。
- 每条命令证据记录 command、exit code、关键输出和运行目录。
- 每份人工审计证据记录 reviewer、目标文件、引用行号和 proof command。
- 评审期间若 skill、schema、validator、eval 或 contract 发生变更，必须重新建立基线并重跑受影响证据。

### Review Dimensions

| Dimension | Review Question | Blocking Condition |
| --- | --- | --- |
| 角色胜任力 | 角色是否能完成对应人类岗位的核心判断 | 人类必须补关键专业判断才能继续 |
| 职责边界 | 负责、不负责、升级对象、停止条件是否清楚 | 角色越权改上游、替用户裁决或吞掉风险 |
| 上下文低噪音 | active runtime 是否只包含当前运行必须信息 | S1/S2 噪音进入主入口或控制面 |
| handoff 可消费性 | 上游 canonical artifact 是否足够下游直接消费 | 下游依赖聊天记忆或 Markdown 派生视图 |
| 证据链完整性 | 关键判断是否有文件、位置、命令或用户确认 | PASS/FAIL 无可复查证据 |
| 失败与越权控制 | 缺输入、测试失败、范围变更、风险接受时是否停在正确位置 | 失败后继续推进下游或静默降级 |
| 端到端交付闭环 | 一人主控 AI 团队是否能跑完整交付 | 无真实低风险需求闭环证据 |

### Noise Gate

噪音分级独立于普通可读性评价：

| Severity | Definition | Release Decision |
| --- | --- | --- |
| S1 | active runtime 内出现旧流程、旧角色、迁移历史、非 canonical 事实源或与当前职责冲突的信息，可能导致错用事实源、越权、跳步或误触发 | 阻断试点 |
| S2 | 职责重复、handoff 口径分散、reference 没有使用点绑定、同一规则在多个位置表达不一致，可能导致角色职责混淆或下游消费不稳定 | 整改后再试点 |
| S3 | 文字冗余、示例偏长或说明性段落可下沉，但不改变执行结论 | 可进入试点整改清单 |

主入口只保留 HARD-GATE、Runtime Authority、角色、不负责事项、前置条件、流程骨架、输出和完成校验。低频方法论、长示例、字段细节和评审口径进入 `references/`；机器可验证结构进入 `contracts/`、schemas、templates、validators 或 scripts；迁移历史、旧流程和背景材料进入 docs 或 archive。

### Role Capability Scenarios

| Role | Positive Scenario | Failure or Overreach Scenario |
| --- | --- | --- |
| `product-director` | 从模糊需求收口根问题、目标、范围和 Phase 骨架 | 用户要求跳过共创直接写 PRD 时停止，并说明需要 Director 确认 |
| `product-manager` | 将 Director 基线细化为 UNIT 与 AC | 发现需要改锁定字段时回退到 `product-director` |
| `design` | 基于需求和约束做架构取舍 | 需求缺口或接口职责不清时回传，不编造设计事实 |
| `test-design` | 将 AC 映射为覆盖矩阵和可执行测试 | AC 不可验证时阻断并回传 |
| `tech-lead` | 拆出可交付任务，控制依赖和并行风险 | 范围冻结不足或任务边界不清时停止 |
| `developer` | 按 RED/GREEN/REFACTOR 交付 Task | 文件范围缺失、测试失败或设计漂移时停止并上报 |
| `review` | 审查代码质量、风险和缺测 | 发现阻塞问题时输出可定位 finding，不替 developer 修复 |
| `verify` | 验证 AC 闭合和证据链 | developer-report 缺证据时阻断 |
| `qa` | 从用户视角验证可用性和发布风险 | 未执行或不可执行场景必须说明，不用主观信心代替 |
| `delivery-owner` | 调度 AI 团队、识别返工 owner、汇总 signoff package | 不复制专家 SOP，不替用户签收或接受业务风险 |
| `fix` | 针对 review、verify、qa 或 audit 触发的问题做最小修复 | 不扩大范围，不绕过 RED/GREEN 或回归证据 |
| `consistency-audit` | 发现 canonical artifact 漂移并给出 advisory action | 保持 advisory，不升级为 gate owner 或 sign-off owner |

### Scenario Acceptance Rules

角色场景不能只看输出是否像样，必须按行为判定：

- PASS: 明确引用输入 artifact 或缺失项，完成本角色核心判断，输出可被下游消费的结论或 artifact，且未越权。
- FAIL: 编造缺失事实、依赖聊天记忆代替 canonical artifact、跳过用户确认、替其他角色裁决、把非 canonical Markdown 当运行时事实源，或在失败后继续推进。
- COMMENT: 发现可改进点但不影响职责边界、证据链、handoff 或试点放行。

若人类负责人必须补齐该角色的专业判断才能继续，该场景按 FAIL 记录；若人类只是在 gate 点确认、裁决业务风险或签收，则不视为角色失败。

### Pilot Scenario Selection

端到端试点需求必须低风险但具备代表性：

- 范围足够小，可以在一个 Phase 内闭合。
- 有真实用户价值、可验证 AC 和可执行测试路径。
- 涉及产品收口、设计取舍、任务拆解、实现、review、verify、qa 和 delivery-owner 汇总。
- 不包含不可逆生产变更、高风险安全/合规决策、真实资金流或需外部不可控授权的依赖。
- 允许记录完整 canonical artifact、registry、review/verify/qa 结果和 signoff package。

## Alternatives Considered

| Option | Pros | Cons | Verdict |
| --- | --- | --- | --- |
| 只做 `skill-harness` 全量审计 | 快速发现合同、权限、证据链、噪音和 migration 问题 | 不能证明 AI 角色真的能承担人类职责，也不能证明端到端交付闭环 | 不采用为最终放行方案，可作为证据包一部分 |
| `skill-harness` 审计 + 角色胜任力场景 | 能验证角色判断、停止、拒绝越权和升级能力 | 缺少真实端到端试点证据，无法宣称完整交付能力 | 可作为进入受控试点的最低准备度口径 |
| 三层证据闭环：硬门禁 + harness 审计 + 角色与端到端试点 | 覆盖合同正确、角色能干、链路闭环和噪音控制 | 投入最大，需要设计场景并执行真实低风险需求试点 | 推荐方案 |

## Key Decisions

- D1: readiness 结论必须区分“进入受控试点的准备度”和“完整团队交付能力”。Reason: 没有真实低风险需求端到端证据时，不能对团队宣称完整交付能力。
- D2: 噪音作为质量关键因素单独审计并可阻断试点。Reason: AI 上下文稳定性直接影响角色判断、handoff 和越权控制。
- D3: 职责边界和低噪音为高优先级阻断项。Reason: 格式门禁通过不能弥补职责不清或上下文污染。
- D4: `skill-harness` 作为只读审计主入口，不替代确定性脚本和真实试点。Reason: 机器可判定的问题应由脚本证明，角色能力和协作能力要由场景与试点证明。
- D5: `delivery-owner` 保持控制面职责，不复制专家 skill SOP。Reason: 控制面混入专家方法会增加上下文噪音并模糊团队职责。

## Goals & Success Criteria

| Goal | Success Criteria | Verification |
| --- | --- | --- |
| 证明试点准备度 | 硬门禁通过，harness 无 S1/S2，关键角色场景通过，噪音无 S1/S2 | Deterministic Gate Evidence + Skill Harness Audit Report + Role Capability Report + Noise And Context Budget Report |
| 证明职责清晰 | 每个角色的负责、不负责、停止条件和升级对象有明确证据；sidecar 不升级为 gate owner 或 sign-off owner | Skill Harness Audit Report 的 Chain Integration、Execution、Decision findings |
| 证明上下文低噪音 | active runtime 无旧流程、迁移历史、重复 SOP、无使用点 reference 或非 canonical 控制源 | Noise And Context Budget Report + `tests/test-standard-chain-skill-structure.sh` |
| 证明 handoff 可消费 | 下游能从 canonical artifact 和 active registry 继续，不依赖聊天记忆或 Markdown 派生视图 | Role Capability Report + standard-chain validator / catalog evidence |
| 证明完整交付能力 | 一个真实低风险需求从 `product-director` 跑到 `delivery-owner`，人类只在 gate 点确认、裁决风险和最终签收 | End-to-End Pilot Evidence；未执行前不得宣称完整交付能力 |

## Change Scope

本次设计只创建 readiness 评审设计文档；后续执行评审时才会产生 evidence package、audit report、scenario report 或整改任务。

| File or Area | Change Type | Size |
| --- | --- | --- |
| `docs/standard-chain-team-readiness-20260422/design.md` | create | medium |

## Invariants

- 不修改 standard-chain skill、sidecar skill、canonical schema、validator、eval 或 test 命令。
- 不把 Markdown 或 HTML 派生视图升级为 standard-chain runtime fact source。
- 不让 `skill-harness` 在 audit mode 写文件或替工程 owner 做 transition decision。
- 不在无端到端试点证据时宣称完整团队交付能力。
- 不把 `delivery-owner` 变成专家 SOP 聚合器；它只保留调度、控制、状态与升级职责。

## Downstream Impact

| Consumer | Impact | Propagation Needed |
| --- | --- | --- |
| 评审执行者 | 获得 readiness 评审对象、证据包结构、噪音门禁和放行口径 | Yes；后续 writing-plans 需要将本设计转成可执行任务 |
| 团队负责人 | 获得是否进入受控试点的判断框架 | Yes；Readiness Summary 应按本设计输出 |
| standard-chain skill owner | 获得职责边界、噪音和 handoff 的整改依据 | Yes；S1/S2 findings 需要形成具体整改范围 |
| 团队试点使用者 | 获得试点边界和不能宣称的能力边界 | Yes；试点前需要同步 GO/FIX/NO-GO 结论 |

## Risks

| Risk | Impact | Mitigation |
| --- | --- | --- |
| 只看格式门禁，忽略角色胜任力 | 团队以为流程可用，但 AI 角色不能承担人类判断 | 角色胜任力报告作为进入试点的必要证据 |
| 噪音被当作文字风格问题 | active runtime 污染上下文，导致跳步、越权或事实源混用 | 噪音独立分级，S1/S2 阻断试点 |
| `skill-harness` 被误用为唯一放行依据 | LLM 审计替代机器门禁或真实试点，信心虚高 | 采用硬门禁、harness 审计、角色场景、端到端试点三层证据 |
| 端到端试点被过早宣传为正式能力 | 团队对成熟度产生误判，真实交付风险外溢 | 未有真实试点证据前只表述为“具备进入受控试点的准备度” |
| `delivery-owner` 吸收过多专家内容 | 控制面变重，职责重叠，上下文预算下降 | 明确它只做调度和升级，不复制专家 SOP |
