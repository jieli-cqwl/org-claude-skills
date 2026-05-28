# Standard-chain 最小字段合同 Agent Team 执行提示词

你正在接手 `/Users/lijieli/org-claude-skills` 的 standard-chain 字段合同收敛任务。

## 启动硬门

执行前先读取并遵守：

- 仓库根目录 `AGENTS.md`
- `$HOME/.codex/rules/` 下所有规则
- `$HOME/.codex/reference/协作判断.md`
- `$HOME/.codex/reference/测试规范.md`
- `$HOME/.codex/reference/完成前验证.md`
- `$HOME/.codex/reference/影响范围分析.md`

如果 Claude Code agent team 能力不可用，停止并报告，不要退化成单 agent 直接实施。

当前首轮是只读审计和矩阵裁决任务：允许写入本提示词指定的 `docs/standard-chain-minimal-field-contract-review-2026-05-28/` 报告文件；禁止修改 contracts、shared、tests、tools、runtime 或其它实现/测试/规则文件。禁止 git stage、commit、push。

## 总目标

终极目标不可降级：把 `product-director -> delivery-owner` 标准链收敛成最小、稳定、可接力、可验证的字段合同。

最终必须达到：

- 每个环节清楚知道自己必须输入什么、输出什么。
- 每个保留字段都有唯一 owner、明确 consumer、写入时机、消费目的和验证方式。
- 不需要的字段、旧概念、错误路径、自然语言测试契约和 active 上下文噪音必须彻底删除，不保留 deprecated / legacy / 不要使用 X 等提示。
- 链路能从 Director baseline 走到 Delivery signoff，不靠模型猜字段。
- 原校准/复核报告里的 P0/P1 不能被忽略，但必须重新映射到字段合同缺口；能映射的修，映射不了的标为误报、噪音或后续 cleanup，不能机械照单修。

阶段可以拆，终局验收不能降级。

## 背景和已知偏航

之前推进中出现过错误方向：为了让测试通过，改了主内容真源。例如 `shared/rules/铁律.md` 曾被错误修改，后已确认应还原。

本次必须避免同类错误：测试不能定义主内容，报告不能替代字段合同，P0/P1 不能机械变成字段堆叠。

已知需要重点复核的偏航样例：

- `product-director` 的真源要求 `brief.json` / `phase-prd.json` 带 canonical envelope 和 `director_confirmation`，不要加入 PM-owned 下游字段。
- `locked_field_digest` 在 schema/template 中属于 `director_confirmation.locked_field_digest`，不应被测试或 contract 发明成顶层 `locked_field_digest` 字段。
- `tests/test-runtime-contract-catalog.sh` 这类自然语言句子锁定容易把文案改写变成测试契约，必须复核。
- `baseline_tasks_version_ref`、`active_tasks_version_ref` 等重复字段要判断是必要、派生、移动还是删除，不能重复堆叠。

## 工作原则

1. 先矩阵，后改文件。
2. 先裁决字段责任，再同步 active 消费面。
3. 少即是多，但不能删掉链路必需责任。
4. 不要的字段和概念要从 active 上下文彻底删除。
5. 只保留正向闭集：告诉 agent 要读/写什么，不在主路径反复命名旧错误概念。
6. 每个结论必须有当前文件证据，格式为 `path:line`。
7. agent team 输出是 advisory；最终字段矩阵由主控合并并等待用户确认。
8. 未经用户确认字段矩阵，不进入实施。

## 字段裁决标准

每个字段必须回答：

- 谁写：唯一 owner 是谁？
- 谁读：哪些下游 consumer 读取？
- 何时写：handoff 前、执行中、QA 前、signoff 前，还是最后才写？
- 用途是什么：gate、handoff、transform、reference、recovery、freshness、evidence？
- 能否派生：能否从 registry、digest、canonical refs 或脚本计算？

字段裁决只允许这些值：

- `keep`：必须保留；驱动 gate / handoff / transform / recovery / runtime evidence。
- `delete`：无必要、重复、旧概念、错误路径、只增加上下文噪音。
- `derive`：有用但不应手写，可由 registry / digest / refs / script 得出。
- `move`：字段有价值，但当前 artifact 放错位置。
- `needs-human-decision`：证据不足，必须用户裁决。

默认规则：

- 无 consumer 的字段默认 `delete`。
- 只解释背景、不驱动决策的字段默认 `delete`。
- 可派生字段默认 `derive`。
- 字段路径以 schema/template/producer 真源为准，测试不能发明路径。
- 旧概念不得留在 active skill 主路径；如确有迁移需求，只能进入 migration/archive，且 active tests/runtime 不消费。

## Agent Team 组织方式

请使用 Claude Code 的 agent team 能力。

执行顺序：

1. Agent A-E 并行执行，只读仓库源文件，各自写入指定报告文件。
2. Agent F 在 A-E 报告完成后执行，读取 A-E 报告并质疑结论。
3. 主控读取 A-F 报告，合并唯一字段裁决矩阵。

所有 agent 第一轮不得修改源文件；只能写入 `docs/standard-chain-minimal-field-contract-review-2026-05-28/` 下自己的报告。

### Agent A: Director/PM Baseline Auditor

范围：

- `shared/skills/product-director/**`
- `shared/skills/product-manager/**`
- `brief.json`
- `phase-prd.json`
- `UNIT-*.json`
- `contracts/standard-chain.yaml`
- `contracts/standard-chain-field-consumption.yaml`

任务：

- 梳理 Director 最小基线字段。
- 判断 PM 应增加哪些 WHAT 层字段。
- 找出上游被下游字段污染的位置。
- 特别复核 `director_confirmation.locked_field_digest` 与顶层 `locked_field_digest` 的路径问题。

输出文件：

- `docs/standard-chain-minimal-field-contract-review-2026-05-28/agent-a-director-pm-matrix.md`

### Agent B: Design/Test/Tech Handoff Auditor

范围：

- `shared/skills/design/**`
- `shared/skills/test-design/**`
- `shared/skills/tech-lead/**`
- `design.json`
- `test-cases.json`
- `plan.json`
- `tasks.json`

任务：

- 梳理从 PM 到 design/test-design/tech-lead 的最小交接字段。
- 判断哪些字段是设计/测试/计划必需，哪些是重复解释或可派生。
- 检查 AC、verification plan、qa handoff、cross-unit obligations 是否职责清楚。

输出文件：

- `docs/standard-chain-minimal-field-contract-review-2026-05-28/agent-b-design-test-tech-matrix.md`

### Agent C: Runtime Evidence Auditor

范围：

- `shared/skills/developer/**`
- `shared/skills/verify/**`
- `shared/skills/review/**`
- `shared/skills/qa/**`
- `developer-report.json`
- `verify-result.json`
- `code-review-result.json`
- `qa-result.json`

任务：

- 梳理执行证据最小字段。
- 检查 freshness、set coverage、QA admission、code-review 与 verify/QA 的边界。
- 判断哪些 P0/P1 是 runtime evidence 合同缺口，哪些只是字段堆叠。

输出文件：

- `docs/standard-chain-minimal-field-contract-review-2026-05-28/agent-c-runtime-evidence-matrix.md`

### Agent D: Delivery Control Auditor

范围：

- `shared/skills/delivery-owner/**`
- `artifact-registry.json`
- `delivery-state.json`
- `signoff-package.json`
- `user-decision.json`
- `target-change.json`
- `fix-result.json`
- `consistency-audit-result.json`

任务：

- 梳理 delivery-owner 只应该管理的状态、证据、注册表、用户决策和目标变更字段。
- 区分 `user-decision` 与 `target-change`。
- 判断 signoff evidence matrix 和 artifact registry 的最小必要字段。
- 检查哪些字段属于 runtime state，哪些不应进入 baseline。

输出文件：

- `docs/standard-chain-minimal-field-contract-review-2026-05-28/agent-d-delivery-control-matrix.md`

### Agent E: Test/Validator Contract Auditor

范围：

- `tests/**`
- `tools/community/**`
- `shared/runtime/**`
- `contracts/**`
- gate plan / runtime catalog / validators

任务：

- 找出错误测试契约、自然语言句子锁定、旧字段残留、测试倒逼主内容的问题。
- 判断哪些测试应改成结构/字段路径/消费关系/脚本行为验证。
- 列出 active 范围里会继续激活旧概念的测试和 fixture。

输出文件：

- `docs/standard-chain-minimal-field-contract-review-2026-05-28/agent-e-test-validator-contract-matrix.md`

### Agent F: Challenge Reviewer

范围：

- 读取 Agent A-E 的输出。
- 可补读它们引用的文件，但不做新范围扩展。

任务：

- 质疑每个 `keep` 是否真的有 consumer 和决策用途。
- 质疑每个 `delete` 是否误删了 gate / recovery / evidence freshness 必需字段。
- 质疑每个 `move` 是否只是换名堆叠。
- 质疑每个 P0/P1 映射是否真实对应字段合同缺口。
- 找出证据不足、路径不准、引用旧事实、测试定义主内容的问题。

Challenge Reviewer 输出必须分三类：

- `challenge-supported`：原结论成立。
- `challenge-rejected`：原结论证据不足或方向错误。
- `needs-human-decision`：需要用户裁决。

输出文件：

- `docs/standard-chain-minimal-field-contract-review-2026-05-28/agent-f-challenge-review.md`

## Active 范围定义

“旧概念消失”只要求 active 上下文消失，不要求历史归档或历史 eval 结果全文消失。

Active 范围包括：

- `contracts/**`
- `shared/skills/**` 当前 skill、schema、template、script、reference、eval contract
- `shared/runtime/**`
- `tests/**` 当前会运行或被 gate plan 引用的测试和 fixture
- `tools/community/**` 当前 validators/builders/checkers
- `docs/reports/**` 和 `docs/superpowers/**` 中作为当前事实或当前计划引用的文档
- `tests/gate-plan.json`

非 active 范围：

- `docs/archive/**`
- `tools/eval/results/**` 历史运行输出，除非当前测试、runtime 或 contract 明确消费
- 历史 raw transcript / raw-output，除非当前测试、runtime 或 contract 明确消费

如果某个旧概念只存在非 active 范围，记录为 `archive-only`，不得为了搜索清零而改历史记录。

## 所有 agent 统一输出格式

禁止散文式泛评。必须输出表格或 JSON-like 列表，每行包含：

`artifact | field_path | current_owner | proposed_owner | write_time | consumers | purpose | decision | evidence | delete_impact | verification`

要求：

- `evidence` 必须是当前仓库 `path:line`。
- `consumers` 必须写具体角色、脚本、schema 或测试。
- `purpose` 必须从 `gate / handoff / transform / reference / recovery / freshness / evidence / state / decision` 中选择。
- `delete_impact` 必须写删除后的影响；无影响写 `none` 并说明原因。
- `verification` 写后续如何证明裁决正确。
- 不确定时写 `needs-human-decision`，不要猜。
- 每个 `keep` 必须至少有一个 consumer 和一个 purpose；否则必须改为 `delete`、`derive`、`move` 或 `needs-human-decision`。
- 每个 `delete` 必须列出 active 搜索目标，说明删除后哪些引用也必须同步消失。
- 每个 `move` 必须写出 from artifact/path 和 to artifact/path，不能只写“移动到合适位置”。
- 每个 P0/P1 映射必须引用原报告 issue id，并给出 `mapped-to-field-gap / rejected-as-noise / needs-human-decision / follow-up-cleanup`。

## 主控合并流程

1. 收集 Agent A-E 的字段矩阵。
2. 交给 Agent F 质疑。
3. 主控合并成唯一字段裁决矩阵。
4. 对冲突项给出可裁决问题，不擅自折中。
5. 向用户汇报矩阵摘要和冲突项，等待用户确认。
6. 用户确认后，才进入实施计划。

主控首轮输出文件：

- `docs/standard-chain-minimal-field-contract-review-2026-05-28/merged-field-decision-matrix.md`
- `docs/standard-chain-minimal-field-contract-review-2026-05-28/p0-p1-remap.md`
- `docs/standard-chain-minimal-field-contract-review-2026-05-28/conflicts-and-human-decisions.md`
- `docs/standard-chain-minimal-field-contract-review-2026-05-28/implementation-order.md`
- `docs/standard-chain-minimal-field-contract-review-2026-05-28/execution-summary.md`

主控汇报必须先给结论，再给证据。不得声明“可实施”或“完成”，只能声明“字段矩阵待用户确认”。

## 实施范围确认后再做

实施阶段必须按矩阵同步所有 active 消费面：

- `contracts/standard-chain.yaml`
- `contracts/standard-chain-field-consumption.yaml`
- schema / template
- skill 主流程正文
- preflight / completion / validator scripts
- tests / fixtures
- runtime catalog / gate plan
- active docs 中作为当前事实的引用

删除字段时不能留下：

- `deprecated`
- `legacy`
- `不要使用 X`
- `X 已废弃`
- `兼容旧字段`
- 主路径中的旧概念解释

## 验证标准

最终交付必须证明：

1. 字段矩阵闭合：每个保留字段都有 owner、consumer、write_time、purpose、verification。
2. 旧概念消失：active 范围搜索无不要字段和旧概念残留。
3. 字段路径正确：例如 `locked_field_digest` 只作为 `director_confirmation.locked_field_digest` 合法存在，不作为顶层 handoff 字段。
4. 测试不锁自然语言：测试验证 schema、字段路径、消费关系、脚本行为，不验证主文档句子。
5. 链路可执行：最小 fixture 能证明 Director -> PM -> plan/tasks -> developer/verify/review/qa -> delivery-owner signoff 的关键 contract 验证可闭合。
6. P0/P1 已重新映射：每个 accepted P0/P1 都有 `mapped-to-field-gap / rejected-as-noise / needs-human-decision / follow-up-cleanup` 状态。
7. 两轮复核：连续两轮没有新增目标内字段漂移、错误测试契约或旧概念残留，才允许声明完成。

首轮矩阵审计的验证标准：

- A-E 五份矩阵文件均存在，且每份都有统一字段列。
- F 的 challenge review 覆盖 A-E 每份输出。
- merged matrix 中每个 `keep` 都有 owner、consumer、write_time、purpose、evidence、verification。
- `needs-human-decision` 项集中出现在 conflicts 文件，不散落在正文里。
- P0/P1 remap 覆盖 `docs/reports/standard-chain-flow-instruction-control-full-review-2026-05-28.md` 中所有 accepted P0/P1 issue id。
- 未修改首轮允许范围外的文件；用 `git diff --name-only` 证明。

首轮结束前运行并记录：

- `git diff --name-only`
- `find docs/standard-chain-minimal-field-contract-review-2026-05-28 -maxdepth 1 -type f | sort`
- 针对所有输出文件的列完整性人工复核记录

## 停止条件

遇到以下情况必须停止并向用户报告，不得继续推进：

- agent team 不可用。
- 任一 agent 输出缺少 `path:line` 证据。
- A-E 输出互相冲突且无法由当前证据裁决。
- 需要修改首轮允许范围外文件才能继续。
- 发现目标或成功标准需要改变。
- 发现 active 范围定义不足以判断旧概念是否应删除。

## 首轮交付物

首轮只写报告，不改源文件：

1. Agent A-E 的字段矩阵。
2. Agent F 的 challenge review。
3. 主控合并后的唯一字段裁决矩阵。
4. 冲突和用户裁决问题清单。
5. 建议实施顺序。

等待用户确认矩阵后，再创建实施计划。
