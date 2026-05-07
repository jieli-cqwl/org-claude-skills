# Standard Chain HTML Result Views

## Problem Statement

`standard-chain` has moved its runtime truth to canonical JSON artifacts, but human-readable projections are still partly Markdown templates scattered under role-specific `projections/` directories. Those Markdown projections create historical noise, duplicate display rules, and make it easy for agents or readers to treat prose as a secondary source of truth.

The new need is to turn existing canonical JSON into human-friendly HTML so business, product, engineering, QA, and delivery reviewers can understand the complete delivery closure without reading raw JSON field names. The HTML must not affect the main agent context or become a control input. It must be derived from verified canonical JSON by deterministic tooling, then reviewed for readability by a sub agent.

## Goals And Success Criteria

1. Provide a `standard-chain` HTML result-view layer that helps humans understand the final closed result of each major chain segment.
2. Preserve canonical JSON as the only runtime truth; HTML is display-only and never a downstream control input.
3. Replace standard-chain Markdown projections in the same migration by deleting their active templates and removing skill/test references to them.
4. Keep generation isolated from the main agent: deterministic renderer writes HTML and manifests; a sub agent reviews readability and visual hierarchy only.
5. Make views understandable to business and product/engineering readers by translating technical field names and enum values into Chinese human-facing labels.
6. Fail closed when canonical fields, schema versions, refs, enum mappings, digests, or manifests drift.

Success is proven when:

- A golden standard-chain phase generates five HTML pages and matching manifests.
- Every visible section can be traced to canonical artifact refs and JSON pointers.
- Dangerous HTML content is escaped.
- Unknown required fields or enum values fail or warn according to view configuration.
- Standard-chain runtime, skills, and tests no longer consume active `.md` projection templates.
- Sub-agent UX review reports PASS for reader clarity, navigation consistency, and evidence discoverability.

## Result View Definition

HTML result views are the **final closed-result views** for standard-chain artifacts. They are not process views.

They may show:

- Background, root problem, goals, scope, business flows, user paths, rules, UNIT closure, acceptance criteria, verification plans, final design decisions, execution evidence, QA results, release recommendations, signoff, risk acceptance, and current delivery state.
- Final decisions and final fields already present in canonical JSON.
- Source evidence folded behind readable labels.

They must not show:

- Draft evolution, option debate, co-creation transcript, reviewer discussion process, or temporary reasoning unless those facts are final canonical fields.
- Any fact invented during HTML rendering.
- Any content that cannot be traced to canonical JSON.

## Approach

Create a deterministic HTML result-view renderer for standard-chain phase directories.

The renderer reads a declarative `shared/runtime/result-views.json` registry that defines each view, its sections, source artifacts, JSON pointers, required/optional behavior, audience, and translation rules. It then writes static HTML and a `projection-manifest.json` per view under `docs/{feature}/phase-{N}/views/`.

The main agent only orchestrates:

1. Reuse existing standard-chain canonical validation to confirm the phase JSON is the current valid truth.
2. Run the renderer and validator.
3. Dispatch a sub agent for UX/readability review.
4. Read PASS/BLOCK results.

The main agent does not rewrite HTML facts. The sub agent does not write canonical JSON or author factual HTML content.

## MVP View Set

The MVP has five static HTML pages:

| View | Purpose | Primary Audience | Canonical Inputs |
| --- | --- | --- | --- |
| `result-index.html` | Phase result navigation and overall status | all readers | active artifact registry, delivery state, signoff summary |
| `product-result.html` | Product closure: why, what, scope, flow, UNIT, AC, verification plan | business, product, engineering | `brief.json`, `phase-prd.json`, `units/UNIT-*.json` |
| `design-result.html` | Design closure: decisions, modules, interfaces, data, quality, migration, rollback, verification mapping | product, engineering, architecture | `design.json` |
| `execution-result.html` | Execution closure: plan, tasks, developer evidence, verify, code review | engineering, delivery | `plan.json`, `tasks.json`, developer reports, verify results, code review result |
| `release-result.html` | Release closure: QA, delivery state, signoff, user decision, risks, blockers, recommendations | business, QA, delivery | `qa-result.json`, `delivery-state.json`, `signoff-package.json`, `user-decision.json`, consistency/fix results when present |

Each page uses the same reading structure:

1. 30-second summary.
2. Complete closed loop for that segment.
3. Confirmation, lock, or delivery state.
4. Downstream handoff.
5. Folded source evidence.

## Content And Language Model

The main reading area uses human-facing Chinese labels, not raw field names.

Examples:

| Canonical Field Or Value | Human Label |
| --- | --- |
| `gate_result: PASS` | `门禁结论：已通过` |
| `active_plan_version_ref` | `当前执行计划版本` |
| `delivery_confirmation.status=confirmed` | `产品交付确认：已确认` |
| `sign_off_status=SIGNED_OFF` | `业务签核：已签署` |
| `release_recommendation=CONDITIONAL_ALLOW` | `发布建议：有条件允许` |
| `blocked_from_stage` | `阻塞发生环节` |
| `resume_stage` | `恢复后继续环节` |

Raw `artifact://...` refs, JSON pointers, digests, schema versions, and registry digests stay in the folded evidence area. They are available for engineering and audit readers, but do not dominate the business reading flow.

Translation rules live in the result-view registry, not in scattered renderer logic. Unknown required enum mappings fail closed. Optional unknown enum mappings may render as `未识别状态` only when the registry explicitly allows a warning.

## Data Flow

1. Existing standard-chain validation proves the phase canonical JSON is valid and active.
2. The renderer loads `shared/runtime/result-views.json`.
3. The renderer resolves each configured source artifact through the active artifact registry.
4. The renderer extracts configured JSON pointers and applies human-label and enum mappings.
5. The renderer escapes all rendered values and writes static HTML.
6. The renderer writes a manifest per HTML file.
7. The validator checks manifest source refs, section source maps, active refs, HTML digest, and view registry drift.
8. A sub agent reviews the rendered HTML for readability, visual hierarchy, terminology, navigation consistency, and evidence discoverability.
9. The main agent reports only PASS/BLOCK evidence.

## Manifest Contract

Each HTML result view has a sibling manifest. The manifest records:

- `artifact_type: projection-manifest`.
- `view_id`.
- `source_artifact_refs`.
- `section_source_map`, mapping section ids to source refs and JSON pointers.
- `renderer_version`.
- `result_view_registry_digest`.
- `chain_version`.
- `chain_registry_digest`.
- `rendered_artifact_ref`.
- `rendered_content_digest`.
- generated timestamp.

The manifest is authoritative only for display provenance. It does not replace canonical JSON and cannot define runtime truth.

## Change Scope

In scope:

- Add the `result-views.json` registry.
- Add or extend deterministic renderer and validator tooling for the five HTML result views.
- Add fixture outputs for a golden standard-chain phase.
- Add tests for positive generation, negative drift, escaping, enum mapping, digest, and reference cleanup.
- Remove active standard-chain Markdown projection templates and update standard-chain skill/test references.
- Update README/contracts/runtime catalog only where they describe projection display behavior.

Out of scope:

- Non-standard-chain projection templates such as research, security, overview, UX, and refactor.
- Interactive web application behavior beyond static HTML and simple folded evidence.
- Process views, choice-decision timelines, co-creation transcripts, or reviewer discussion views.
- Changing canonical schema semantics solely to make HTML easier.

## Standard-Chain Markdown Projection Cutover

Standard-chain `.md` projection templates are removed in the same implementation batch after HTML parity is proven. Deletion must be scoped by standard-chain use, not by directory name alone.

Known candidate templates from current scan:

- `shared/skills/product-manager/projections/brief-template.md`
- `shared/skills/product-manager/projections/phase-prd-template.md`
- `shared/skills/product-manager/projections/product-manager-review-template.md`
- `shared/skills/design/projections/design-template.md`
- `shared/skills/design/projections/adr-spec.md`
- `shared/skills/test-design/projections/test-cases-template.md`
- `shared/skills/tech-lead/projections/plan-template.md`
- `shared/skills/tech-lead/projections/design-review-template.md`
- `shared/skills/review/projections/code-review-report-template.md`
- `shared/skills/qa/projections/qa-report-template.md`
- `shared/skills/consistency-audit/projections/consistency-report-template.md`
- `shared/skills/fix/projections/fix-report-template.md`

Before deleting templates that also support standalone skill usage, the implementation must confirm the standalone usage is either out of standard-chain scope or covered by the new HTML result view. If not covered, deletion is blocked for that template until a replacement display path is defined.

## Invariants

- Canonical JSON remains the only source of truth for status, progress, decisions, handoff, acceptance, release, and signoff.
- HTML result views are display-only and never consumed by runtime gates, handoff recovery, or downstream skills.
- Renderer code cannot contain scattered business JSON pointer policy; view pointers and required/optional behavior live in the registry.
- No renderer or sub agent may invent facts missing from canonical JSON.
- All visible facts must be source-mapped.
- Field drift fails closed unless the registry explicitly marks the field optional.
- Sub-agent review cannot change facts; it only produces a UX/readability report.

## Error Handling

| Failure | Behavior |
| --- | --- |
| Canonical phase validation fails | Do not mark result views ready; return `CANONICAL_PHASE_INVALID`. |
| Required JSON pointer missing | Renderer fails with view id, section id, source artifact, and pointer. |
| Optional JSON pointer missing | Renderer omits or displays configured empty-state text. |
| Required enum mapping unknown | Renderer fails with field and value. |
| Optional enum mapping unknown | Render `未识别状态` only if configured as warnable; emit warning. |
| Source ref not active | Manifest validator fails. |
| HTML digest mismatch | Manifest validator fails. |
| HTML injection content present | Renderer must escape; test fails if raw script/content is embedded. |
| Sub-agent UX review fails | HTML is generated but not marked ready. |
| Old Markdown projection reference remains | Migration test fails. |

## Downstream Impact

Business and product readers get complete closed-loop views without learning JSON field names. Engineering and audit readers retain folded source evidence.

Standard-chain skills must stop instructing agents to read active `.md` projection templates. They may refer to HTML result views only as human display outputs after canonical JSON validation.

Validators and tests gain a new display-provenance layer, but canonical artifact validation remains the primary gate. Handoff recovery continues to use active scope registry, worklog, artifact registry, and canonical JSON refs.

## Alternatives Considered

1. Role result-view framework. Recommended because it matches human responsibility boundaries while preserving canonical traceability.
2. One HTML file per canonical artifact. Rejected for MVP because it is too close to a file browser and less friendly to business/product readers.
3. Single interactive result workbench. Deferred because it increases client-side complexity, digest validation complexity, and MVP risk.
4. Let sub agents generate HTML directly. Rejected because it risks turning an LLM into a fact transformation layer.
5. Keep Markdown compatibility wrappers. Rejected because the goal is to reduce historical projection noise and avoid dual display contracts.

## Testing And Validation

Required test categories:

- Unit tests for field extraction, pointer resolution, enum translation, optional/required behavior, HTML escaping, and digest calculation.
- Integration test using a golden standard-chain phase to generate five HTML pages and manifests.
- Negative tests for missing required pointers, unknown enum values, source ref drift, schema or registry digest mismatch, raw HTML/script injection, manifest digest drift, and stale active refs.
- Reference cleanup tests proving standard-chain skills and tests no longer consume active Markdown projections.
- UX review artifact proving a sub agent checked readability, Chinese terminology, visual hierarchy, navigation consistency, and folded evidence discoverability.

Fresh proving commands will be finalized in `tasks.md`, but must include the standard contract validator stack and the new result-view test suite.

## Risks

1. Standard-chain skills are still being optimized, so fields may change. Mitigation: store field paths and enum mappings in `result-views.json`, bind views to schema/chain digests, and fail closed on required drift.
2. HTML may become a second source of truth. Mitigation: display-only invariant, source maps, manifest validation, and tests forbidding runtime consumption.
3. Business readers may still see too much technical language. Mitigation: Chinese semantic labels in main reading flow, folded evidence for raw refs, and sub-agent UX review.
4. Deleting Markdown projections may break standalone skill usage. Mitigation: scoped deletion audit and block deletion where no HTML replacement exists for standard-chain use.
5. Renderer output may become visually poor while mechanically correct. Mitigation: sub-agent readability review is required before marking views ready.

## Contract-Grade Preflight

This design triggers contract-grade preflight because it affects source-of-truth boundaries, display projection contracts, validators, migration/cutover, and multi-agent handoff.

### C1 Current Vs Target

Current HEAD has canonical JSON as standard-chain runtime truth, plus active Markdown projection templates for human display in several standard-chain skills and an existing minimal `phase-operational.html` projection path.

Target contract keeps canonical JSON unchanged as runtime truth and replaces standard-chain Markdown projections with deterministic HTML result views plus manifests. Migration phase is this feature workset. Cutover owner is `feature-runtime-owner`.

### C2 Source Of Truth Matrix

| Fact Type | Authoritative Source | HTML Role |
| --- | --- | --- |
| Product direction and scope | `brief.json`, `phase-prd.json` | display |
| Product flows, UNIT, AC | `phase-prd.json`, `units/UNIT-*.json` | display |
| Design decisions and boundaries | `design.json` | display |
| Plan and tasks | `plan.json`, `tasks.json` | display |
| Developer evidence | `developer-report.json` | display |
| Verify result | `verify-result.json` | display |
| Code review | `code-review-result.json` | display |
| QA and release recommendation | `qa-result.json` | display |
| Delivery state | `delivery-state.json` | display |
| Signoff and user decision | `signoff-package.json`, `user-decision.json` | display |
| Display provenance | `*.projection-manifest.json` | provenance only |

If HTML conflicts with canonical JSON, canonical JSON wins and the view is invalid.

### C3 Closed Vocabulary And Grammar

The result-view registry defines view ids, section ids, source artifact refs, JSON pointers, required/optional behavior, enum mappings, empty-state text, and audience labels. Failure shapes include `CANONICAL_PHASE_INVALID`, missing required pointer, unknown required enum, source ref drift, digest mismatch, and UX review failure.

### C4 Ownership And Waiver

| Artifact | Owner | Writer | Waiver |
| --- | --- | --- | --- |
| canonical JSON | existing standard-chain artifact owners | existing skills/tools | existing owner rules |
| `result-views.json` | feature-runtime-owner | implementation task owner | user or feature-runtime-owner |
| HTML result pages | renderer | deterministic renderer | none for fact drift |
| projection manifests | renderer | deterministic renderer | none for digest/source drift |
| UX review report | sub agent reviewer | sub agent | feature-runtime-owner may accept non-critical visual issues |

### C5 Failure Contract

Failures block result-view readiness and report fixed failure class, view id, section id when applicable, source artifact, pointer/value when applicable, and proving command. The system must not guess from archive, history, Markdown projections, or oral summaries.

### C6 Implementation Surface

Allowed implementation surface:

- `shared/runtime/result-views.json`
- `tools/community/*result*html*.py` or an equivalent deterministic renderer/validator path following existing tooling patterns
- `shared/runtime/standard-chain-catalog.json` only if projection artifact metadata must be extended
- `shared/skills/*/SKILL.md` and references that currently mention standard-chain Markdown projections
- standard-chain tests and fixtures
- standard-chain Markdown projection templates listed in the scoped deletion audit
- docs for this feature

Cutover order: add registry and renderer, add manifest validation, generate golden fixtures, prove HTML parity, update skill/test references, delete scoped Markdown projections, run contract and regression tests.

### C7 Proving Categories

Each success criterion maps to tests or reviewable evidence:

- HTML generation and manifest: result-view integration test.
- Source traceability: manifest validator.
- Escape behavior: injection negative test.
- Drift behavior: missing pointer, unknown enum, digest, source ref, schema/digest negative tests.
- No runtime Markdown consumption: static reference cleanup tests.
- UX readability: sub-agent review report with PASS/BLOCK.
- Existing contract health: `tools/validate-contracts.sh` and relevant standard-chain tests.

### C8 Existing Contract Diff

Existing governing surfaces to check during implementation:

- `contracts/standard-chain.yaml`
- `contracts/canonical/compatibility-matrix.yaml`
- `shared/runtime/standard-chain-catalog.json`
- `shared/runtime/projection-views.json`
- `tools/community/materialize_canonical_html.py`
- `tools/community/validate_projection_manifest.py`
- `tools/community/replay_canonical_phase.py`
- standard-chain skill files and tests that mention `projections/*.md`
- README sections describing standard-chain projection behavior

Any conflict between this design and existing canonical truth contracts must be resolved in favor of canonical JSON truth and display-only HTML.

## Design Completeness Self-Check

| Check | Status |
| --- | --- |
| D1 Problem statement | Clear |
| D2 Goals and success criteria | Clear |
| D3 Approach | Clear |
| D4 Alternatives considered | Clear |
| D5 Change scope | Clear |
| D6 Invariants | Clear |
| D7 Downstream impact | Clear |
| D8 Risks | Clear |
| D9 Contract-grade preflight | Clear |
