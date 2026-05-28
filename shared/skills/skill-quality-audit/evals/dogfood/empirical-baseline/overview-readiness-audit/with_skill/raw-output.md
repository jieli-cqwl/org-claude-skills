# Raw Output

## Scope

- Case: `overview-readiness-audit`
- Run mode: `with_skill`
- Target skill: `shared/skills/overview`
- Audit skill loaded: `shared/skills/skill-quality-audit/SKILL.md`
- Required references loaded: `audit-dimensions.md`, `team-use-readiness.md`, `instruction-contract.md`, `benchmark-mechanism-alignment.md`, `noise-taxonomy.md`, `runtime-integration.md`, `claim-review-gate.md`
- Global rules/reference loaded before execution: `$HOME/.codex/rules/*`, `$HOME/.codex/reference/协作判断.md`, `$HOME/.codex/reference/测试规范.md`, `$HOME/.codex/reference/完成前验证.md`, `$HOME/.codex/reference/设计原则.md`, `$HOME/.codex/reference/影响范围分析.md`
- Write boundary observed: only files under `shared/skills/skill-quality-audit/evals/dogfood/empirical-baseline/overview-readiness-audit/with_skill/`

## Target Surfaces

- `shared/skills/overview/SKILL.md`: checked. Goal and completion boundary at line 13; hard gates at lines 17-21; workflow at lines 47-69; output/checklist at lines 87-107.
- `shared/skills/overview/agents/openai.yaml`: checked. Adapter declares `allow_implicit_invocation: true` at line 7.
- `shared/skills/overview/references/mode-selection.md`: checked. Mode options and stop conditions at lines 5-7 and 25-28.
- `shared/skills/overview/references/agent-assignments.md`: checked. Agent contracts and failure handling at lines 5-8, 23-29, 31-38.
- `shared/skills/overview/scripts/project-detect.sh`: checked. Detects language/framework and emits JSON.
- `shared/skills/overview/scripts/dir-tree.sh`: checked. Fallback uses `eval find` at line 26.
- `shared/skills/overview/projections/project-overview-template.md`: checked. Active report template.
- `shared/skills/overview/test-prompts.json`: checked. Prompt expectations are natural language at lines 5, 10, 15.
- Target package absent surfaces: no `shared/skills/overview/contracts/`, `evals/`, `fixtures/`, or `README.md`.
- Runtime surface: `contracts/skill-runtime-surface.json:231-235` registers `overview` as first-party manual.
- Install path: `install.sh:1090-1098` applies runtime surface tool; `install.sh:1168` applies it to Codex staging; `tools/skills/apply_skill_runtime_surface.py:262-263` applies Codex policy.
- Gate/test consumers: `tests/test-platform-runtime-noise.sh:266-270` checks installed overview script path rendering; no overview behavior eval gate found in current scan.
- Downstream routing: `shared/skills/github-repo-radar/SKILL.md:32` routes some project health requests to `scan` / `overview`.

## Existing Artifact Triage

- Command: `python3 shared/skills/skill-quality-audit/scripts/classify_audit_artifact.py overview审查.md`
- Output: `artifact_type=transcript`
- Decision: treat `overview审查.md` only as a lead, not as a formal report.

## Key Findings

### OVERVIEW-P1-001

- Severity: P1
- Claim: `dir-tree.sh` fallback builds a shell command with `eval` from overview inputs.
- Evidence:
  - `shared/skills/overview/SKILL.md:51` requires `dir-tree.sh <项目路径> 3` after project path confirmation.
  - `shared/skills/overview/scripts/dir-tree.sh:9` assigns `PROJECT_DIR="${1:-.}"`.
  - `shared/skills/overview/scripts/dir-tree.sh:10` assigns `DEPTH="${2:-3}"`.
  - `shared/skills/overview/scripts/dir-tree.sh:26` executes `eval find "$PROJECT_DIR" -maxdepth "$DEPTH" -type d $EXCLUDES ...`.
  - `shared/skills/overview/scripts/dir-tree.sh:11` only checks that the path is a directory.
  - Current environment check: `tree=absent`, so the fallback branch is relevant in this environment.
- Claim review: supported. Required premises are current-file backed; no direct refutation found beyond the tree-present branch.
- Severity calibration: P1, not P0. The branch is conditional, but when used it affects runtime command safety for a required scan helper.
- Repair target: `shared/skills/overview/scripts/dir-tree.sh`.
- Verification hint: remove `eval`, validate numeric depth, preserve ignore semantics, test paths with spaces and shell metacharacters.

### OVERVIEW-P2-001

- Severity: P2
- Claim: overview behavior is represented by prompt fixtures, not executable readiness gates.
- Evidence:
  - `shared/skills/overview/test-prompts.json:5`, `:10`, `:15` store natural-language expectations.
  - No target `evals/` or `fixtures/` directory exists.
  - `tests/test-platform-runtime-noise.sh:266-270` checks path rendering, not overview behavior.
- Impact: no deterministic proof for scan-before-write, mode confirmation, blocked states, Mermaid check, or final user confirmation.
- Repair target: `shared/skills/overview/evals` or a focused gate in `tests/gate-plan.json`.

### OVERVIEW-P2-002

- Severity: P2
- Claim: source OpenAI adapter contradicts manual runtime contract before install self-heal.
- Evidence:
  - `shared/skills/overview/agents/openai.yaml:7` sets `allow_implicit_invocation: true`.
  - `contracts/skill-runtime-surface.json:232` sets `overview` mode to `manual`.
  - `tools/skills/apply_skill_runtime_surface.py:262-263` self-heals Codex installed policy from the runtime surface.
- Impact: source package and runtime contract disagree; installed output is protected, but source review and pre-install consumption are noisy.
- Repair target: `shared/skills/overview/agents/openai.yaml` or generated-source policy contract.

### OVERVIEW-P3-001

- Severity: P3
- Claim: maintainer sync clauses are mixed into runtime user workflow.
- Evidence:
  - `shared/skills/overview/SKILL.md:53` includes `Sync: 更新模式选择模板和治理测试`.
  - `shared/skills/overview/SKILL.md:55` includes `Sync: 更新 agent 合同和 overview template`.
- Impact: minor attention-economy drag; agents may confuse maintainer synchronization with user-request execution.
- Repair target: move sync clauses to maintenance docs/tests or convert to non-runtime comments.

## Readiness Checks For This Run

- Scenario Capability: PASS. Report names the scenario, consumer, output decision, completion boundary, and why the team would use the audit.
- Structure-Content Coherence: PASS. Report checks how scan, mode selection, agent assignment, document generation, and confirmation feed later steps.
- Evidence Integrity: PASS. Findings distinguish observed file facts, inferred risk, classifier output, and validator output; P1 includes evidence checks, claim review, and severity calibration.
- Repairable Handoff: PASS. Findings include impact, repair target, and verification hint; handoff groups file targets.
- Attention Economy: PASS. Audit flags runtime maintenance noise and separates deterministic validators/scripts from prose.

## Validator

- Command: `python3 shared/skills/skill-quality-audit/scripts/validate_skill_audit_report.py shared/skills/skill-quality-audit/evals/dogfood/empirical-baseline/overview-readiness-audit/with_skill/skill-audit-report.json`
- Initial output: `[FAIL] summary_markdown for P1 finding OVERVIEW-P1-001 must include impact`
- Repair made: updated `audit-summary.md` to include the exact P1 `impact` and `verification_hint` strings from `skill-audit-report.json`.
- Final output: `[PASS] skill audit report valid`
