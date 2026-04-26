# Small-Chain Execution Router Design

## Why

small-chain 当前在 `writing-plans` 之后直接进入 `using-git-worktrees` 和 `subagent-driven-development`，实际执行路径由 LLM 口头判断，且官方 `subagent-driven-development` 语义仍是按 task 串行分派实现 subagent。要把并行开发变成可自动化、可恢复、可验收的路径，必须在计划完成后增加一个确定性路由层，否则并行是否生效、何时隔离 worktree、失败时怎么回退都会依赖上下文记忆。

## Scope

- In scope: 在 small-chain 的 `writing-plans` 和执行环境准备之间新增 execution router 合同，定义 `serial / parallel / blocked` 三态路由、路由输入输出工件、保守并行判定规则、hook 接入点、并行执行 wrapper 的边界、文档与验证传播面。
- In scope: 保持现有串行链路可继续工作；新计划必须有路由输入才能进入执行，旧计划缺少路由工件时一律 `blocked`，需要重新运行 `writing-plans` 或补齐路由输入后再继续。
- In scope: 交付可运行的并行 V1 wrapper：只支持 router 判定安全的 task/group，创建隔离 worktree，派发有界并行 worker，记录执行与合并证据。
- Out of scope: 本设计不实现高级调度优化器、不自动解决跨 worktree merge 冲突、不改变官方 upstream skill 正文、不放宽 `verify-change` 和归档门禁。

## Approach

新增 `small-chain-execution-router` 作为本地 wrapper 节点，位置在 `writing-plans` 之后、`using-git-worktrees` 之前。`writing-plans` 负责生成结构化的路由候选输入，router 脚本负责做确定性裁决，LLM 只负责读取裁决并继续调度对应 skill。

路由输入是 active workset 下的 `execution-routing-input.json`，由 `writing-plans` 生成。它只描述可被机器验证的事实：task id、候选文件范围、depends、共享文件、独占文件、证明命令、风险标签、是否触碰 contract-grade 面。路由输出是同目录的 `execution-route.json`，由 `tools/community/small_chain_execution_router.py` 生成，包含 `decision`、`reason`、`eligible_tasks`、`parallel_groups`、`worktree_policy`、`tasks_hash`、`plan_hash`、`routing_input_hash`、`router_version`、`generated_at` 和固定失败结构。

路由规则采用保守 V1：只有无共享写文件、无 task 依赖冲突、证明命令可独立运行、不触碰高风险公共面时才允许 `parallel`。高风险公共面包括 hooks、validators、runtime install、contracts、manifest、schema、migration、归档恢复、全局规则、跨 skill 共享入口。默认选择串行或任务强耦合时，router 返回 `serial`；缺少路由输入、输入无效、hash 过期、用户或计划显式要求并行但安全条件不满足时，router 返回 `blocked`，禁止静默降级为串行。

`writing-plans` 结束时负责追加 `worklog.md` 记录：`stage: plan`、`handoff_status: doing`、`state_ref` 指向 `tasks.md`、`next_ref` 指向 `execution-routing-input.json`。hook 不直接调度 subagent，也不创建 worktree。新增的 Stop hook 基于当前 cwd 或唯一 plan-stage workset 选择 active small-chain workset；只要最新 worklog 记录处于 `stage: plan` 就运行 router。router 负责检查 `tasks.md / plan.md / execution-routing-input.json` 是否齐全，缺失时写入 `blocked` 路由工件，并向 LLM 返回下一步提示：`serial` 走现有 `using-git-worktrees -> subagent-driven-development`，`parallel` 走本地 `parallel-subagent-development` wrapper，`blocked` 停止并要求修正计划或路由输入。这样脚本控制状态与合同，LLM 控制解释和实际调度。

并行路径需要本地 wrapper，而不是直接把官方 `dispatching-parallel-agents` 当作 small-chain 执行节点。原因是 small-chain 还需要 per-task worktree、tasks.md 状态同步、merge evidence、失败恢复、verify-change 消费路由证据。官方并行 skill 可以作为调度参考，但本仓库的可执行合同必须落在本地 wrapper 和验证脚本中。

## Alternatives Considered

| Option | Pros | Cons | Verdict |
|--------|------|------|---------|
| LLM 在 `writing-plans` 后自行判断串行或并行 | 改动最小，上手快 | 不可复现，不能稳定恢复，无法证明并行是否真的生效 | Rejected |
| 仅给 `writing-plans` 增加 completion gate | 链路位置接近计划产物 | 当前 Codex active skill tracker 主要记录显式 slash skill，自动触发场景可能漏判 | Rejected |
| 全脚本状态机接管 small-chain | 自动化最强 | 过度设计，会把 LLM 擅长的解释、调度、上下文整合也硬编码 | Rejected |
| Stop hook + router artifact + LLM 按决策调度 | 决策可验证，调度仍灵活，能渐进落地 | 需要新增合同、hook、skill wrapper 和测试 | Accepted |

## Key Decisions

- D1: Router 放在 `writing-plans` 之后、worktree 创建之前。Reason: 串行只需要一个 feature worktree，而并行需要按 task 或 group 隔离 worktree，环境策略必须由路由先决定。
- D2: 脚本裁决 `serial / parallel / blocked`，LLM 执行后续调度。Reason: 路由条件、hash、工件状态适合确定性校验；跨 skill 调度和异常解释仍由 LLM 更合适。
- D3: 并行 V1 默认保守，无法证明安全就不并行。Reason: 并行提效的失败代价是冲突、覆盖、伪完成和验证不可信，先保护正确性。
- D4: 并行执行使用本地 `parallel-subagent-development` wrapper。Reason: 官方 `dispatching-parallel-agents` 提供协作模式，但没有承担本仓库的 small-chain 工件、worktree、merge 和 verify-change 合同。
- D5: 路由输出必须带 `tasks_hash`、`plan_hash` 与 `routing_input_hash`。Reason: 计划或路由输入变更后旧路由必须失效，避免 LLM 拿过期决策继续执行。
- D6: 用户显式要求并行但不满足安全条件时返回 `blocked`。Reason: 静默降级会掩盖“并行没有生效”的核心问题。
- D7: Phase 1 交付可运行并行 V1，而不是只交付 router skeleton。Reason: 用户目标是自动化提效，只有路由没有并行 wrapper 会让“parallel”决策无法落地。
- D8: Contract-grade/runtime-gate changes must pass adversarial review before `verify-change`. Reason: `verify-change` proves declared evidence, but it does not discover undeclared failure modes; review must be a separate gate.

## Goals & Success Criteria

| Goal | Success Criteria | Verification |
|------|------------------|--------------|
| G1: 计划后有确定性路由 | `writing-plans` 产出 `execution-routing-input.json` 并追加 plan-stage worklog，router 产出 `execution-route.json`，且字段足够支持三态裁决 | 新增 fixture 覆盖 serial、parallel、blocked、unknown task id、stale route 二次运行；运行 router 测试 |
| G2: 自动化接入点稳定 | Stop hook 可基于 latest worklog `stage: plan`、当前 cwd 或唯一 plan-stage workset 触发 router，不依赖只记录 slash skill 的 active skill tracker | hook contract 测试覆盖 active workset、缺失工件、blocked 输出、多 active workset 下的当前 cwd 选择 |
| G3: 串行路径保持兼容 | `decision=serial` 时仍进入现有 `using-git-worktrees -> subagent-driven-development`，旧执行语义不变 | `contracts/small-chain.yaml` 验证和现有 small-chain boundary 测试通过 |
| G4: 并行路径可证明隔离 | `decision=parallel` 时 `parallel-subagent-development` 创建 per-task 或 per-group worktree，派发有界并行 worker，并记录互斥写范围与合并证据 | router fixture、parallel wrapper contract 测试、verify-change evidence 检查 |
| G5: 失败不猜测 | 缺少路由输入、`tasks_hash / plan_hash / routing_input_hash` 过期、共享写文件、依赖冲突或高风险公共面时输出固定失败结构 | blocked fixture 和 hook failure contract 测试 |
| G6: 文档与合同同步 | README、`contracts/small-chain.yaml`、superpowers boundary、skills、hooks registry、测试均描述同一链路 | `bash tools/validate-contracts.sh` 与相关 shell tests |
| G7: 流程内置对抗性质量门禁 | contract-grade/runtime-gate 计划必须有 failure matrix，且 `verify-change` 前必须有 `code-review-result.json` PASS | `bash tests/test-small-chain-boundary.sh`、`bash tests/test-closeout-routing.sh` |

## Change Scope

| File or Area | Change Type | Size |
|--------------|-------------|------|
| `contracts/small-chain.yaml` | modify | medium |
| `contracts/superpowers-boundary.yaml` | modify | small |
| `README.md` | modify | small |
| `community/superpowers/skills/writing-plans/SKILL.md` | modify | medium |
| `community/superpowers/skills/subagent-driven-development/SKILL.md` | modify | small |
| `community/superpowers/skills/parallel-subagent-development/SKILL.md` | create | medium |
| `community/superpowers/skills/requesting-code-review/SKILL.md` | modify | small |
| `tools/community/small_chain_execution_router.py` | create | medium |
| `shared/hooks/managed/*` and `shared/hooks/registry.json` | modify/create | medium |
| `tools/community/validate_context_contract.py` and related validators | modify | small |
| `tests/test-small-chain-boundary.sh` and new router/hook tests | modify/create | medium |
| `install.sh` or runtime render inputs if new managed hook/skill must install | modify | small |
| `docs/feature--small-chain--execution-router/` | create | small |

## Invariants

- `tasks.md` remains the task completion status source of truth.
- `plan.md` remains the execution plan mapping and does not own checkbox state.
- `verify-change` remains required before `finishing-a-development-branch` or `archive`.
- Official upstream superpowers skill bodies remain mirrored; local behavior changes live in declared overlays, local-only skills, contracts, hooks, or tools.
- Hooks may validate and emit continuation instructions, but must not spawn implementation agents or run long development tasks.
- No route may execute on a stale `tasks.md / plan.md` pair; hash mismatch blocks.
- No route may execute on a stale `execution-routing-input.json`; `routing_input_hash` mismatch blocks.
- No parallel path may write to the same file from multiple workers unless a later design introduces an explicit merge protocol and validator.
- Existing serial behavior must stay available for small or coupled changes.
- Old plans without `execution-routing-input.json` must stop for plan regeneration rather than silently entering serial execution.
- Contract-grade or runtime-gate changes must not report `verify-change PASS` without `code-review-result.json` showing `review_conclusion=APPROVE` and `gate_result=PASS`.

## Downstream Impact

| Consumer | Impact | Propagation Needed |
|----------|--------|--------------------|
| LLM executing small-chain | Reads `execution-route.json` before choosing serial or parallel path | yes, update skills and README |
| `writing-plans` | Must emit machine-readable route input in addition to `tasks.md / plan.md`, then append plan-stage worklog | yes, update skill contract and tests |
| `using-git-worktrees` | Moves from unconditional next node to route-dependent env strategy | yes, update small-chain contract |
| `subagent-driven-development` | Remains serial executor for `decision=serial` | yes, clarify boundary |
| New `parallel-subagent-development` | Owns parallel worker dispatch, per-task worktree lifecycle and merge evidence | yes, create local wrapper contract |
| `requesting-code-review` | Becomes conditional small-chain gate for contract-grade/runtime-gate work before `verify-change` | yes, update skill, contract and closeout tests |
| Hooks runtime | Adds plan-stage route validation and continuation instruction | yes, update managed hook and registry |
| Context recovery | Must preserve route artifact as active workset state | yes, update validator if stage/ref grammar changes |
| `verify-change` | Must check route evidence before accepting parallel execution | yes, add evidence checks |
| Installer/runtime render | Must include any new hook and local skill | yes, update install/render tests if affected |

## Contract-Grade Preflight

| Check | Answer |
|-------|--------|
| Current vs Target | Current HEAD contract is `writing-plans -> using-git-worktrees -> subagent-driven-development`, with execution effectively serial. Target Phase 1 contract is `writing-plans -> small-chain-execution-router -> serial or parallel branch`, where router is the cutover owner for route decision and `feature-runtime-owner` owns migration. |
| Source of Truth Matrix | Plan facts live in `tasks.md / plan.md`; route candidates live in `execution-routing-input.json`; route decision lives only in `execution-route.json`; execution progress remains in `tasks.md`; plan-stage handoff state remains in `worklog.md`; final acceptance remains in `verify-change-report.md`. Conflict priority is `verify-change-report.md` for acceptance, `tasks.md` for task status, `execution-route.json` for route, `execution-routing-input.json` for route candidates, then `plan.md` for execution instructions. |
| Closed Vocabulary / Grammar | `decision` enum is `serial / parallel / blocked`; `worktree_policy` enum is `single_feature_worktree / per_task_worktree / per_group_worktree / none`; `worklog.stage` at route handoff is `plan`; failure shape is `{ "decision": "blocked", "reason": "...", "blocking_checks": [...], "next_action": "..." }`; refs are active-workset relative paths; hashes are SHA-256 of normalized `tasks.md`, `plan.md`, and canonical JSON `execution-routing-input.json`. |
| Ownership / Waiver | `writing-plans` writes `execution-routing-input.json` and appends the plan-stage `worklog.md` record; router script writes `execution-route.json`; hook invokes router after plan-stage stop; `parallel-subagent-development` writes parallel execution evidence; `verify-change` validates route and evidence. Waivers require explicit user approval in the thread and must be recorded in route output; mechanical checks are router tests, hook tests, boundary tests and `validate-contracts`. |
| Failure Contract | Missing input, unreadable JSON, stale `tasks_hash / plan_hash / routing_input_hash`, stale route already marked blocked without `--force-refresh`, shared writes under a parallel request, dependency conflicts under a parallel request, high-risk common files or `touches_contract_grade=true` under a parallel request, route/task/plan task-id drift and unsupported worktree policy all return `decision=blocked` with fixed fields. The hook must stop continuation on blocked output and must not infer route from unmanaged docs or chat history. |
| Implementation Surface | Phase 1 may edit contracts, README, community superpowers skill overlays and local-only skills, one router script, managed hook registry/files, validators, tests and this feature doc. Cutover order is docs and contract, router script, tests and fixtures, hook registration, skill wrapper updates, verify-change evidence checks. |
| Proving Categories | G1 maps to router fixtures; G2 maps to hook contract tests; G3 maps to existing small-chain boundary tests; G4 maps to parallel route fixtures and wrapper contract tests; G5 maps to blocked fixture tests; G6 maps to `bash tools/validate-contracts.sh` plus targeted shell tests. |
| Existing Contract Diff | Existing README says execution uniformly收口到 `subagent-driven-development`; `contracts/small-chain.yaml` has no route node; boundary tests know only current serial chain; hooks registry has no writing-plans route gate. These must change together or validation should fail. |

## Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| Hook detection misses auto-invoked `writing-plans` | Router may not run when expected | Detect active managed small-chain workset and plan artifacts, not only active slash skill |
| Markdown and JSON route data drift | LLM may execute a path the script did not approve | Treat JSON artifacts as route source of truth and validate hashes |
| Parallel eligibility too aggressive | Merge conflicts, hidden coupling, unreliable verification | Conservative V1 blocks shared writes and high-risk common surfaces |
| Route artifact becomes stale after plan or route-input edits | Old parallel decision may be reused | Hash `tasks.md / plan.md / execution-routing-input.json` and block mismatch |
| Worktree cleanup is incomplete | Repo accumulates branches/worktrees and verification evidence becomes confusing | Parallel wrapper must own worktree naming, cleanup and merge evidence |
| Official upstream skill updates conflict with local wrapper | Local behavior could drift from supported semantics | Keep upstream mirrored and declare all local changes in boundary contract |
| verify-change ignores route evidence | Parallel execution could pass without proving isolation | Add route/evidence checks to verify-change path before archive |
