# skill-harness 标准流程 Harness 治理设计

## 背景

本设计冻结 `skill-harness` 的下一阶段方向：它从单个 Skill 的运行合同审计器升级为标准流程的 Harness 治理入口。用户在使用 `skill-harness` 审计某个 Skill 时，目标从泛化评分转向按照严格的 Harness 合同治理它在标准流程中的职责、主内容、状态流转、证据链、权限边界和工程化控制能力。

旧 `skill-audit` 归档中已经沉淀触发、加载、决策、执行、验证、演化六段链路，也沉淀 reference contract、runtime noise contract、permission/script contract、hook adapter contract、SubAgent handoff contract、schemas、field consumers、evals、examples、templates 和 renderer 等能力。

当前 `skill-harness` 已保留 read-first、consumer-first、evidence-first、JSON 按消费者触发、retired name 去噪、Darwin 候选独立裁决等轻量运行边界。

本设计的目标是把两者合并为一套可执行的最佳实践：用旧 `skill-audit` 补全能力视野，用当前 `skill-harness` 控制默认路径重量，用标准流程场景验证治理能力。

## 定位

`skill-harness` 的一句话定位：

```text
skill-harness 是标准流程的 Harness 治理入口：它规定 LLM 在被治理 Skill 中负责什么，SKILL.md 如何承载这些职责，工程机制如何控制状态、证据、权限、验证和演化。
```

它治理的是被指定的 Skill。LLM 保持运行时语义执行单元定位；治理责任属于 `skill-harness` 定义的合同和工程机制。

使用方式接近 `darwin-skill`：用户指定一个目标 Skill，`skill-harness` 按治理合同审计该 Skill 是否符合标准流程最佳实践。

## 治理对象

`skill-harness` 的治理对象包含两类：

| 对象 | 治理重点 |
| --- | --- |
| 单个 Skill | LLM 职责边界、主内容结构、资源路由、权限、证据、验证、演化噪音 |
| 标准流程链路中的 Skill | 所属阶段、上游输入、下游输出、状态转移、hard gate、消费者、交接边界 |

标准流程链路定义为：

```text
product-director
-> product-manager
-> design
-> test-design
-> tech-lead
-> delivery-owner
-> developer
-> verify / review / qa
-> sign-off / archive
```

`delivery-owner` 是关键校准样本：它在本仓库承载执行期交付闭环，能同时检验正确闭环变重、流程编排噪音和工程状态真源漂移。

## 三层治理模型

### 第一层：LLM 职责层

这一层回答：当某个 Skill 被 `skill-harness` 治理后，LLM 在该 Skill 中负责什么，哪些事项交给工程机制或用户承接。

LLM 负责：

| 职责 | 含义 |
| --- | --- |
| 触发判断 | 判断用户请求是否匹配该 Skill，识别相邻 Skill 冲突 |
| 目标理解 | 理解用户目标、约束、完成边界和验收口径 |
| 语义裁决 | 判断当前情况属于哪个流程分支、风险类型或异常状态 |
| 流程编排 | 决定下一步读取哪个 reference、调用哪个 script、派发哪个 agent、触发哪个 gate |
| 证据解释 | 解释工程产物、验证输出和风险边界对用户的意义 |
| 风险升级 | 在越权、证据不足、状态不一致、验证失败时停止推进并升级 |
| 人类对齐 | 写入、删除、提交、签收、风险接受、外部副作用前请求用户确认 |

LLM 交接事项：

| 事项 | 承接方式 |
| --- | --- |
| 状态真源 | 状态需要由 artifact、validator、hook 或脚本维护 |
| 状态授权 | 状态变化需要工程门禁或用户确认授权 |
| 完成证明 | 完成需要 fresh proving command、真实证据或用户确认支撑 |
| 用户签收 | 业务风险接受由用户完成 |
| 门禁失败处理 | 失败后进入诊断、修复、复验和用户对齐闭环 |
| 机器事实源 | 机器消费者读取结构化 artifact |
| 凭记忆承接跨轮状态 | 跨轮状态需要落到可读事实源 |

### 第二层：Skill 主内容层

这一层回答：为了让 LLM 正确履行职责，`SKILL.md` 主内容需要放什么，哪些内容属于运行时噪音。

`SKILL.md` 的定义：

```text
SKILL.md 是 LLM 的运行时入口和路由器；知识库、历史档案、schema 手册和全量流程百科进入按需资源或 archive。
```

主内容保留：

| 内容 | 用途 |
| --- | --- |
| frontmatter | 描述触发、权限、自动/手动调用属性 |
| 一句话定位 | 让 LLM 识别角色和相邻边界 |
| HARD-GATE | 放置最高优先级运行规则 |
| LLM 职责边界 | 明确职责、交接点和升级条件 |
| 默认流程 | 描述高频路径和关键分支 |
| reference 路由 | 指向低频方法、示例、模板、规则和工程合同 |
| 输出合同 | 规定人类输出或机器 artifact 的最低字段 |
| 停止条件 | 定义何时阻断、等待用户、触发 replan 或退出 |
| 完成校验 | 声称完成前需要的证据类型和验证命令 |

主内容去噪规则：

| 噪音类型 | 去向 |
| --- | --- |
| 历史迁移说明、旧版本对比、退役入口解释 | `docs/archive/` 或迁移报告 |
| 长篇方法论、调研材料、agent team review 过程 | `references/` 或研究文档 |
| schema 全字段说明、validator 实现细节 | `schemas/`、`scripts/` 或 runtime blueprint |
| 完整 examples/evals 数据集 | `examples/`、`evals/` |
| 无消费者目录说明 | 删除或保留在 archive |
| 过期 alias、兼容入口、旧命令名 | 删除；仅保留负例 fixture |
| 低频异常路径长说明 | 按触发条件路由到 reference |

主内容顺序需要保护 LLM 加载路径：

```text
frontmatter -> 定位 -> HARD-GATE -> 职责边界 -> 默认流程 -> 分支路由 -> 输出合同 -> 完成校验 -> references
```

主内容准入合同：

| 准入项 | 进入主内容条件 | 默认去向 |
| --- | --- | --- |
| 高频默认路径 | 当前调用每次都会用到，缺失会导致错误路由或错误交接 | `SKILL.md` 默认流程 |
| 状态转移前置条件 | 当前动作需要立刻检查，且能用一句话路由到工程 gate | `SKILL.md` gate 摘要 + 工程合同 |
| LLM 职责与交接点 | LLM 需要当场知道谁承接状态、证据、签收或副作用 | `SKILL.md` 职责边界 |
| 字段级 schema | 需要机器校验或 renderer 消费 | `schemas/` 或 `references/` |
| 低频异常案例 | 只在特定失败模式出现时读取 | `references/` 或 `examples/` |
| 长解释与方法论 | 用于学习、复盘或实现细节 | `references/` 或 `docs/archive/` |

每条 HARD-GATE 进入主内容前需要具备四个要素：触发条件、工程承接方式、状态结果、证据来源。缺任一项时，降为 reference guidance、eval case 或脚本校验规则。

主内容去噪判定矩阵：

| 判定字段 | 说明 |
| --- | --- |
| `runtime_path` | 内容是否处于默认运行加载路径 |
| `current_consumer` | 当前是否有 LLM、script、validator、renderer、hook、test 或 human reviewer 消费 |
| `default_step_required` | 当前默认路径是否每次都需要该内容 |
| `failure_if_absent` | 移出主内容后是否会导致错误路由、错误状态或证据断链 |
| `better_as_route` | 是否可由一句路由指向 reference、schema、script、example 或 eval |
| `cleanup_action` | `keep_inline / route_to_reference / move_to_schema / move_to_example / move_to_eval / archive` |

主内容噪音 finding 需要输出 `file:line`、`noise_class`、`consumer_status`、`target_location` 和证明方式。

### 第三层：工程化控制层

这一层回答：哪些事情交给工程机制稳定控制。

工程机制负责：

| 能力 | 责任 |
| --- | --- |
| JSON fact source | 只有机器消费者、跨轮状态、hook、validator、runner、Darwin gate、发布验证需要时启用 |
| schema validation | 校验结构、类型、枚举和必填字段 |
| semantic validation | 校验证据、状态、流转、消费者、权限和失败语义 |
| field consumers | 每个 runtime 字段需要声明消费者、用途、验证方式和删除条件 |
| scripts manifest | 命令需要声明 path、allowed args、denied args、timeout、输出根、失败语义和验证命令 |
| examples | 校准 LLM 对正例、反例、边界例的判断 |
| evals | 固化触发、非触发、权限、handoff、噪音、链路集成和失败路径样例 |
| templates | 承载稳定人类视图，保持派生展示层身份 |
| renderer | 从 JSON 派生 Markdown/HTML，并记录 provenance |
| hook adapter | 消费已验证 artifact，阻断非法状态流转 |
| SubAgent handoff | 约束 fork 输入、输出、证据、不确定点、消费者和下一步 |
| runtime noise checks | 识别无消费者、退役、迁移、临时和历史内容 |

工程触发合同：

| 能力 | 权威来源 | 证明方式 | 启用条件 | 删除条件 |
| --- | --- | --- | --- | --- |
| JSON fact source | JSON upgrade gate | named consumer + validation command + drop condition | 机器消费者、跨轮状态、hook、validator、runner、Darwin gate 或发布验证需要读取 | consumer 删除且无跨轮状态 |
| schema validation | `schemas/` | schema validator 正负例 | JSON artifact 成为机器事实源 | artifact 退回人类报告 |
| semantic validation | `scripts/` 或 `tests/` | semantic validator 或 contract test | 状态、证据、消费者、权限或 gate 需要机器裁决 | 语义裁决回到人类 review 且无机器 gate |
| field consumers | field consumer matrix | 缺 consumer / 缺 drop condition 的负例失败 | runtime 字段进入 artifact | 字段无消费者或不再影响 gate |
| evals | `evals/` | seed dataset 正负例 | 触发、非触发、handoff、噪音或失败路径需要回归样例 | 样例失去对应规则或迁移到真实测试 |
| hook adapter | hook adapter minimum contract | adapter fixture + rollback proof | hook 消费已验证 artifact 并阻断状态流转 | hook 下线且 registry/adapter 测试移除 |

核心原则：

```text
LLM can propose; engineering must authorize.
```

这条原则作用于状态、证据、权限、验证和副作用，保持 LLM 的语义执行单元定位。

## 目录能力模型

目录存在的前提是有消费者、验证路径和失败边界。目录质量由消费者、证据和验证路径证明。

| 目录 | 职责 | 创建条件 |
| --- | --- | --- |
| `references/` | 方法细节、审计合同、低频流程、handoff、runtime noise、hook adapter | 被 `SKILL.md` 契约式路由 |
| `schemas/` | runtime artifact schema、state vocabulary、field consumers | 存在机器事实源消费者 |
| `scripts/` | 确定性校验、validator、renderer、artifact builder | 有 manifest、测试、timeout 和输出边界 |
| `examples/` | 正例、反例、边界例、校准样本 | 被 eval、人类审计或 reference 消费 |
| `evals/` | seed dataset、触发/非触发、权限、handoff、链路失败样例 | 有可复跑命令和结果校验 |
| `templates/` | Markdown/HTML 或结构化报告模板 | 被 renderer 消费，且只是派生视图 |
| `agents/` | 平台暴露、SubAgent 角色边界 | 被运行时入口消费 |
| `rules/` | skill-local 权限或行为规则 | 与全局 rules 不同且有消费者 |
| `hooks/` | 局部 hook adapter 入口 | validator 稳定且接入范围被用户确认 |

reference 最小合同：

```text
Trigger / Read / Expect / Consume / Evidence / Sync
```

关键 reference 进入运行合同前需要写清：何时读取、读哪个文件、期望得到什么、谁消费、证据如何体现、相关文件变更时同步哪些对象。

hook adapter 最小合同：

```text
phase / trigger / input_artifact / allowed_action / output_artifact / failure_state / owner / rollback
```

hook 只消费已验证 artifact。缺少 `failure_state`、`owner` 或 `rollback` 时，先停留在 adapter 设计或测试 fixture，不进入 hook 实现。

## 旧 skill-audit 资产归位

归位动作定义：

| 动作 | 含义 |
| --- | --- |
| `keep_inline_summary` | 只保留一句运行时摘要，细节进入 reference |
| `route_to_reference` | 作为按需知识被 `SKILL.md` 路由 |
| `port_to_contract` | 迁入 active reference、schema、manifest 或 validator 合同 |
| `move_to_fixture` | 作为正反例或回归样例进入 `tests/fixtures` 或 `evals` |
| `triggered_artifact` | 只在用户接受 findings、发布复验或跨轮状态需要时生成 |
| `archive_only` | 只作为历史证据、迁移输入或反例保留 |

立即承接资产：

| 旧资产 | source_path | target_action | immediate_target_path | deferred_until | consumer | validation / drop / failure |
| --- | --- | --- | --- | --- | --- | --- |
| 六段链路：触发、加载、决策、执行、验证、演化 | `docs/archive/skill-auditor/runtime-source-2026-04-19/references/audit-method.md` | `keep_inline_summary` + `route_to_reference` | `shared/skills/skill-harness/SKILL.md` + `shared/skills/skill-harness/references/audit-method.md` | `none` | LLM default audit | `bash tests/test-skill-harness-contract.sh`; drop when audit dimensions move to machine schema; failure `AUDIT_DIMENSION_MISSING` |
| `runtime-noise-contract` | `docs/archive/skill-auditor/runtime-source-2026-04-19/references/runtime-noise-contract.md` | `port_to_contract` | `shared/skills/skill-harness/references/runtime-noise-contract.md` | `none` | main-content-noise audit | `bash tests/test-skill-harness-gates.sh`; drop when no runtime path consumes noise finding; failure `RUNTIME_NOISE_UNCLASSIFIED` |
| `reference-contract` | `docs/archive/skill-auditor/runtime-source-2026-04-19/references/reference-contract.md` | `port_to_contract` | `shared/skills/skill-harness/references/reference-contract.md` | `none` | LLM router + doc sync reviewer | reference fixture gate; drop when references leave runtime contract; failure `REFERENCE_CONTRACT_INCOMPLETE` |
| `permission-script-contract` | `docs/archive/skill-auditor/runtime-source-2026-04-19/references/permission-script-contract.md` | `port_to_contract` | `shared/skills/skill-harness/references/permission-script-contract.md` + `shared/skills/skill-harness/scripts/manifest.json` | `none` | script runner / hook adapter | manifest validation; drop when script leaves proof chain; failure `SCRIPT_MANIFEST_INCOMPLETE` |
| `hook-adapter-contract` | `docs/archive/skill-auditor/runtime-source-2026-04-19/references/hook-adapter-contract.md` | `route_to_reference` + `move_to_fixture` | `shared/skills/skill-harness/references/hook-adapter-contract.md` + `tests/fixtures/skill-harness/hook-adapter/` | hook implementation waits for hook registry consumer | hook registry / adapter tests | adapter fixture + rollback proof; drop when hook is removed; failure `HOOK_ADAPTER_UNBOUND` |
| `subagent-handoff-contract` | `docs/archive/skill-auditor/runtime-source-2026-04-19/references/subagent-handoff-contract.md` | `route_to_reference` + `move_to_fixture` | `shared/skills/skill-harness/references/subagent-handoff-contract.md` + `tests/fixtures/skill-harness/subagent-handoff/` | subagent runner waits for active handoff consumer | SubAgent dispatcher / reviewer | handoff fixture; drop when skill has no subagent path; failure `HANDOFF_CONTRACT_MISSING` |
| `field-consumers.json` | `docs/archive/skill-auditor/runtime-source-2026-04-19/schemas/field-consumers.json` | `port_to_contract` | `shared/skills/skill-harness/schemas/field-consumers.json` + `tests/fixtures/skill-harness/field-consumers/` | `none` | JSON upgrade gate | field-consumer validation; drop when no runtime field enters JSON; failure `FIELD_CONSUMER_MISSING` |
| schemas | `docs/archive/skill-auditor/runtime-source-2026-04-19/schemas/skill-audit.schema.json` + `docs/archive/skill-auditor/runtime-source-2026-04-19/schemas/state-vocabulary.json` | `move_to_fixture` by default | `tests/fixtures/skill-harness/schemas/` | active schema path waits for named machine consumer | validator / runner / release gate | schema positive and negative fixtures; drop when JSON artifact leaves machine fact source; failure `SCHEMA_CONSUMER_MISSING` |
| evals | `docs/archive/skill-auditor/runtime-source-2026-04-19/evals/evals.json` | `move_to_fixture` | `tests/fixtures/skill-harness/evals/` | active eval runner waits for regression consumer | regression gate | eval runner; drop when rule loses runtime consumer; failure `EVAL_CASE_STALE` |
| examples | `docs/archive/skill-auditor/runtime-source-2026-04-19/examples/*.md` | `move_to_fixture` + `route_to_reference` | `tests/fixtures/skill-harness/examples/` + `shared/skills/skill-harness/references/example-contract.md` | `none` | LLM judgment calibration | fixture review; drop when example lacks rule owner; failure `EXAMPLE_WITHOUT_CONSUMER` |

触发式资产：

| 旧资产 | source_path | target_action | deferred_until | target_path_when_triggered | consumer | validation / drop / failure |
| --- | --- | --- | --- | --- | --- | --- |
| templates / renderer | `docs/archive/skill-auditor/runtime-source-2026-04-19/templates/*` + `scripts/render_report.py` | `triggered_artifact` | structured findings require human projection | `shared/skills/skill-harness/templates/` + `shared/skills/skill-harness/scripts/render_report.py` | human report viewer | rendered-view validation; drop when no human projection is needed; failure `DERIVED_VIEW_UNBOUND` |
| `optimization-plan.json` | `docs/archive/skill-auditor/runtime-source-2026-04-19/schemas/optimization-plan.schema.json` | `triggered_artifact` | user accepts findings and enters implementation planning | `docs/{feature}/phase-{N}/optimization-plan.json` | user-approved implementation flow | plan consumption validation; drop when audit remains read-only; failure `PLAN_WITHOUT_ACCEPTED_FINDINGS` |
| `verification-result.json` | `docs/archive/skill-auditor/runtime-source-2026-04-19/schemas/verification-result.schema.json` | `triggered_artifact` | release gate or machine recheck consumes verification result | `docs/{feature}/phase-{N}/verification-result.json` | release gate / cross-round state | verification-result validation; drop when no release or machine recheck consumes it; failure `VERIFICATION_RESULT_UNCONSUMED` |

剩余旧资产裁决：

| 旧资产组 | source_path | target_action | active_target_or_archive_boundary | consumer | validation / drop / failure |
| --- | --- | --- | --- | --- | --- |
| old runtime entry | `docs/archive/skill-auditor/runtime-source-2026-04-19/SKILL.md` | `archive_only` | same archive path | migration reviewer | `bash tests/test-skill-harness-migration.sh`; drop when archive retention policy changes; failure `OLD_RUNTIME_ENTRY_ACTIVE` |
| old agent exposure | `docs/archive/skill-auditor/runtime-source-2026-04-19/agents/openai.yaml` | `archive_only` | same archive path | migration reviewer | install smoke; drop when active exposure uses `skill-harness`; failure `OLD_AGENT_EXPOSURE_ACTIVE` |
| permission profiles | `docs/archive/skill-auditor/runtime-source-2026-04-19/rules/permission-profiles.md` | `route_to_reference` + `move_to_fixture` | `shared/skills/skill-harness/references/permission-script-contract.md` + `tests/fixtures/skill-harness/permission-profiles/` | permission/script audit | permission fixture gate; drop when no permission profile is consumed; failure `PERMISSION_PROFILE_UNBOUND` |
| source map | `docs/archive/skill-auditor/runtime-source-2026-04-19/references/source-map.md` | `archive_only` | same archive path | migration reviewer | archive reference check; drop when source map is superseded by active manifest; failure `SOURCE_MAP_REACTIVATED` |
| quality mapping | `docs/archive/skill-auditor/runtime-source-2026-04-19/references/quality-dimension-mapping.md` | `move_to_fixture` | `tests/fixtures/skill-harness/dimension-mapping/` | dimension migration gate | dimension enum fixture; drop when final enum migration completes; failure `QUALITY_MAPPING_DRIFT` |
| old scripts manifest | `docs/archive/skill-auditor/runtime-source-2026-04-19/scripts/manifest.json` | `move_to_fixture` | `tests/fixtures/skill-harness/legacy-manifest/manifest.json` | script manifest gate | manifest fixture validation; drop when every retained command has active owner; failure `LEGACY_MANIFEST_UNCLASSIFIED` |
| old audit runner scripts | `docs/archive/skill-auditor/runtime-source-2026-04-19/scripts/audit_skill.py` + `scripts/validate_*.py` + `scripts/run_evals.py` | `move_to_fixture` by default | `tests/fixtures/skill-harness/legacy-scripts/` | script behavior regression | script fixture classification; drop when no active behavior uses the script; failure `LEGACY_SCRIPT_UNCLASSIFIED` |
| old artifact builders | `docs/archive/skill-auditor/runtime-source-2026-04-19/scripts/generate_optimization_plan.py` + `scripts/build_verification_result.py` + `scripts/render_report.py` | `triggered_artifact` | triggered target paths listed above | artifact consumer | artifact builder fixture; drop when triggered artifact path is removed; failure `LEGACY_BUILDER_UNBOUND` |
| archive README docs | `docs/archive/skill-auditor/runtime-source-2026-04-19/README.md` + `evals/README.md` | `archive_only` | same archive path | migration reviewer | archive reference check; drop when archive is retired; failure `ARCHIVE_DOC_ACTIVE` |

旧 `skill-auditor` 名称保留为 archive、fixture、历史证据和迁移审计输入。active runtime 使用 `skill-harness`。

## 标准流程集成合同

当 `skill-harness` 审计标准流程中的某个 Skill 时，需要按以下合同判断该 Skill 是否正确嵌入链路：

基础字段每次都需要输出：

| 字段 | 含义 |
| --- | --- |
| `role` | 该 Skill 在标准流程中的职责 |
| `input` | 必须读取的上游真源 |
| `output` | 必须产出的下游工件 |
| `state_transition` | 允许推动的状态变化 |
| `hard_gate` | 状态转移前需要通过的门禁 |
| `evidence` | 结论可复验的证据 |
| `consumer` | 谁消费该 Skill 的输出 |
| `handoff_boundary` | 需要交给相邻角色、工程机制或用户承接的事项 |
| `gate_type` | `machine_gate / human_review_gate / user_decision_gate` |
| `audit_proof_type` | `file_evidence / fixture_proof / fresh_proving` |
| `proof_scope` | `target_file / fixture / target_skill / standard_chain` |
| `freshness_required` | 当前裁决是否需要读取真实目标并 fresh 运行 |
| `dry_run_allowed` | 当前裁决是否允许只输出预期发现 |

条件字段由 proof 或 gate 类型触发：

| 触发条件 | 条件字段 |
| --- | --- |
| `gate_type=machine_gate` | `must_block_when / failure_state` |
| `gate_type=human_review_gate` | `review_owner / verdict_field / block_when / evidence_ref` |
| `gate_type=user_decision_gate` | canonical envelope + `user-decision` 必填字段：`artifact_type / artifact_id / schema_version / producer / produced_at / chain_version / chain_registry_digest / authority_scope / authoritative_fields / current_stage / decision / decision_source / actor_id / sign_off_status / business_risk_acceptance_status / authority_proof_refs / decision_basis_refs / director_lock_digests / decision_payload_digest / baseline_plan_version_ref / baseline_tasks_version_ref / active_plan_version_ref / active_tasks_version_ref` |
| `gate_type=user_decision_gate` authorization | `must_verify_authority_proof_refs / must_verify_payload_digest / allowed_final_decision_sources / must_match_actor_and_channel / must_match_active_baseline_refs / must_block_when / failure_state` |
| `allowed_final_decision_sources` source | read `contracts/canonical/authority-registry.yaml:v1_user_decision_policy.allowed_final_sources`; non-registry final source, proof mismatch, payload digest mismatch, actor/channel mismatch, or active baseline drift writes `failure_state` |
| `audit_proof_type=fresh_proving` | `proof_command`，命令需要读取真实目标并可复跑 |
| `audit_proof_type=file_evidence` | `file:line / evidence_locator` |
| `audit_proof_type=fixture_proof` | `fixture_path / fixture_command` |
| JSON 进入机器事实源 | `consumer / read_purpose / validation_command / drop_condition` |

示例裁决：

| Skill | 正向职责 | 交接边界 |
| --- | --- | --- |
| `product-director` | 冻结根问题、目标、范围和 Phase 边界 | 执行期交付交给 `delivery-owner`，质量判断交给 `qa`，签收交给用户 |
| `product-manager` | 把 Director 基线细化为 PRD、UNIT、AC 和业务流程 | 技术结构交给 `design`，测试义务交给 `test-design`，执行规划交给 `tech-lead` |
| `design` | 冻结系统架构、模块边界、接口和技术取舍 | 测试设计消费架构风险，实施计划交给 `tech-lead` |
| `test-design` | 冻结测试义务、test cases、execution mode 和 QA handoff | 计划拆分交给 `tech-lead`，独立验收交给 `qa` |
| `tech-lead` | 冻结 plan、scope、task、gate matrix，并消费 `test-cases.json` | 实现交给 `developer`，执行调度交给 `delivery-owner` |
| `delivery-owner` | 执行期编排、偏差治理、动态 gate 升级、目标级收口 | 需求定义交给产品链路，技术方案交给设计链路，质量判断交给 `qa`，业务风险接受交给用户 |
| `developer` | 按 Task 与 AC 完成 RED -> GREEN -> REFACTOR，并产出 developer evidence | Task 验收交给 `verify`，代码审查交给 `review`，用户视角验证交给 `qa` |
| `verify` | 验证 Task 级 AC 覆盖、文件范围和实现证据 | 不满足 AC 时回到 `developer`，通过后进入 review/qa gate |
| `review` | 独立审查代码风险、证据链和质量门禁 | FAIL 交给 `fix` 或 `developer`，PASS/COMMENT 交给 `delivery-owner` 汇总 |
| `qa` | 独立质量判断、release recommendation、residual risk | 最终签收和业务风险接受交给用户 |
| `sign-off` | 冻结用户签收、风险接受和最终决策来源 | 交付归档交给 `archive`，未签收时阻断提交或发布 |
| `archive` | 归档已验证交付工件、变更摘要和残余风险 | 只消费已冻结证据，不生成新的质量结论 |

delivery-owner 校准矩阵：

| 校准场景 | structured dimension results | legacy baseline label | 触发条件 | 证据 |
| --- | --- | --- | --- | --- |
| canonical JSON、manifest、validator、handoff 全部有消费者 | `[{dimension: Chain Integration, dimension_result: PASS}, {dimension: Engineering Control, dimension_result: PASS}, {dimension: Verification, dimension_result: PASS}]` | `Correctness PASS / Practice PASS` | `delivery-state.json / signoff-package.json / user-decision.json` 为运行时真源，manifest 覆盖 fresh proof | 目标文件、manifest、validator 输出 |
| 功能闭环存在，但主内容或 reference 仍有 legacy/PM/Markdown 双轨噪音 | `[{dimension: Main Content Noise, dimension_result: FAIL}, {dimension: Engineering Control, dimension_result: WARN}]` | `Correctness PASS / Practice FAIL` | `SKILL.md` 能指导执行，但运行路径仍教未来 agent 使用旧真源或旧角色名 | `file:line` + runtime noise finding |
| fresh proof 命令未进入 manifest 或无法复跑 | `[{dimension: Verification, dimension_result: FAIL}, {dimension: Engineering Control, dimension_result: FAIL}]` | `Correctness PASS / Practice FAIL` | SKILL 要求运行某命令，但 manifest 缺少 owner、allowed args、timeout、output root、failure state 或 exit semantics | manifest finding + fresh proof command |
| 机器 gate 只写说明，没有 `must_block_when / failure_state` | `[{dimension: Chain Integration, dimension_result: FAIL}, {dimension: Engineering Control, dimension_result: FAIL}]` | `Correctness PASS / Practice FAIL` | 人能理解 gate，但工程无法 fail-closed | standard-chain integration finding |
| delivery-owner dry-run | `{dry_run_verdict: CONTINUE|STOP, aggregation: high_value_finding}` | `no legacy label` | dry-run 输出至少 3 条高价值 finding，且每条有真实 `file:line`、治理维度、下一步实施对象、收益假设、停止条件 | dry-run report + file evidence |

delivery-owner dry-run 的价值门槛：

| 字段 | 含义 |
| --- | --- |
| `finding.file_line` | 真实目标文件位置 |
| `finding.dimension` | 命中的治理维度，如 Main Content Noise、Engineering Control、Chain Integration |
| `next_implementation_object` | 下一步要改的对象，如 `SKILL.md`、manifest、validator、reference、fixture |
| `expected_benefit` | 修复后会提升的可验证能力 |
| `stop_condition` | 发现数量、严重度或收益不达标时停止推进 |

`high_value_finding` 判定：

| 判定项 | 要求 |
| --- | --- |
| `success_criterion_ref` | 映射到本设计成功标准中的一项 |
| `implementation_boundary_ref` | 命中本设计允许进入实施计划的能力范围 |
| `dimension_spread` | 计入聚合时覆盖 Main Content Noise、Engineering Control、Chain Integration、Directory Capability 中的至少一类 |
| `proof_or_gate_ref` | 包含可复跑 proof 入口、fixture gate 或机器 gate 字段 |
| `next_implementation_object` | 指向下一步要改的真实对象 |
| `expected_benefit` | 写明修复后提升的可验证能力 |
| `stop_condition` | 写明该 finding 停止推进的条件 |
| `non_duplicate` | 不与已计入 finding 指向同一个根因和同一个实施对象 |

dry-run 聚合规则：

| verdict | 条件 |
| --- | --- |
| `CONTINUE` | 至少 3 条 `high_value_finding`，覆盖至少 2 个治理维度，其中至少 1 条命中 Engineering Control 或 Chain Integration，且每条都有下一步实施对象、可验证收益、停止条件和 proof/gate |
| `STOP` | 少于 3 条 `high_value_finding`，或全部集中在同一低收益维度，或任一 finding 缺实施对象、收益说明、停止条件、proof/gate |

dry-run 只给出 `CONTINUE / STOP` 建议。进入实施或发布声明前，需要 fresh proving command。

## 审计输出模型

默认输出为结构化 Markdown，默认字段保持最小集合：

```text
overall_verdict
finding_severity
dimension
dimension_result
file:line
evidence
impact
recommendation
audit_proof_type
proof_command
proof_scope
freshness_required
dry_run_allowed
gate_type
```

条件字段只在对应 gate、proof 或 JSON 升级场景出现：

| 触发条件 | 条件字段 |
| --- | --- |
| `gate_type=human_review_gate` | `review_owner / verdict_field / block_when / evidence_ref` |
| `gate_type=user_decision_gate` | canonical envelope + `user-decision` 必填字段 + authorization 字段；字段清单以标准流程集成合同为准 |
| `audit_proof_type=file_evidence` | `file:line / evidence_locator` |
| `audit_proof_type=fixture_proof` | `fixture_path / fixture_command` |
| `audit_proof_type=fresh_proving` | `proof_command / freshness_required=true` |
| `dry_run_allowed=true` | `dry_run_verdict / high_value_finding` 聚合字段 |
| JSON 进入机器事实源 | `consumer / read_purpose / validation_command / drop_condition / failure_state` |

证明字段规则：

| 场景 | 要求 |
| --- | --- |
| dry-run | `audit_proof_type=file_evidence` 或 `fixture_proof`，`dry_run_allowed=true`，只允许输出预期发现和 `CONTINUE / STOP` |
| 人类只读审计 | `audit_proof_type=file_evidence`，需要 `file:line` 和 evidence |
| 机器 gate、发布、最佳实践声明 | `audit_proof_type=fresh_proving`，`freshness_required=true`，`proof_command` 必须读取真实目标并可复跑 |
| 证据定位命令 | 作为 `evidence_locator` 写入 evidence；fresh proof 由 `audit_proof_type=fresh_proving` 承担 |

JSON 只在存在机器消费者时启用。启用前需要记录：

```text
consumer
read_purpose
validation_command
drop_condition
```

JSON 启用后成为唯一机器事实源。Markdown/HTML 从 JSON 派生，用于人类阅读和复盘。

proof command 语义：

| 证明类型 | 可证明内容 | 适用边界 |
| --- | --- | --- |
| file evidence | 目标文件存在明确文本、字段、路径或锚点 | 适合 read-first 审计和 dry-run |
| fixture proof | 合同样例、正负例、失败路径稳定 | 适合回归样例，代表规则样例稳定 |
| fresh proving command | 当前目标 Skill 的真实文件、消费者、门禁字段和证据锚点被命令读取并校验 | 适合发布、合入、最佳实践声明 |

dry-run 只能输出“预期可发现问题”。发布或最佳实践声明需要 fresh proving command。

## 审计维度

`skill-harness` 的审计维度采用运行链路加三层治理模型组合：

| 维度 | 审计问题 |
| --- | --- |
| Trigger | 触发、非触发、相邻 Skill 冲突是否清楚 |
| Loading | 主内容是否干净，低频知识是否按需路由 |
| Decision | LLM 分支判断是否有规则、证据和停止条件 |
| Execution | 权限、脚本、agent handoff 和副作用边界是否受控 |
| Verification | fresh proof、schema、semantic、eval、消费者校验是否支撑结论 |
| Evolution | 迁移、retired name、runtime noise、Darwin 候选和回退边界是否清楚 |
| Main Content Noise | 主内容是否只承载高频运行规则和路由，低频内容是否进入按需资源 |
| Chain Integration | 该 Skill 是否正确嵌入标准流程 |
| Engineering Control | 状态、证据、权限和验证是否交给工程机制 |
| Directory Capability | 目录、schema、script、eval、example、template、hook 是否有消费者、验证路径和失败边界 |

维度枚举裁决：

| 裁决项 | 结论 |
| --- | --- |
| final_dimension_enum | `Trigger / Loading / Decision / Execution / Verification / Evolution / Main Content Noise / Chain Integration / Engineering Control / Directory Capability` |
| legacy_fixture_status | 旧 `Correctness / Practice / Boundary / Proof Chain` 只作为 baseline smoke 输入保留 |
| implementation_gate | 后续 checker 需要拒绝 final enum 之外的新增 finding dimension |
| fixture_update_boundary | 实施 proof 创建时迁移 `tests/fixtures/skill-harness/cases/*.json` 的旧维度字段，并同步 active runtime 的 `shared/skills/skill-harness/SKILL.md` 与 `tests/test-skill-harness-contract.sh` |
| active_runtime_legacy_label_boundary | active audit output 使用 final enum；`Correctness PASS / Practice FAIL` 只保留为 `legacy_baseline_label` 或 archive text |

旧四维迁移映射：

| 旧维度 | 迁移到 |
| --- | --- |
| `Correctness` | `Trigger / Loading / Decision / Execution`，按证据所在运行环节选择 |
| `Practice` | `Main Content Noise / Engineering Control / Directory Capability / Chain Integration`，按噪音、工程控制、目录能力或链路集成根因选择 |
| `Boundary` | `Execution / Evolution / Engineering Control`，按权限、迁移、脚本或状态控制根因选择 |
| `Proof Chain` | `Verification` |

verdict enum 裁决：

| 字段 | 合法值 | 适用场景 | checker 拒绝规则 |
| --- | --- | --- | --- |
| `overall_verdict` | `PASS / FAIL / COMMENT` | 整体审计结论 | 旧 `Correctness PASS / Practice FAIL` 只允许出现在 `legacy_baseline_label` |
| `dimension_result` | `PASS / FAIL / WARN / NOT_APPLICABLE` | 单个 final dimension 的裁决 | `dimension` 不在 `final_dimension_enum` 或 `dimension_result` 不在合法值内均非法 |
| `finding_severity` | `S1 / S2 / S3 / INFO` | finding 风险排序 | 非枚举 severity 视为非法 |
| `dry_run_verdict` | `CONTINUE / STOP` | 只读推理治理校准 | dry-run 以外输出该字段视为非法 |
| `legacy_baseline_label` | historical string | baseline smoke fixture 和迁移报告 | active audit output 不消费该字段 |

## 职责边界

`skill-harness` 的边界：

- active Skill 名称使用 `skill-harness`，旧 `skill-auditor` 保留为 archive、fixture 和迁移证据。
- 默认审计采用结构化 Markdown，JSON 由机器消费者触发。
- schema、validator、renderer、hook adapter 通过消费者进入运行合同。
- LLM 是语义执行单元，治理权属于合同和工程机制。
- 交付推进由 `delivery-owner` 承担。
- 候选生成由 `darwin-skill` 承担。
- 新 Skill 创建由 `skill-creator` 承担。
- 机器事实源使用 JSON，Markdown/HTML 作为派生视图。
- Skill 质量由消费者、证据和验证路径证明。

## 成功标准

本设计达成后，`skill-harness` 的最佳实践需要满足：

baseline smoke 只证明当前运行基线未回退。新增合同验收由 `implementation_proof_to_create` 承担，后续 `tasks.json / plan.json` 需要按 RED -> GREEN 创建对应 proof。

| 标准 | 可观察输出 | BLOCK 条件 | baseline_smoke_existing | implementation_proof_to_create |
| --- | --- | --- | --- | --- |
| LLM 职责清楚 | 目标 Skill 有 `responsibility / handoff / escalation` 合同 | 职责、交接点或升级条件缺任一项 | `bash tests/test-skill-harness-contract.sh` | `tests/test-skill-harness-responsibility-contract.sh` |
| 主内容可执行 | `SKILL.md` 命中主内容准入合同，低频内容有 route | 主内容出现无 consumer 的历史、schema 全字段、完整 eval 数据或旧入口说明 | `bash tests/test-skill-harness-gates.sh` | `tests/test-skill-harness-main-content-noise.sh` |
| 噪音可识别 | finding 输出 `noise_class / consumer_status / target_location` | runtime path 内容缺 current consumer 且无 cleanup action | `bash tests/test-skill-harness-gates.sh` | `tests/test-skill-harness-runtime-noise.sh` |
| 工程控制接住状态 | 状态、证据、权限、验证和副作用有 artifact、manifest、validator、hook 或用户确认承接 | 仅有自然语言声明，无工程或用户承接证据 | `bash tests/test-skill-harness-gates.sh` | `tests/test-skill-harness-engineering-control.sh` |
| 复杂度有消费者 | JSON、schema、script、eval、example、template、hook 都声明 consumer、validation path、drop condition | 缺 consumer、validation path 或 drop condition | `none` | `tests/test-skill-harness-field-consumers.sh` |
| 标准链路可审计 | 标准链路角色目录完整，基础字段完整，条件字段按 gate/proof 类型出现 | 标准链路角色缺失；基础字段缺失；`gate_type=machine_gate` 缺 `must_block_when / failure_state`；`gate_type=human_review_gate` 缺 `review_owner / verdict_field / block_when / evidence_ref`；`gate_type=user_decision_gate` 缺 canonical `user-decision` 必填字段或授权校验字段；`audit_proof_type=fresh_proving` 缺 `proof_command`；`audit_proof_type=file_evidence` 缺 `file:line / evidence_locator`；`audit_proof_type=fixture_proof` 缺 `fixture_path / fixture_command` | `bash tests/test-delivery-owner-phase3-contract.sh` | `tests/test-skill-harness-standard-chain-integration.sh` |
| delivery-owner 校准可证明 | dry-run report 至少 3 条非重复 high-value finding，覆盖至少 2 个治理维度，至少 1 条命中 Engineering Control 或 Chain Integration，且每条有真实语义行、实施对象、收益、停止条件和 proof/gate | finding 只指向 frontmatter 或抽象评价；少于 3 条高价值 finding；缺实施对象、收益、停止条件或 proof/gate；STOP 负例未覆盖 | `none` | `tests/test-skill-harness-dry-run.sh` |
| 旧资产被归位 | 立即承接资产有 `source_path / target_action / immediate_target_path / consumer / validation / drop / failure`；触发式资产有 `deferred_until / target_path_when_triggered` | 旧资产只做名称映射；立即承接资产缺真实目标路径；触发式资产缺触发条件或触发后目标路径；target_action 无 consumer、validation、drop、failure；同一 source 同时进入 immediate 与 triggered | `bash tests/test-skill-harness-migration.sh` | `tests/test-skill-harness-directory-capability.sh` |
| legacy label 迁移 | active runtime 输出使用 final enum，legacy label 只保留在 baseline fixture、迁移报告或 archive text | `shared/skills/skill-harness/SKILL.md`、`tests/test-skill-harness-contract.sh` 或 active fixture 要求 active output 使用 `Correctness PASS / Practice FAIL` | `bash tests/test-skill-harness-contract.sh` | `tests/test-skill-harness-legacy-label-migration.sh`，覆盖 `shared/skills/skill-harness/SKILL.md`、`tests/test-skill-harness-contract.sh`、`tests/fixtures/skill-harness/cases/delivery-owner-practice-risk.json` |
| 当前轻量边界保留 | 默认审计仍是 read-first、structured Markdown、evidence-first、consumer-first | 默认路径强制 JSON/schema/renderer/hook 全量启用 | `bash tests/test-skill-harness-contract.sh` + `bash tests/test-skill-harness-gates.sh` | `tests/test-skill-harness-lightweight-path.sh` |

## 方案取舍

| 方案 | 裁决 | 原因 | 失效条件 |
| --- | --- | --- | --- |
| 正向准入合同 + 少量机器 gate | 采用 | 主内容保持正向引导，工程合同保留 fail-closed 语义 | gate 无 failure state 或 proof command |
| 负向限制清单驱动 | 不作为主路径 | 容易把 Skill 主内容写成限制列表，导致 LLM 过度收缩 | 高风险副作用入口需要明确阻断时，可下沉到工程字段 |
| 复制旧 `skill-audit` 全平台能力 | 不作为默认路径 | 会恢复旧重量，干扰 read-first 审计 | 出现真实机器消费者时按触发合同引入 |
| 仅保留当前轻量 `skill-harness` | 不作为目标态 | 覆盖不了标准流程集成、主内容去噪和目录能力审计 | 标准流程治理需求撤销时可回退 |

## 风险与裁决

| 风险 | 裁决 |
| --- | --- |
| 旧资产全量恢复导致 `skill-harness` 变重 | 按消费者触发，默认路径只保留最小审计合同 |
| 轻量审计覆盖不足导致标准流程治理能力缺口 | 新增 Chain Integration、Main Content Noise、Directory Capability 三类审计 |
| LLM 职责被误解成 LLM 治理标准流程 | 明确 LLM 只是语义执行单元，治理权属于合同和工程机制 |
| JSON 重新变成仪式化产物 | JSON 触发依据是机器消费者、validation path 和 drop condition |
| `delivery-owner` 被当成全能 owner | 标准流程集成合同明确 role/input/output/handoff_boundary |
| examples/evals 被误当成真实质量收益 | eval 证明边界样例稳定，质量收益需要真实案例和 fresh proof 支撑 |

## 实施范围边界

本设计允许进入实施计划的能力范围限定为：

| 能力 | 设计边界 |
| --- | --- |
| LLM responsibility contract | 定义 LLM 在被治理 Skill 中的职责、交接点、升级条件和人类确认点 |
| main-content-noise audit | 审计 `SKILL.md` 主内容是否聚焦高频运行规则和路由 |
| directory-capability audit | 审计目录是否有消费者、验证路径和失败边界 |
| standard-chain integration audit | 审计目标 Skill 是否正确嵌入标准流程 |
| field-consumer gate | 阻断无消费者 runtime 字段进入机器事实源 |
| retained `skill-audit` asset mapping | 将旧资产按职责归入新治理模型，并绑定可执行 gate 承接方式；active runtime 保持 `skill-harness` |

后续实施工件承载任务拆分、执行顺序、文件范围和验证命令；进入标准链路运行态时，`tasks.json / plan.json` 是机器真源，Markdown 只作为人类计划视图。
