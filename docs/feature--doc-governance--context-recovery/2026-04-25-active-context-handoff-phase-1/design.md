# 活跃需求上下文接手协议 Phase 1 设计

Created: 2026-04-25

## Design Authority

本设计是 Phase 1 的当前设计基线。后续 plan、validator、hook 和测试以本文为输入。

既有 README、`contracts/active-doc-scope.yaml`、`contracts/small-chain.yaml` 中已经存在 `worklog.md`、active scope 和 small-chain 接手入口口径。本文在当前仓库状态上重新收口这些口径，并补齐 ownership、hook 把关、失败合同和 small-chain / standard-chain 接手恢复流程。

若本文与早期 context contract 设计或 README 示例存在冲突，Phase 1 以后以本文为准。早期材料作为 prior input，不作为当前实施真源。

接手者先读 `Goals & Success Criteria`、`Architecture`、`Failure Contract`。实现者再读 `Artifact Responsibility Model`、`Hook Enforcement Matrix` 和 `Phase 1 Scope`。不要从早期 context contract 推断当前口径。

## Why

AI 编码协作中的需求经常跨天、换窗口、换 AI、人工介入后再交回 AI，也会出现多个 feature 并行推进。需求上下文会分散在 PRD、设计、计划、任务、执行报告、验证结果和补充材料里。只要入口、有效范围、当前状态和下一步不清晰，接手者就会重新猜：该读哪个文件、哪个文件可信、当前做到哪里、下一步从哪里继续。

文档命名和目录结构不是表面整洁问题。它们服务于人类视觉查找和 AI 上下文边界：让人快速识别入口、类型、所属需求和可信程度，同时限制 AI 随意创建、随意命名和误读旧材料。

本设计要建立一套轻量的活跃需求上下文接手协议，让人和 AI 不依赖聊天记忆，也能从仓库文件恢复现场。

## Problem Statement

Phase 1 只解决活跃需求接手和上下文恢复。它必须稳定回答四个问题：

1. 我现在接手的是哪一个活跃需求？
2. 当前有效上下文在哪里？
3. 当前进展以哪个真实工件为准？
4. 下一步从哪里继续？

当前仓库已经存在 `small-chain` 和 `standard-chain` 两套真实工作流。设计不能新建一套替代流程，也不能把入口文件变成第二套 PRD、任务表或验收报告。统一的是接手协议，不统一真实工件模型。

## Goals & Success Criteria

| Goal | Success Criteria |
|------|------------------|
| G1. 活跃需求可发现 | 新窗口只拿到仓库路径时，读取 scope registry 即可列出被纳管需求；未入 registry 的 `docs/*` 不作为默认接手候选。 |
| G2. 单需求可接手 | 每个被纳管 feature 有且只有一个 `worklog.md` 作为接手入口，接手者能从最新记录找到 `state_ref` 和 `next_ref`。 |
| G3. 进展真源不混乱 | `worklog.md` 只导航到真实工件；small-chain 的进展回 `tasks.md / plan.md / design.md`，standard-chain 的进展回 canonical JSON。 |
| G4. 维护责任可追溯 | 每类关键工件都有 `artifact_owner`、更新触发条件和校验方式；feature 级接手链路有 `context_owner`。 |
| G5. 机械漂移可阻断 | validator、runtime hook、pre-commit 或 `validate-contracts` 能阻断字段缺失、引用不可达、非法入口、归档后仍活跃等确定性漂移。 |
| G6. 失败可解释 | 无法恢复现场时明确报告失败原因，不扫描历史 `docs/` 猜测，不把旧材料自动纳入上下文。 |

最高验收是新窗口接手测试：给新 AI 或新人一个仓库路径，不提供聊天记录，它必须能列出被纳管需求，选择或接收指定 feature，打开 `worklog.md`，从 `state_ref / next_ref` 跳到真实工件，并输出当前事实依据、下一步入口和阻塞信息。

## Non-Goals

- 不治理全量历史 `docs/`。
- 不新增 `docs/ACTIVE.md` 或 dashboard。
- 不让 scope registry 记录进度状态、blocked 状态或下一步动作。
- 不把 `worklog.md` 做成日报、变更日志或全量历史。
- 不替换 standard-chain canonical JSON。
- 不承诺 hook 能进行深层业务语义审查。
- 不承诺 runtime hook 能认证真实写入者身份。
- 不靠 LLM 自觉维护入口、命名、引用和 owner 边界。

## Existing Context

仓库已有以下基础：

- `README.md` 已描述 `worklog.md` 是受管通用入口，仅对 `contracts/active-doc-scope.yaml` 纳管的 feature 生效。
- `contracts/active-doc-scope.yaml` 已存在，但当前仍偏 rollout registry 草案，字段 `status` 容易被误读为需求进度状态。
- `contracts/small-chain.yaml` 已把 `docs/*/worklog.md`、dated workset、`design.md / tasks.md / plan.md` 纳入 small-chain 输入输出。
- `contracts/standard-chain.yaml` 与 canonical templates 已建立 standard-chain 的 JSON 真源体系。

当前缺口不是“没有入口概念”，而是：

- registry、worklog、真实工件之间职责边界仍需收窄。
- 每类文档谁更新、何时更新、如何校验仍未形成统一 ownership contract。
- hook、validator、`validate-contracts`、audit 尚未形成单一机械把关链路。
- 旧文档示例和当前仓库状态存在漂移风险，AI 会从旧路径推断当前口径。

## Change Scope

Phase 1 的修改范围是上下文接手协议和工程把关边界，不是需求交付系统重建。

必须覆盖：

- scope registry 的字段语义、生命周期写入路径和候选解析规则。
- `worklog.md` 的块格式、最小字段、更新触发和引用规则。
- Artifact Ownership Contract 的默认 owner、更新触发和校验方式。
- small-chain 与 standard-chain 接手恢复流程。
- validator、runtime hook、pre-commit、`validate-contracts`、audit 的职责分层。
- README、contracts、skills、tests 中与接手协议直接冲突的口径。

不覆盖：

- 历史 `docs/` 全量迁移。
- standard-chain canonical producer 重写。
- UI、dashboard、自动排期或进度看板。
- 基于聊天历史、LLM 自述或手写总结的恢复机制。

## Invariants

以下约束在实现和后续演进中不可破坏：

- scope registry 只表达纳管边界，不表达需求进度。
- `worklog.md` 只表达接手路径，不复制真实工件内容。
- 真实进展回到 small-chain 或 standard-chain 的原生工件。
- 未入 scope registry 的 `docs/*` 不作为默认接手候选。
- hook/validator 只裁决可机械证明的合同边界。
- 阻断式 validator 故障时 fail-closed。
- audit 只报告长期风险，不修改 registry，不更新 worklog，不判断进度完成。
- 统一接手协议，不统一 small-chain 与 standard-chain 的真实工件模型。

## Downstream Impact

本设计影响以下下游消费者：

| Consumer | Impact |
|----------|--------|
| `small-chain` skills | 需要把 `scope registry -> worklog -> dated workset` 作为接手入口，不再只靠用户口述或目录扫描。 |
| `standard-chain` skills | 需要支持 `scope registry -> worklog -> canonical JSON` 的恢复方式，但不改写 canonical JSON 真源。 |
| hook registry | 需要把 context contract validator 作为 runtime/pre-commit/`validate-contracts` 的单一规则入口。 |
| tests | 需要覆盖 registry 解析、worklog 引用、small-chain task/plan 一致性、standard-chain active refs、失败恢复场景。 |
| README and contracts | 需要统一术语：scope registry、management_status、handoff_status、context_owner、artifact_owner。 |
| AI and human handoff | 接手输出从散文式总结收敛为 feature、mode/layout、state_ref、next_ref、risk/blocker。 |

## Architecture

Phase 1 采用四层接手链路：

```text
scope registry
  -> docs/{feature}/worklog.md
  -> small-chain 或 standard-chain 真实工件
  -> validator / hook / validate-contracts / audit
```

| Layer | Artifact | Owns | Does Not Own |
|-------|----------|------|--------------|
| 仓库级登记 | `contracts/active-doc-scope.yaml` | 哪些 feature 被纳管、mode、layout、entry、context owner 绑定 | 进度、blocked、下一步、task 状态 |
| 单需求入口 | `docs/{feature}/worklog.md` | 当前从哪里接手、当前事实引用、下一步引用、阻塞信息 | PRD、设计、任务、验收结论全文 |
| 真实工件 | `tasks.md`、`delivery-state.json` 等 | 需求、设计、计划、进展、验证、签收事实 | 仓库级活跃需求发现 |
| 工程兜底 | validator、hook、CI、audit | 机械边界、引用、命名、字段、长期漂移风险 | 深层业务语义裁决 |

核心边界：

> scope registry 决定是否纳管，worklog 决定从哪里接手，真实工件决定进展事实，hook 只校验可机械判定的漂移。

## Scope Registry Contract

`contracts/active-doc-scope.yaml` 对外统一称为 scope registry，避免和 standard-chain 的 `artifact-registry.json` 混淆。

Phase 1 建议字段：

```yaml
scope_entries:
  - feature_path: docs/feature--context--handoff
    mode: small-chain
    management_status: managed
    layout: dated-workset
    entry_ref: worklog.md
    context_owner: feature-runtime-owner
```

字段语义：

| Field | Meaning |
|-------|---------|
| `feature_path` | 被上下文接手协议纳管的 feature 根目录，相对仓库根。 |
| `mode` | `small-chain` 或 `standard-chain`。旧称 `full-chain` 只作为兼容说明，不作为新枚举。 |
| `management_status` | `managed`、`migrated`、`legacy`。它表示纳管状态，不表示需求进度。 |
| `layout` | `dated-workset` 或 `phase-tree`。 |
| `entry_ref` | 相对 `feature_path` 的入口引用，Phase 1 固定为 `worklog.md`。 |
| `context_owner` | 当前 feature 接手链路负责人。 |

活跃候选列表只包含 `management_status in [managed, migrated]` 的条目。`legacy` 仅供审计和历史跟踪，不作为默认接手候选。

registry 只随生命周期事件更新：

- 新需求进入上下文机制。
- 旧需求被纳入机制。
- 需求归档。
- mode 或 layout 变化。
- context owner 绑定变化。

日常 task 推进、blocked、恢复、验证、签收不更新 registry。

## Worklog Contract

`docs/{feature}/worklog.md` 是单个 feature 的唯一接手入口。它最新记录在最上方，只记录接手路径变化，不记录所有历史进展。

每条记录使用固定块格式：

```markdown
## 2026-04-25 10:30

- actor: Codex
- context_owner: feature-runtime-owner
- mode: small-chain
- stage: planning
- scope_ref: tasks.md#T2
- handoff_status: doing
- state_ref: 2026-04-25-active-context-handoff-phase-1/tasks.md#T2
- next: 执行 T2 的 validator contract 设计任务
- next_ref: 2026-04-25-active-context-handoff-phase-1/plan.md#T2
```

字段约束：

| Field | Meaning |
|-------|---------|
| `actor` | 写入本条记录的人或 agent。 |
| `context_owner` | 负责维护接手链路的人或协调 agent。 |
| `mode` | `small-chain` 或 `standard-chain`。 |
| `stage` | 当前流程阶段。 |
| `scope_ref` | 当前接手项范围，如 `feature`、`tasks.md#T2`、`phase-1/unit-1`。 |
| `handoff_status` | `doing`、`blocked`、`done`。它只表示当前 handoff item 状态，不表示整个 feature 生命周期。 |
| `state_ref` | 当前事实以哪个真实工件为准。 |
| `next` | 下一步动作的短说明。 |
| `next_ref` | 下一步先打开哪个真实工件。 |

`blocked` 记录必须包含 `blocker`、`waiting_on`、`unblock_condition`，需要人工或上游裁决时还必须包含 `decision_needed`。

`done` 记录必须保留下一步入口：verify、archive、signoff 或新的 `scope_ref`。没有 `next_ref` 的 `done` 不能作为可接手记录。

更新触发固定为以下字段任一变化：

- `stage`
- `scope_ref`
- `handoff_status`
- `state_ref`
- `next_ref`
- `context_owner`

禁止回写历史语义。历史记录写错时，用新的 correction 记录修正。纯格式修复只能由 validator repair 流程处理。

只有 coordinator 或 `context_owner` 写根 `worklog.md`。并行 worker 和 explorer 只能在自己的报告中提供候选 handoff 内容，不能直接更新根入口。

## Artifact Responsibility Model

Phase 1 新增仓库级 Artifact Ownership Contract，建议落点为 `contracts/context-artifact-ownership.yaml`。该文件定义默认 owner、更新触发和校验方式。feature 级只写 owner 绑定、waiver 和必要例外。

统一字段：

- `context_owner` 管 feature 接手链路。
- `artifact_owner` 管具体工件正确性。
- `authenticated_writer` 只在运行面提供稳定身份时参与校验。

默认责任矩阵：

| Artifact | Artifact Owner | Update Trigger | Mechanical Checks |
|----------|----------------|----------------|-------------------|
| scope registry | context registry owner | bootstrap、adopt、archive、mode/layout/context owner 变化 | schema、路径存在、entry 唯一、active/archive 冲突 |
| `worklog.md` | feature context owner | 接手路径字段变化、blocked/恢复、handoff 切换 | 块格式、字段枚举、引用可达、倒序、append-only |
| `design.md/json` | design owner | 设计冻结、批准后的设计变更 | completeness、关键字段、下游影响说明 |
| `tasks.md/json` | planning owner 定义，execution coordinator 更新完成状态 | 任务冻结、任务验收通过 | AC 覆盖、task ID 唯一、plan 引用一致 |
| `plan.md/json` | planning owner | 执行计划生成、重规划 | task 引用完整、依赖合法、文件范围明确 |
| `developer-report / verify-result` | developer / verifier owner | 执行或验证动作完成 | schema、证据引用、task 状态一致 |
| `code-review / qa-result / signoff / user-decision` | review / QA / signoff owner | 审查、QA、签收、用户裁决完成 | schema、结论枚举、active refs 一致 |
| `research/debug/verification/supporting/*` | material author，feature context owner 兜底 | 产生辅助材料 | 目录合法、文件名日期、purpose/serves/reason_here |

无 `principal_id` 时，runtime hook 和 pre-commit 不基于身份阻断。真实责任确认通过 PR approval、merge approval、`branch-finalization` 或 audit 兜底。

## Recovery Flows

统一恢复协议：

```text
scope registry -> worklog.md -> 真实工件 -> 下一步动作
```

### Common Recovery Flow

| Step | Action | Failure Handling |
|------|--------|------------------|
| 1 | 读取 `contracts/active-doc-scope.yaml` | 文件缺失或不可解析时报告 context contract 未启用。 |
| 2 | 列出 `managed / migrated` 候选 feature | registry 为空时提示无纳管需求，不扫描 `docs/` 猜。 |
| 3 | 用户指定或选择需求 | 多个候选时不自行选择。Phase 1 支持精确 `feature_path` 或 basename；模糊匹配只列候选。 |
| 4 | 读取 `entry_ref` 指向的 `worklog.md` 最新记录 | 缺失时阻断并报告 registry/worklog 漂移。 |
| 5 | 先读 `state_ref`，再读 `next_ref` | ref 不可达时阻断并指出失效引用。 |
| 6 | 根据 `mode/layout` 进入对应链路 | mode/layout 与真实目录冲突时阻断。 |

恢复输出只作为对话摘要，不落盘。需要持久化接手变化时，必须追加 `worklog.md`，且满足更新触发条件。

### Small-Chain Recovery

small-chain 真实现场通常位于 dated workset：

```text
docs/{feature}/
  worklog.md
  YYYY-MM-DD-{change}/
    design.md
    tasks.md
    plan.md
```

接手判断：

| Question | Source |
|----------|--------|
| 需求为什么做、边界是什么 | `design.md` |
| 当前事实入口 | `worklog.state_ref` |
| 完成状态 | `tasks.md` |
| 下一步怎么执行 | `worklog.next_ref`，通常指向 `plan.md` 或 `tasks.md` |

`worklog.state_ref` 是接手事实入口，`tasks.md` 是完成状态真源。两者都读，不能把其中一个替代另一个。

### Standard-Chain Recovery

standard-chain 真实现场保留 canonical JSON：

```text
docs/{feature}/
  worklog.md
  brief.json
  phase-{N}/
    phase-prd.json
    design.json
    plan.json
    tasks.json
    delivery-state.json
    artifact-registry.json
    qa-result.json
    signoff-package.json
```

接手判断：

| Question | Source |
|----------|--------|
| 当前 phase / stage | `worklog.scope_ref` + `delivery-state.json` |
| 当前可消费工件版本 | `artifact-registry.json` |
| 当前任务与计划 | `plan.json / tasks.json` |
| QA、签收、用户裁决 | `qa-result.json / signoff-package.json / user-decision.json` |
| 下一步先看哪里 | `worklog.next_ref` |

多 phase 并存时，当前 phase 必须由 `worklog.scope_ref` 与 `delivery-state.json` 对齐。冲突时阻断，不根据目录猜测。

## Hook Enforcement Matrix

LLM 负责产出候选内容，owner 负责语义正确性，hook/validator 负责机械边界，`validate-contracts` 和 audit 负责防漂移和长期风险。

| Layer | Trigger | Blocks |
|-------|---------|--------|
| runtime hook | AI 回合结束或工具写入后 | 当前改动造成的入口缺失、引用不可达、字段非法、明显越界 |
| pre-commit | commit 前 | 文档结构、命名、scope registry/worklog 一致性、非法散落文件 |
| `validate-contracts` / CI | push、PR、本地验证 | 全仓合同回归、防绕过、本地 hook 缺失 |
| audit | 手动或定期 | 不阻断，只报告长期 blocked、过期 waiver、supporting 滥用、legacy 漂移 |

确定性阻断规则：

| Scenario | Decision |
|----------|----------|
| scope registry 指向不存在的 feature | block |
| `managed / migrated` feature 缺 `worklog.md` | block |
| `entry_ref` 不可达 | block |
| `worklog.md` 缺必填字段或枚举非法 | block |
| `state_ref / next_ref` 不可达 | block |
| 归档 feature 后仍出现在活跃候选列表 | block 或 CI fail |
| 移动/删除被 `worklog` 引用的文件但未修 ref | block |
| small-chain `tasks.md` 和 `plan.md` task 引用不一致 | block |
| standard-chain canonical active refs 不一致 | block |
| `supporting/` 文档缺 purpose/serves/reason_here | block |
| validator 在阻断式场景故障 | fail-closed |

非阻断 audit 规则：

- 长期 blocked。
- 长期 stale。
- 过期 waiver。
- `supporting/` 同类文档过多。
- legacy 目录漂移。

hook 不判断 `next` 是否最优，不判断设计是否合理，不判断任务拆分是否合理。设计变更是否充分影响 plan/tasks，可以触发 `impact_review_required`，由 owner review 裁决。

## Failure Contract

无法恢复时必须明确失败，不扫描历史 `docs/` 猜。

| Failure | Required Response |
|---------|-------------------|
| scope registry 缺失 | 报告 context contract 未启用。 |
| scope registry 为空 | 报告当前没有纳管需求。 |
| registry entry 指向不存在路径 | 阻断，报告失效 `feature_path`。 |
| `entry_ref` 缺失或不可达 | 阻断，报告 registry/worklog 漂移。 |
| `worklog.md` 最新记录不可解析 | 阻断，报告字段或块格式问题。 |
| `state_ref / next_ref` 不可达 | 阻断，报告失效引用。 |
| 多个候选匹配用户输入 | 列候选，等待选择。 |
| mode/layout 与目录冲突 | 阻断，报告 contract 与真实目录冲突。 |
| archived feature 仍为 `managed/migrated` | 阻断或 CI fail，archive 流程必须修 registry。 |

## Phase 1 Scope

Phase 1 的交付物不是所有真实需求都完成纳管，而是纳管协议、模板、validator、hook 接线和测试夹具闭环成立。

### In Scope

| Area | Object | Purpose |
|------|--------|---------|
| Contract | `contracts/active-doc-scope.yaml` | 收窄为 scope registry，明确 `management_status / mode / layout / entry_ref / context_owner`。 |
| Contract | `contracts/context-artifact-ownership.yaml` 或同等 contract | 定义各类上下文工件的 owner、更新触发、校验方式。 |
| Entry | `worklog.md` 模板与规范 | 固定块格式、字段、状态、引用和更新触发。 |
| small-chain | `contracts/small-chain.yaml` 与 superpowers skills | 明确依赖 scope registry、worklog、active workset。 |
| standard-chain | `contracts/standard-chain.yaml` 与 shared skills | 接手入口走 scope registry + worklog，真实进展继续使用 canonical JSON。 |
| Validator | context contract validator | 校验 registry、worklog、引用、命名、owner contract、场景目录。 |
| Hook | runtime/pre-commit/`validate-contracts` 接线 | 调用同一 validator，阻断机械漂移。 |
| Audit | report-only audit entrypoint | 暴露长期 blocked、过期 waiver、supporting 滥用、legacy 漂移。 |
| Docs | README 与相关 contract 文案 | 同步新口径，避免文档和 runtime 分叉。 |
| Tests | contract tests and fixtures | 覆盖 small-chain、standard-chain、失败场景、新窗口恢复测试。 |

### Out of Scope

- 迁移所有历史 `docs/`。
- 新增 `docs/ACTIVE.md`。
- 让 scope registry 记录进度。
- 把 `worklog.md` 做成日报或全量历史。
- 替换 standard-chain canonical producer。
- 实现 UI 或 dashboard。
- 让 audit 参与日常进度判断。
- 基于 hook 认证真实写入者身份。

### Minimum Closed Loop

Phase 1 最小闭环：

1. scope registry 能登记一个 small-chain fixture 和一个 standard-chain fixture。
2. 两个 fixture 都有合法 `worklog.md`。
3. 新窗口恢复测试能列出它们，并分别跳到真实工件。
4. validator 能阻断关键漂移：入口不存在、worklog 缺字段、ref 不可达、归档后仍活跃、small-chain task/plan 不一致、standard-chain canonical refs 不一致。
5. hook 或 `validate-contracts` 调用 validator，而不是只在文档里写规则。
6. audit 能输出 report-only 风险，不改变 registry，不更新 worklog，不判断进度完成。

## Alternatives Considered

| Option | Description | Pros | Cons | Decision |
|--------|-------------|------|------|----------|
| A. 最小导航契约 | scope registry 登记 feature，worklog 指向真实工件，validator 只查路径/字段/引用 | 最轻，落地快 | 不能解决谁维护、何时更新、漏更如何拦截 | Rejected |
| B. Ownership 驱动的接手协议 | scope registry 极窄，worklog 导航，每类工件有 owner/update trigger/check，hook/CI/audit 兜底 | 覆盖接手、真源、维护责任和工程把关；不替换现有链路 | 设计和 validator 首批规则必须收窄 | Chosen |
| C. 全量上下文控制面 | 所有需求工件统一 schema、总索引、生成视图、强生命周期状态机 | 长期治理最强 | Phase 1 过重，容易压过 standard-chain canonical JSON | Rejected for Phase 1 |

## Key Decisions

| ID | Decision | Reason |
|----|----------|--------|
| D1 | Phase 1 采用 Ownership 驱动的接手协议。 | 既覆盖接手恢复，也覆盖维护责任和工程兜底。 |
| D2 | `active-doc-scope.yaml` 对外称为 scope registry。 | 避免和 standard-chain `artifact-registry.json` 混淆。 |
| D3 | registry 使用 `management_status`，不使用泛化 `status`。 | 避免误读为需求进度状态。 |
| D4 | `worklog.md` 使用 `handoff_status`。 | 明确它只表示当前接手项状态。 |
| D5 | `worklog.md` 只在接手路径变化时追加。 | 防止入口膨胀成日报或第二状态真源。 |
| D6 | owner 分为 `context_owner` 和 `artifact_owner`。 | 区分接手链路责任和具体工件正确性责任。 |
| D7 | hook 只守机械边界。 | 不夸大自动化能力，深层语义交给 owner review。 |
| D8 | 阻断式 validator 默认 fail-closed。 | 防止 validator 故障时静默绕过合同。 |
| D9 | 未入 scope registry 的 `docs/*` 不作为默认接手候选。 | 避免历史材料污染活跃上下文。 |
| D10 | Phase 1 用真实试点加 fixture 矩阵证明机制，不全量纳管历史文档。 | 控制范围，先证明协议成立。 |

## Risks

| Risk | Impact | Response |
|------|--------|----------|
| registry 膨胀为进度表 | 形成第二状态真源 | registry 字段只允许纳管边界，不记录 blocked、下一步、task 状态。 |
| `worklog.md` 变成日报 | 接手入口噪音变大，真实工件被复制 | 只允许接手路径字段变化时追加。 |
| hook 能力被夸大 | 误以为自动化能判断业务语义或真实写入者 | 文档和实现都限制 hook 为机械校验；身份确认走 approval/audit。 |
| standard-chain 被错误压成 small-chain 模型 | 损害 canonical JSON 体系 | 统一接手协议，不统一真实工件模型。 |
| 旧文档继续被误读为当前真源 | AI 恢复时采用过时口径 | 本设计声明当前优先级，后续 plan 处理 README 和旧引用漂移。 |
| waiver 被滥用 | hook 规则被长期关闭 | `contract-waivers.md` 必须包含 rule、scope、reason、approver、expires_at、compensating_control，过期由 audit 报告。 |

## Proving Categories

后续 implementation plan 必须给每类成功标准绑定 proving command。至少覆盖：

- scope registry schema 与 active candidate 解析。
- `worklog.md` 块格式、必填字段、枚举、append-only 与引用可达。
- small-chain `tasks.md / plan.md` 一致性。
- standard-chain canonical JSON active refs 与 phase/stage 对齐。
- archive 后 registry 不再列出该 feature。
- validator 在 runtime/pre-commit/`validate-contracts` 中可调用。
- audit 的 report-only 输出。
- 新窗口恢复测试。

## Open Decisions

Phase 1 设计层没有保留阻断性未决事项。具体脚本名称、测试 fixture 路径、hook 注册方式和命令清单留给 writing-plans 冻结。
