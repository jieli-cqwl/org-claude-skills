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
| G4. 维护责任可追溯 | 闭合集合内的关键工件都有 `artifact_owner`、更新触发条件和校验方式；feature 级接手链路有 `context_owner`。 |
| G5. 机械漂移可阻断 | validator、runtime hook、pre-commit 和 `validate-contracts` 使用同一规则入口，能阻断字段缺失、引用不可达、非法入口、归档后仍活跃等确定性漂移。 |
| G6. 失败可解释 | 无法恢复现场时输出固定失败结构，不扫描历史 `docs/` 猜测，不把旧材料自动纳入上下文。 |

闭合集合指 `Phase 1 Scope` 中列出的 contract、entry、small-chain、standard-chain、validator、hook、audit、docs 和 tests 文件面。

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
- 同一 `feature_path` 同时最多只有一个 `management_status in [managed, migrated]` 的条目。
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

真源优先级固定如下。任何工具发现低优先级入口与高优先级真源冲突时，必须阻断或报告漂移，不能用低优先级内容覆盖真源。

| Question | Authoritative Source | Lower-Priority Hint |
|----------|----------------------|---------------------|
| feature 是否纳管 | scope registry 的 `management_status` | `docs/{feature}` 是否存在 |
| single feature 的接手入口 | scope registry 的 `entry_ref` | 目录中任意 README 或 dated workset |
| small-chain 完成状态 | `tasks.md` | `worklog.handoff_status` |
| small-chain 下一步执行依据 | `plan.md / tasks.md` 中的任务定义 | `worklog.next` 的短说明 |
| standard-chain 当前 stage | `delivery-state.current_stage` | `worklog.stage` |
| standard-chain 当前可消费版本 | `artifact-registry.active_revision_id` 和 entry `active_for_consumption` | 任意存在的 canonical JSON 文件 |
| blocked / doing / done 的接手项状态 | 最新 `worklog.handoff_status` | 聊天记录或 agent 自述 |

## Scope Registry Contract

`contracts/active-doc-scope.yaml` 对外统一称为 scope registry，避免和 standard-chain 的 `artifact-registry.json` 混淆。

Phase 1 目标字段：

```yaml
version: 2
context_contract_phase: bootstrap
scope_entries:
  - feature_path: docs/feature--context--handoff
    mode: small-chain
    management_status: managed
    status: managed
    rollout_phase: phase-1-pilot
    layout: dated-workset
    entry_ref: worklog.md
    primary_workset_relpath: 2026-04-25-active-context-handoff-phase-1
    context_owner: feature-runtime-owner
    owner: feature-runtime-owner
```

字段语义：

| Field | Meaning |
|-------|---------|
| `version` | scope registry schema version。Phase 1 目标为 `2`。 |
| `context_contract_phase` | 全仓唯一迁移控制点，取值 `bootstrap`、`enforce`、`cleanup`。validator、hook、CI 和 audit 都从该字段读取阶段，不使用环境变量或本地配置。 |
| `feature_path` | 被上下文接手协议纳管的 feature 根目录，相对仓库根。 |
| `mode` | `small-chain` 或 `standard-chain`。旧称 `full-chain` 只作为兼容说明，不作为新枚举。 |
| `management_status` | `managed`、`migrated`、`legacy`。它表示纳管状态，不表示需求进度。 |
| `layout` | `dated-workset` 或 `phase-tree`。 |
| `entry_ref` | 相对 `feature_path` 的入口引用，Phase 1 固定为 `worklog.md`。 |
| `status / owner / rollout_phase / primary_workset_relpath` | v1 兼容字段。`bootstrap` 阶段按当前消费者要求保留；`enforce` 阶段允许保留但必须与目标字段一致；`cleanup` 阶段必须移除。当前事实仍由 `worklog.state_ref` 决定。 |
| `context_owner` | 当前 feature 接手链路负责人。 |
| `archive_ref` | `management_status: legacy` 时指向 `docs/archive/{feature}` 的归档目录。 |
| `archived_at` | `management_status: legacy` 时记录归档日期或时间。 |

活跃候选列表只包含 `management_status in [managed, migrated]` 的条目。`legacy` 仅供审计和历史跟踪，不作为默认接手候选。

同一 `feature_path` 的 active 唯一性是硬约束：

- `managed/migrated` 条目中，同一 `feature_path` 出现两次即 block。
- `mode/layout` 切换是同一条 registry entry 的受控更新，不创建双活条目。
- 如旧链路需要保留历史，先把旧材料归档到 `archive_ref`，再让同一 active entry 指向新 `mode/layout`。
- 切换期间 `entry_ref` 仍固定为根 `worklog.md`；worklog 最新记录的 `mode/stage/state_ref/next_ref` 必须与新链路对齐。

### Registry Migration Contract

当前仓库中的 `contracts/active-doc-scope.yaml` 已有 `status`、`owner`、`primary_workset_relpath` 等字段。Phase 1 不能在未接线 validator 前直接破坏既有消费者，迁移采用分阶段读写：

| Phase | Read | Write | Validation |
|-------|------|-------|------------|
| bootstrap | 同时读取 `status/owner/primary_workset_relpath` 与 `management_status/context_owner/entry_ref` | 新增或修改条目写目标字段，并保留当前 v1 消费者需要的兼容字段 | 缺目标字段 warning；兼容字段仍可解析 |
| enforce | 同时读取旧字段和目标字段 | 新写入只写目标字段；旧兼容字段存在时必须与目标字段一致 | `managed/migrated` 条目缺目标字段 block |
| cleanup | 读取目标字段，旧字段仅用于错误提示 | 只写目标字段 | 旧字段残留 fail，除非 waiver 有效 |

兼容映射固定为：

| Existing Field | Target Field | Rule |
|----------------|--------------|------|
| `status` | `management_status` | 仅表达纳管状态；不得映射到需求进度。 |
| `owner` | `context_owner` | 作为迁移默认值；目标字段存在时以目标字段为准。 |
| `primary_workset_relpath` | compatibility field | dated-workset 的 v1 兼容字段；bootstrap 必填，enforce 允许，cleanup 移除。 |
| `rollout_phase` | rollout metadata | 仅用于迁移阶段管理，不进入恢复输出。 |

当旧字段与目标字段同时存在且含义冲突时，validator 在 bootstrap 阶段 warning，在 enforce 阶段 block。新工具不得把旧字段写回为主字段。

阶段切换由 `tools/community/update_active_doc_scope.py` 写入 `context_contract_phase`，并同时更新 `record_contract`。手工修改该字段属于 break-glass，只允许在同一提交中附带 validator 通过证据。runtime hook、pre-commit、`validate-contracts`、audit 和 recovery command 都读取同一个 `context_contract_phase`。

registry 只随生命周期事件更新：

- 新需求进入上下文机制。
- 旧需求被纳入机制。
- 需求归档。
- mode 或 layout 变化。
- context owner 绑定变化。

日常 task 推进、blocked、恢复、验证、签收不更新 registry。

归档生命周期固定为：

1. 归档动作先移动或确认目标目录为 `docs/archive/{feature}`。
2. registry 条目改为 `management_status: legacy`。
3. registry 增加 `archive_ref: docs/archive/{feature}`。
4. registry 增加 `archived_at`。
5. `entry_ref` 保留为归档目录内的相对入口；默认仍为 `worklog.md`。
6. 活跃候选列表排除该条目；用户显式请求归档需求时，恢复流程使用 `archive_ref + entry_ref`。

## Worklog Contract

`docs/{feature}/worklog.md` 是单个 feature 的唯一接手入口。它最新记录在最上方，只记录接手路径变化，不记录所有历史进展。

每条记录使用固定块格式：

```markdown
## 2026-04-25 10:30

- actor: Codex
- context_owner: feature-runtime-owner
- mode: small-chain
- stage: plan
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
| `stage` | 当前流程阶段路由提示。 |
| `scope_ref` | 当前接手项范围，如 `feature`、`tasks.md#T2`、`phase-1/unit-1`。 |
| `handoff_status` | `doing`、`blocked`、`done`。它只表示当前 handoff item 状态，不表示整个 feature 生命周期。 |
| `state_ref` | 当前事实以哪个真实工件为准。 |
| `next` | 下一步动作的短说明。 |
| `next_ref` | 下一步先打开哪个真实工件。 |

`stage` 是路由提示，不是第二状态机。枚举按 `mode` 分层：

| Mode | Allowed `stage` |
|------|-----------------|
| `small-chain` | `brainstorming`、`plan`、`env`、`execute`、`verify-preflight`、`verify`、`integrate`、`finish`、`blocked` |
| `standard-chain` | `PLANNING`、`TASK_DISPATCH`、`TASK_EXECUTION`、`TASK_VERIFICATION`、`PHASE_REVIEW`、`PHASE_QA`、`SIGNOFF_PENDING`、`SIGNOFF_RECORDED`、`CLOSED`、`BLOCKED`、`REPLAN_PENDING` |

small-chain 的 `stage` 复用 `contracts/small-chain.yaml` 的 `position` 词表。路由映射固定为：

| `stage` | Skill |
|---------|-------|
| `brainstorming` | `brainstorming` |
| `plan` | `writing-plans` |
| `env` | `using-git-worktrees` |
| `execute` | `subagent-driven-development` |
| `verify-preflight` | `verification-before-completion` |
| `verify` | `verify-change` |
| `integrate` | `finishing-a-development-branch` |
| `finish` | `archive` |
| `blocked` | no skill dispatch until unblocked |

standard-chain 的 `stage` 必须与 `delivery-state.current_stage` 对齐。冲突时以 `delivery-state.current_stage` 为真源并阻断恢复，直到追加新的 worklog 记录修正路由提示。

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

只有 `context_owner` 或下表定义的 active coordinator 写根 `worklog.md`。并行 worker 和 explorer 只能在自己的报告中提供候选 handoff 内容，不能直接更新根入口。

解除 blocked 只能追加新记录，不能编辑旧 blocked 记录。新记录必须满足：

- `handoff_status: doing` 或 `done`。
- `state_ref` 指向已经更新的真实工件。
- `next_ref` 指向恢复后的下一步入口。
- 如旧记录包含 `decision_needed`，新记录必须在 `state_ref` 指向的真实工件中留下裁决依据，或在记录中加入 `decision_ref`。

### Ref Grammar

`state_ref` 和 `next_ref` 使用受限语法，禁止自然语言路径和未定义 fragment。

| Mode | Ref Type | Grammar | Allowed Usage |
|------|----------|---------|---------------|
| `small-chain` | repo-relative ref | `{workset_relpath}/{artifact}.md` 或 `{workset_relpath}/{artifact}.md#{anchor}` | `state_ref`、`next_ref` |
| `standard-chain` | active artifact ref | `canonical:{registry_relpath}::artifact://{artifact_type}/{artifact_id}@{version}#{anchor}` | `state_ref`、`next_ref` |
| `standard-chain` | control ref | `{phase_relpath}/delivery-state.json#current_stage` 或 `{phase_relpath}/artifact-registry.json#active_revision_id` | `next_ref` only |

standard-chain 的 `canonical:` ref 解析顺序固定为：

1. 解析 `registry_relpath`，文件必须是当前 `scope_ref` phase 下的 `artifact-registry.json`。
2. 把 `artifact://{artifact_type}/{artifact_id}@{version}#{anchor}` 交给 `tools/community/canonical_ref_resolver.py`。
3. resolver 必须只读取 `active_revision_id` 对应 revision 中 `active_for_consumption: true` 且 `lifecycle_state: FINALIZED` 的 entry。
4. 解析出的 `artifact_path` 才能作为真实工件读取入口。

示例：

```markdown
- mode: standard-chain
- stage: TASK_EXECUTION
- scope_ref: phase-1
- state_ref: canonical:phase-1/artifact-registry.json::artifact://plan/phase-plan@v1#root
- next_ref: canonical:phase-1/artifact-registry.json::artifact://tasks/phase-tasks@v1#T2
```

standard-chain 的 `state_ref` 不允许直接指向 `phase-{N}/plan.json`、`tasks.json` 或其他 canonical JSON。`next_ref` 只有在指向 `delivery-state.current_stage` 或 `artifact-registry.active_revision_id` 这类控制字段时，才允许使用 control ref。

## Artifact Responsibility Model

Phase 1 新增仓库级 Artifact Ownership Contract，固定落点为 `contracts/context-artifact-ownership.yaml`。该文件定义默认 owner、更新触发和校验方式。feature 级只写 owner 绑定、waiver 和必要例外。

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

按 mode 的 writer / owner / approver 映射固定如下：

| Mode | Stage / Artifact | Root `worklog.md` Writer | Artifact Owner | Context Waiver Approver |
|------|------------------|--------------------------|----------------|-------------------------|
| `small-chain` | `brainstorming` / `design.md` | `context_owner` | brainstorming owner | `context_owner` + design owner |
| `small-chain` | `plan` / `tasks.md` / `plan.md` | `context_owner` | writing-plans owner | `context_owner` + planning owner |
| `small-chain` | `execute` / task progress | `context_owner` | subagent-driven-development coordinator | `context_owner` + execution coordinator |
| `small-chain` | `verify-preflight` / `verify` | `context_owner` | verification-before-completion or verify-change owner | `context_owner` + verifier owner |
| `small-chain` | `integrate` / `finish` | `context_owner` | finishing or archive owner | `context_owner` + archive owner |
| `standard-chain` | plan artifacts | `context_owner` or `tech-lead` | `authority_contract.plan_owner` | `context_owner` + `tech-lead` |
| `standard-chain` | delivery state / artifact registry | `context_owner` or `delivery-owner` | `authority_contract.phase_delivery_owner` | `context_owner` + `delivery-owner` |
| `standard-chain` | implementation reports | `context_owner` or `delivery-owner` | `authority_contract.task_implementation_owner` | `context_owner` + `delivery-owner` |
| `standard-chain` | QA result | `context_owner` or `qa` | `authority_contract.quality_judgment_owner` | `context_owner` + `qa` |
| `standard-chain` | signoff / user decision | `context_owner` or `user` | `authority_contract.sign_off_owner` / `business_risk_acceptance_owner` | no context waiver; use canonical decision path |

ownership contract 不替代 standard-chain 的 authority contract：

- standard-chain canonical JSON 内部的 `authority_contract`、`waiver_entries`、签收和发布裁决仍是业务真源。
- `contracts/context-artifact-ownership.yaml` 只管理接手链路维护责任、更新触发和机械校验责任。
- feature 级 `contract-waivers.md` 只豁免 context contract 的机械规则，例如临时路径迁移或旧字段兼容。
- standard-chain 的业务、验收、发布豁免继续写入 canonical `waiver_entries`，不得迁移到 `contract-waivers.md`。

waiver namespace 固定为：

| Namespace | Storage | Scope |
|-----------|---------|-------|
| `context.*` | `docs/{feature}/contract-waivers.md` | context contract 的机械规则，例如临时 ref 迁移、旧字段兼容、supporting 目录例外。 |
| `standard.*` and canonical rule IDs | canonical `waiver_entries` | standard-chain 的业务、验收、发布、authority、风险接受和签收规则。 |

`context.*` waiver 不得覆盖以下 gate：`authority_contract`、`active_revision_id`、`delivery-state.current_stage`、`quality_judgment_owner`、`sign_off_owner`、`business_risk_acceptance_owner`、canonical `waiver_entries` 的有效期与审批要求。触碰这些 gate 时必须升级到 standard-chain canonical 决策路径。

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

### Archived Recovery Flow

默认恢复只列活跃候选，不把 `legacy` 混入 active list。归档恢复只在以下两类输入下触发：

- 用户显式要求查看 archived / legacy / history 需求。
- 用户给出精确 `feature_path` 或 basename，活跃候选无匹配，但 registry 中存在 `legacy` 匹配。

归档恢复只读取 scope registry 中的 `legacy` 条目，不扫描 `docs/archive/` 猜测。输出字段在活跃恢复字段基础上增加：

| Field | Source |
|-------|--------|
| `archive_ref` | scope registry |
| `archived_at` | scope registry |
| `archived_entry_ref` | `archive_ref + entry_ref` |

当同一个输入同时命中 active 和 archived 条目时，recovery command 必须列出两类候选并等待选择，不自动选 archived。

### Candidate and Recovery Output Contract

候选列表输出字段固定为：

| Field | Source |
|-------|--------|
| `feature_path` | scope registry |
| `mode` | scope registry |
| `layout` | scope registry |
| `context_owner` | scope registry |
| `latest_worklog_at` | 最新 worklog 记录标题时间 |
| `handoff_status` | 最新 worklog 记录 |
| `state_ref` | 最新 worklog 记录 |
| `next_ref` | 最新 worklog 记录 |

排序规则固定为：`latest_worklog_at desc`，再按 `feature_path asc`。`latest_worklog_at` 不可解析的条目排在最后并标记 warning；`managed/migrated` 条目缺 worklog 时阻断，不进入正常候选列表。

用户指定需求时只允许两种自动命中：

- 精确匹配 `feature_path`。
- 精确匹配 `feature_path` basename。

除此以外均为模糊匹配。模糊匹配只列候选，不自动选择。

恢复输出最小结构固定为：

```yaml
feature_path: docs/feature--context--handoff
mode: small-chain
layout: dated-workset
context_owner: feature-runtime-owner
handoff_status: doing
state_ref: 2026-04-25-active-context-handoff-phase-1/tasks.md#T2
next_ref: 2026-04-25-active-context-handoff-phase-1/plan.md#T2
blocker_summary: null
source:
  registry: contracts/active-doc-scope.yaml
  worklog: docs/feature--context--handoff/worklog.md
```

当 `handoff_status: blocked` 时，`blocker_summary` 必须填入 `blocker`、`waiting_on`、`unblock_condition` 和 `decision_needed`。

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
    user-decision.json
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

standard-chain 的 active revision 绑定规则固定为：

- `worklog.state_ref` 必须使用 `canonical:` active artifact ref。
- 读取当前事实时，先解析 `canonical:` 中的 `registry_relpath`，再通过 `active_revision_id` 读取该 revision 下 `active_for_consumption: true` 的 entry。
- `worklog.next_ref` 指向 active artifact 时必须使用 `canonical:` active artifact ref；只有 stage 或 registry 控制字段使用 control ref。
- 存在但未被 active revision 选中的 JSON 文件不得作为当前事实入口。
- `delivery-state.current_stage` 是当前 stage 真源；`worklog.stage` 只用于快速路由并必须与它一致。

## Hook Enforcement Matrix

LLM 负责产出候选内容，owner 负责语义正确性，hook/validator 负责机械边界，`validate-contracts` 和 audit 负责防漂移和长期风险。

| Layer | Trigger | Blocks |
|-------|---------|--------|
| runtime hook | AI 回合结束或工具写入后 | 本次改动造成的入口缺失、引用不可达、字段非法、未授权根 worklog 写入、受管路径外新增入口文件 |
| pre-commit | commit 前 | 文档结构、命名、scope registry/worklog 一致性、非法散落文件、append-only 破坏 |
| `validate-contracts` / CI | push、PR、本地验证 | 全仓合同回归、防绕过、本地 hook 缺失、标准夹具回归失败 |
| audit | 手动或定期 | 不阻断，只报告长期 blocked、过期 waiver、supporting 滥用、legacy 漂移 |

四层共用同一个 context contract validator。hook 和 CI 只选择不同 scope，不复制规则：

| Entry | Scope | Required Assertions |
|-------|-------|---------------------|
| runtime hook | changed files and impacted registry entries | changed refs 可达、枚举合法、root worklog 写入者边界、managed entry 不破坏 |
| pre-commit | staged files and impacted registry entries | runtime assertions + append-only + 命名路径规则 |
| `validate-contracts` / CI | full repository | full registry/worklog graph + fixtures + small-chain/standard-chain consistency |
| audit | full repository | stale/long-blocked/waiver/supporting/legacy 风险，仅 report-only |
| recovery command | scope registry and selected feature | 候选列表、精确/模糊选择、恢复输出结构 |

确定性阻断规则：

| Scenario | Decision |
|----------|----------|
| scope registry 指向不存在的 feature | block |
| scope registry 缺 `context_contract_phase` 或阶段非法 | block |
| `managed / migrated` feature 缺 `worklog.md` | block |
| `entry_ref` 不可达 | block |
| `worklog.md` 缺必填字段或枚举非法 | block |
| `state_ref / next_ref` 不可达 | block |
| 同一 `feature_path` 存在两个 active registry 条目 | block |
| 归档 feature 后仍出现在活跃候选列表 | block |
| 移动/删除被 `worklog` 引用的文件但未修 ref | block |
| small-chain `tasks.md` 和 `plan.md` task 引用不一致 | block |
| standard-chain canonical active refs 不一致 | block |
| `supporting/` 文档缺 purpose/serves/reason_here | block |
| validator 在阻断式场景故障 | fail-closed |
| standard-chain `worklog.state_ref` 绕过 active revision | block |
| `worklog.stage` 与 `delivery-state.current_stage` 冲突 | block |
| 新字段和旧字段冲突 | enforce 阶段 block |
| ownership contract 缺 artifact owner、update trigger 或 mechanical checks | block |
| feature 级 context waiver 试图覆盖 standard-chain 业务 waiver | block |

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
| scope registry 缺 `context_contract_phase` 或阶段非法 | 阻断，报告迁移阶段控制点缺失或非法。 |
| registry entry 指向不存在路径 | 阻断，报告失效 `feature_path`。 |
| registry 旧字段与目标字段冲突 | bootstrap 阶段 warning；enforce 阶段阻断并报告冲突字段。 |
| 同一 `feature_path` 存在两个 active registry 条目 | 阻断，报告 duplicate active feature。 |
| `entry_ref` 缺失或不可达 | 阻断，报告 registry/worklog 漂移。 |
| `worklog.md` 最新记录不可解析 | 阻断，报告字段或块格式问题。 |
| `worklog.md` 缺 required owner 或 stage 枚举非法 | 阻断，报告缺失字段或非法枚举。 |
| ownership contract 缺 owner、trigger 或 check | 阻断，报告缺失的 artifact responsibility 字段。 |
| `state_ref / next_ref` 不可达 | 阻断，报告失效引用。 |
| standard-chain active revision 不一致 | 阻断，报告 `artifact-registry.active_revision_id` 与 active entry 冲突。 |
| standard-chain ref grammar 非法 | 阻断，报告非法 `canonical:` 或 control ref。 |
| `worklog.stage` 与 `delivery-state.current_stage` 冲突 | 阻断，报告 stage 漂移。 |
| 多个候选匹配用户输入 | 列候选，等待选择。 |
| mode/layout 与目录冲突 | 阻断，报告 contract 与真实目录冲突。 |
| archived feature 仍为 `managed/migrated` | 阻断，报告 archive lifecycle 未完成；在 CI 中表现为 fail。 |
| validator 在阻断式检查中不可用 | fail-closed，报告 validator unavailable。 |

失败输出最小结构固定为：

```yaml
decision: block
reason: state_ref_unreachable
path: docs/feature--context--handoff/worklog.md
expected: reachable state_ref
actual: 2026-04-25-active-context-handoff-phase-1/tasks.md#T2 missing
next_action: update worklog with reachable state_ref or restore referenced artifact
```

failure output 也必须用于恢复命令的 golden fixture。验证时必须断言失败输出结构完整，并断言 recovery command 没有扫描未入 registry 的 `docs/*` 目录。

## Phase 1 Scope

Phase 1 的交付物不是所有真实需求都完成纳管，而是纳管协议、模板、validator、hook 接线和测试夹具闭环成立。

### In Scope

| Area | Object | Purpose |
|------|--------|---------|
| Contract | `contracts/active-doc-scope.yaml` | 收窄为 scope registry，明确 `management_status / mode / layout / entry_ref / context_owner`。 |
| Contract | `contracts/context-artifact-ownership.yaml` | 定义各类上下文工件的 owner、更新触发、校验方式。 |
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

### Implementation Surface

设计层冻结以下首批文件面。writing-plans 可以拆任务，但不得把规则散落成多个互相不一致的入口。

| Area | Path |
|------|------|
| scope registry contract | `contracts/active-doc-scope.yaml` |
| ownership contract | `contracts/context-artifact-ownership.yaml` |
| small-chain contract | `contracts/small-chain.yaml` |
| standard-chain contract | `contracts/standard-chain.yaml` |
| canonical stage registry | `contracts/canonical/stage-registry.yaml` |
| context validator | `tools/community/validate_context_contract.py` |
| recovery command | `tools/community/recover_context.py` |
| registry lifecycle helper | `tools/community/update_active_doc_scope.py` |
| audit entrypoint | `tools/dev/run-context-contract-audit.sh` |
| global contract runner | `tools/dev/validate-contracts.sh` and `tools/validate-contracts.sh` |
| hook registry | `shared/hooks/registry.json` |
| hook renderer | `tools/community/render_hook_registry.py` |
| runtime hook dispatch | `shared/hooks/managed/codex_stop_dispatch.py` |
| README | `README.md` |
| small-chain skill references | `community/superpowers/skills/{brainstorming,writing-plans,using-git-worktrees,subagent-driven-development,verification-before-completion,verify-change,finishing-a-development-branch,archive}/SKILL.md` |
| standard-chain skill references | `shared/skills/{product-director,product-manager,design,tech-lead,test-design,developer,verify,qa,delivery-owner,fix,consistency-audit}/SKILL.md` |
| fixture root | `tests/fixtures/context-contract/` |
| recovery fixtures | `tests/fixtures/context-contract/recovery/` |
| validator tests | `tests/test-context-contract-validator.sh` |
| lifecycle tests | `tests/test-active-doc-scope-lifecycle.sh` |
| recovery tests | `tests/test-context-recovery.sh` |
| audit tests | `tests/test-context-contract-audit.sh` |

### Cutover Order

1. Atomically update `contracts/active-doc-scope.yaml` to version 2 dual-accept contract and set `context_contract_phase: bootstrap`; update README and `contracts/small-chain.yaml` so v1 compatibility fields and target fields are both visible.
2. Add fixtures, `tools/community/validate_context_contract.py`, and `tools/community/recover_context.py` in bootstrap mode.
3. Add `contracts/context-artifact-ownership.yaml`.
4. Wire `tools/dev/validate-contracts.sh` and the hook registry to the validator.
5. Update `contracts/standard-chain.yaml` and skill references to this design vocabulary and ref grammar.
6. Register the real pilot with target fields plus bootstrap compatibility fields.
7. Switch `context_contract_phase` to `enforce` only after fixtures, recovery command, hook registry rendering, and real pilot pass.
8. Switch to `cleanup` only after no runtime consumer reads v1 fields and cleanup fixtures pass.

### Current Design Workset Boundary

当前设计 workset 是 docs-only 的 Phase 1 规格工件。它是下一轮 implementation plan 的真源，但还不是 managed active scope entry，因为 Phase 1 validator 和 registry lifecycle helper 尚未存在。

第一轮 implementation plan 必须通过新 lifecycle path bootstrap pilot：

1. 先完成 Cutover Order 的第 1 步，让现有合同接受 target fields 和兼容字段。
2. 创建或校验 feature root `worklog.md`。
3. 用 target fields 加 bootstrap compatibility fields 注册 pilot。
4. 运行 context validator bootstrap mode。
5. 在 `tasks.md / plan.md` 产生前，把本 `design.md` 作为 `state_ref`。

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
| D11 | standard-chain 恢复必须先经 `artifact-registry.active_revision_id`。 | 防止读取存在但非 active 的 canonical JSON。 |
| D12 | `contracts/context-artifact-ownership.yaml` 是固定 owner contract。 | 避免同一责任模型出现多个等价落点。 |
| D13 | registry 迁移采用 bootstrap dual-write、enforce target-write、cleanup target-only。 | 兼容当前仓库合同，同时阻止新写入继续漂移。 |
| D14 | `context_contract_phase` 是唯一迁移阶段控制点。 | 避免 hook、CI、recovery command 通过不同 flag 产生分叉。 |
| D15 | 同一 `feature_path` 禁止双 active。 | 防止 small-chain 与 standard-chain 在同一需求上串线。 |
| D16 | standard-chain ref grammar 固定为 `canonical:` active artifact ref。 | 复用现有 resolver，避免各层自造解析规则。 |

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

后续 implementation plan 必须给每类成功标准绑定 fresh proving command。首批证明面固定如下：

| Category | Required Proof |
|----------|----------------|
| scope registry schema | `tests/test-active-doc-scope-lifecycle.sh` 覆盖 version 2、bootstrap dual-write、enforce target-write、cleanup target-only、archive lifecycle。 |
| active candidate parsing | validator fixture 覆盖精确 feature_path、basename、fuzzy 多候选和 latest_worklog_at 排序。 |
| `worklog.md` contract | `tests/test-context-contract-validator.sh` 覆盖块格式、必填字段、枚举、append-only、引用可达。 |
| ownership contract | `tests/test-context-contract-validator.sh` 覆盖 `contracts/context-artifact-ownership.yaml` 必填 owner、update trigger、mechanical checks、waiver namespace。 |
| ref grammar | `tests/test-context-contract-validator.sh` 覆盖 small-chain repo-relative ref、standard-chain `canonical:` ref、control ref、非法 ref。 |
| small-chain consistency | fixture 覆盖 `tasks.md / plan.md` task 引用一致性和 `worklog.state_ref` 路由。 |
| standard-chain consistency | fixture 覆盖 `artifact-registry.active_revision_id`、`active_for_consumption`、`delivery-state.current_stage`。 |
| archive exclusion | lifecycle test 覆盖 `management_status: legacy`、`archive_ref`、活跃候选排除。 |
| archived recovery | `tests/test-context-recovery.sh` 覆盖 explicit archived lookup、active miss 后 legacy basename lookup、active 与 archived 同时命中时等待选择。 |
| blocked and unblock | `tests/test-context-contract-validator.sh` 覆盖 blocked 必填字段、unblock 追加新记录、`decision_ref` 或真实工件裁决依据。 |
| hook and contracts wiring | `tools/dev/validate-contracts.sh` 调用 context validator；hook registry 渲染后包含同一 validator。 |
| audit report-only | `tests/test-context-contract-audit.sh` 覆盖长期 blocked、过期 waiver、supporting 滥用、legacy 漂移，且不修改文件。 |
| new-window recovery | `tests/test-context-recovery.sh` 调用 `tools/community/recover_context.py`，golden fixture 输出必须匹配 Recovery Output Contract。 |
| failure output | `tests/test-context-recovery.sh` 覆盖固定 Failure Contract 输出，并证明未扫描未入 registry 的 `docs/*`。 |

## Open Decisions

Phase 1 设计层没有保留阻断性未决事项。writing-plans 只能在 `Implementation Surface` 范围内拆任务、确定参数和命令细节；如需新增文件面，必须先追加设计变更记录并重新 review。
