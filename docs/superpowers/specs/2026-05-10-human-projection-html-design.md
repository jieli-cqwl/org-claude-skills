# Human Projection HTML 设计稿

日期：2026-05-10

## 目标

standard-chain 的运行时真源是 canonical JSON。AI 消费 JSON，工具校验 JSON，交付链路也应该以 JSON 为准。

但人类需要一个更快、更清楚、更适合审阅的界面。人不应该被迫阅读几百行 Markdown，也不应该把 raw JSON 当成主要阅读材料。

本设计定义一层确定性的 HTML 投影：

```text
canonical JSON → role view-model → static HTML → projection manifest
```

HTML 只负责展示。它不是编辑器，不是审批系统，不是 dashboard，也不是第二真源。任何纠正、修改、裁决都回到 Claude Code 或 Codex 对话，再由对应 skill 写回 canonical JSON。

## 当前基线

仓库里已经有一条最小 HTML projection 链路：

- `shared/runtime/projection-views.json`：声明当前 `phase-operational` view。
- `tools/community/materialize_canonical_html.py`：从 canonical artifact 渲染确定性 HTML。
- `tools/community/validate_projection_manifest.py`：校验 source refs、section source map 和 HTML digest。
- `shared/skills/delivery-owner/contracts/projection-manifest.schema.json`：定义 projection manifest 契约。

当前实现可信，但不好读。它主要把 JSON value 放进 HTML section 里，适合证明 provenance，不适合人类审阅。

目标状态不是丢掉这条可信链路，而是保留 deterministic provenance，同时把展示层升级成角色化、图形化、可追踪的审阅界面。

## 产品决策

每个 Phase 生成一个人类审阅入口：

```text
docs/{feature}/phase-{N}/views/phase-human-review.html
```

对应 projection 身份固定为：

```text
view_id: phase-human-review
manifest: docs/{feature}/phase-{N}/views/phase-human-review.projection-manifest.json
```

现有 `phase-operational` 是兼容期的最小运行投影。目标态是 `phase-human-review` 承担人类审阅职责；实现迁移期可以并存，但 readiness/replay 最终不能只认旧 manifest。

页面结构固定为：顶部显示 Phase、产物状态和生成信息；左侧是角色导航；右侧是当前角色详情。

左侧不是普通菜单，而是标准交付链路地图：

```text
产品 → 架构 → 测试 → 计划 → 交付
```

每个角色都有自己的审阅问题：

| 角色 | 人类真正要判断的问题 |
| --- | --- |
| 产品 | 业务流程、范围、UNIT、AC 是否清楚到足以判断？ |
| 架构 | 方案是否可实现、可追踪、可回滚？ |
| 测试 | 业务路径、边界路径、失败路径是否有测试义务覆盖？ |
| 计划 | 任务是否可执行、顺序是否合理、并行是否安全、证据是否明确？ |
| 交付 | 证据链是否闭环，哪些事实还需要用户判断？ |

## 非目标

明确不做：HTML 内编辑 JSON，HTML 内审批/签收/纠正，agent 自由编写无来源事实，旧 Markdown 模版直转 HTML，把 raw JSON `pre` dump 当主界面，在 HTML parity 和契约迁移证明前删除 active Markdown projections。

## 真源边界

canonical JSON 仍然是 AI 和运行时消费的唯一真源。

HTML 只在 projection 元数据层面可信：

```text
source_artifact_refs
section_source_map
rendered_content_digest
renderer_version
generated_at
view_id
```

renderer 可以从 JSON 派生展示用 view-model，但不能新增业务事实。

如果字段结构不足以生成图，页面必须降级展示，而不是脑补一张“看起来合理”的图。

## Projection Worker 契约

生成 HTML 的 worker 是确定性 projection worker，不是创作型 sub agent。

它可以读取 active canonical JSON artifacts、projection view registry，生成角色 view-model、静态 HTML、projection manifest，并报告缺失字段和降级 section。

它不能修改 canonical JSON、推断无来源业务事实、重写用户结论、把 Markdown projection 当展示真源，或隐藏 schema、source、digest、artifact coverage 错误。

是否由 sub agent 执行不是核心。核心是：它必须只做确定性投影，不能变成第二个会“解释业务”的 agent。

## 页面统一节奏

每个角色页都按同一种信息节奏组织：

1. 关键事实：首屏只展示 3 到 5 个最需要看的判断事实。
2. 图形结构：流程图、依赖图、覆盖图、计划图或证据链。
3. 矩阵：追踪矩阵、覆盖矩阵、任务合同表或 source mapping。
4. 缺口与风险：缺字段、降级区块、阻塞、未闭环风险。
5. 来源追踪：artifact ref 和 JSON pointer。

这样每个页面的阅读方式一致，但每个角色看到的专业内容不同。

## 共享组件语义

页面应该使用一组稳定的展示组件语义。它们不一定是前端框架组件，也可以是静态 HTML 模版和 CSS class。

| 组件 | 作用 |
| --- | --- |
| `RoleShell` | 角色页容器和页内锚点。 |
| `ArtifactStatusStrip` | 展示 artifact 是否存在、schema 是否通过、digest 是否一致、角色是否完整。 |
| `CriticalFacts` | 首屏关键事实。 |
| `DiagramPanel` | 流程图、依赖图、覆盖图、关键路径图、证据链图。 |
| `TraceMatrix` | source 到 consumer 的追踪表。 |
| `CoverageHeatmap` | AC、测试、风险覆盖密度。 |
| `RiskLedger` | 风险、阻塞、缓解方式、影响 artifact。 |
| `EvidenceChain` | 从 task 到 signoff 的证据链。 |
| `SourceBadge` | 内联来源标记，显示 source ref 和 JSON pointer。 |
| `MissingDataCard` | 明确展示缺失 artifact 或缺失字段。 |
| `DegradedViewNotice` | 说明为什么从图形降级成卡片或事实列表。 |

## 图形生成等级

所有图形必须有结构化等级：

| 等级 | 条件 | 展示方式 |
| --- | --- | --- |
| High | 必需结构化字段完整。 | 完整图：节点、边、标签、source badge。 |
| Medium | 部分结构化字段存在。 | 卡片链路图，并显示缺失字段。 |
| Low | 只有自然语言或字段不足。 | 来源事实卡，不生成推断关系。 |

每个图形 section 都要记录：

```text
render_mode: diagram | cards | degraded
structure_level: high | medium | low
source_refs
json_pointers
missing_fields
```

红线：没有结构化来源，就不能生成“看起来很对”的关系图。

## 产品页

产品页是业务审阅台。它合并 product-director 的基线和 product-manager 的细化，但不能退化成 PRD 摘要。

首屏关键事实：

- 业务流程是否清楚。
- 范围边界是否清楚。
- UNIT 是否闭合。
- AC 是否覆盖正向、边界、失败路径。
- 下游消费是否完整。

主要区块：

| 区块 | 可视化 | canonical source |
| --- | --- | --- |
| 业务问题总览 | 事实卡 | `brief.json`、`phase-prd.json` |
| 业务流程 | 泳道图或来源流程卡 | `business_flows`、`user_paths`、`rule_mappings`、`units` |
| 范围边界 | in-scope / out-of-scope / constraints 边界图 | `phase-prd.json`、`units` |
| Phase 与 UNIT 地图 | Phase 到 UNIT 的关系图 | `phase-prd.json`、`units/UNIT-*.json` |
| AC 覆盖 | AC trace matrix | `units[].acceptance_criteria` |
| 下游映射 | 产品到架构、测试、计划、交付的 trace | `brief.json`、`phase-prd.json`、`units/UNIT-*.json`、`review_conclusion`、`issue_ledger`、`delivery_confirmation` |

业务流程是产品页的锚点。结构化字段不足时，页面必须明确显示“流程结构化不足”，并展示已有来源事实，不能强行生成完整流程图。

## 架构页

架构页回答：这个方案是否可实现、可追踪、可回滚。

首屏关键事实：

- 最高风险设计点。
- 不可逆或高成本决策。
- 外部依赖。
- 回滚是否清楚。
- 产品追踪是否覆盖。

主要区块：

| 区块 | 可视化 | canonical source |
| --- | --- | --- |
| 系统上下文 | actor / system / context diagram | `design.json` |
| 组件依赖 | module dependency graph | `design.json` |
| 决策影响 | decision 到 UNIT / risk 的影响图 | `design.json`、`units` |
| 数据与接口契约 | contract matrix | `design.json` |
| 风险与回滚 | risk ledger | `design.json` |
| 产品追踪 | design 到 product 的 trace matrix | `design.json`、`phase-prd.json`、`units` |

架构页不能只是 design.json 摘要。人类需要看到结构、依赖方向、决策影响和回滚路径。

## 测试页

测试页回答：业务路径、边界路径和失败路径是否有足够测试义务。

首屏关键事实：

- 未覆盖 AC。
- 缺失失败路径。
- 缺失边界场景。
- 高风险低覆盖区域。
- 环境或 fixture 缺口。

主要区块：

| 区块 | 可视化 | canonical source |
| --- | --- | --- |
| 覆盖热力图 | UNIT × test obligation matrix | `test-cases.json`、`units` |
| 场景树 | normal / boundary / failure / recovery paths | `test-cases.json`、`units` |
| 用例矩阵 | case 到 AC 的 trace | `test-cases.json` |
| 风险路径覆盖 | risk 到 case 的 map | `test-cases.json`、`design.json` |
| 数据与 fixture | fixture matrix | `test-cases.json` |
| 产品与架构追踪 | upstream trace matrix | `phase-prd.json`、`units`、`design.json` |

测试页不优化“测试数量”，而是优化“证明清晰度”：什么被覆盖，什么没被覆盖，缺口带来什么风险。

## 计划页

计划页回答：这些任务是否能被 agent 清楚执行，顺序是否合理，并行是否安全。

首屏关键事实：

- 关键路径。
- 阻塞任务。
- 并行批次。
- 缺失 task contract。
- 缺失 evidence path。

主要区块：

| 区块 | 可视化 | canonical source |
| --- | --- | --- |
| 关键路径 | dependency path graph | `plan.json`、`tasks.json` |
| Task 依赖 DAG | task graph | `tasks.json` |
| 并行批次 | batch lane diagram | `plan.json`、`tasks.json` |
| Task 合同 | task contract cards | `tasks.json` |
| 证据路径 | task 到 evidence 的 matrix | `tasks.json`、plan evidence fields |
| 前置条件与阻塞 | blocker ledger | `plan.json`、`tasks.json` |

计划页不是项目管理看板。它的目标是验证 AI task contract 是否足够清楚、可执行、可验收。

## 交付页

交付页回答：证据是否完整，问题是否闭环，哪些事实还需要用户判断。

首屏关键事实：

- 当前交付状态。
- 未闭环问题。
- 证据缺口。
- 失败重试链。
- 用户裁决事实。

主要区块：

| 区块 | 可视化 | canonical source |
| --- | --- | --- |
| 执行时间线 | delivery stage timeline | `delivery-state.json` |
| 证据链 | task 到 report 到 signoff 的 graph | `developer-report.json`、`code-review-result.json`、`verify-result.json`、`qa-result.json`、`fix-result.json`、`signoff-package.json` |
| 报告聚合 | role report matrix | `developer-report.json`、`code-review-result.json`、`verify-result.json`、`qa-result.json`、`consistency-audit-result.json`、`fix-result.json` |
| 阻塞与风险 | blocker ledger | `delivery-state.json`、`qa-result.json`、`code-review-result.json`、`consistency-audit-result.json`、`fix-result.json` |
| Signoff 包 | signoff fact cards | `signoff-package.json` |
| 用户裁决 | decision fact panel | `user-decision.json` |

交付页必须证据优先。没有 evidence 的 progress label 一律显示为 incomplete。

## Manifest 扩展

现有 manifest 已经能证明 HTML 从哪些 artifact 来，以及 HTML digest 是否一致。

目标状态需要进一步证明每个 section 是如何渲染的：

```json
{
  "source_artifact_refs": [],
  "json_pointers": [],
  "render_mode": "diagram",
  "structure_level": "high",
  "missing_fields": [],
  "consumer_role": "product"
}
```

top-level manifest 继续保留：

```text
view_id
source_artifact_refs
section_source_map
projection_view_registry_digest
renderer_version
rendered_artifact_ref
rendered_content_digest
```

`projection_view_registry_digest` 指向 `shared/runtime/projection-views.json` 或后续等价 view registry 的内容摘要。它不同于现有 `chain_registry_digest`：前者证明展示规则没漂移，后者证明 standard-chain artifact catalog 没漂移。

## Markdown Projection 退出原则

主链路 Markdown projections 应该退出，但必须在 HTML parity 被证明之后。

退出契约是：

```text
role HTML 已覆盖人类阅读职责
manifest validation 已覆盖 source / render mode / missing fields / registry digest
fixtures 已证明 canonical JSON 能生成角色页面
skill instructions 已改为 HTML display projection
tests 已不再把主链 Markdown projection 当 active contract
```

只有满足上述条件，才能删除被完整替代的 active standard-chain Markdown projection。

删除范围按职责判断，不按目录名判断。不能因为文件在 `projections/` 目录下就删除。非 standard-chain 的 projection template 不在本设计范围内。

## UX 边界

正常路径：打开 `phase-human-review.html`，在左侧选择角色，先看首屏关键事实，进入图形或矩阵区块，通过 source badge 追踪不清楚的事实，再回到 Claude Code / Codex 对话纠正 canonical JSON。

失败路径：打开页面后看到 missing artifact、missing field、schema error、digest drift 或 degraded diagram，确认受影响的角色和 section，通过 source ref 定位要修正的 canonical artifact，再回到对应 skill 对话处理。

页面不能静默失败。empty、error、boundary、degraded 都必须是明确可见状态。

## 视觉方向

视觉方向是：

```text
Operational Editorial
```

中文理解为：作战审阅台。

它应该像一个清楚、冷静、证据优先的协作界面，而不是营销页，也不是指标 dashboard。它使用强信息层级、清晰分组、克制角色色、图/矩阵/台账优先、紧凑重复卡片、source badge 和 missing-data notice。

它避免营销式 hero、装饰性渐变、大卡片堆叠、dashboard vanity metrics、只靠颜色表达状态、卡片套卡片和无意义视觉噪音。

## 验收标准

实现后的系统必须能证明这些结果：

| 标准 | 证据 |
| --- | --- |
| 用户 5 秒内知道哪个角色有缺口。 | 左侧角色状态 + 首屏关键事实。 |
| 用户 30 秒内看懂当前 Phase 的业务与交付链路。 | 产品流程、角色链路、交付证据链。 |
| 用户能追踪任一 UNIT 从产品意图到交付证据。 | 跨角色 trace matrix 和 source mapping。 |
| 图形不会编造无来源事实。 | render level metadata 和 degraded-state validation。 |
| 缺失字段明确可见。 | `MissingDataCard` 和 manifest `missing_fields`。 |
| HTML 不会变成第二真源。 | digest validation、section source map、canonical-only renderer inputs。 |
| Markdown projection 删除是安全的。 | 测试证明 HTML replacement 后再删除 active Markdown projection。 |

## 主要风险

最大风险是 canonical JSON 结构化不足。正确做法不是让 HTML 自行推断更丰富的图，而是诚实降级，并暴露缺失字段。这可能反过来说明上游 schema 需要增加更结构化的 workflow、dependency 或 evidence 字段。

第二个风险是 UI 过度建设。审阅面应该保持 static、deterministic、source-mapped。交互只允许导航、展开、过滤和来源查看。

第三个风险是把人类展示误解为人类决策采集。用户决策仍然应该由相关 skill 产出 canonical artifact，而不是存在 HTML mutable state 里。
