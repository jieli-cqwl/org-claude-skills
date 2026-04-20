# skill-auditor Runtime 蓝图

## 目的

本文件承载 `skill-auditor` 的 Harness Engineering 细节。`design.md` 冻结方向和边界；本文件冻结 JSON artifact、schema、状态、validator、renderer 和 hook adapter 的工程合同。

## Runtime 原则

1. JSON artifact 是机器事实源。
2. Markdown/HTML 是派生视图。
3. 字段进入 artifact 前通过 consumer-first gate。
4. schema validation 证明形状，semantic validation 证明语义、状态、证据和消费者一致。
5. hook adapter 只消费已验证 artifact，不自行解释 Markdown。

## Artifact profiles

| artifact | 职责 | 主要消费者 |
| --- | --- | --- |
| `skill-audit.json` | 记录目标 Skill、审计范围、发现、证据和风险 | renderer、optimization planner、semantic validator |
| `optimization-plan.json` | 记录采纳策略、非目标、文件边界、回退和实施约束 | `tasks.md`、`plan.md`、执行 Agent |
| `verification-result.json` | 记录 schema、semantic validation、eval 和 fresh command 结果 | final report、hook adapter、benchmark |

## 公共字段

| 字段 | 类型 | 消费者 | 用途 | drop condition |
| --- | --- | --- | --- | --- |
| `artifact_type` | enum | schema validator、renderer | 识别 artifact profile | 无消费者时删除 artifact |
| `schema_version` | string | schema validator、migration | 控制 schema 演化 | 不允许省略 |
| `artifact_id` | string | registry、renderer | 建立稳定引用 | 无跨文件引用时可降为文件名 |
| `producer` | object | final report、debug | 记录模型、时间、命令 | 无法采集时写明来源为空 |
| `inputs` | array | semantic validator | 记录目标 Skill、source notes、design refs | 无输入引用时 validation 失败 |
| `status` | enum | state validator、hook adapter | 表达 artifact 生命周期 | 无状态消费时降级为报告字段 |
| `design_anchors` | array | tasks/plan、coverage report | 连接 SO-* 锚点 | 无设计锚点时 validation 失败 |
| `evidence_refs` | array | semantic validator、human review | 指向文件、命令输出、hash | 无证据时不能产生 FAIL |
| `rendered_views` | array | renderer、stale checker | 记录派生视图 provenance | 无 renderer 时为空数组 |

## skill-audit.json 字段

| 字段 | 消费者 | 语义 |
| --- | --- | --- |
| `target_skill` | audit runner、renderer | 被审 Skill 的路径、hash、入口描述 |
| `scope` | audit runner、human review | 审计范围和非范围 |
| `findings` | optimization planner、renderer | 结构化问题列表 |
| `findings[].severity` | semantic validator、report | `FAIL`、`WARN`、`INFO` |
| `findings[].evidence_level` | semantic validator | E1-E5 来源等级 |
| `findings[].source_marker` | coverage report | C09-C14、C99、L、O、S |
| `findings[].file_ref` | human review、fix agent | 目标文件和行号 |
| `findings[].recommendation` | optimization planner | 改造建议 |
| `permission_profile` | permission validator | read/edit/script/commit 边界 |
| `reference_contracts` | reference validator | 契约式引用检查结果 |

## optimization-plan.json 字段

| 字段 | 消费者 | 语义 |
| --- | --- | --- |
| `accepted_findings` | tasks generator | 被采纳的 audit finding id |
| `rejected_findings` | review report | 未采纳原因 |
| `file_boundaries` | plan generator、developer | 每个改动的文件范围 |
| `non_goals` | developer、reviewer | 不进入实施的范围 |
| `rollback` | plan validator、human review | 回退动作 |
| `verification_contracts` | plan generator、validator | 命令、输入、预期输出、通过条件 |

## verification-result.json 字段

| 字段 | 消费者 | 语义 |
| --- | --- | --- |
| `schema_validation` | final report、hook adapter | schema validator 结果 |
| `semantic_validation` | final report、hook adapter | semantic validator 结果 |
| `fresh_commands` | final report | 命令文本、退出码、输出摘要 |
| `eval_results` | benchmark、human review | seed dataset 结果 |
| `coverage` | coverage report | SO-*、source marker、AC 覆盖 |
| `decision` | final report、hook adapter | `verified`、`blocked`、`partial` |

## State vocabulary

| state | 含义 | 可进入条件 |
| --- | --- | --- |
| `draft` | artifact 已生成但未验证 | 初始产出 |
| `audited` | `skill-audit.json` 通过 schema 与基础语义校验 | audit runner 通过 |
| `planned` | `optimization-plan.json` 能机械消费 audit findings | plan validator 通过 |
| `implemented` | 文件改动已产生并绑定 plan step | diff coverage 通过 |
| `verified` | fresh commands、schema、semantic validation 和 eval 通过 | verification-result 通过 |
| `blocked` | 缺字段、证据断链、命令失败或用户裁决阻断 | 任一 gate 失败 |

## State transitions

| from | action | to | required evidence |
| --- | --- | --- | --- |
| `draft` | `validate_audit` | `audited` | schema validation、target skill hash、findings evidence |
| `audited` | `accept_plan` | `planned` | accepted findings、file boundaries、verification contracts |
| `planned` | `apply_changes` | `implemented` | diff refs、changed files、plan step refs |
| `implemented` | `verify` | `verified` | fresh command output、semantic validation、eval results |
| `draft/audited/planned/implemented` | `block` | `blocked` | failure code、evidence ref、owner |
| `blocked` | `revise` | `draft` | fix summary、changed artifact hash |

## Semantic invariants

| invariant | 失败条件 |
| --- | --- |
| 每个 `FAIL` finding 有 `file_ref` 和 `evidence_refs` | FAIL 结论无可复核证据 |
| 每个 `design_anchors[]` 命中 `design.md` SO-* | 设计追踪断链 |
| 每个 E5 结论有实验或回退合同 | E5 被硬化 |
| 每个 runtime 字段有消费者 | 字段堆积 |
| `status=verified` 时 fresh command 全部通过 | 虚假完成 |
| Markdown/HTML 只由 renderer 写入 | 派生视图污染事实源 |

## Validator stack

| validator | 输入 | 输出 | 阻断对象 |
| --- | --- | --- | --- |
| `validate_schema` | artifact JSON + schema | shape result | 缺字段、错类型、未知枚举 |
| `validate_semantics` | artifact JSON + design/source refs | semantic result | 断链、状态非法、证据不足 |
| `validate_consumers` | field matrix + artifact | consumer result | 无消费者字段 |
| `validate_rendered_views` | artifact + rendered views | provenance result | hash 漂移、renderer 漂移 |
| `validate_eval_results` | dataset + run output | eval result | 触发误判、失败路径缺失 |

## Renderer contract

Renderer 读取 JSON artifact 和模板，输出 Markdown/HTML。每个 rendered view 记录：

| 字段 | 含义 |
| --- | --- |
| `view_path` | 派生视图路径 |
| `source_artifact_id` | 源 artifact id |
| `source_artifact_hash` | 源 artifact hash |
| `renderer` | renderer 名称 |
| `renderer_version` | renderer 版本 |
| `generated_at` | 生成时间 |
| `stale` | source hash 变化后的失效标志 |

## Hook adapter contract

Hook adapter 不直接解析 Markdown。它只读取已通过 validator 的 JSON artifact。

| phase | trigger | input_artifact | allowed_action | output_artifact | failure_state | owner | rollback |
| --- | --- | --- | --- | --- | --- | --- | --- |
| audit | audit finished | `skill-audit.json` | block unsupported FAIL | `skill-audit.json` with blocked status | `blocked` | audit runner | revise finding evidence |
| plan | plan generated | `optimization-plan.json` | block missing verification contract | `optimization-plan.json` with blocked status | `blocked` | plan validator | revise accepted findings and file boundaries |
| verify | verification finished | `verification-result.json` | block false verified state | `verification-result.json` with blocked status | `blocked` | verification aggregator | rerun failed fresh command and rebuild result |

全局 hook registry 接入需要用户单独确认。未接入前，semantic validator、eval 和人工复审承担等价门禁。

## 回退合同

若 runtime artifact 无法证明消费者真实、字段稳定或验证收益，则回退为：

1. JSON artifact 保留为实验输出，不作为 gate 输入。
2. Markdown 审计报告加 evidence refs 承担人类复审。
3. schema HARD-GATE 降级为审计建议。
4. hook adapter 不接入 registry。
5. 回退结果记录在 `review-resolution.md` 或后续 `verification-result.json`。
