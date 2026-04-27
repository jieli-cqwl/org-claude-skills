# Tasks — Standard Chain Flow Optimization
Created: 2026-04-27
Related design: ./design.md
Related plan: ./plan.md

## Goal Traces
- G1: Versioned failure routing contract with closed schema, registry-owned codes, and fail-closed unknown-code behavior.
- G2: Explicit core checker CLI and hook adapter split for preflight and completion.
- G3: Role-specific preflight profiles for all ten main standard-chain roles.
- G4: Role-specific completion profiles for all ten main standard-chain roles, with delivery sequencing aligned to `developer -> verify -> review -> qa`.
- G5: Skill-body noise reduction with single-responsibility content layers and auditable migration records.
- G6: Login homepage delegated pilot proves the current chain end to end with fresh artifacts, delegated confirmation basis, retrospective, and current canonical schemas.
- G7: Final proof covers targeted contract tests, login homepage pilot, contract validation, context contract validation, and quick regression.

## Acceptance Checklist
- [x] T1 Failure routing registry and result schema
  - AC: `bash tests/test-standard-chain-failure-routing-contract.sh` proves `failure-routing-result.schema.json`, `contracts/standard-chain-failure-routing.yaml`, the real `validate_failure_routing_contract.py` consumer, the derived runtime catalog if present, required fields, closed `PASS/WARN/BLOCKED` status, unknown-code rejection, and `UNREGISTERED_FAILURE_CODE` fail-closed semantics.
  - AC: `bash tools/validate-contracts.sh` consumes the new schema/registry without hidden source-of-truth drift.
  - Traces: G1
  - Depends: -
  - Complexity: complex
- [x] T2 Shared checker runtime and role profile catalogs
  - AC: `bash tests/test-standard-chain-checker-contract.sh` proves shared routing helpers emit schema-valid JSON, core checkers are argv-only, stdin hook payloads are rejected by core CLIs, malformed arguments fail closed, `WARN` requires `continuation_condition`, and the preflight/completion profile catalogs cover exactly the ten main roles.
  - AC: The profile catalogs reference registered failure codes only and do not define new schema or ownership policy outside contracts.
  - Traces: G1, G2, G3, G4
  - Depends: T1
  - Complexity: complex
- [ ] T3 Preflight core checkers and hook adapters
  - AC: `bash tests/test-standard-chain-preflight-profiles.sh` proves `check_preflight.sh` and `preflight_check.sh` for `product-director`, `product-manager`, `design`, `test-design`, `tech-lead`, `delivery-owner`, `developer`, `verify`, `review`, and `qa`.
  - AC: The test covers missing artifact, malformed artifact, stale ref, ambiguous active target, missing human confirmation, Director entry without existing `brief.json`, adapter payload conversion, timeout/output bounds, and core/adapter routing drift.
  - AC: Preflight checks are read-only and do not create, patch, normalize, or migrate artifacts.
  - Traces: G2, G3
  - Depends: T1, T2
  - Complexity: complex
- [ ] T4 Completion core checkers and hook adapters
  - AC: `bash tests/test-standard-chain-completion-profiles.sh` proves `check_completion.sh` and `completion_check.sh` delegation for the same ten roles.
  - AC: The test covers missing canonical output, malformed output, stale fresh-proof evidence, missing handoff readiness, missing delegated confirmation basis in pilot-only gates, existing hook payload compatibility, adapter/core routing drift, and `developer -> verify -> review -> qa` sequencing.
  - AC: `contracts/standard-chain.yaml`, role manifests, and `shared/hooks/registry.json` stay consistent with completion adapter paths and timeout policy.
  - Traces: G2, G4
  - Depends: T1, T2, T3
  - Complexity: complex
- [x] T5 Content-quality validator and audit gate
  - AC: `bash tests/test-standard-chain-content-quality.sh` proves content-layer rules for `HARD-GATE`, `Protocol`, `Why`, `How`, `Script Contract`, `Failure Routing`, `Reference Link`, and `Output Contract`.
  - AC: The validator rejects hidden MUST requirements inside `Why`, concrete file/field commands inside `How`, unowned failure statements, repeated source-of-truth claims, vague ambiguous action wording, and `delete` audit records without reason and verification ref.
  - AC: Fixture tests prove valid and invalid `noise-migration-audit.json` shapes before the active skill migration begins.
  - Traces: G5
  - Depends: T1, T2
  - Complexity: moderate
- [ ] T6 Standard-chain skill-body migration and noise audit
  - AC: `bash tests/test-standard-chain-skill-structure.sh` and `bash tests/test-standard-chain-content-quality.sh` pass against the active ten main role `SKILL.md` files.
  - AC: `docs/standard-chain-flow-optimization/2026-04-27-preflight-noise-regression/noise-migration-audit.json` records every removed or substantially rewritten normative segment with source location, content layer, migration action, destination ref, consumer, reason, and verification ref.
  - AC: Skill bodies keep judgment guidance and triggered references, but move mechanical checks, repeated schema facts, display templates, obsolete history, and role-crossing failure ownership to scripts, contracts, projections, references, archive, or deletion records.
  - Traces: G2, G5
  - Depends: T3, T4, T5
  - Complexity: complex
- [ ] T7 Delegated login homepage pilot proof and fixture synchronization
  - AC: `bash tests/test-standard-chain-delegated-pilot-proof.sh` proves `delegated-pilot-proof.json`, `process-retrospective.md`, login homepage fixture artifacts, active plan/tasks refs, confirmation records, fixture sync refs, and current `developer-report.schema.json` agree.
  - AC: `bash tests/test-standard-chain-login-homepage-pilot.sh` passes because the fixture was regenerated or updated through the delegated proof, not because an old artifact was patched without traversal evidence.
  - AC: The pilot proof records all stages from `product-director` through delivery signoff, `confirmed_by=codex-delegated-gatekeeper` or equivalent, and a confirmation basis citing this workset's delegated authorization.
  - Traces: G6
  - Depends: T1, T2, T3, T4, T6
  - Complexity: complex
- [ ] T8 Final verification and closeout readiness
  - AC: `bash tests/test-standard-chain-failure-routing-contract.sh`, `bash tests/test-standard-chain-checker-contract.sh`, `bash tests/test-standard-chain-preflight-profiles.sh`, `bash tests/test-standard-chain-completion-profiles.sh`, `bash tests/test-standard-chain-content-quality.sh`, `bash tests/test-standard-chain-skill-structure.sh`, `bash tests/test-standard-chain-delegated-pilot-proof.sh`, `bash tests/test-standard-chain-login-homepage-pilot.sh`, `bash tools/validate-contracts.sh`, `python3 tools/community/validate_context_contract.py --repo-root .`, and `bash tests/run-all.sh --quick` pass.
  - AC: Full regression with `bash tests/run-all.sh` is run when local runtime cost is acceptable; if blocked, `verify-change-report.md` records the concrete blocker and the quick regression is not presented as a full-regression substitute.
  - AC: `tasks.md`, `worklog.md`, and `verify-change-report.md` record final status, proof commands, residual risks, and next handoff.
  - Traces: G1, G2, G3, G4, G5, G6, G7
  - Depends: T1, T2, T3, T4, T5, T6, T7
  - Complexity: complex

## Definition of Done
All tasks checked means the optimized standard-chain flow is ready for verify-change or archive, with no blocked fresh proof.
