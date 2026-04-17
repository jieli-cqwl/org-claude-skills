# Fix-5

## 目的
记录 runtime control-plane 收口阶段暴露的剩余 canonical contract 漏洞，以及本轮围绕 `stop dispatcher / replan switch / readiness active evidence / signoff closure / review+verify runtime contracts` 的修复与验证证据。

## 历史诊断快照
本轮系统性 review 后，剩余风险集中在两条链：
- runtime fail-open：
  - `codex_stop_dispatch.py` 在 `session_id` 缺失、active-skill 状态损坏、gate 脚本缺失时仍可能返回 `{}`，没有 fail-closed。
  - `update_delivery_state.py --apply-replan-switch` 接受非法或跨 feature 的 `plan_ref / tasks_ref`。
- canonical contract 仍然偏薄：
  - readiness 只校验 task runtime 文件存在，没有要求 task-level active registry entry 精确覆盖。
  - `signoff-package.json` 没有承接 runtime summary 与 goal-closure 锚点。
  - `phase3-dispatch.md` 仍残留 review/qa legacy 口径。
  - `code-review-result.json / verify-result.json / developer-report.json` 只承接最小骨架，没有把 review 十维语义、verify 阶段 verdict、TDD 证据锚点下沉成工程合同。

## 本轮修复
- runtime fail-closed：
  - `shared/hooks/managed/codex_stop_dispatch.py`
  - `tests/test-codex-skill-adapter.sh`
- replan baseline 约束：
  - `tools/community/update_delivery_state.py`
  - `tests/test-standard-chain-runtime-state.sh`
- readiness task active evidence：
  - `tools/community/validate_standard_chain_readiness.py`
  - `tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/artifact-registry.json`
  - `tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/replay/phase-operational.replay-oracle.json`
- signoff canonical closure：
  - `contracts/canonical/schemas/runtime/signoff-package.schema.json`
  - `contracts/canonical/templates/runtime/signoff-package.template.json`
  - `tests/fixtures/standard-chain-foundation/golden-pilot/sample-feature/phase-1/signoff-package.json`
  - `tools/community/replay_canonical_phase.py`
- delivery-owner phase3 canonical drift：
  - `shared/skills/delivery-owner/SKILL.md`
  - `shared/skills/delivery-owner/references/phase3-dispatch.md`
  - `tests/test-delivery-owner-phase3-contract.sh`
- review / verify / developer-report runtime contract 下沉：
  - `contracts/canonical/schemas/runtime/code-review-result.schema.json`
  - `contracts/canonical/templates/runtime/code-review-result.template.json`
  - `shared/skills/review/SKILL.md`
  - `shared/skills/review/scripts/completion_check.sh`
  - `contracts/canonical/schemas/runtime/verify-result.schema.json`
  - `contracts/canonical/templates/runtime/verify-result.template.json`
  - `contracts/canonical/schemas/runtime/developer-report.schema.json`
  - `contracts/canonical/templates/runtime/developer-report.template.json`
  - `shared/skills/verify/SKILL.md`
  - `shared/skills/verify/scripts/completion_check.sh`
  - `tests/test-standard-chain-foundation-registry.sh`
  - `tests/test-skill-output-and-gate-contract.sh`
  - `tests/test-codex-skill-adapter.sh`
  - golden pilot task/runtime fixtures

## Fresh Evidence
- `bash tests/test-standard-chain-foundation-registry.sh`
- `bash tests/test-codex-skill-adapter.sh`
- `bash tests/test-standard-chain-validator-stack.sh`
- `bash tests/test-standard-chain-projection-replay.sh`
- `bash tests/test-standard-chain-readiness-gate.sh`
- `bash tests/test-standard-chain-runtime-state.sh`
- `bash tests/test-delivery-owner-phase3-contract.sh`
- `bash tests/test-skill-output-and-gate-contract.sh`
- `bash tests/test-standard-chain-cutover.sh`
- `bash tests/test-runtime-integrity.sh`
- `bash tests/test-chain-completeness.sh`
- `python3 tools/community/check_task_plan_consistency.py docs/standard-chain-contract-foundation/2026-04-14-contract-foundation/tasks.md docs/standard-chain-contract-foundation/2026-04-14-contract-foundation/plan.md`
- `python3 -m py_compile tools/community/validate_standard_chain_readiness.py tools/community/update_delivery_state.py tools/community/replay_canonical_phase.py shared/hooks/managed/codex_stop_dispatch.py`
- `git diff --check`

## 当前状态
- 当前分支：`codex/standard-chain-contract-foundation`
- 当前基线：`95a61b0` + working tree 修复中
- review 闭环状态：`PASS`
- 本轮新增 `P0/P1`：`0`
- 本轮 fix 已具备继续进入系统复审 / 分支收口的 fresh 证据。
