# research artifact triage audit raw output

## Scope

- Case: `research-artifact-triage-audit`
- Run id: `2026-06-04-sqa-fresh-baseline-001`
- Run mode: `with_skill`
- Source boundary: repository custom team-use readiness
- Target skill: `shared/skills/research`
- Audit skill used: `shared/skills/skill-quality-audit/SKILL.md`
- Output directory: `shared/skills/skill-quality-audit/evals/dogfood/empirical-baseline/research-artifact-triage-audit/with_skill/`
- Write boundary respected: only files in the output directory were created or edited.

## Success Criteria

- Produce `raw-output.md`, `skill-audit-report.json`, `audit-summary.md`, and `summary.json`.
- Formal report validates with `python3 shared/skills/skill-quality-audit/scripts/validate_skill_audit_report.py <report>`.
- Empirical summary records all five readiness checks: Scenario Capability, Structure-Content Coherence, Evidence Integrity, Repairable Handoff, Attention Economy.
- Do not modify `shared/skills/research` or `shared/skills/skill-quality-audit` source, references, scripts, tests, or gate plan.

## Loaded Instructions And References

- Repository instructions: `AGENTS.md`.
- Global rules loaded: `/Users/lijieli/.codex/rules/default.rules`, `/Users/lijieli/.codex/rules/代码规范.md`, `/Users/lijieli/.codex/rules/执行纪律.md`, `/Users/lijieli/.codex/rules/文档管理.md`, `/Users/lijieli/.codex/rules/铁律.md`.
- Collaboration decision reference loaded: `/Users/lijieli/.codex/reference/协作判断.md`.
- Verification references loaded: `/Users/lijieli/.codex/reference/测试规范.md`, `/Users/lijieli/.codex/reference/完成前验证.md`, `/Users/lijieli/.codex/reference/影响范围分析.md`.
- Note: `/Users/lijieli/.codex/reference/代码质量.md` is absent; this run did not perform a code-quality-check scene.
- Audit references loaded: `audit-dimensions.md`, `team-use-readiness.md`, `instruction-contract.md`, `benchmark-mechanism-alignment.md`, `noise-taxonomy.md`, `runtime-integration.md`, `claim-review-gate.md`.

## Collaboration Decision

- Decision: single-agent direct audit.
- Reason: one target skill, narrow write boundary, no independent implementation subtask. P0/P1 claim review was performed directly with claim decomposition, refutation check, and severity calibration.

## Target Surfaces Checked

- `shared/skills/research/SKILL.md`
- `shared/skills/research/agents/openai.yaml`
- `shared/skills/research/references/analysis-frameworks.md`
- `shared/skills/research/references/evidence-package-guide.md`
- `shared/skills/research/references/report-presentation-framework.md`
- `shared/skills/research/projections/research-report-template.md`
- `shared/skills/research/scripts/completion_check.sh`
- `shared/skills/research/scripts/validate_retain_evidence.py`
- `shared/skills/research/test-prompts.json`
- `shared/skills/research/evals/evals.json`
- `shared/skills/research/evals/lifecycle-review.json`
- `shared/skills/research/evals/retain-gate-2026-05-12/research-retain-evidence.json`
- `shared/skills/research/evals/skill-creator-deep-audit-2026-05-12/research-skill-creator-deep-audit.json`
- `shared/skills/research/evals/brainstorming-parity-2026-05-25/reference-chain-evidence.json`
- Runtime and consumers: `contracts/skill-runtime-surface.json`, `shared/hooks/registry.json`, `install.sh`, `tests/gate-plan.json`, `tests/run-all.sh`, `tests/run-focused.sh`, `tests/test-research-skill-contract.sh`, `tests/test-research-skill-quality-audit-eval.sh`, `tests/test-research-skill-retain-gate.sh`, `tests/test-skill-runtime-surface-contract.sh`.

## Key Evidence

- Real use capability is explicit:
  - `shared/skills/research/SKILL.md:14` defines the source-targeting and calibrated team judgment mission.
  - `shared/skills/research/SKILL.md:33` says the skill applies before a team may believe, adopt, reject, compare, learn, reuse, or write an external object into a plan.
  - `shared/skills/research/SKILL.md:127` defines the default Decision Package output.
- Strong workflow and evidence order:
  - `shared/skills/research/SKILL.md:59-67` orders route, target object, source targeting, evidence qualification, judgment calibration, decision package, formal report, self-review, confirmation/handoff.
  - `shared/skills/research/SKILL.md:101-123` requires Source Targeting before judgment and separates strong/medium/weak evidence.
  - `shared/skills/research/projections/research-report-template.md:20-48` encodes Source Targeting, Evidence Qualification, Judgment Calibration, and Decision Package fields.
- Adjacent routing is explicit:
  - `shared/skills/research/SKILL.md:50-52` excludes latest-status-only, broad deep research/PDF, and GitHub repo adoption states.
  - `shared/skills/research/SKILL.md:79-83` routes GitHub repo radar and deep-research requests away from research.
- Formal completion requirement:
  - `shared/skills/research/SKILL.md:24` requires `docs/{feature}/research-report.md`, Report Self-Review, and user confirmation before formal completion.
  - `shared/skills/research/SKILL.md:86` repeats that formal report closure requires report, self-review, and user confirmation.
  - `shared/skills/research/SKILL.md:162` requires updating the report and rerunning self-review on requested changes.
  - `shared/skills/research/projections/research-report-template.md:198-212` includes Report Self-Review and User Confirmation Gate sections.
- Gate under-validation evidence:
  - `shared/skills/research/scripts/completion_check.sh:92-127` checks shared appendix and profile section order but does not check `Report Self-Review` or `User Confirmation Gate`.
  - `tests/test-research-skill-contract.sh:179-208` defines a "valid decision report" fixture without Report Self-Review or User Confirmation Gate.
  - `tests/test-research-skill-contract.sh:210-211` asserts that fixture passes.
- Runtime registration evidence:
  - `shared/skills/research/scripts/completion_check.sh:3` says the trigger is `research skill-local Stop`.
  - `shared/hooks/registry.json:3` defines `skill_completion_gates`.
  - `shared/hooks/registry.json:289` closes the last listed gate (`refactor`); no `research` gate exists in the registry.
  - Independent check output: `registry_has_research_gate= False`.
- Adapter/routing drift evidence:
  - `shared/skills/research/agents/openai.yaml:7` sets `allow_implicit_invocation: true`.
  - `contracts/skill-runtime-surface.json:308-312` sets `research` to manual because research workflows are broad and potentially high-cost.
  - `install.sh:2191-2193` requires manual skills to disable model and implicit invocation.
  - `tools/skills/apply_skill_runtime_surface.py:169-203` can self-heal runtime copies, so the source adapter drift is bounded but still active source inconsistency.

## Executed Verification

- `bash tests/run-focused.sh research`
  - Status: PASS.
  - Observed output: 13/13 focused research gates passed, including `research-skill-contract`, `research-skill-quality-audit-eval`, `research-skill-retain-gate`, `deep-research-skill-contract`, and eval contract checks.
- Independent registry/fixture/source drift probe:
  - Status: PASS.
  - Output:
    - `registry_has_research_gate= False`
    - `registry_gate_count= 14`
    - `source_adapter_allow_implicit_true= True`
    - `runtime_surface_mode= manual`
    - `valid_fixture_has_report_self_review= False`
    - `valid_fixture_has_user_confirmation_gate= False`

## Findings Kept

1. P1: Formal report completion gate is not registered in the runtime hook registry.
   - Why kept: the skill and script say formal research completion is gated, but the active hook registry has no research entry. Current focused tests still pass, so this defect is not caught by existing gates.
2. P1: `completion_check.sh` and its contract fixture accept formal reports missing Report Self-Review and User Confirmation Gate.
   - Why kept: the target skill's hard gate requires those completion conditions, the template contains them, but the deterministic script and "valid" fixture do not enforce them.
3. P2: Source OpenAI adapter allows implicit invocation while the runtime surface contract says research is manual.
   - Why kept: source package policy contradicts the active runtime contract. Severity is P2 because install-time runtime-surface application can self-heal installed copies, but source drift remains a repairable routing risk.

## Verdict

- Verdict: `conditional`.
- Reason: no P0 was kept, but two P1 findings remain in deterministic/runtime completion gates. The skill has strong scenario capability and useful structure, but team use should remain conditional until formal completion gates are registered and aligned with the hard gate.

## Readiness Checks For This Empirical Run

- Scenario Capability: PASS. The report identifies the real research scenario, consumer, output, and team decision value.
- Structure-Content Coherence: PASS. The report distinguishes high-value workflow structure from defective runtime/validation structures.
- Evidence Integrity: PASS. P1 findings include current `path:line` evidence, claim review, refutation checks, and severity calibration.
- Repairable Handoff: PASS. Findings name concrete file targets and verification hints for a separate repair window.
- Attention Economy: PASS. The report avoids replaying full transcripts and keeps raw output focused on evidence, judgments, and verification.

## Residual Risks

- No target skill files were modified; repair must happen in a separate window.
- Focused research gates pass despite the kept findings; that is evidence of test blind spots, not evidence the findings are false.
