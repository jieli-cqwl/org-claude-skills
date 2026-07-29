# Rule Runtime Effectiveness Design

## Objective

Build one repeatable evaluation path that proves whether the installed runtime entry, rules, and references change agent behavior in the scenarios they are intended to control.

The first delivery is a Codex-only diagnostic slice. It must distinguish four outcomes:

1. The relevant scene contract was loaded and the expected behavior followed.
2. The contract was loaded but did not change behavior.
3. The contract was not loaded but the model happened to answer well.
4. The candidate contract caused a behavioral or process-lightness regression.

## Acceptance Scope

The first slice is accepted only when:

- The current worktree can be evaluated as a candidate without writing to the user's installed runtime.
- An explicit Git ref can be evaluated as a baseline under the same model and execution settings.
- Candidate and baseline runs persist current source identity, runtime identity, raw execution evidence, final output, grading, and timing.
- Required scene-contract reads and final behavioral quality are evaluated separately.
- Every runtime source changed by the candidate is connected to at least one selected case.
- Infrastructure failures remain distinct from behavioral failures and cannot produce a passing verdict.
- One generated report shows coverage, freshness, blocking failures, candidate/baseline differences, and unverified scope.

## Non-goals

- Do not rewrite `shared/assistant.md` as part of the first slice.
- Do not replace first-party Skill evals or the standard-chain local eval runner.
- Do not redesign every eval schema in the repository.
- Do not run every internal judge case before the focused runner proves useful.
- Do not promote Claude Code or broad team rollout from Codex-only evidence.
- Do not use exact natural-language prose assertions against Skill, Rule, Reference, or Agent Markdown bodies.
- Do not turn generated coverage or summary reports into a second source of truth.

## Current Problem

The repository already has the necessary pieces, but they do not form one current evidence chain:

- `shared/assistant.md` defines runtime defaults and scene routing.
- `docs/rule-runtime--team-readiness/acceptance-pack.json` defines rollout pressure cases and promotion rules.
- `tools/eval/scenarios/assistant-entry/` evaluates broad entry behavior.
- `tools/eval/scenarios/sql-schema-comments/` evaluates SQL/schema comment behavior.
- Runtime install and capability probes prove rendering and reference-read capability.
- Historical run records prove only the runtime, source version, cases, and evidence captured at that time.

The missing link is a runner that evaluates the current candidate source, verifies actual scene reads, grades behavior, compares a baseline, and binds all evidence to current source and runtime identities.

## Design Decision

Extend the existing rule-runtime readiness path instead of creating another rollout authority.

`docs/rule-runtime--team-readiness/acceptance-pack.json` remains the rollout decision source. Assistant-entry and SQL/schema eval files remain owners of their prompts, expected behavior, anti-patterns, and preference anchors. The new runner consumes those sources and generates evidence; it does not copy or redefine their behavioral content.

The standard-chain local eval runner remains unchanged because its capability owner is first-party Skill evaluation. Rule-runtime evaluation has a different installation boundary, baseline model, and route-read requirement. Shared subprocess or grading utilities may be reused only when doing so does not couple the two ownership domains or expand the first slice.

## System Boundary

### Inputs

- Current repository worktree.
- Explicit baseline Git ref.
- Rule-runtime readiness acceptance pack.
- Selected assistant-entry and SQL/schema case packs.
- Codex CLI runtime and model configuration.

### Outputs

- Candidate and baseline runtime homes under a temporary directory.
- Per-run raw execution logs and final outputs.
- Structured grading and route-read results.
- Source, prompt, grader, runtime, and model fingerprints.
- Generated coverage and decision reports.

### External Boundary

The first slice may execute `codex exec` locally. It must not:

- Modify the real `$HOME/.codex`.
- Use network research.
- Push, publish, or promote rules.
- Treat model-graded output as independent promotion approval.

## Component Responsibilities

### Acceptance Pack

`docs/rule-runtime--team-readiness/acceptance-pack.json` will:

- Include every runtime rule and reference reachable from the active entry contract.
- Declare external case-pack references rather than copying their cases.
- Define stable scene identifiers and the runtime source paths they activate.
- Declare the focused diagnostic selection and the existing promotion selection separately.
- Keep historical promotion requirements, reviewer independence, rollback, and escalation semantics.

It will not store generated scores, current run status, or copied prompts.

### Case Packs

The existing case packs remain behavioral truth for their own scenarios:

- `tools/eval/scenarios/assistant-entry/evals.json`
- `tools/eval/scenarios/sql-schema-comments/evals.json`

Each case must expose enough metadata for the runner to resolve:

- Case ID and prompt.
- Expected behaviors or expectations.
- Anti-patterns and blocking failures.
- Expected preference anchors.
- Expected scene-contract identifiers.

Missing metadata is a case-pack validation failure, not a reason for the runner to infer intent.

### Runtime Evaluator

Add one CLI entrypoint:

`tools/eval/scripts/run_rule_runtime_eval.py`

Its internal modules may be split under:

`tools/eval/scripts/rule_runtime_eval/`

The boundaries are:

- `contracts.py`: load and validate acceptance-pack and case-pack contracts.
- `workspace.py`: materialize candidate and baseline repositories and isolated runtime homes.
- `execution.py`: invoke installers and Codex, capture JSONL, output, timing, and process failures.
- `grading.py`: grade behavioral expectations and anchors with structured output.
- `evidence.py`: fingerprint sources and parse structured tool events for required scene reads.
- `reporting.py`: generate coverage, comparison, and decision artifacts.

The implementation plan may combine modules that remain small, but it must preserve these responsibilities.

## Candidate And Baseline Isolation

### Candidate

The candidate is the current worktree, including relevant uncommitted changes. The manifest must record:

- Current `HEAD`.
- Dirty paths.
- Content hash for every runtime source, selected case pack, and grader.

### Baseline

The baseline is an explicit Git ref supplied by the caller. The runner must:

- Reject a missing or unresolved ref.
- Materialize the ref into a temporary repository snapshot.
- Record the resolved commit.
- Use the baseline's installer and runtime sources.
- Require an explicit `case_source` decision: `candidate` freezes candidate-owned cases and graders across both configurations, while `baseline` uses each configuration's own cases and graders for historical replay.

The runner must never silently substitute `HEAD`, the parent commit, an empty runtime, or a case source.

### Runtime Homes

Candidate and baseline use separate temporary homes. Each home is installed through the repository's real installer path with explicit Codex target settings. Installation occurs once per configuration and is reused across selected cases.

Cleanup must remove only evaluator-created temporary directories. A `--keep-workspaces` option may retain them for diagnosis.

## Execution Flow

For each configuration and selected case:

1. Validate source, case, grader, baseline, and runtime prerequisites.
2. Install the configuration into its isolated runtime home.
3. Run the prompt in a fresh ephemeral Codex session.
4. Capture structured execution events and final output.
5. Parse actual file-read events for expected scene contracts.
6. Grade expected behavior, anti-patterns, anchors, and blocking failures.
7. Record timing and infrastructure status.
8. Compare candidate and baseline only after both runs have valid evidence.

No candidate score is produced from a baseline run, and no partial pair supports an attribution claim.

## Evidence Contract

Each run persists:

- `eval_metadata.json`: case, configuration, case source, source refs, expected scenes, and grader identity.
- `runtime_manifest.json`: Git ref, source hashes, runtime version, model, reasoning level, install command, and install result.
- `executor.jsonl`: structured Codex execution events.
- `executor.log`: stderr and non-structured process diagnostics.
- `outputs/response.md`: final assistant output.
- `route_reads.json`: expected and observed runtime source reads.
- `grading.json`: expectation, anti-pattern, blocking-failure, and anchor results.
- `timing.json`: start, end, and duration.

Each evaluation set generates:

- `coverage.json`: generated mapping from runtime source to selected cases and fresh evidence.
- `comparison.json`: candidate/baseline score and failure differences.
- `summary.json`: machine-readable suite verdict.
- `summary.md`: human review projection.

Generated reports must contain source references back to case packs and run artifacts. They must not redefine prompts, expectations, or rules.

## Freshness

Evidence is fresh only when all of these match the evaluated run:

- Runtime source hashes.
- Selected case prompt and expectation hashes.
- Grader hash.
- Runtime target and version.
- Model and reasoning settings.
- Candidate or baseline Git identity.

Changing any matched input invalidates the affected evidence. Unchanged cases may remain valid only when their runtime source dependencies and evaluation inputs remain unchanged.

The report must say `STALE`, `MISSING`, `INFRA_BLOCKED`, `BEHAVIOR_FAIL`, or `FRESH_PASS`; it must not collapse these states into one pass/fail boolean.

## Route And Behavior Separation

### Route Verdict

A route passes only when structured execution evidence proves every required runtime source was read for that case. Mentioning a rule name in the final answer is not route evidence.

### Behavior Verdict

Behavior grading checks:

- Expected behaviors.
- Anti-patterns.
- Blocking failures.
- Preference anchors.
- Process lightness where declared.

A good answer with a failed route is reported as `behavior_pass_route_fail`. A successful route with poor behavior is reported as `route_pass_behavior_fail`. Neither supports a rule-effectiveness claim.

## Grading And Attribution

Deterministic checks own:

- Process exit status.
- Output presence.
- Runtime and source identity.
- Case and grader contract validity.
- Expected scene reads.
- Complete candidate/baseline pairs.

A structured model grader owns semantic behavior judgment. It must receive the case prompt, expected behaviors, anti-patterns, blocking failures, anchor definitions, and actual output. It must not receive whether the output is candidate or baseline during grading.

Candidate improvement is attributable only when:

- Both configurations have valid, fresh evidence.
- The candidate does not introduce a blocking failure.
- The changed behavior maps to a source changed between candidate and baseline.
- The difference is visible in expectation, anchor, route, or process-lightness evidence.

No difference means the contract may be redundant, already encoded elsewhere, or not exercised by the case. It does not automatically mean the contract is ineffective.

## Focused Diagnostic Slice

The first run uses eight high-value cases:

1. SQL/schema comment semantics.
2. Completion claim without adequate evidence.
3. Existing-path reuse before adding behavior.
4. Debugging under a biased user diagnosis.
5. Configuration or secret ownership and failure behavior.
6. Collaboration across a shared prerequisite or shared contract.
7. Full-stack dual-source or contract shortcut.
8. Process lightness for a simple judgment task.

Existing cases are reused when they cover the behavior. Add only the missing configuration/secret or collaboration case if the current packs do not provide one with the required metadata.

The first diagnostic uses one run per configuration. Repeated runs and the full internal judge set are promotion work, not prerequisites for proving the runner.

## Baseline Selection For The First Diagnostic

- Assistant-entry comparison baseline: `f9cbf552`, before the refined thinking contracts.
- SQL/schema comparison baseline: `68abd950`, before the current uncommitted SQL/schema reference changes.

The invocation must pass these refs explicitly and use `case_source=candidate`, so the same current cases and grader judge both runtime configurations. These are first-run decisions, not defaults embedded in the runner.

## Decision Rules

Any of these produces `FAIL`:

- False completion or release claim.
- Hidden failure, unsafe fallback, or fake success.
- Ignored existing behavior, compatibility, or authoritative ownership.
- Required scene contract not read.
- Infrastructure failure reported as behavior evidence.
- Candidate-only or baseline-only output used for attribution.
- Candidate introduces a new blocking failure.

The focused diagnostic passes only when:

- All eight selected cases have complete candidate and baseline evidence.
- Required scene reads pass for candidate runs.
- No blocking failure appears.
- Average expected-anchor score is at least `1.6 / 2`.
- Changed SQL/schema guidance has an explainable candidate/baseline difference or is explicitly reported as no observed marginal effect.
- The lightness case shows no material increase in irrelevant reads or final-output ceremony.

The diagnostic verdict does not authorize controlled pilot or all-runtime rollout.

## Failure Handling

- Installer failure: stop the affected configuration and mark all dependent runs `INFRA_BLOCKED`.
- Codex timeout: preserve partial logs, mark the run `INFRA_BLOCKED`, and do not grade partial output as a normal response.
- Missing structured route events: mark route evidence unavailable; do not infer reads from final prose.
- Grader failure: preserve executor evidence and mark grading `INFRA_BLOCKED`.
- Candidate/baseline mismatch in model or reasoning settings: reject comparison.
- Missing source dependency metadata: fail contract validation before model execution.
- Cleanup failure: report retained paths and do not delete outside evaluator-owned temporary roots.

Retries are manual and create a new run sequence. The runner does not silently retry model or grader failures.

## Testing Strategy

### Contract Tests

Add tests that reject:

- Unknown case-pack refs.
- Duplicate case IDs inside one selected namespace.
- Unknown scene identifiers.
- Runtime sources with no selected coverage.
- Missing expectations, anti-patterns, or blocking-failure definitions where required.
- Unresolved baseline refs.

### Runner Tests

Use fake installer and fake Codex executables to verify:

- Candidate and baseline homes are isolated.
- Commands receive the intended runtime home and working directory.
- Structured events produce route-read evidence.
- Missing reads fail the route verdict.
- Timeouts and non-zero exits remain infrastructure failures.
- Candidate-only evidence cannot produce comparison success.
- Generated summaries preserve freshness and failure-state distinctions.

### Repository Verification

The first slice uses:

- Targeted runner contract tests.
- Targeted acceptance-pack validator tests.
- `bash tests/run-all.sh --quick`.
- `bash install.sh --target all --dry-run`.

The full repository gate is out of scope unless targeted or quick verification exposes a cross-cutting failure.

### Live Diagnostic

Run the eight selected cases against Codex after static and fake-process tests pass. Live results are diagnostic evidence, not deterministic gate evidence.

## File Impact

Expected modifications:

- `docs/rule-runtime--team-readiness/acceptance-pack.json`
- `tools/eval/scenarios/assistant-entry/evals.json`
- `tools/eval/scenarios/sql-schema-comments/evals.json`
- `tests/gate-plan.json`

Expected additions:

- `tools/eval/scripts/run_rule_runtime_eval.py`
- `tools/eval/scripts/rule_runtime_eval/`
- `tests/test-rule-runtime-eval-runner.sh`
- Focused fake CLI and contract fixtures under `tests/fixtures/rule-runtime-eval/`

Generated live results stay under `tools/eval/results/rule-runtime/`. The implementation plan must decide which summary and redacted evidence artifacts are committed; raw local-only evidence must not be cited as promotion-grade repository evidence.

Out of scope:

- `shared/assistant.md`
- Existing historical run records
- Standard-chain skill eval runner behavior
- Real user runtime installation before the diagnostic passes

## Risks And Trade-offs

### Model Grader Bias

The same model family may execute and grade. Blind configuration labels and deterministic route checks reduce, but do not remove, this risk. Independent human review remains required for promotion.

### Runtime Cost

Candidate/baseline pairs increase model calls. The focused eight-case slice and one run per configuration cap diagnostic cost. Promotion repeats only after the runner proves signal.

### Transcript Stability

Codex JSONL event shapes may change. Route parsing must fail visibly on unknown event shapes instead of silently treating them as no reads or successful reads.

### Over-enforcement

Requiring every reference for every task could reproduce the current process-lightness problem. Cases declare only the contracts needed for their failure mode, and the lightness case checks irrelevant loading.

### Evidence Volume

Raw JSONL can grow. Local diagnostic evidence may remain uncommitted, but any promotion claim requires stable, reviewable, sufficiently redacted repository or artifact evidence with hashes.

## Rollout Sequence

1. Validate and normalize the acceptance-pack and case-pack contracts.
2. Implement fake-process runner tests.
3. Implement candidate and baseline workspace isolation.
4. Implement structured execution and route evidence.
5. Implement semantic grading and comparison.
6. Generate coverage and decision reports.
7. Run targeted tests, quick regression, and install dry-run.
8. Run the eight-case Codex diagnostic.
9. Review failures by root cause: route, instruction, case, grader, runner, or model variance.
10. Install to the real local runtime only after the candidate diagnostic passes.

Claude Code parity, repeated promotion runs, and broad rollout require separate evidence after the Codex diagnostic.

## Completion Criteria

The first slice is complete only when:

- The accepted architecture is implemented without creating a second rollout authority.
- Candidate and baseline runtimes are isolated and reproducible.
- All deterministic failure paths are covered by targeted tests.
- The eight-case live diagnostic produces complete evidence or explicitly blocks on infrastructure.
- Coverage and freshness are generated from canonical sources.
- No completion or rollout claim exceeds the recorded runtime, case, model, source, and evidence scope.
