# One-Human + Agent Operating Architecture Visual Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the four table-shaped architecture projections with one coherent operating-system architecture suite that makes stage purpose, ownership, next stage, handoff evidence, human authority, shared state, and failure routing legible without changing the normative architecture.

**Architecture:** Keep the approved normative document as the only semantic source and keep the existing `.dot`, `.svg`, and `.png` paths as its deterministic projections. Rebuild each view from real Graphviz clusters, nodes, ranks, and edges using one visual grammar; prove the main map first, then apply the same grammar to three orthogonal supporting views. Generated SVG and 144-DPI PNG files remain derived artifacts and must be reproducible from the adjacent DOT source.

**Tech Stack:** Graphviz 12-compatible DOT, SVG, 144-DPI PNG, `xmllint`, ImageMagick `identify`, repository Markdown, existing quick regression gate.

## Global Constraints

- Approved visual design: `docs/superpowers/specs/2026-07-30--one-human-agent-operating-architecture-visual-redesign--design.md`, approved by the human on 2026-07-30; approved content commit is `f7d38fdd`.
- Normative semantic source: `docs/superpowers/specs/2026-07-30--one-human-agent-team-operating-architecture-v1.2--design.md`.
- The work is a view-only revision. It must not add, delete, reorder, weaken, or reinterpret a role, authority, flow, artifact, state domain, return route, terminal result, or architecture invariant.
- Keep architecture version `TARGET-V1.2`, runtime status `not implemented`, and operating mode `M0`.
- Bump only the normative document's view revision from `R3` to `R4` after all four projections pass.
- Preserve the existing asset directory and filenames; do not create a parallel visual source of truth.
- Keep editable DOT source plus generated SVG and 144-DPI PNG for each view.
- Eliminate monolithic HTML-table renderings. A DOT source must not contain `<TABLE`, `shape=plain`, or one node that contains the whole diagram.
- Use real clusters for responsibility domains, real nodes for Owners/executors/gates/evidence/state, and real edges for allowed transitions or return paths.
- Every diagram has one dominant reading direction. Color supplements labels and shapes; it never carries meaning alone.
- No paragraph-sized node labels. One node contains at most one short responsibility statement and one output or state statement.
- Conditional Owners use dashed borders. Human authority uses a gold-accent node with an explicit `[H]` or `[H-GATE]` label. Immutable Candidate identity uses a double border. Failure and incident paths use both red styling and explicit route text.
- Product Manager capability scope must visibly include business actors, user-facing business entry points/touchpoints, main and exception flows, business objects, states, rules, permissions, and acceptance criteria.
- Development and Quality remain separate responsibility domains. Quality must not be nested inside Build.
- Shared state objects are not rendered as stages. Deployment success is not rendered as product success. Product closeout does not close an Incident Case.
- Graphviz remains the implementation path only if the main-map proof satisfies the approved hierarchy. If the proof still looks table-shaped or requires paragraph nodes, stop before Tasks 2–4 and amend this plan for a deterministic SVG generator; do not dilute the approved design.
- Do not touch unrelated worktree changes in `shared/reference/code-comments.md`, `shared/skills/rules-manager/references/mysql-db.md`, or `tools/eval/results/sql-schema-comments-smoke-20260729/`.

---

## Acceptance Scope

Implementation is acceptable only when current evidence proves all of the following:

- At normal desktop width, a first-time reader can identify the five main subsystems and trace the normal left-to-right path without reading a legend.
- Every subsystem shows a short purpose, its accountable components, and its boundary output.
- The Human Control Plane is visibly cross-cutting rather than a serial first stage.
- Product Manager capability scope includes user-facing business entry points/touchpoints and main/exception business flows.
- Authority topology distinguishes Human authority, Agent Owner accountability, and bounded execution Agents.
- Artifact/state view separates package lifecycle, Baseline, Candidate, Manifest, environment state, action evidence, Incident Case, and Phase/Demand outcomes.
- Failure view separates diagnostic, corrective, authority/incident, and terminal lanes; `RT` is visibly non-success and `R10` is the only success route.
- All four DOT files parse without warnings, all SVG files are valid XML, and both SVG and PNG bytes are deterministic on the recorded renderer version.
- No text is clipped or overlapped, no edge crosses a label, and the hierarchy remains legible in grayscale.
- The normative Markdown links resolve to the replaced SVG/PNG files.
- Repository quick regression passes, or an unrelated failure is reproduced against the pre-change commit and reported without being hidden.
- The human can review the four final projections and trace any displayed role, transition, artifact, or route back to the normative document.

## Non-goals

- No role Skill design or implementation.
- No Product Manager discovery method, template, or project-specific flow.
- No change to automated orchestration, runtime contracts, active-doc scope, deployment mechanisms, or `qft-tenants`.
- No full `R00`–`R10` route table on the main map.
- No decorative icon system, gradient, shadow, animation, or frontend application.

---

## File Structure

### Approved Sources

```text
docs/superpowers/specs/
  2026-07-30--one-human-agent-team-operating-architecture-v1.2--design.md
  2026-07-30--one-human-agent-operating-architecture-visual-redesign--design.md
```

Responsibilities:

- The V1.2 document remains the normative architecture and embeds the projections.
- The visual-redesign document remains the approved visual contract and records implementation status.

### Projection Suite

```text
docs/superpowers/specs/assets/
  2026-07-30--one-human-agent-team-operating-architecture-v1.2/
    team-battle-map.dot
    team-battle-map.svg
    team-battle-map.png
    authority-and-team-topology.dot
    authority-and-team-topology.svg
    authority-and-team-topology.png
    artifacts-versions-and-state.dot
    artifacts-versions-and-state.svg
    artifacts-versions-and-state.png
    failure-routing-and-terminal-outcomes.dot
    failure-routing-and-terminal-outcomes.svg
    failure-routing-and-terminal-outcomes.png
```

Each `.dot` file is the editable source for its adjacent generated pair. No generated SVG or PNG may contain information absent from the source.

## Canonical Visual Grammar

Every DOT file starts from these exact semantic defaults:

```dot
graph [
  bgcolor="#F7F9FC",
  fontname="PingFang SC",
  fontcolor="#152238",
  compound=true,
  newrank=true,
  outputorder=edgesfirst,
  pad="0.30",
  nodesep="0.30",
  ranksep="0.56",
  splines=ortho
];

node [
  shape=box,
  style="rounded,filled",
  fontname="PingFang SC",
  fontsize=11,
  fontcolor="#152238",
  color="#B8C2D1",
  fillcolor="#FFFFFF",
  margin="0.13,0.09",
  penwidth=1.2
];

edge [
  fontname="PingFang SC",
  fontsize=9,
  fontcolor="#40536D",
  color="#66768D",
  arrowsize=0.72,
  penwidth=1.25
];
```

Semantic palette and shape contract:

| Semantic type | Fill | Border/text | Required non-color marker |
|---|---|---|---|
| subsystem | `#F8FBFF` | `#24466F` | named `cluster_*` with uppercase subsystem title |
| accountable Owner | `#EAF2FF` | `#2459A9` | label begins `[AO]` |
| execution Agent | `#F3F5F8` | `#66768D` | label begins `[AE]` |
| evidence or verified state | `#E7F7F3` | `#0F766E` | label begins `[ART]` or `[STATE]` |
| Human authority/gate | `#FFF4D6` | `#A16207` | label begins `[H]` or `[H-GATE]`, `penwidth=2.0` |
| conditional Owner | same as Owner | `#66768D` | `style="rounded,dashed,filled"` and `[OPTIONAL]` |
| immutable Candidate | `#E7F7F3` | `#0F766E` | `peripheries=2` |
| failure/incident | `#FDECEC` | `#B42318` | explicit route or incident label |

Primary forward edges are solid. Human authority, optional activation, invalidation, and return edges are dashed and explicitly labelled. Invisible edges may control layout but must be commented `// layout only` and must never imply semantics.

---

### Task 1: Prove and Implement the Main Team Operating-System Map

**Files:**

- Modify: `docs/superpowers/specs/assets/2026-07-30--one-human-agent-team-operating-architecture-v1.2/team-battle-map.dot`
- Regenerate: `docs/superpowers/specs/assets/2026-07-30--one-human-agent-team-operating-architecture-v1.2/team-battle-map.svg`
- Regenerate: `docs/superpowers/specs/assets/2026-07-30--one-human-agent-team-operating-architecture-v1.2/team-battle-map.png`

**Interfaces:**

- Consumes: approved visual design; normative roles, `F01`–`F17` macro order, artifact classes, shared state domains, `R00`–`R10` macro return law.
- Produces: the canonical visual grammar proof and the five subsystem names/layout that Tasks 2–4 must reuse.

- [ ] **Step 1: Prove the current source violates the selected structure**

Run:

```bash
rg -n '<TABLE|shape=plain|battle_map \\[' \
  docs/superpowers/specs/assets/2026-07-30--one-human-agent-team-operating-architecture-v1.2/team-battle-map.dot
```

Expected: matches the monolithic `battle_map` table implementation. This is the failing structural baseline.

- [ ] **Step 2: Replace the table with four architectural bands**

Rewrite the DOT source with `rankdir=TB` and these exact bands:

```text
HEADER
  ONE-HUMAN + AGENT TEAM
  TARGET OPERATING ARCHITECTURE · V1.2 · VIEW R4
  M0 MANUAL CONTROL · Human-governed · Agent-executed · Evidence-driven

HUMAN CONTROL PLANE
  co-create value/direction
  accept exact artifact
  invoke next Owner
  execute test deployment
  execute production deployment
  business acceptance/disposition

MAIN SYSTEM PATH
  01 PRODUCT DEFINITION
  → 02 PROOF & PLAN
  → 03 BUILD
  → 04 QUALITY & RELEASE
  → 05 OUTCOME

SHARED STATE & EVIDENCE BACKBONE
  Phase Success Baseline
  Candidate
  Deployment Manifest
  Environment State
  Finding Route

FAILURE & INCIDENT LANE
  failure/gap → diagnose domain → earliest wrong Owner
  → invalidate affected evidence → re-enter every affected gate
  Incident Case closes independently
```

Implement the five main domains as `cluster_product`, `cluster_proof`, `cluster_build`, `cluster_quality`, and `cluster_outcome`. Each cluster contains:

| Cluster | One-line purpose | Components | Boundary output node |
|---|---|---|---|
| Product Definition | `Find the right problem and freeze the complete product boundary.` | `[AO] Product Director`; `[AO] Product Manager`; `[AO] Impact Owner`; dashed `[AO][OPTIONAL] UX Owner`; dashed `[AO][OPTIONAL] Architecture Owner` | `[ART] Director Decision Case · Product Definition Package · Impact Freeze` |
| Proof & Plan | `Define how success will be proved, then bound the work.` | `[AO] Test Design Owner`; `[AO] Tech Lead` | `[ART] Test Design Package · Tech Lead Package · Bounded Task Packets` |
| Build | `Produce one verified immutable Candidate ready for test deployment.` | `[AO] Development Owner`; `[AE] Developer`; `[AE] Code Fixer`; `[AE] Verifier`; `[AE] Code Reviewer`; `[H-GATE] Test Deployment` | `[ART] Phase Success Baseline · Candidate · Test Manifest · Test Admission · Test Outcome` |
| Quality & Release | `Independently qualify the Candidate and verify production.` | `[AO] Quality Owner`; `[AE] QA Executor`; `[AE] Quality Analyst`; `[H-GATE] Production Deployment`; `[AO] Production Verification` | `[ART] Release Package · Production Outcome · Production Verification Evidence` |
| Outcome | `Judge the real business result and close honestly.` | `[H] Business Acceptance`; `[AO] Product Director Closeout Recommendation`; `[H] Phase & Demand Disposition` | `[ART] Business Acceptance Record · Closeout Recommendation · Phase Outcome · Demand Outcome` |

Use these stable node families so the DOT remains auditable:

```text
human_*       Human Control Plane components
product_*     Product Definition components
proof_*       Proof & Plan components
build_*       Build components
quality_*     Quality & Release components
outcome_*     Outcome components
state_*       shared evidence/state backbone
failure_*     failure and Incident lane
```

Inside each subsystem, order nodes `purpose → Owner/executor group → boundary output`. Put `product_purpose`, `proof_purpose`, `build_purpose`, `quality_purpose`, and `outcome_purpose` in one `rank=same` subgraph to force the five-column main path. Use invisible edges only to align the Human and shared-state bands above and below those five anchors.

Product Manager gets a compact capability annotation, not a paragraph:

```text
Actors · User touchpoints · Main/exception flows
Objects · States · Rules · Permissions · AC
```

Use short handoff labels between subsystem boundary outputs:

```text
accepted definition
accepted proof & plan
trusted test outcome
trusted production evidence
```

Human Control Plane nodes connect with dashed authority edges only to the gates they actually govern. Do not draw a forward edge from the Human rail into Product Definition.

- [ ] **Step 3: Enforce the structural rejection check**

Run:

```bash
if rg -n '<TABLE|shape=plain|battle_map \\[' \
  docs/superpowers/specs/assets/2026-07-30--one-human-agent-team-operating-architecture-v1.2/team-battle-map.dot; then
  echo "monolithic table structure remains" >&2
  exit 1
fi
```

Expected: exit `0` with no matches.

- [ ] **Step 4: Produce two independent proof renders**

Run:

```bash
ASSET_DIR="docs/superpowers/specs/assets/2026-07-30--one-human-agent-team-operating-architecture-v1.2"
RENDER_CHECK="$(mktemp -d /tmp/org-claude-skills-main-map.XXXXXX)"

dot -Tsvg "$ASSET_DIR/team-battle-map.dot" \
  -o "$ASSET_DIR/team-battle-map.svg" 2>"$RENDER_CHECK/source.stderr"
dot -Tpng -Gdpi=144 "$ASSET_DIR/team-battle-map.dot" \
  -o "$ASSET_DIR/team-battle-map.png" 2>>"$RENDER_CHECK/source.stderr"
dot -Tsvg "$ASSET_DIR/team-battle-map.dot" \
  -o "$RENDER_CHECK/team-battle-map.svg" 2>"$RENDER_CHECK/check.stderr"
dot -Tpng -Gdpi=144 "$ASSET_DIR/team-battle-map.dot" \
  -o "$RENDER_CHECK/team-battle-map.png" 2>>"$RENDER_CHECK/check.stderr"

test ! -s "$RENDER_CHECK/source.stderr"
test ! -s "$RENDER_CHECK/check.stderr"
xmllint --noout "$ASSET_DIR/team-battle-map.svg"
xmllint --noout "$RENDER_CHECK/team-battle-map.svg"
cmp "$ASSET_DIR/team-battle-map.svg" "$RENDER_CHECK/team-battle-map.svg"
cmp "$ASSET_DIR/team-battle-map.png" "$RENDER_CHECK/team-battle-map.png"
magick identify "$ASSET_DIR/team-battle-map.png"

case "$RENDER_CHECK" in
  /tmp/org-claude-skills-main-map.*) rm -rf -- "$RENDER_CHECK" ;;
  *) echo "unsafe proof path: $RENDER_CHECK" >&2; exit 1 ;;
esac
```

Expected: no renderer warning, valid SVG, byte-identical render pairs, and a readable PNG identity line.

- [ ] **Step 5: Inspect the proof at normal scale and in grayscale**

Use `view_image` on the committed-path candidate:

```text
docs/superpowers/specs/assets/2026-07-30--one-human-agent-team-operating-architecture-v1.2/team-battle-map.png
```

Create a unique grayscale proof:

```bash
ASSET_DIR="docs/superpowers/specs/assets/2026-07-30--one-human-agent-team-operating-architecture-v1.2"
GRAY_PROOF="$(mktemp /tmp/org-claude-skills-main-map-gray.XXXXXX.png)"
magick "$ASSET_DIR/team-battle-map.png" -colorspace Gray "$GRAY_PROOF"
printf 'GRAY_PROOF=%s\n' "$GRAY_PROOF"
printf 'CLEANUP=rm -f -- %q\n' "$GRAY_PROOF"
```

Use `view_image` on the exact printed `GRAY_PROOF` path. After inspection, execute the exact printed `CLEANUP` command.

Reject the proof if any of these is true:

- the five subsystem names are not the first dominant reading layer;
- the normal path requires a legend;
- Product Manager's touchpoints and main/exception flows are not visible;
- the Human rail looks like stage zero;
- Quality looks contained by Build;
- a state node looks like a sixth stage;
- any component needs zooming to read a paragraph;
- an edge crosses a label;
- color removal destroys Human, conditional, immutable, or failure distinctions.

If rejected, revise only `team-battle-map.dot` and repeat Steps 3–5. If the accepted hierarchy cannot be achieved without returning to table cells or paragraph nodes, stop the implementation and trigger the Graphviz fallback rule in Global Constraints.

- [ ] **Step 6: Promote the accepted render and commit the proof**

Run:

```bash
ASSET_DIR="docs/superpowers/specs/assets/2026-07-30--one-human-agent-team-operating-architecture-v1.2"
dot -Tsvg "$ASSET_DIR/team-battle-map.dot" -o "$ASSET_DIR/team-battle-map.svg"
dot -Tpng -Gdpi=144 "$ASSET_DIR/team-battle-map.dot" \
  -o "$ASSET_DIR/team-battle-map.png"
git diff --check -- \
  "$ASSET_DIR/team-battle-map.dot" \
  "$ASSET_DIR/team-battle-map.svg"
git add -- \
  "$ASSET_DIR/team-battle-map.dot" \
  "$ASSET_DIR/team-battle-map.svg" \
  "$ASSET_DIR/team-battle-map.png"
git commit -m "docs: redesign team operating architecture map"
```

Expected: exactly three projection files in the commit.

---

### Task 2: Rebuild Authority and Team Topology as Three Explicit Layers

**Files:**

- Modify: `docs/superpowers/specs/assets/2026-07-30--one-human-agent-team-operating-architecture-v1.2/authority-and-team-topology.dot`
- Regenerate: `docs/superpowers/specs/assets/2026-07-30--one-human-agent-team-operating-architecture-v1.2/authority-and-team-topology.svg`
- Regenerate: `docs/superpowers/specs/assets/2026-07-30--one-human-agent-team-operating-architecture-v1.2/authority-and-team-topology.png`

**Interfaces:**

- Consumes: Task 1 palette, typography, node markers, subsystem names, and Human cross-cutting semantics.
- Produces: one authority topology that makes decision rights, accountability, bounded execution, and prohibited crossings explicit.

- [ ] **Step 1: Record the failing table baseline**

Run:

```bash
rg -n '<TABLE|shape=plain|topology \\[' \
  docs/superpowers/specs/assets/2026-07-30--one-human-agent-team-operating-architecture-v1.2/authority-and-team-topology.dot
```

Expected: matches the current monolithic topology table.

- [ ] **Step 2: Implement three visual layers**

Use `rankdir=TB` and these layers:

```text
HUMAN CONTROL PLANE
  direction/value · exact acceptance · next-Owner invocation
  environment action · risk/incident authority · final disposition

ACCOUNTABLE OWNER PLANE
  Product Definition subsystem
  Proof & Plan subsystem
  Development domain
  Independent Quality domain
  Outcome activities

BOUNDED EXECUTION PLANE
  Developer · Code Fixer · Verifier · Code Reviewer
  QA Executor · Quality Analyst
```

Rules:

- draw Human-to-Owner edges as dashed `authority / co-create / accept / invoke`, never as execution flow;
- draw Owner-to-executor edges as solid `delegates bounded work`;
- keep UX Owner and Architecture Owner dashed and independently conditional;
- group Development execution Agents only under Development Owner;
- group QA Executor and Quality Analyst only under Quality Owner;
- show `Development Owner ≠ independent QA/deployment authority`;
- show `Quality Owner = NO CODE CHANGE`;
- show `PRODUCT authority ≠ INCIDENT_REMEDIATION authority`;
- do not repeat the five-stage process; this view answers only who may decide, own, and execute.

- [ ] **Step 3: Reject table structure, render twice, and inspect**

Run:

```bash
ASSET_DIR="docs/superpowers/specs/assets/2026-07-30--one-human-agent-team-operating-architecture-v1.2"
RENDER_CHECK="$(mktemp -d /tmp/org-claude-skills-authority-map.XXXXXX)"

if rg -n '<TABLE|shape=plain|topology \\[' \
  "$ASSET_DIR/authority-and-team-topology.dot"; then
  echo "monolithic table structure remains" >&2
  exit 1
fi

dot -Tsvg "$ASSET_DIR/authority-and-team-topology.dot" \
  -o "$ASSET_DIR/authority-and-team-topology.svg" \
  2>"$RENDER_CHECK/source.stderr"
dot -Tpng -Gdpi=144 "$ASSET_DIR/authority-and-team-topology.dot" \
  -o "$ASSET_DIR/authority-and-team-topology.png" \
  2>>"$RENDER_CHECK/source.stderr"
dot -Tsvg "$ASSET_DIR/authority-and-team-topology.dot" \
  -o "$RENDER_CHECK/authority-and-team-topology.svg" \
  2>"$RENDER_CHECK/check.stderr"
dot -Tpng -Gdpi=144 "$ASSET_DIR/authority-and-team-topology.dot" \
  -o "$RENDER_CHECK/authority-and-team-topology.png" \
  2>>"$RENDER_CHECK/check.stderr"

test ! -s "$RENDER_CHECK/source.stderr"
test ! -s "$RENDER_CHECK/check.stderr"
xmllint --noout "$ASSET_DIR/authority-and-team-topology.svg"
xmllint --noout "$RENDER_CHECK/authority-and-team-topology.svg"
cmp "$ASSET_DIR/authority-and-team-topology.svg" \
  "$RENDER_CHECK/authority-and-team-topology.svg"
cmp "$ASSET_DIR/authority-and-team-topology.png" \
  "$RENDER_CHECK/authority-and-team-topology.png"
magick identify "$ASSET_DIR/authority-and-team-topology.png"

case "$RENDER_CHECK" in
  /tmp/org-claude-skills-authority-map.*) rm -rf -- "$RENDER_CHECK" ;;
  *) echo "unsafe proof path: $RENDER_CHECK" >&2; exit 1 ;;
esac

GRAY_PROOF="$(mktemp /tmp/org-claude-skills-authority-map-gray.XXXXXX.png)"
magick "$ASSET_DIR/authority-and-team-topology.png" -colorspace Gray "$GRAY_PROOF"
printf 'GRAY_PROOF=%s\n' "$GRAY_PROOF"
printf 'CLEANUP=rm -f -- %q\n' "$GRAY_PROOF"
```

Use `view_image` on the final-path PNG and the exact printed `GRAY_PROOF` path, then execute the exact printed `CLEANUP` command.

Expected:

- no `<TABLE`, `shape=plain`, or `topology [` match;
- no Graphviz warning;
- byte-identical SVG and PNG pairs;
- valid SVG;
- normal and grayscale views preserve all three authority layers;
- no edge visually grants deployment, QA, code-change, or disposition authority to the wrong role.

- [ ] **Step 4: Promote and commit**

```bash
ASSET_DIR="docs/superpowers/specs/assets/2026-07-30--one-human-agent-team-operating-architecture-v1.2"
dot -Tsvg "$ASSET_DIR/authority-and-team-topology.dot" \
  -o "$ASSET_DIR/authority-and-team-topology.svg"
dot -Tpng -Gdpi=144 "$ASSET_DIR/authority-and-team-topology.dot" \
  -o "$ASSET_DIR/authority-and-team-topology.png"
git diff --check -- \
  "$ASSET_DIR/authority-and-team-topology.dot" \
  "$ASSET_DIR/authority-and-team-topology.svg"
git add -- \
  "$ASSET_DIR/authority-and-team-topology.dot" \
  "$ASSET_DIR/authority-and-team-topology.svg" \
  "$ASSET_DIR/authority-and-team-topology.png"
git commit -m "docs: redesign agent team authority topology"
```

Expected: exactly three topology projection files in the commit.

---

### Task 3: Rebuild Artifacts, Versions, and State as a Lifecycle Architecture

**Files:**

- Modify: `docs/superpowers/specs/assets/2026-07-30--one-human-agent-team-operating-architecture-v1.2/artifacts-versions-and-state.dot`
- Regenerate: `docs/superpowers/specs/assets/2026-07-30--one-human-agent-team-operating-architecture-v1.2/artifacts-versions-and-state.svg`
- Regenerate: `docs/superpowers/specs/assets/2026-07-30--one-human-agent-team-operating-architecture-v1.2/artifacts-versions-and-state.png`

**Interfaces:**

- Consumes: Task 1 visual grammar and the normative artifact/state identities.
- Produces: one lifecycle view that prevents package acceptance, release identity, environment state, incident state, and terminal outcome from being collapsed.

- [ ] **Step 1: Record the failing catalog baseline**

Run:

```bash
rg -n '<TABLE|shape=plain|artifact_map \\[' \
  docs/superpowers/specs/assets/2026-07-30--one-human-agent-team-operating-architecture-v1.2/artifacts-versions-and-state.dot
```

Expected: matches the current nested-table catalog.

- [ ] **Step 2: Implement four connected lifecycle lanes**

Use `rankdir=LR` and these lanes:

```text
PACKAGE LINEAGE
  Director Decision → Product Definition → Impact Freeze
  → Test Design → Tech Lead → Task Packets

PACKAGE LIFECYCLE
  DRAFT → READY_FOR_REVIEW → [H] ACCEPTED
  BLOCKED / STALE → new DRAFT revision
  ACCEPTED → SUPERSEDED only as history

RELEASE & ENVIRONMENT IDENTITY
  Phase Success Baseline
  → Candidate (double border)
  → environment-specific Manifest
  → authorized action
  → trustworthy outcome
  → current Environment State

ORTHOGONAL OUTCOME / INCIDENT STATE
  Incident Case → independent current-safety resolution
  Phase Outcome
  Demand Outcome
```

Required labels:

- `Human ACCEPTS exact immutable revision`;
- `Candidate change → new Candidate + affected gates`;
- `Manifest-only change → same Candidate, new deployment identity`;
- `authorization ≠ attempt ≠ observation ≠ outcome`;
- `failed / partial / unknown → environment BLOCKED`;
- `product disposition does not close Incident Case`;
- `incident evidence has no product-success authority`.

Render invalidation as a dashed red edge from changed upstream identity to affected downstream evidence. Do not render the lifecycle as a state table.

- [ ] **Step 3: Reject table structure, render twice, and inspect**

Run:

```bash
ASSET_DIR="docs/superpowers/specs/assets/2026-07-30--one-human-agent-team-operating-architecture-v1.2"
RENDER_CHECK="$(mktemp -d /tmp/org-claude-skills-artifact-map.XXXXXX)"

if rg -n '<TABLE|shape=plain|artifact_map \\[' \
  "$ASSET_DIR/artifacts-versions-and-state.dot"; then
  echo "monolithic table structure remains" >&2
  exit 1
fi

dot -Tsvg "$ASSET_DIR/artifacts-versions-and-state.dot" \
  -o "$ASSET_DIR/artifacts-versions-and-state.svg" \
  2>"$RENDER_CHECK/source.stderr"
dot -Tpng -Gdpi=144 "$ASSET_DIR/artifacts-versions-and-state.dot" \
  -o "$ASSET_DIR/artifacts-versions-and-state.png" \
  2>>"$RENDER_CHECK/source.stderr"
dot -Tsvg "$ASSET_DIR/artifacts-versions-and-state.dot" \
  -o "$RENDER_CHECK/artifacts-versions-and-state.svg" \
  2>"$RENDER_CHECK/check.stderr"
dot -Tpng -Gdpi=144 "$ASSET_DIR/artifacts-versions-and-state.dot" \
  -o "$RENDER_CHECK/artifacts-versions-and-state.png" \
  2>>"$RENDER_CHECK/check.stderr"

test ! -s "$RENDER_CHECK/source.stderr"
test ! -s "$RENDER_CHECK/check.stderr"
xmllint --noout "$ASSET_DIR/artifacts-versions-and-state.svg"
xmllint --noout "$RENDER_CHECK/artifacts-versions-and-state.svg"
cmp "$ASSET_DIR/artifacts-versions-and-state.svg" \
  "$RENDER_CHECK/artifacts-versions-and-state.svg"
cmp "$ASSET_DIR/artifacts-versions-and-state.png" \
  "$RENDER_CHECK/artifacts-versions-and-state.png"
magick identify "$ASSET_DIR/artifacts-versions-and-state.png"

case "$RENDER_CHECK" in
  /tmp/org-claude-skills-artifact-map.*) rm -rf -- "$RENDER_CHECK" ;;
  *) echo "unsafe proof path: $RENDER_CHECK" >&2; exit 1 ;;
esac

GRAY_PROOF="$(mktemp /tmp/org-claude-skills-artifact-map-gray.XXXXXX.png)"
magick "$ASSET_DIR/artifacts-versions-and-state.png" -colorspace Gray "$GRAY_PROOF"
printf 'GRAY_PROOF=%s\n' "$GRAY_PROOF"
printf 'CLEANUP=rm -f -- %q\n' "$GRAY_PROOF"
```

Use `view_image` on the final-path PNG and the exact printed `GRAY_PROOF` path, then execute the exact printed `CLEANUP` command.

Expected:

- no table/shape monolith;
- all state domains remain distinct in normal and grayscale views;
- Candidate is identifiable without color;
- failed/partial/unknown actions cannot be visually followed into QA, acceptance, or success;
- byte-deterministic outputs and valid SVG.

- [ ] **Step 4: Promote and commit**

```bash
ASSET_DIR="docs/superpowers/specs/assets/2026-07-30--one-human-agent-team-operating-architecture-v1.2"
dot -Tsvg "$ASSET_DIR/artifacts-versions-and-state.dot" \
  -o "$ASSET_DIR/artifacts-versions-and-state.svg"
dot -Tpng -Gdpi=144 "$ASSET_DIR/artifacts-versions-and-state.dot" \
  -o "$ASSET_DIR/artifacts-versions-and-state.png"
git diff --check -- \
  "$ASSET_DIR/artifacts-versions-and-state.dot" \
  "$ASSET_DIR/artifacts-versions-and-state.svg"
git add -- \
  "$ASSET_DIR/artifacts-versions-and-state.dot" \
  "$ASSET_DIR/artifacts-versions-and-state.svg" \
  "$ASSET_DIR/artifacts-versions-and-state.png"
git commit -m "docs: redesign architecture artifact lifecycle"
```

Expected: exactly three artifact/state projection files in the commit.

---

### Task 4: Rebuild Failure Routing and Real Completion as Swimlanes

**Files:**

- Modify: `docs/superpowers/specs/assets/2026-07-30--one-human-agent-team-operating-architecture-v1.2/failure-routing-and-terminal-outcomes.dot`
- Regenerate: `docs/superpowers/specs/assets/2026-07-30--one-human-agent-team-operating-architecture-v1.2/failure-routing-and-terminal-outcomes.svg`
- Regenerate: `docs/superpowers/specs/assets/2026-07-30--one-human-agent-team-operating-architecture-v1.2/failure-routing-and-terminal-outcomes.png`

**Interfaces:**

- Consumes: Task 1 failure grammar and normative `R00`–`R10`, `D00`–`D02`, `IR00`–`IR03`, `F16`, and `F17` semantics.
- Produces: one routing view that distinguishes diagnosis, correction, authority/incident handling, and real terminal outcomes.

- [ ] **Step 1: Record the failing route-table baseline**

Run:

```bash
rg -n '<TABLE|shape=plain|routing_map \\[' \
  docs/superpowers/specs/assets/2026-07-30--one-human-agent-team-operating-architecture-v1.2/failure-routing-and-terminal-outcomes.dot
```

Expected: matches the current nested route tables.

- [ ] **Step 2: Implement four horizontal swimlanes**

Use `rankdir=LR` with clusters:

```text
DIAGNOSTIC
  R00 unknown domain
  → bounded diagnostic Owner
  → evidence only
  → back to R00
  production-only branch: D00 → D01 [H-GATE] → D02 → R00

CORRECTIVE
  R01 Product Director
  R02 Product Manager
  R03 Impact Owner
  R04 UX Owner
  R05 Architecture Owner
  R06 Test Design Owner
  R07 Development Owner
  → invalidate affected evidence
  → rerun every affected gate

AUTHORITY & INCIDENT
  R08 reconcile environment/permission/action
  R09 contain + open/preserve exact Incident Case
  IR00 → IR01 [H] → IR02 affected remediation gates → IR03 independent safety proof

REAL COMPLETION
  trustworthy production evidence
  → [H] Business Acceptance
  → Product Director recommendation
  → [H] Phase/Demand disposition
  RT NON-SUCCESS
  R10 ONLY SUCCESS ROUTE
```

Required guards:

- unknown root cause cannot enter correction, PASS, release, or closeout;
- post-Baseline `R01`–`R07` changes must map old obligations;
- `R09` blocks success until safe state, incident resolution, settled mutation, one non-diagnostic route, and fresh Human authority;
- production diagnostics carry `NO RELEASE PASS`;
- `F16 NEW PHASE` and `F17 SAME PHASE RESUME` are mutually exclusive;
- product closeout never closes an Incident Case.

Use red solid/dashed connectors plus explicit `BLOCKED`, `NON-SUCCESS`, or route IDs. Do not rely on red color alone.

- [ ] **Step 3: Reject table structure, render twice, and inspect**

Run:

```bash
ASSET_DIR="docs/superpowers/specs/assets/2026-07-30--one-human-agent-team-operating-architecture-v1.2"
RENDER_CHECK="$(mktemp -d /tmp/org-claude-skills-routing-map.XXXXXX)"

if rg -n '<TABLE|shape=plain|routing_map \\[' \
  "$ASSET_DIR/failure-routing-and-terminal-outcomes.dot"; then
  echo "monolithic table structure remains" >&2
  exit 1
fi

dot -Tsvg "$ASSET_DIR/failure-routing-and-terminal-outcomes.dot" \
  -o "$ASSET_DIR/failure-routing-and-terminal-outcomes.svg" \
  2>"$RENDER_CHECK/source.stderr"
dot -Tpng -Gdpi=144 "$ASSET_DIR/failure-routing-and-terminal-outcomes.dot" \
  -o "$ASSET_DIR/failure-routing-and-terminal-outcomes.png" \
  2>>"$RENDER_CHECK/source.stderr"
dot -Tsvg "$ASSET_DIR/failure-routing-and-terminal-outcomes.dot" \
  -o "$RENDER_CHECK/failure-routing-and-terminal-outcomes.svg" \
  2>"$RENDER_CHECK/check.stderr"
dot -Tpng -Gdpi=144 "$ASSET_DIR/failure-routing-and-terminal-outcomes.dot" \
  -o "$RENDER_CHECK/failure-routing-and-terminal-outcomes.png" \
  2>>"$RENDER_CHECK/check.stderr"

test ! -s "$RENDER_CHECK/source.stderr"
test ! -s "$RENDER_CHECK/check.stderr"
xmllint --noout "$ASSET_DIR/failure-routing-and-terminal-outcomes.svg"
xmllint --noout "$RENDER_CHECK/failure-routing-and-terminal-outcomes.svg"
cmp "$ASSET_DIR/failure-routing-and-terminal-outcomes.svg" \
  "$RENDER_CHECK/failure-routing-and-terminal-outcomes.svg"
cmp "$ASSET_DIR/failure-routing-and-terminal-outcomes.png" \
  "$RENDER_CHECK/failure-routing-and-terminal-outcomes.png"
magick identify "$ASSET_DIR/failure-routing-and-terminal-outcomes.png"

case "$RENDER_CHECK" in
  /tmp/org-claude-skills-routing-map.*) rm -rf -- "$RENDER_CHECK" ;;
  *) echo "unsafe proof path: $RENDER_CHECK" >&2; exit 1 ;;
esac

GRAY_PROOF="$(mktemp /tmp/org-claude-skills-routing-map-gray.XXXXXX.png)"
magick "$ASSET_DIR/failure-routing-and-terminal-outcomes.png" \
  -colorspace Gray "$GRAY_PROOF"
printf 'GRAY_PROOF=%s\n' "$GRAY_PROOF"
printf 'CLEANUP=rm -f -- %q\n' "$GRAY_PROOF"
```

Use `view_image` on the final-path PNG and the exact printed `GRAY_PROOF` path, then execute the exact printed `CLEANUP` command.

Expected:

- the four lanes are immediately distinguishable;
- `R00` loops to diagnosis rather than correction;
- the incident lane remains independent;
- `RT` cannot be mistaken for success;
- `R10` is the only visible success route;
- normal/grayscale layouts have no edge-label collision;
- byte-deterministic outputs and valid SVG.

- [ ] **Step 4: Promote and commit**

```bash
ASSET_DIR="docs/superpowers/specs/assets/2026-07-30--one-human-agent-team-operating-architecture-v1.2"
dot -Tsvg "$ASSET_DIR/failure-routing-and-terminal-outcomes.dot" \
  -o "$ASSET_DIR/failure-routing-and-terminal-outcomes.svg"
dot -Tpng -Gdpi=144 "$ASSET_DIR/failure-routing-and-terminal-outcomes.dot" \
  -o "$ASSET_DIR/failure-routing-and-terminal-outcomes.png"
git diff --check -- \
  "$ASSET_DIR/failure-routing-and-terminal-outcomes.dot" \
  "$ASSET_DIR/failure-routing-and-terminal-outcomes.svg"
git add -- \
  "$ASSET_DIR/failure-routing-and-terminal-outcomes.dot" \
  "$ASSET_DIR/failure-routing-and-terminal-outcomes.svg" \
  "$ASSET_DIR/failure-routing-and-terminal-outcomes.png"
git commit -m "docs: redesign failure routing architecture"
```

Expected: exactly three route/outcome projection files in the commit.

---

### Task 5: Synchronize View Metadata and Prove the Complete Suite

**Files:**

- Modify: `docs/superpowers/specs/2026-07-30--one-human-agent-team-operating-architecture-v1.2--design.md`
- Modify: `docs/superpowers/specs/2026-07-30--one-human-agent-operating-architecture-visual-redesign--design.md`
- Verify: all twelve projection files in the existing asset directory.

**Interfaces:**

- Consumes: accepted outputs from Tasks 1–4.
- Produces: one synchronized R4 visual suite, current implementation status, reproducibility evidence, and user-reviewable projections.

- [ ] **Step 1: Update view-only metadata**

Make only these status changes:

```text
V1.2 normative document:
  View revision: R3 → R4

Visual redesign document:
  Implementation: not started. → Implementation: completed; final human visual acceptance pending.
```

Do not change `TARGET-V1.2`, normative tables, guards, invariants, role definitions, runtime status, or activation boundary.

- [ ] **Step 2: Prove source structure and renderer determinism for all views**

Run:

```bash
ASSET_DIR="docs/superpowers/specs/assets/2026-07-30--one-human-agent-team-operating-architecture-v1.2"
RENDER_CHECK="$(mktemp -d /tmp/org-claude-skills-architecture-suite.XXXXXX)"

if rg -n '<TABLE|shape=plain|battle_map \\[|topology \\[|artifact_map \\[|routing_map \\[' \
  "$ASSET_DIR"/*.dot; then
  echo "table-shaped projection remains" >&2
  exit 1
fi

for VIEW_NAME in \
  team-battle-map \
  authority-and-team-topology \
  artifacts-versions-and-state \
  failure-routing-and-terminal-outcomes
do
  dot -Tsvg "$ASSET_DIR/$VIEW_NAME.dot" \
    -o "$RENDER_CHECK/$VIEW_NAME.svg" \
    2>"$RENDER_CHECK/$VIEW_NAME.stderr"
  dot -Tpng -Gdpi=144 "$ASSET_DIR/$VIEW_NAME.dot" \
    -o "$RENDER_CHECK/$VIEW_NAME.png" \
    2>>"$RENDER_CHECK/$VIEW_NAME.stderr"

  test ! -s "$RENDER_CHECK/$VIEW_NAME.stderr"
  xmllint --noout "$RENDER_CHECK/$VIEW_NAME.svg"
  cmp "$ASSET_DIR/$VIEW_NAME.svg" "$RENDER_CHECK/$VIEW_NAME.svg"
  cmp "$ASSET_DIR/$VIEW_NAME.png" "$RENDER_CHECK/$VIEW_NAME.png"
  magick identify "$ASSET_DIR/$VIEW_NAME.png"
done

dot -V

case "$RENDER_CHECK" in
  /tmp/org-claude-skills-architecture-suite.*) rm -rf -- "$RENDER_CHECK" ;;
  *) echo "unsafe proof path: $RENDER_CHECK" >&2; exit 1 ;;
esac
```

Expected: no source rejection, no renderer warnings, valid XML, committed outputs equal a fresh render byte-for-byte, and four PNG identity lines. Record the exact Graphviz version in the final evidence.

- [ ] **Step 3: Validate links and inspect the four-view suite**

Run:

```bash
ASSET_DIR="docs/superpowers/specs/assets/2026-07-30--one-human-agent-team-operating-architecture-v1.2"
for VIEW_NAME in \
  team-battle-map \
  authority-and-team-topology \
  artifacts-versions-and-state \
  failure-routing-and-terminal-outcomes
do
  test -f "$ASSET_DIR/$VIEW_NAME.dot"
  test -f "$ASSET_DIR/$VIEW_NAME.svg"
  test -f "$ASSET_DIR/$VIEW_NAME.png"
done

git diff --check -- \
  docs/superpowers/specs/2026-07-30--one-human-agent-team-operating-architecture-v1.2--design.md \
  docs/superpowers/specs/2026-07-30--one-human-agent-operating-architecture-visual-redesign--design.md \
  "$ASSET_DIR"
```

Use `view_image` on all four final PNG files. Create four unique grayscale proofs, print their paths, inspect those exact paths, then delete those exact files:

```bash
ASSET_DIR="docs/superpowers/specs/assets/2026-07-30--one-human-agent-team-operating-architecture-v1.2"
for VIEW_NAME in \
  team-battle-map \
  authority-and-team-topology \
  artifacts-versions-and-state \
  failure-routing-and-terminal-outcomes
do
  GRAY_PROOF="$(mktemp "/tmp/org-claude-skills-$VIEW_NAME-gray.XXXXXX.png")"
  magick "$ASSET_DIR/$VIEW_NAME.png" -colorspace Gray "$GRAY_PROOF"
  printf '%s=%s\n' "$VIEW_NAME" "$GRAY_PROOF"
  printf 'CLEANUP=rm -f -- %q\n' "$GRAY_PROOF"
done
```

Compare each diagram against its single question:

| View | Question that must be answered |
|---|---|
| Team operating-system map | What does each stage do, what follows it, and what evidence permits the handoff? |
| Authority and team topology | Who decides, who owns, who executes, and which boundary must not be crossed? |
| Artifacts, versions, and state | What is handed over, which identity is current, and what becomes stale or blocked? |
| Failure routing and real completion | Where does failure return, what becomes invalid, and what counts as real completion? |

Any diagram that cannot answer its one question without reading the normative tables remains incomplete.

- [ ] **Step 4: Run repository regression and scope audit**

Run:

```bash
bash tests/run-all.sh --quick
git diff --check
git status --short
git diff --stat HEAD~4..HEAD
```

Expected:

- quick gate passes;
- no whitespace error;
- only the twelve projection files and two in-scope specification status lines are changed across implementation commits;
- the three pre-existing unrelated worktree paths remain untracked/modified but unstaged and untouched.

If the repository gate fails, reproduce the same command against the pre-implementation commit before deciding whether the failure is in scope. Do not weaken or skip a gate to obtain green output.

- [ ] **Step 5: Commit metadata and hand off final visual acceptance**

Stage only the two specification files and commit:

```bash
git add -- \
  docs/superpowers/specs/2026-07-30--one-human-agent-team-operating-architecture-v1.2--design.md \
  docs/superpowers/specs/2026-07-30--one-human-agent-operating-architecture-visual-redesign--design.md
git diff --cached --check
git diff --cached --name-status
git commit -m "docs: publish operating architecture visual revision"
```

Final handoff must:

- show the main map inline and link all four SVG/PNG projections;
- report the exact commits and Graphviz version;
- distinguish deterministic/static validation from human visual acceptance;
- state that the target architecture is still not runtime-active;
- request the human's final visual acceptance before using the diagrams as the baseline for role-by-role Skill evaluation.
