# Fix-4

## 目的
记录 merge-main 后系统性 review 暴露的 canonical gate、schema/readiness、runtime integration 漏洞，以及本轮修复后的收口证据。

## 历史诊断快照
首轮 review 暴露了两类阻断：
- canonical gate 与 runtime dispatcher 仍有 fail-open / false-stop：
  - design/review 在 canonical-only 模式下零产出仍可收口
  - `browser_required` 只做字段存在校验
  - verify happy-path 会被错误 stop
- schema/readiness 只补到了“字段存在”，没有补到“语义闭环”：
  - `delivery_plan` 可空
  - `qa_handoff_contract` 可空
  - `ruled_out_issues` 可空
  - FAIL `issue_ledger` triage 不完整仍可 closeout

## 本轮修复
- 收紧 canonical Stop gate：
  - `shared/skills/product/scripts/completion_check.sh`
  - `shared/skills/design/scripts/completion_check.sh`
  - `shared/skills/test-design/scripts/completion_check.sh`
  - `shared/skills/review/scripts/completion_check.sh`
  - `shared/skills/qa/scripts/completion_check.sh`
  - `shared/skills/delivery-owner/scripts/completion_check.sh`
- 收紧浏览器语义与 FAIL triage：
  - `tools/community/validate_standard_chain_readiness.py`
  - `shared/skills/qa/scripts/completion_check.sh`
- 修正 verify runtime happy-path：
  - `shared/hooks/managed/codex_stop_dispatch.py`
  - `tests/test-codex-skill-adapter.sh`
- 收紧 schema 与 canonical 输出契约：
  - `contracts/canonical/schemas/planning/brief.schema.json`
  - `contracts/canonical/schemas/planning/test-cases.schema.json`
  - `contracts/canonical/schemas/runtime/qa-result.schema.json`
  - `shared/skills/qa/SKILL.md`

## Fresh Evidence
- `bash tests/test-standard-chain-foundation-registry.sh`
- `bash tests/test-standard-chain-readiness-gate.sh`
- `bash tests/test-standard-chain-cutover.sh`
- `bash tests/test-standard-chain-validator-stack.sh`
- `bash tests/test-skill-output-and-gate-contract.sh`
- `bash tests/test-codex-skill-adapter.sh`
- `bash tests/test-runtime-integrity.sh`
- `bash tests/test-delivery-owner-phase3-contract.sh`
- `python3 tools/community/check_task_plan_consistency.py docs/standard-chain-contract-foundation/2026-04-14-contract-foundation/tasks.md docs/standard-chain-contract-foundation/2026-04-14-contract-foundation/plan.md`
- `python3 -m py_compile tools/community/validate_standard_chain_readiness.py shared/hooks/managed/codex_stop_dispatch.py`
- `git diff --check`

## 当前状态
- review 闭环状态：`PASS`
- 本轮新增 `P0/P1`：`0`
- 可继续进入后续分支集成决策
