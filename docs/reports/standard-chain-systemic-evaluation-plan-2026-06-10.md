# Standard-chain Systemic Evaluation Plan

Date: 2026-06-10

## Conclusion

This work is not a patch plan for `product-director`. It is a systemic evaluation
track for `standard-chain/v1`.

The immediate lesson from the `product-director` pain point is that a green
contract can still protect the wrong behavior. Existing tests and evals heavily
cover artifacts, schemas, final gates, and handoff contracts. They are weaker at
multi-turn interaction behavior: user correction, fact sufficiency, candidate
versus confirmed state, and evidence invalidation after a human changes the
target.

This plan adds a new interaction-eval layer. It does not replace the harness
capability matrix, episode package work, or existing role evals. It fills the
missing surface between user conversation and canonical artifacts.

## Scope

Evaluation target:

- Main chain roles: `product-director`, `product-manager`, `design`,
  `test-design`, `tech-lead`, `developer`, `review`, `verify`, `qa`,
  `delivery-owner`.
- Behavior under multi-turn pressure: unclear facts, user correction, scope
  drift, downstream handoff ambiguity, and stale evidence after target changes.
- Existing evidence surfaces: role `evals/evals.json`, graders, contracts,
  harness capability reports, and stage fixtures.

Out of scope for this first slice:

- No runtime hook changes.
- No automatic episode-package generation.
- No wholesale import of gstack or Superpowers workflows.
- No skill edits before behavior or contract red evidence is captured.
- No claim that planned cases prove current behavior until they are executed.

## Why prior evaluation missed this class

The miss was methodological:

- Current product tests validated the existing flow instead of challenging
  whether the flow was correct.
- Existing evals were mostly single-turn or final-artifact oriented.
- Pass rate measured anchor compliance, not whether the anchor represented user
  intent.
- Gate strength protected final writes more than conversation-level conclusions.
- "One question" was not disambiguated as one question per turn, not one
  question total.

## Evaluation dimensions

| Dimension | What it protects |
| --- | --- |
| `fact_sufficiency` | A role cannot advance when the facts needed for the current stage are missing, conflicting, or rejected. |
| `user_correction` | A role must treat user correction as evidence that can supersede candidate state. |
| `candidate_vs_confirmed_state` | Candidate judgments cannot be written or spoken as confirmed baseline. |
| `stage_backtracking` | Changed upstream facts route back to the owning stage instead of being patched downstream. |
| `role_boundary` | A role does not fill facts owned by another role. |
| `scope_control` | Scope expansion, target drift, and acceptance changes require explicit opt-in or rebaseline. |
| `downstream_handoff` | Downstream roles pause instead of inferring missing upstream facts. |
| `evidence_freshness` | Proof created before a target or acceptance change cannot close the changed target. |
| `process_lightness` | Clear facts are reused; the role does not become an interview script. |
| `eval_validity` | Tests and graders must distinguish correct behavior from the known failure mode. |

## Case matrix

The executable case registry lives at
`tests/fixtures/standard-chain-harness/interaction-eval/cases.json`.

| Case | Role | Primary failure class |
| --- | --- | --- |
| `SC-INT-PD-001` | product-director | Solution-first demand advances before fact sufficiency. |
| `SC-INT-PD-002` | product-director | User rejects the first hypothesis but the role does not backtrack. |
| `SC-INT-PD-003` | product-director | Clear facts are mechanically re-asked instead of compressed into a candidate baseline. |
| `SC-INT-PD-004` | product-director | A single partial answer is treated as enough to close problem clarification. |
| `SC-INT-PM-001` | product-manager | PM mutates locked Director baseline while refining UNIT or AC. |
| `SC-INT-DES-001` | design | Design invents missing product flow or state facts. |
| `SC-INT-TD-001` | test-design | Test-design fabricates coverage from vague acceptance criteria. |
| `SC-INT-TL-001` | tech-lead | Tech-lead plans implementation after target drift instead of rebaseline. |
| `SC-INT-DO-001` | delivery-owner | Delivery-owner reuses old evidence after acceptance criteria change. |
| `SC-INT-DEV-001` | developer | Developer implements from a superseded task packet after target change. |
| `SC-INT-REV-001` | review | Review passes stale developer evidence after task drift. |
| `SC-INT-VER-001` | verify | Verify closes changed AC with old proof. |
| `SC-INT-QA-001` | qa | QA passes release against outdated acceptance. |

## Optimization standard

Every proposed optimization must pass this filter before implementation:

1. Name the failure mode it addresses.
2. Identify the owning role and stage.
3. Prove why existing rules do not already cover it.
4. Define the smallest observable signal that catches the failure.
5. Add or update an eval before changing the skill.
6. Keep canonical artifacts and role boundaries unchanged unless the evidence
   proves they are the root cause.
7. Run the affected role eval plus the interaction-eval structure gate.

## gstack and Superpowers migration rule

Migrate mechanisms, not style.

Allowed candidates:

- Fact-sufficiency loops from gstack `/spec`: ask until the blocking facts are
  closed, then proceed.
- Premise challenge from gstack `/office-hours`: challenge the current problem
  frame before proposing solutions.
- Scope opt-in from gstack `/plan-ceo-review`: every scope change is explicit.
- Superpowers one-question-per-message: one blocking question per turn, not one
  question total.
- Superpowers section approval: user confirmation closes the current section,
  and objections route upstream.

Rejected defaults:

- YC/founder voice.
- Boil-the-ocean scope expansion.
- Mandatory design-doc or issue-filing flow inside Director.
- Engineering/API/AC detail inside Director.
- Additional artifacts that compete with canonical JSON.

## Evidence Update

External audits were used as challenge inputs, not as authority:

- gstack audit source commit: `8241949357263be64013a8410171def68cff920c`.
  Useful mechanisms: user-decision gates, question ledger shape, evidence-bound
  findings, and structured specialist review merge. Rejected mechanisms:
  autoplan-style decision automation, "boil the ocean" scope expansion, and
  memory systems that would compete with canonical JSON.
- Superpowers audit source commit: `6fd4507659784c351abbd2bc264c7162cfd386dc`.
  Useful mechanisms: one blocking question per message, not one question total;
  red-green proof before skill edits; completion claims backed by fresh evidence;
  and feedback loops that route objections back instead of pushing forward.

Local evidence from the first execution slice:

- Existing `upstream-fact-replacement-backtracks` behavior eval passed with
  hidden expectations under `gpt-5.4-mini`: `5/5` expectations and `1/1`
  anchors. This means the previous eval was not sharp enough to reproduce the
  reported "one question then wrong conclusion" pain.
- New `partial-answer-stays-in-problem-clarification` eval was added to
  `shared/skills/product-director/evals/evals.json` to cover the sharper case:
  user answers only one local fact, while current handling, real cost, and
  direct cause remain unclosed.
- A structural red test was captured in
  `tests/test-product-director-cocreation-contract.sh`: the old flow lacked
  `"Explore demand context" -> "Ask one blocking fact"` and the current-stage
  closure loop. After updating `shared/skills/product-director/SKILL.md`, the
  contract passed.
- Eval-runner infrastructure red was captured in
  `tests/test-standard-chain-local-eval-runner.sh`: the runner could not pass
  `model_reasoning_effort` to nested executor and judge runs. The runner now
  accepts `--reasoning-effort` and `--judge-reasoning-effort`, translating both
  into Codex `-c model_reasoning_effort="..."`.
- A low-reasoning behavior red was then captured for
  `partial-answer-stays-in-problem-clarification`: after the flow fix, the role
  still omitted the five-dimension fact-state table under
  `--reasoning-effort low`. The top-level `Ask one blocking fact` step now
  explicitly requires the `受影响角色 / 触发场景 / 当前处理方式 / 现实代价 / 直接原因`
  fact states during problem clarification.
- Fresh post-fix behavior evidence:
  `tools/eval/results/standard-chain-systemic-baseline-2026-06-10/pd-002-partial-answer-after-fact-state-fix-reasoning-low/summary.json`
  shows `6/6` expectations and `5/5` preference anchors passing with hidden
  expectations under explicit low reasoning.
- `SC-INT-PD-001` then produced a sharper red:
  `tools/eval/results/standard-chain-systemic-baseline-2026-06-10/pd-001-low-reasoning-judge54/summary.json`
  shows the role still entered baseline-option discussion before problem facts
  were closed (`6/7` expectations, `3/4` anchors). Intermediate retries showed
  two additional loopholes: the role could hide `推荐理由 / 待验证关键事实`, or turn
  one blocking fact into a multi-option question. The final fix adds a top-level
  `问题澄清输出契约` requiring `输入线索 / 推荐根问题 / 事实状态表 / 推荐理由 /
  待验证关键事实 / 一个问题`, while forbidding baseline titles, options, scope,
  Phase, compound facts, and multi-option questions before fact closure.
- Fresh `SC-INT-PD-001` post-fix evidence:
  `tools/eval/results/standard-chain-systemic-baseline-2026-06-10/pd-001-after-clarification-template-low-reasoning/summary.json`
  shows `7/7` expectations and `4/4` preference anchors passing with hidden
  expectations under explicit low reasoning.
- The `SC-INT-PD-001` fix initially regressed `SC-INT-PD-003` by applying the
  problem-clarification template to already-closed facts. A `闭合事实快路径`
  was added so clear root problem, goal, first-slice scope, and non-goals are
  accepted as confirmed Director facts instead of being downgraded to input
  clues. The `clear-goal-default-judgment` eval was sharpened to reject that
  downgrade.
- The same regression loop exposed another gap in `SC-INT-PD-002`: when a user
  replaces an upstream fact, the role must not merely return to problem
  clarification; it must also mark target, success-standard, business-semantics,
  scope, risk, and Phase conclusions as invalidated or pending re-review. The
  top-level `上游事实替换回退` rule now makes that invalidation explicit.
- Final product-director interaction regression evidence:
  `tools/eval/results/standard-chain-systemic-baseline-2026-06-10/pd-001-004-regression-after-upstream-invalidation-fix-low-reasoning/summary.json`
  shows `25/25` expectations and `13/13` preference anchors passing with hidden
  expectations under explicit low reasoning across `SC-INT-PD-001` through
  `SC-INT-PD-004`.
- `SC-INT-TD-001` was selected next because vague AC can create downstream fake
  green coverage. A new `vague-ac-blocks-test-design` eval produced a red:
  `tools/eval/results/standard-chain-systemic-baseline-2026-06-10/td-001-vague-ac-baseline-low-reasoning/summary.json`
  showed `3/7` expectations and `0/2` anchors. The role correctly refused to
  generate test cases, but did not emit a typed `PRODUCT_GAP` or
  `TESTABILITY_GAP` with missing observable outcome, assertion target, evidence
  expectation, owner, required artifact, decision, and `blocking=true`.
- The test-design fix adds `TD-HG-4` for vague AC, a preflight-time typed-gap
  requirement, a `说明类请求边界`, a typed-gap output contract, and an AC coverage
  output contract. Final test-design regression evidence:
  `tools/eval/results/standard-chain-systemic-baseline-2026-06-10/td-001-regression-after-structure-contract-low-reasoning/summary.json`
  shows `16/16` expectations and `7/7` preference anchors passing with hidden
  expectations under explicit low reasoning across vague AC, typed-gap routing,
  and AC boundary/exclusion coverage.
- `SC-INT-DO-001` was selected next because a user can change AC after
  `signoff-package.json` is prepared, and a delivery role may incorrectly treat
  that message as commit authorization. A new
  `acceptance-change-invalidates-signoff-evidence` eval produced a red:
  `tools/eval/results/standard-chain-systemic-baseline-2026-06-10/do-001-acceptance-change-baseline-low-reasoning/summary.json`
  showed `10/14` expectations passing. The role blocked `/commit`, but omitted
  `changed_target_type=AC`, `affected_refs`, `rebaseline_required=true`, and the
  full `required_fresh_proof_after_rebaseline` list.
- The delivery-owner fix adds a DO-S8b target-change field contract. When a user
  changes scope, AC, goal, tasks, or design after signoff preparation, the role
  must output a `target-change.json` field projection, invalidate old signoff
  evidence, route to the owner that must rebaseline, and block
  `READY_FOR_COMMIT` and `/commit` until fresh proof exists.
- This DO run also exposed eval-infra risk: the judge can mutate expectation
  text in `grading.json`. `tools/eval/scripts/standard_chain_local_eval/grading.py`
  now normalizes graded expectation text from source evals and only trusts the
  judge for `passed` and `evidence`. The contract is locked by
  `tests/test-standard-chain-local-eval-runner.sh`.
- Fresh `SC-INT-DO-001` post-fix evidence:
  `tools/eval/results/standard-chain-systemic-baseline-2026-06-10/do-001-acceptance-change-after-runner-normalization-low-reasoning/summary.json`
  shows `14/14` expectations and `3/3` preference anchors passing with hidden
  expectations under explicit low reasoning. The grading text was verified to
  match the source eval expectation.
- A follow-up DO regression exposed a stale eval standard: the old
  `qa-pass-dispatches-commit` prompt treated QA PASS plus verbal authorization
  as enough to dispatch `/commit`, while the current chain contract requires
  `signoff-package.json` and `user-decision.json` before DO-S8c. The eval was
  repaired to test final-ready dispatch, not to weaken the real signoff gate.
- The repaired final-ready eval then found a behavior gap: the role reached
  `READY_FOR_COMMIT` but pushed `/commit handoff` into a future next step. The
  DO-S8c/DO-S8d contract now requires the current response to inline a structured
  `/commit handoff` with `handoff_target`, `dispatch_state`, `commit_input_refs`,
  `change_scope`, `verification_evidence_refs`, `user_authorization_ref`,
  `expected_commit_result`, and `forbidden_actions`.
- Final delivery-owner regression evidence:
  `tools/eval/results/standard-chain-systemic-baseline-2026-06-10/do-final-target-change-and-commit-regression-low-reasoning/summary.json`
  shows `32/32` expectations and `9/9` preference anchors passing with hidden
  expectations under explicit low reasoning across stale evidence after fix,
  final-ready commit handoff, missing commit authorization, and AC target-change
  invalidation.
- `SC-INT-TL-001` was then covered without a skill edit. A new
  `target-drift-blocks-planning` eval checks the case where frozen tasks only
  cover overdue reminders, while the user asks to change the source system and
  approval state model. Current tech-lead behavior already blocks planning,
  routes to product/design/test upstream owners, and refuses to create WBS,
  `plan.json`, or `tasks.json` from the drifted baseline. Evidence:
  `tools/eval/results/standard-chain-systemic-baseline-2026-06-10/tl-001-target-drift-baseline-low-reasoning/summary.json`
  shows `8/8` expectations and `3/3` preference anchors passing with hidden
  expectations under explicit low reasoning.
- `SC-INT-PD-002` and `SC-INT-PD-003` were promoted from planned to covered
  after a fresh low-reasoning run:
  `tools/eval/results/standard-chain-systemic-baseline-2026-06-10/pd-002-003-low-reasoning/summary.json`.
  The combined run shows `11/11` expectations passing with no infrastructure
  failures. This covers user correction backtracking and the positive
  process-lightness case where clear Director facts should not trigger
  mechanical re-asking.
- A consistency challenge then found an `eval_validity` false green in
  `SC-INT-PD-001`: the old passing evidence still allowed a compound question
  around `人工审核 + 人工配置开户`. The `director-baseline-no-prd` eval was
  sharpened to reject compound root-problem facts and multi-bottleneck
  questions, producing a red:
  `tools/eval/results/standard-chain-systemic-baseline-2026-06-10/pd-001-root-problem-atomic-red-check-low-reasoning/summary.json`.
  The `product-director` skill now requires atomic facts, forbids candidate
  mechanism bundling in the recommended root problem, gives closed facts a
  fast-path priority over problem clarification, and requires explicit
  target/success/investment/business-semantics invalidation after upstream
  fact replacement. Fresh regression evidence:
  `tools/eval/results/standard-chain-systemic-baseline-2026-06-10/pd-001-004-regression-after-fastpath-and-rebaseline-fix-low-reasoning/summary.json`
  shows `27/27` expectations and `13/13` preference anchors passing with hidden
  expectations under explicit low reasoning.
- `SC-INT-PM-001` was covered without a skill edit. Existing PM evals
  `director-lock-drift-blocking` and `director-lock-drift-after-handoff`
  already protect locked Director fields before and after UNIT drafting. Fresh
  hidden low-reasoning evidence:
  `tools/eval/results/standard-chain-systemic-baseline-2026-06-10/pm-001-director-drift-baseline-low-reasoning-agent-check/summary.json`
  shows `9/9` expectations and `5/5` preference anchors passing.
- `SC-INT-DES-001` was covered by adding the focused
  `missing-business-state-blocks-design` eval. The current design skill already
  blocks invention of merchant document states and routes the missing business
  state fact to `/product-manager`; no design skill edit was required. Evidence:
  `tools/eval/results/standard-chain-systemic-baseline-2026-06-10/des-001-missing-business-state-baseline-low-reasoning/summary.json`
  shows `6/6` expectations and `3/3` anchors passing. Adjacent upstream-drift
  regression evidence:
  `tools/eval/results/standard-chain-systemic-baseline-2026-06-10/design-upstream-drift-regression-baseline-low-reasoning/summary.json`
  shows `11/11` expectations passing; one preference-anchor cluster remains an
  optimization signal, not a blocking behavior failure.
- The interaction registry was expanded to include the remaining main runtime
  roles: `SC-INT-DEV-001`, `SC-INT-REV-001`, `SC-INT-VER-001`, and
  `SC-INT-QA-001`. These cases explicitly target stale task packets, stale
  developer evidence, old verification proof, and outdated QA acceptance after
  target drift. Each covered case is now backed by current hidden eval evidence,
  not by the mere presence of a source eval file.
- `SC-INT-DEV-001` was then covered without a skill edit. A new
  `stale-task-packet-blocks-implementation` eval showed current developer
  behavior already blocks implementation when `active_tasks_version_ref=tasks@v1`
  conflicts with a changed enterprise-tier same-day SLA acceptance target.
  Evidence:
  `tools/eval/results/standard-chain-systemic-baseline-2026-06-10/dev-001-stale-task-baseline-low-reasoning/summary.json`
  shows `5/5` expectations and `3/3` anchors passing with hidden expectations
  under explicit low reasoning.
- `SC-INT-REV-001` was covered without a skill edit after adding the focused
  `stale-developer-evidence-blocks-review-pass` eval and a matching
  evidence-freshness preference anchor. Current review behavior blocks
  APPROVE/PASS when `developer-report.json` is tied to `tasks@v1` while the
  active plan/tasks reference is `tasks@v2`. Evidence:
  `tools/eval/results/standard-chain-systemic-baseline-2026-06-10/rev-001-stale-developer-evidence-after-anchor-fix-low-reasoning/summary.json`
  shows `5/5` expectations and `1/1` anchor passing with hidden expectations
  under explicit low reasoning.
- `SC-INT-VER-001` was covered without a skill edit after adding
  `stale-ac-proof-blocks-verify-pass` and a matching proof freshness anchor.
  Current verify behavior blocks PASS when old developer/test proof was
  generated for generic SLA AC but current acceptance requires enterprise-tier
  same-day SLA. Evidence:
  `tools/eval/results/standard-chain-systemic-baseline-2026-06-10/ver-001-stale-ac-proof-baseline-low-reasoning/summary.json`
  shows `5/5` expectations and `1/1` anchor passing with hidden expectations
  under explicit low reasoning.
- `SC-INT-QA-001` was covered without a skill edit after adding
  `outdated-acceptance-blocks-qa-pass` and a matching QA evidence freshness
  anchor. Current QA behavior blocks PASS when old QA evidence and old
  `qa_handoff_contract` were produced for the previous acceptance target while
  current AC adds enterprise-tier same-day SLA. Evidence:
  `tools/eval/results/standard-chain-systemic-baseline-2026-06-10/qa-001-outdated-acceptance-after-anchor-fix-low-reasoning/summary.json`
  shows `5/5` expectations and `2/2` anchors passing with hidden expectations
  under explicit low reasoning. The earlier `PA-1` anchor was removed from this
  eval because the no-file prompt cannot prove canonical `brief` / `phase-prd`
  / `UNIT` reading; the case now only claims the handoff/evidence freshness
  behavior it directly exercises.

The important conclusion is narrow: this slice improves the top-level
`product-director` state machine and eval validity, `test-design` vague-AC
blocking, `delivery-owner` target-change rebaseline handling, `tech-lead`
target-drift blocking, and current evidence coverage for `product-manager` and
`design`, stale-task admission for `developer`, and stale developer evidence
blocking for `review`, stale proof blocking for `verify`, and outdated
acceptance blocking for `qa`. It proves the 13 current interaction cases are
covered only at this interaction-eval slice; it does not prove every possible
standard-chain behavior or every cross-role failure mode is closed.

## First execution loop

1. Run `bash tests/test-standard-chain-interaction-eval.sh`.
2. For each planned case, run a current-output baseline with the relevant role
   skill or local eval runner.
3. Grade current behavior against the interaction dimensions.
4. Cluster failures by causal mechanism, not by role name.
5. Pick one mechanism to optimize.
6. Write the failing eval for that mechanism.
7. Change only the owning skill/reference/test.
8. Re-run existing role regressions and interaction-eval gates.

## Exit criteria for this evaluation slice

This slice is successful only when:

- The interaction case registry is structurally gated, and every `covered` case
  references at least one passing `summary.json` with no infrastructure
  failures.
- At least one current behavior or contract red signal is captured for a real
  interaction failure mode.
- The selected optimization improves that failure without reducing process
  lightness or breaking existing role boundaries.
- Any future residual planned cases must stay planned until backed by current
  passing evidence, not falsely reported as covered.
