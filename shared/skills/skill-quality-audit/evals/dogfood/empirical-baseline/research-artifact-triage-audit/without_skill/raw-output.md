# without_skill audit: shared/skills/research

## Conclusion

Target `shared/skills/research` is broadly usable as a generic research skill, with strong scenario coverage, explicit routing boundaries, and good progressive disclosure. It is not fully clean for formal report readiness: the formal report template and `completion_check.sh` disagree on heading shape and names, so a report produced by the bundled template is likely to fail the bundled structural gate unless the model rewrites headings away from the template.

Overall readiness: 3/5 PASS. The handoff is repairable because the main defect has a small, concrete repair surface.

## Scope And Method

- Mode: without_skill baseline.
- Run id: `2026-06-04-sqa-fresh-baseline-001`.
- Source boundary: repository custom team-use readiness.
- Target: `shared/skills/research`.
- Excluded by instruction: any dedicated `shared/skills/skill-quality-audit` audit method, validator, references, contracts, scripts, evals, or tests.
- Review basis: generic skill authoring judgment, local repo constraints, and target skill artifacts only.
- Files read from target: `SKILL.md`, `references/*.md`, `projections/research-report-template.md`, `scripts/completion_check.sh`, `test-prompts.json`, and target-local eval evidence JSON.
- Files written: this empirical artifact directory only.

## Readiness Checks

| Check | Status | Rationale |
| --- | --- | --- |
| Scenario Capability | PASS | The skill covers adoption judgment, candidate selection, claim review, community object identification, judgment review, external solution scouting, lightweight triage, formal reports, and adjacent routing. Evidence: `shared/skills/research/SKILL.md:31-53`, `shared/skills/research/SKILL.md:69-85`, `shared/skills/research/evals/evals.json:50-160`. |
| Structure-Content Coherence | PARTIAL | Main flow is coherent, but formal report template and completion hook disagree. Template uses `### decision` plus list items such as `- 最大风险` and `- 下一步`; hook searches exact `##` headings such as `最大风险与保留意见` and `建议动作`. Evidence: `shared/skills/research/projections/research-report-template.md:57-69`, `shared/skills/research/projections/research-report-template.md:173-191`, `shared/skills/research/scripts/completion_check.sh:52-57`, `shared/skills/research/scripts/completion_check.sh:92-126`. |
| Evidence Integrity | PARTIAL | The skill itself demands source targeting, evidence tiering, strongest opposition, failure boundaries, and flip conditions. That is strong. But target-local lifecycle evidence is explicitly bounded to static contracts / recorded evals, not blind fresh runs, and the formal completion claim depends on the mismatched hook/template pair. Evidence: `shared/skills/research/SKILL.md:101-129`, `shared/skills/research/SKILL.md:131-138`, `shared/skills/research/evals/lifecycle-review.json:22-69`, `shared/skills/research/evals/retain-gate-2026-05-12/research-retain-evidence.json:4-23`, `shared/skills/research/evals/skill-creator-deep-audit-2026-05-12/research-skill-creator-deep-audit.json:132-150`. |
| Repairable Handoff | PASS | The defect is narrow: align the report template headings with the hook, or relax the hook to accept the template structure; then add a fixture proving a generated formal report can pass. No broad redesign is needed. |
| Attention Economy | PASS | `SKILL.md` is 191 lines and keeps detailed frameworks in references/templates/scripts. It also has a lightweight triage path that avoids forcing full reports for every research-like request. Evidence: `shared/skills/research/SKILL.md:69-77`, `shared/skills/research/SKILL.md:140-142`, `shared/skills/research/references/analysis-frameworks.md:1-20`. |

## Findings

### F1: Template and hook mismatch can break formal report completion

Severity: high for formal-report scenarios.

Evidence:

- Template instructs using a profile block under `### decision`, `### understanding`, or `### audit`, with required fields written as list items, not second-level headings. See `shared/skills/research/projections/research-report-template.md:57-111`.
- Shared audit appendix sections are also `### 独立挑战记录`, `### 检索路径与覆盖证明`, and `### 项目上下文`. See `shared/skills/research/projections/research-report-template.md:173-191`.
- `completion_check.sh` only finds sections matching `^## ${section}$`. See `shared/skills/research/scripts/completion_check.sh:52-57`.
- The hook requires `## 独立挑战记录`, `## 检索路径与覆盖证明`, and `## 项目上下文`; for `decision` it requires `## 这次要回答的问题`, `## 当前判断`, `## 决定性理由`, `## 最大风险与保留意见`, `## 建议动作`. See `shared/skills/research/scripts/completion_check.sh:92-126`.

Impact:

- A model following the bundled template literally may produce a report that violates the bundled completion hook.
- This weakens `formal-report-completion-gate` despite the skill's strong written contract.

Repair:

- Choose one canonical structure. Prefer updating `research-report-template.md` to emit exact `##` headings expected by `completion_check.sh`, because the hook is deterministic and already encodes the gate.
- Alternatively, change `completion_check.sh` to accept the current `###`/list-item template shape, but then add fixtures for each profile.
- Add one regression fixture per profile (`decision`, `understanding`, `audit`) or at least one formal report fixture generated from the template.

### F2: Evidence claims are honest but bounded

Severity: medium.

Evidence:

- Retain evidence says the scope is `static_contract_and_recorded_eval_gate` and not an external blind LLM run. See `shared/skills/research/evals/retain-gate-2026-05-12/research-retain-evidence.json:4-7`.
- Lifecycle review says future improvement should create a fresh non-workspace benchmark or collect human-reviewed samples before claiming statistically robust retain. See `shared/skills/research/evals/lifecycle-review.json:22`.
- Deep audit records missing proof for fresh current-vs-baseline benchmark evidence, multi-run statistical confidence, and blind randomized comparison. See `shared/skills/research/evals/skill-creator-deep-audit-2026-05-12/research-skill-creator-deep-audit.json:141-150`.

Impact:

- The target can credibly claim bounded retain/readiness, not statistically robust empirical superiority.
- This is acceptable if future summaries preserve the boundary. It becomes a problem only if downstream artifacts collapse "static recorded evals" into "fresh empirical proof."

Repair:

- Keep bounded wording in lifecycle summaries.
- If stronger empirical claims are needed, run fresh with/without samples with blinded labels and multiple runs per scenario.

### F3: Trigger and routing are strong enough for real use

Severity: positive finding.

Evidence:

- Trigger description is broad but anchored to external information guiding action. See `shared/skills/research/SKILL.md:4`.
- When-to-use and when-not-to-use sections split adoption, selection, claim review, object identification, simple facts, summaries, breaking news, deep research, GitHub repo radar, and downstream execution. See `shared/skills/research/SKILL.md:31-53`.
- Quick triage prevents report overproduction. See `shared/skills/research/SKILL.md:69-77`.
- Evals cover selection, analysis, discovery audit, quick advisory, GitHub repo radar routing, deep-research routing, and formal report gate. See `shared/skills/research/evals/evals.json:50-160`.

Impact:

- The skill should trigger in the right broad class of tasks without swallowing adjacent long-form or repo-specific workflows.

## Repair Handoff

Minimum handoff:

1. Fix the formal report structure mismatch:
   - Either update `shared/skills/research/projections/research-report-template.md` to use the exact `##` headings expected by `shared/skills/research/scripts/completion_check.sh`.
   - Or update `completion_check.sh` to parse the current template's `###` headings and list-item required fields.
2. Add deterministic coverage that proves a report following the template passes the completion hook.
3. Preserve the user-confirmation gate as a human/process gate; do not pretend a shell script can prove user confirmation unless transcript evidence is explicitly parsed.
4. Preserve bounded evidence language for retain/readiness claims unless fresh empirical runs are added.

## Multi-Round Recheck

Round 1 target-boundary review:

- Goal: assess readiness of `shared/skills/research` without using dedicated quality-audit methods.
- New target-in-scope issue found: template/hook mismatch for formal report completion.
- Boundary-only notes: existing dirty worktree includes unrelated skill-quality-audit edits by others; untouched.

Round 2 target-boundary review:

- Rechecked trigger scope, routing, report gate, evidence evidence, and repair path.
- No new target-in-scope issue beyond F1/F2.

Round 3 target-boundary review:

- Rechecked five readiness decisions against evidence and PASS counting.
- No new target-in-scope issue.

Delivery criterion met: two consecutive review rounds found no new target-in-scope issue after the initial finding set.
