# Tasks — /product 角色拆分实施计划
Created: 2026-04-15
Related plan: ./plan.md

## 需求

把当前单体 `shared/skills/product/` 拆成 `product-director` 与 `product-manager` 两个独立 skill，引入共享模板真源与 Director lock snapshot 契约，并同步收口 runtime hooks、兼容入口、下游 skill 引用、安装器、tests 与 eval 资产。

## 目标

1. 让 `product-director` 只负责根问题、目标、范围、Phase 规划和 Director 基线冻结。
2. 让 `product-manager` 只负责 handoff 后的业务流程细化、UNIT 共创、AC 收口、审查与交付确认。
3. 让 `brief.md / phase-{N}/prd.md` 保持共享工件语义，但通过 `brief.lock.json / prd.lock.json` 阻断 PM 改写 Director 锁定内容。
4. 让 `contracts / hooks / install / downstream skills / tests / evals` 一起迁移，避免仓库内同时存在两套矛盾契约。

## 非目标

- 不改变 `/design`、`/test-design`、`/tech-lead`、`/delivery-owner` 的内部职责，只更新它们的上游入口与 source anchor。
- 不删除历史 eval 结果目录 `tools/eval/results/**`。
- 不在本轮引入第三个新角色或新的主干 artifact 类型。

## Acceptance Checklist

- [ ] T1 建立共享模板真源与 product split 基础契约
  - AC: `shared/skills/product-shared/references/templates/brief-template.md` 与 `shared/skills/product-shared/references/templates/phase-prd-template.md` 存在，并成为 Director / Manager 唯一共享模板真源。
  - AC: `tests/test-product-role-split-contract.sh` 能对共享模板与新 skill 根目录做存在性断言，并 fresh 运行通过。
  - AC: 共享模板已经包含 `## 产品总监确认`、`## 引用锚点合同`、Director 锁定字段 / PM 可写字段所需的结构承载位。

- [ ] T2 落地 `product-director` 合同与轻量 gate
  - AC: `shared/skills/product-director/SKILL.md`、`agents/openai.yaml`、`references/conversation-guide.md`、`references/phase-splitting-guide.md`、`scripts/completion_check.sh` 存在并可表达 D-S1~D-G1、产出与 HARD-GATE。
  - AC: Director gate 只校验 Director 负责的工件、确认门与 `brief.lock.json / phase-{N}/prd.lock.json`，不要求 UNIT / AC / 审查结论 / 交付确认。
  - AC: `tests/test-product-stability-guidance-contract.sh` 与 `tests/test-product-role-split-contract.sh` 已转向 `product-director + product-shared` 路径，并 fresh 运行通过。

- [ ] T3 落地 `product-manager` 合同与 handoff / drift gate
  - AC: `shared/skills/product-manager/SKILL.md`、`agents/openai.yaml`、`references/*`、`scripts/completion_check.sh` 存在并可表达 M-S0~M-S9、legacy re-signoff、lock drift 阻断和字段级写入边界。
  - AC: `shared/skills/product-manager/references/prd-reviewer-prompt.md` 已把 R1 收口为“UNIT 与根问题一致性 + Director 锁定内容漂移检查”。
  - AC: Manager gate 会在 Director lock 缺失、lock drift、`scope_item_id` 未细化、审查 FAIL 未关闭时拒绝通过。
  - AC: `tests/test-skill-output-and-gate-contract.sh` 与 `tests/test-product-role-split-contract.sh` 已覆盖 Manager 路径、hook fixture 和 gate 失败模式，并 fresh 运行通过。

- [ ] T4 更新 contracts、runtime hooks、兼容入口与下游 skill 入口
  - AC: `contracts/skill-chain.yaml` 已从单个 `product` 改为 `product-director → product-manager → ...`。
  - AC: `shared/hooks/registry.json` 过渡期保留 `product-director`、`product-manager` 与兼容入口 `product` 三个条目，其中 `product` 明确为 `supported: false`。
  - AC: `shared/hooks/managed/codex_user_prompt_submit.py`、`shared/hooks/managed/codex_stop_dispatch.py`、`install.sh` 实现 unsupported skill no-op、旧 `product` active-state 阻断升级与兼容入口迁移。
  - AC: `shared/skills/product/SKILL.md` 只保留重定向说明；`shared/skills/design/SKILL.md`、`shared/skills/test-design/SKILL.md`、`shared/skills/tech-lead/SKILL.md`、`shared/skills/delivery-owner/SKILL.md`、`shared/skills/fix/SKILL.md`、`shared/skills/design/references/decision-templates.md` 已改为新链路和新 source anchor。

- [ ] T5 更新验证资产、eval/probe 与目标证明命令
  - AC: `tests/test-codex-skill-adapter.sh`、`tests/test-runtime-integrity.sh`、`tests/test-install-smoke.sh`、`tests/test-install-systematic.sh`、`tests/test-delivery-owner-source-anchor-contract.sh`、`tests/test-team-native-contract.sh`、`tests/test-subagent-context-contract.sh`、`tests/test-product-eval-contract.sh` 已覆盖双 skill + compat 入口行为。
  - AC: `tools/dev/probe-codex-capabilities.sh`、`tools/eval/run_skill_eval.sh`、新的 Director / Manager eval scenarios / graders / evidence plan 已完成迁移，不再把旧 `/product` 当作活跃执行入口。
  - AC: 以下 fresh proving commands 全部通过：`bash tests/test-product-role-split-contract.sh`、`bash tests/test-product-stability-guidance-contract.sh`、`bash tests/test-skill-output-and-gate-contract.sh`、`bash tests/test-codex-skill-adapter.sh`、`bash tests/test-runtime-integrity.sh`、`bash tests/test-install-smoke.sh`、`bash tests/test-install-systematic.sh`、`bash tests/test-delivery-owner-source-anchor-contract.sh`、`bash tests/test-team-native-contract.sh`、`bash tests/test-subagent-context-contract.sh`、`bash tests/test-product-eval-contract.sh`。

## Definition of Done

All tasks checked = ready for `using-git-worktrees` / `subagent-driven-development`.
