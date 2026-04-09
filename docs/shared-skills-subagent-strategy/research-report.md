# shared skills sub agent 显式化调研报告

## 一页判断
- 当前结论：条件推荐
- 是否符合当前目标：高
- 一句话判断：应该把 `shared/skills` 里的 sub agent 从“局部隐式技巧”升级为“命中模式时显式触发的协作契约”，但不应把“所有可能位置”一律改成默认 sub agent。
- 最大收益：降低大体量只读扫描、稳定工件多视角评审、可隔离子任务的上下文噪音；同时修复“文档要求会派 agent，但 frontmatter/tool contract 没开 `Agent`”的漂移。
- 最大风险：把上下文噪音转移成调度噪音、汇总噪音和预算噪音；把用户共创主链切碎；让验收链失去单一证据口径。
- 不适用场景：连续用户共创、强顺序依赖、单 owner 副作用步骤、最终签收/提交、叶子执行型 skill。
- 结论翻转条件：如果后续实证表明当前主要瓶颈不是“主 agent 上下文污染”，而是“agent 调度与汇总成本”，则应进一步收缩显式 sub agent 的覆盖范围。

## 关键论点挑战表
| 论点 | 最强支持证据 | 最强反方挑战 | 当前判断 | 结论稳健性 |
|---|---|---|---|---|
| 应把 sub agent 规则显式写出来 | `research`、`review`、`product`、`design`、`test-design` 已证明“显式分工 + 主 agent 汇总”有效 | 若没有触发条件、输出契约和熔断，显式化只会增加编排噪音 | 成立 | 高 |
| “有可能加”就应默认加 | `agent-team-patterns` 提供了 4 种高价值模式 | 同一 reference 明确要求“不确定时，从最简单的模式开始”，说明 agent 不是默认解 | 不成立 | 高 |
| 主要问题是新增不足 | `project-manager`、`tech-lead`、`overview` 已经在流程或 reference 中依赖 agent，但主文档/工具契约没完全显式 | 这类问题更多是“显式化和契约对齐不足”，不是“完全没设计” | 成立 | 高 |
| 共创主链也应更多下放 sub agent | `product/design` 的前置扫描、`test-design` 的专项展开，确实存在条件式隔离空间 | `product` S2-S10、`design` S3-S8 都依赖连续对话与用户反馈，拆开会破坏收口 | 条件成立 | 高 |
| QA/Verify/Analyze 也应默认内部多 agent 化 | 某些阶段天然可分层，例如 `qa` 的 B/C/D、`verify` 的 2A/2B/2C | 这些 leaf skill 的价值在于直接接触证据；更合适的 fan-out 位置通常是外部 orchestrator，而不是 skill 内部递归派发 | 条件成立 | 中高 |

## 独立挑战记录
| 领域 | challenger 结论 | 对主结论的影响 |
|---|---|---|
| 产品/流程设计 | 反对“能加就加”。认为正确命题应是“命中模式时显式触发，否则默认单 agent”，并强调共创主链不能被切碎。 | 采纳。最终结论从“全面增加”收缩为“条件式显式化”。 |
| 工程可靠性/验收 | 反对把上下文压力简单转移为调度压力，强调 agent 调用预算、统一证据链、稳定 issue id 和失败 scope 重跑规则。 | 采纳。最终建议里加入预算、输出 schema、熔断和禁止场景。 |

## 核心证据
- `shared/reference/agent-team-patterns.md` 已定义四种模式，并明确“不确定时，从最简单的模式开始”：[agent-team-patterns](/Users/lijieli/org-claude-skills/shared/reference/agent-team-patterns.md#L6)
- 已有成熟显式模式：
  - `product` 在跨职能评审使用 3 reviewer：[product](/Users/lijieli/org-claude-skills/shared/skills/product/SKILL.md#L200)
  - `design` 在跨职能评审使用 3 reviewer：[design](/Users/lijieli/org-claude-skills/shared/skills/design/SKILL.md#L189)
  - `test-design` 在跨职能评审使用 3 reviewer：[test-design](/Users/lijieli/org-claude-skills/shared/skills/test-design/SKILL.md#L74)
  - `review` 在 `A/B/C` 三组 reviewer 并行后统一裁决：[review](/Users/lijieli/org-claude-skills/shared/skills/review/SKILL.md#L51)
  - `research` 明确要求并行深挖和 challenger 反驳：[research](/Users/lijieli/org-claude-skills/shared/skills/research/SKILL.md#L54)
- 已有显式需求但存在契约漂移：
  - `project-manager` frontmatter 未开放 `Agent`，但 Phase 2/3 明确依赖 developer/verifier/review/qa/fix 流程：[project-manager](/Users/lijieli/org-claude-skills/shared/skills/project-manager/SKILL.md#L7) [project-manager-flow](/Users/lijieli/org-claude-skills/shared/skills/project-manager/SKILL.md#L134)
  - `tech-lead` frontmatter 未开放 `Agent`，但 S8 明确要求派发审查子代理：[tech-lead](/Users/lijieli/org-claude-skills/shared/skills/tech-lead/SKILL.md#L7) [tech-lead-step8](/Users/lijieli/org-claude-skills/shared/skills/tech-lead/SKILL.md#L99)
  - `overview` frontmatter 未开放 `Agent`，但并行模式引用了 8 Agent 分工表：[overview](/Users/lijieli/org-claude-skills/shared/skills/overview/SKILL.md#L8) [overview-parallel](/Users/lijieli/org-claude-skills/shared/skills/overview/SKILL.md#L55)
- 风险证据：
  - `project-manager` 已把全局 agent 调用纳入预算熔断：[project-manager-budget](/Users/lijieli/org-claude-skills/shared/skills/project-manager/SKILL.md#L58)
  - `qa` 强调真实服务、统一 `qa-report.md` 和完整汇总，不适合在 skill 内无限拆分：[qa](/Users/lijieli/org-claude-skills/shared/skills/qa/SKILL.md#L15)
  - `verify` 强调独立读代码核验，不应被多层转派稀释：[verify](/Users/lijieli/org-claude-skills/shared/skills/verify/SKILL.md#L14)
  - `security` 默认顺序执行，仅在用户明确要求时启用并行：[security](/Users/lijieli/org-claude-skills/shared/skills/security/SKILL.md#L40)

## 技能分组与建议

### P0：先修“显式化已有规则”与契约漂移
| skill | 建议 | 说明 |
|---|---|---|
| `project-manager` | 主文档显式写出 agent roster、触发条件、重试边界，并把 frontmatter 补齐 `Agent` | 这里不是“要不要用”，而是“已经在用但不够显式” |
| `tech-lead` | 为 S8 审查补强 reviewer schema，并把 frontmatter 补齐 `Agent` | 当前只有“派发审查子代理”，没有稳定 issue/verdict 契约 |
| `overview` | 保留“默认串行”，但把“用户明确要求时的 8 Agent 模式”真正做成可执行 contract | 这是低风险的显式化，不是默认并行化 |
| `new-skills` | 元 skill 增加强制要求：凡设计多 agent skill，必须写触发条件、最大 agent 数、停止条件、汇总协议 | 不先在元 skill 固化，后续 skill 还会继续漂移 |

### P1：条件式新增显式 sub agent 规则
| skill | 建议 | 说明 |
|---|---|---|
| `product` | 仅对 S1 静默信息收集增加条件式 sub agent；S2-S10 保持单线共创 | 适合“高上下文只读扫描”，不适合拆散业务收口 |
| `design` | 对 S2 现状扫描和高代价 S5 方案探索增加条件式 sub agent；S3-S8 保持单线共创 | 可用“竞争假设”模式，但不能滑向方案投票 |
| `test-design` | 对 S6 专项测试展开增加条件式 sub agent | 专项天然可隔离，但 UNIT 主线仍应顺序推进 |
| `research` | 保持现有模式，作为“显式 sub agent 标杆” | 已具备候选并行、深挖、challenger 反驳和报告输出 |
| `review` | 保持现有模式，补强 merge protocol 的显式表述 | 已有 reviewer 分组、Verification、统一裁决 |
| `scan` | 保持现有 6 Agent 扫描，补充主 agent 汇总职责与失败处理的可见性 | 已是多 agent 场景，重点是避免汇总层被拆散 |
| `security` | 保持默认顺序，仅为“用户明确要求并行”补充角色分工和汇总协议 | 不建议改成默认显式多 agent |
| `refactor` | 只在“大型重构诊断阶段”显式引入并行分析 | 当前只是提了一句“并行分析”，不够可执行 |
| `fix` | 只在升级分析层级时引入假设 challenger 或影响范围分析 agent | 修复主线必须保持最小修复和因果链完整 |

### P2：默认保持单 agent，或把 fan-out 留给外部 orchestrator
| skill | 建议 | 说明 |
|---|---|---|
| `analyze` | 默认单 agent；仅在工件超大时允许按 phase/layer 分段预检测，最终分级仍由主 agent 裁决 | 本质是单主体一致性判断 |
| `qa` | skill 内保持单 agent；若要并行，放在 `project-manager` 外层按 `QA_A/B/C/D` scope 调度 | 重点是统一证据链，不是内部再递归派发 |
| `verify` | skill 内保持单 agent；若要并行，放在 `project-manager` 外层按 `Phase1/2A/2B/2C` scope 调度 | 重点是直接接触代码证据 |
| `developer` | 不建议再套 sub agent | TDD 连续性和文件边界会被破坏 |
| `worktree` | 不建议 | 属于副作用型 git 操作，天然不适合多 owner 并发 |
| `commit` | 不建议 | 并发提交/推送风险远大于上下文收益 |
| `prompt` | 默认不建议；仅在用户明确要求多方案对比时人工触发 | 主线是单次综合生成和自检 |
| `project-memory` | 不建议 | 强用户共创，拆开会导致入口文档口径漂移 |
| `rules-manager` | 不建议 | 规则边界需要单一裁决和逐条确认 |
| `ux` | 默认不建议；仅在超大 PRD 且要拆“认知走查/启发式评审”时条件触发 | 体验权衡需要统一视角 |
| `h5` | 不建议 | 页面实现和交互连贯性不适合默认拆散 |

## 最终建议
1. 不采用“所有可能位置都显式使用 sub agent”。
2. 采用“命中模式时显式触发，否则默认单 agent”。
3. 每个显式 sub agent 入口必须同时写清：
   - 触发条件
   - 最大 agent 数
   - 主 agent 汇总职责
   - 输出 schema：稳定 issue id / 明确 verdict / file:line 证据
   - 失败重试规则
   - 熔断条件
   - 禁止场景
4. 优先顺序：
   - 先修 `project-manager / tech-lead / overview / new-skills`
   - 再补 `product / design / test-design / security / refactor / fix`
   - 最后才讨论 `analyze / qa / verify / ux` 这类是否需要条件式扩展

## 采纳速览
- 现在该做什么：改写后采纳
- 最匹配的点：仓库已经在多个高价值节点证明了 sub agent 有用，但缺少统一显式规则和契约对齐
- 最不匹配的点：原命题过宽，会把“减少上下文噪音”误写成“默认多 agent 化”

## 落地动作
- P0：统一补一套 sub agent 写法模板，沉到 `new-skills`
- P0：修 `project-manager / tech-lead / overview` 的 `allowed-tools` 与主文档显式性
- P1：为 `product / design / test-design / security / refactor / fix` 增加“条件式 sub agent”章节
- P1：在主文档而非 reference 中写出最大 agent 数、返回格式、失败重试和熔断
- P2：做一次小规模试点，验证“显式化后是否真的减少主 agent 上下文和返工”

## 检索路径与覆盖证明
- 扫描对象：`shared/skills` 下全部 24 个 `SKILL.md`，以及与 sub agent 直接相关的 `shared/reference/agent-team-patterns.md`、`overview/references/agent-assignments.md`、`project-manager/references/dispatch-guide.md`、`project-manager/references/phase3-dispatch.md`、`tech-lead/references/plan-reviewer-prompt.md`、`product/design/test-design` reviewer prompts。
- 并行分析：本轮拉起了多组 agent，分别覆盖流程型 skill、分析/审查型 skill、元技能/支持技能，以及 2 个不同领域 challenger。
- 已覆盖模式：竞争假设、分层评审、模块化开发、规划-审批。
- 已排除的过宽结论：
  - “所有可能位置都应该默认 sub agent”
  - “叶子 skill 内部也应无限递归分派”
  - “只要能并行就优先并行”
- 剩余盲区：当前结论基于仓库结构和 contract 设计，没有引入历史执行 telemetry；后续应补一次真实任务试点来验证收益。

## 项目上下文
- 本仓库以 `shared/skills + shared/reference + shared/rules + hooks + tests` 组织 Claude/Codex 共享运行时知识。
- 当前工作树本身已有未提交改动；本次调研保持只读分析，并仅新增本报告文件，不覆盖现有修改。

