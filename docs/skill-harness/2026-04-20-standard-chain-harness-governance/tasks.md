# Tasks - skill-harness standard-chain governance
Created: 2026-04-20
Related plan: ./plan.md

## Acceptance Checklist

- [ ] T1 Freeze final audit enums and LLM-facing contract
  - AC: `shared/skills/skill-harness/SKILL.md` and `shared/skills/skill-harness/references/audit-method.md` expose final `overall_verdict`, `dimension`, `dimension_result`, `finding_severity`, `dry_run_verdict`, `legacy_baseline_label`, and `audit_proof_type` contracts; standalone `proof_type` detection does not match `audit_proof_type`; `bash tests/test-skill-harness-responsibility-contract.sh` exits 0.
  - Traces: LLM 职责清楚, 主内容可执行, legacy label 迁移
  - Depends: -
  - Complexity: moderate
- [ ] T2 Implement deterministic checker support for new audit fields
  - AC: `shared/skills/skill-harness/scripts/check_skill_harness_contract.py` rejects illegal dimensions, illegal verdict fields, standalone `proof_type`, missing `audit_proof_type`, and active legacy labels; every existing positive and negative baseline fixture under `tests/fixtures/skill-harness/cases/` uses final dimensions and `audit_proof_type` so intended negative failure codes remain stable; `bash tests/test-skill-harness-main-content-noise.sh`, `bash tests/test-skill-harness-runtime-noise.sh`, and `bash tests/test-skill-harness-legacy-label-migration.sh` exit 0.
  - Traces: 噪音可识别, 当前轻量边界保留, legacy label 迁移
  - Depends: T1
  - Complexity: complex
- [ ] T3 Add field-consumer, engineering-control, and old-asset directory capability gates
  - AC: runtime fields that enter machine facts have declared consumers, validation commands, drop conditions, and failure states; consumer references point to real repo paths or allowed runtime consumer types; validation commands resolve to repo-local scripts and execute in a controlled smoke run; retained `skill-audit` assets have existing source paths plus exactly one immediate target, triggered target, or archive boundary; invalid consumer, invalid command, missing drop condition, fake target, duplicate source, and immediate-plus-triggered fixtures fail; `bash tests/test-skill-harness-field-consumers.sh`, `bash tests/test-skill-harness-engineering-control.sh`, and `bash tests/test-skill-harness-directory-capability.sh` exit 0.
  - Traces: 复杂度有消费者, 旧资产被归位, 工程控制接住状态
  - Depends: T1, T2
  - Complexity: complex
- [ ] T4 Add standard-chain gate integration fixtures
  - AC: fixtures cover the complete standard-chain role catalog, `machine_gate`, `human_review_gate`, `user_decision_gate`, `file_evidence`, `fixture_proof`, and `fresh_proving`; standard-chain runtime fields are added to `field-consumers.json`; user decision validation reads `contracts/canonical/authority-registry.yaml:v1_user_decision_policy.allowed_final_sources` and `decision_source_rules.required_proof_type / allowed_channels`; proof, channel, digest, actor, and baseline drift negative cases fail; `bash tests/test-skill-harness-standard-chain-integration.sh` and `bash tests/test-skill-harness-field-consumers.sh` exit 0.
  - Traces: 标准链路可审计, 工程控制接住状态, 当前轻量边界保留
  - Depends: T2, T3
  - Complexity: complex
- [ ] T5 Add delivery-owner dry-run calibration proof
  - AC: `docs/skill-harness/2026-04-20-standard-chain-harness-governance/delivery-owner-dry-run-report.json` is the machine-consumed dry-run proof, `delivery-owner-dry-run-report.md` is the human projection, the report records at least 3 non-duplicate high-value findings against real `shared/skills/delivery-owner/SKILL.md` semantic lines, covers at least 2 governance dimensions, includes at least one Engineering Control or Chain Integration finding, dry-run fields are added to `field-consumers.json`, and STOP negative fixtures fail; `bash tests/test-skill-harness-dry-run.sh` and `bash tests/test-skill-harness-field-consumers.sh` exit 0.
  - Traces: delivery-owner 校准可证明, 标准链路可审计, 噪音可识别
  - Depends: T1, T2, T4
  - Complexity: complex
- [ ] T6 Preserve lightweight default path
  - AC: default audit stays read-first structured Markdown with a minimal default field set; JSON/schema/renderer/hook stay consumer-triggered; the default manifest does not include renderer or hook commands; `bash tests/test-skill-harness-lightweight-path.sh` exits 0.
  - Traces: 当前轻量边界保留, 主内容可执行
  - Depends: T1, T2, T3, T4, T5
  - Complexity: moderate
- [ ] T7 Verify and package the small-chain result
  - AC: primary implementation proof commands for T1-T6 exit 0; baseline smoke and hygiene commands exit 0 as secondary checks; `python3 tools/community/check_task_plan_consistency.py docs/skill-harness/2026-04-20-standard-chain-harness-governance/tasks.md docs/skill-harness/2026-04-20-standard-chain-harness-governance/plan.md` exits 0; final report records residual risk and dirty-worktree assumptions.
  - Traces: all success criteria
  - Depends: T1, T2, T3, T4, T5, T6
  - Complexity: moderate

## Definition of Done

All tasks checked = ready for verify-change.
