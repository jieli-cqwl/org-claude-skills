# Tasks — 活跃文档上下文契约实施计划
Created: 2026-04-13
Related plan: ./plan.md

## 需求

把当前已经冻结的 context contract 设计，真正落成仓库里的运行时约束。

这次不再继续扩设计面，也不再停留在命名讨论。要落地的是：

- `managed active scope` 的显式纳管与校验
- `worklog.md + dated workset` 的 small-chain 兼容桥接
- `brainstorming / writing-plans / verify-change / archive` 的链路对齐
- hooks / scripts / tests / install runtime 的工程兜底

## 目标

1. 让 `contracts/active-doc-scope.yaml` 从“文档真源”变成会被 validator、hook、测试真实消费的纳管真源。
2. 让 `brainstorming`、`writing-plans` 与 `product` 通过同一 validator + registry helper 承接 `small-chain / full-chain` 两种 bootstrap。
3. 让 small-chain 的 closeout / archive 链路不再停留在“归档 change 子目录 + 追加 CHANGELOG”的旧语义。
4. 让这套 contract 的关键约束都能通过脚本和测试稳定兜底，而不是依赖 LLM 自觉。

## 验收标准

- 新增 `tools/community/validate_context_contract.py`，按冻结的 `Validator Contract` 消费 `repo_root / trigger / changed_paths[] / runtime_context / approval_context`，并输出结构化 `decision / scope / findings[] / report_relpath`，退出码遵循 `0/2/3`。
- 新增 `tools/community/update_active_doc_scope.py`，支持 `bootstrap / adopt / archive` 三类写路径；`archive` 后 registry 条目会转成 `legacy`，并同步到归档路径。
- `tools/dev/validate-contracts.sh` 已接入 context contract validator；未纳管 `legacy` 目录不会被误阻断，`managed / migrated` 目录会被严格校验。
- `brainstorming`、`writing-plans` 与 `product` 的 gate 都是“事件适配层”，只负责构造 payload、调用单一 validator 和 registry helper，不再各写一套规则。
- `verify-change`、`using-superpowers`、`subagent-driven-development`、`finishing-a-development-branch`、`archive` 已统一切换到 `worklog.md + active workset + branch-finalization + feature-root archive` 语义。
- `finishing-a-development-branch` 产出的 `branch-finalization` 语义包含 `approved_by / approved_at / approval_ref`，可在 `principal_id` 缺失时被 integrate/CI 复核消费。
- `tools/community/sync_canonical_from_upstream.py` 与对应测试已同步到新路径约定，不再把 upstream patch 回写成旧 small-chain 路径。
- `phase-tree` / full-chain 至少有一条受管 bootstrap 与验证闭环，可证明这套 contract 不只适用于 small-chain。
- 目标测试矩阵通过：
  - `bash tests/test-context-contract-validator.sh`
  - `bash tests/test-active-doc-scope-lifecycle.sh`
  - `bash tests/test-small-chain-boundary.sh`
  - `bash tests/test-chain-completeness.sh`
  - `bash tests/test-closeout-routing.sh`
  - `bash tests/test-community-tools.sh`
  - `bash tests/test-runtime-integrity.sh`
  - `bash tests/test-codex-skill-adapter.sh`
  - `bash tests/test-subagent-context-contract.sh`
  - `bash tools/dev/validate-contracts.sh`

## 修改范围

- validator / contract enforcement
  - `tools/community/validate_context_contract.py`
  - `tools/community/update_active_doc_scope.py`
  - `tools/dev/validate-contracts.sh`
  - `tools/dev/run-context-contract-audit.sh`
  - `tests/test-context-contract-validator.sh`
  - `tests/test-active-doc-scope-lifecycle.sh`
  - `tests/test-context-contract-audit.sh`
- community skill runtime gates
  - `community/superpowers/skills/brainstorming/SKILL.md`
  - `community/superpowers/skills/brainstorming/scripts/completion_check.sh`
  - `community/superpowers/skills/writing-plans/SKILL.md`
  - `community/superpowers/skills/writing-plans/scripts/completion_check.sh`
  - `shared/skills/product/SKILL.md`
  - `shared/skills/product/scripts/completion_check.sh`
  - `shared/hooks/registry.json`
  - `tools/community/render_hook_registry.py`
- small-chain closeout / archive alignment
  - `community/superpowers/skills/using-superpowers/SKILL.md`
  - `community/superpowers/skills/verify-change/SKILL.md`
  - `community/superpowers/skills/finishing-a-development-branch/SKILL.md`
  - `community/superpowers/skills/archive/SKILL.md`
  - `community/superpowers/skills/subagent-driven-development/SKILL.md`
  - `contracts/small-chain.yaml`
- sync / install / runtime / regression
  - `README.md`
  - `tools/community/sync_canonical_from_upstream.py`
  - `tests/test-chain-completeness.sh`
  - `tests/test-small-chain-boundary.sh`
  - `tests/test-closeout-routing.sh`
  - `tests/test-community-tools.sh`
  - `tests/test-runtime-integrity.sh`
  - `tests/test-codex-skill-adapter.sh`
  - `tests/test-subagent-context-contract.sh`
  - `tests/run-all.sh`

## 非目标

- 不全量迁移历史 `docs/` 目录，也不补旧 feature 的 `worklog.md`。
- 不重写 full-chain 主干工件 producer，只实现与现有 contract 的兼容消费。
- 不在本轮接入真正的 scheduler/cron；但会补 `report-only` 的 audit entrypoint 与回归测试。
- 不依赖真实 PR 平台 API 做写入者鉴权；无 `principal_id` 时按设计收口到 owner acknowledgement / `branch-finalization` 路径。

## Acceptance Checklist

- [ ] T1 落地 context contract validator、结构化输入输出与 registry 生命周期写路径
  - AC: `tools/community/validate_context_contract.py` 能从 `contracts/active-doc-scope.yaml` 解析 `mode / status / layout / primary_workset_relpath`，并只对 `status in [managed, migrated]` 的条目做阻断式校验。
  - AC: validator 输入至少支持 `repo_root / trigger / changed_paths[] / runtime_context / approval_context`，输出至少包含 `decision / scope / findings[] / report_relpath`，退出码遵循设计冻结的 `0/2/3` 语义。
  - AC: feature 目录名必须匹配 `<前缀>--<场景>--<主题>`；非法命名、非法场景目录、非法辅助文档日期命名会返回 `block`。
  - AC: `worklog.md` 缺字段、枚举非法、`state_ref / next_ref` 不可达、`supporting/` 缺少自解释头时会返回 `block`。
  - AC: `worklog.md` 的根级写入仍满足 append-only、倒序读取、`YYYY-MM-DD HH:mm` 时间格式，以及“只有阶段/状态/引用/接手切换才允许追加”的更新纪律；违反时会被 validator 或回归测试拦截。
  - AC: `contract-waivers.md` 若存在，必须包含批准人、到期时间、补偿控制与作用域引用；缺任一关键项不得静默放行。
  - AC: `tools/community/update_active_doc_scope.py` 支持 `bootstrap / adopt / archive` 三种写路径；`archive` 会把条目降级为 `legacy` 并同步归档后的 `feature_path`。
  - AC: `tools/dev/validate-contracts.sh` 已接线新 validator，community skill 路径已从旧的 `third_party/community/superpowers/skills` 收口到真实的 `community/superpowers/skills`，且不会把未纳管 legacy 目录误判成 active scope。

- [ ] T2 落地 `brainstorming / writing-plans / product` 的 bootstrap runtime gate
  - AC: `brainstorming` completion gate 能定位 `docs/{feature}/worklog.md` 和唯一 active workset 下的 `design.md`，缺任一工件时阻断；首次进入 managed scope 时会通过 registry helper 完成 `small-chain + dated-workset` bootstrap。
  - AC: `writing-plans` completion gate 要求 `worklog.md + design.md + tasks.md + plan.md` 同时存在，并调用 `check_task_plan_consistency.py`；它只做事件适配，不复制 validator 规则。
  - AC: `product` completion gate 对受管 full-chain feature 校验 `worklog.md + registry + phase-tree` 最小骨架；缺失时阻断，不要求重写现有 producer。
  - AC: `shared/hooks/registry.json`、`render_hook_registry.py` 与安装后的 runtime 已纳入上述 gate。
  - AC: `brainstorming/SKILL.md`、`writing-plans/SKILL.md` 与 `product/SKILL.md` 的输入输出、完成条件、流程导航都已承接新的 bootstrap 口径。

- [ ] T3 对齐 verify / closeout / archive 链路到新 small-chain 语义
  - AC: `verify-change` 以 `worklog.md` 为第一跳，并显式消费 `contracts/active-doc-scope.yaml` 判定当前 active workset。
  - AC: `archive` 不再描述“只移动 dated change 目录 + 追加 CHANGELOG”；改为归档整个 `docs/{feature}/` 到 `docs/archive/{feature}/`，并调用 registry helper 完成 archive 写路径。
  - AC: `using-superpowers`、`subagent-driven-development`、`finishing-a-development-branch` 的链路说明都已承接 `branch-finalization` 与 feature-root archive 语义。
  - AC: `finishing-a-development-branch` 产出的 `branch-finalization` 记录必须包含 `approved_by / approved_at / approval_ref`，以承接无 `principal_id` 运行面的 owner acknowledgement。
  - AC: closeout 文档不再把 `docs/{feature}/CHANGELOG.md` 作为 small-chain 必需工件。

- [ ] T4 补齐 sync / install / runtime / regression 矩阵
  - AC: `tools/dev/run-context-contract-audit.sh` 以 `trigger=audit` 调用单一 validator，并以 `report-only` 方式覆盖 `supporting/` 滥用、过期 waiver、长期 blocked、legacy drift。
  - AC: `tools/community/sync_canonical_from_upstream.py` 的 local override 已同步到 `worklog.md + dated workset` 约定。
  - AC: `tests/test-active-doc-scope-lifecycle.sh` 覆盖 `bootstrap / adopt / archive` 三种 registry 写路径与状态迁移。
  - AC: `tests/test-context-contract-audit.sh` 覆盖 audit entrypoint 的 `warn` 输出与非阻断语义。
  - AC: `tests/test-chain-completeness.sh` 覆盖至少一条 managed full-chain feature 的 `phase-tree` 最小骨架与 `worklog.md` 入口。
  - AC: `README.md` 与 `contracts/active-doc-scope.yaml`、validator 真源和 small-chain 边界测试口径保持一致，README drift 继续作为 CI 阻断项。
  - AC: `tests/test-community-tools.sh` 覆盖 superpowers patch 路径和新 completion gate 文件存在性。
  - AC: `tests/test-runtime-integrity.sh` 与 `tests/test-codex-skill-adapter.sh` 覆盖安装后 runtime 的 gate、hooks.json 渲染和文档引用完整性。
  - AC: `tests/run-all.sh` 与 repo 级 proving path 显式纳入 `test-context-contract-validator.sh`、`test-active-doc-scope-lifecycle.sh`、`test-context-contract-audit.sh`，避免新 contract 回归被总入口漏掉。
  - AC: `tests/test-small-chain-boundary.sh`、`tests/test-closeout-routing.sh`、`tests/test-subagent-context-contract.sh` 均已收口到新 contract 语义并通过。

## Definition of Done

All tasks checked，`tasks.md` 与 `plan.md` 一致性通过，目标验证命令全绿，且这套 context contract 已经从设计说明升级成可执行的 runtime / hook / test 约束。
