# One-Human + Agent Operating Architecture Visual Redesign

## Status

- Visual direction: approved by the human on 2026-07-30.
- Written design: pending final human review.
- Implementation: not started.
- Normative architecture: unchanged.
- Runtime activation: out of scope.

## Goal

Replace the current table-like architecture projections with a professional operating-system architecture that lets a reader answer, without reading the normative specification:

1. What does each team stage do?
2. Who owns it?
3. What is the next stage?
4. What evidence permits the handoff?
5. Where does the human co-create, authorize, deploy, and decide?
6. Where do failures and operational incidents go?

The visual suite must remain rigorous enough for an Agent to map every displayed component and transition back to the normative architecture.

## Source-of-Truth Boundary

The normative source remains:

[`2026-07-30--one-human-agent-team-operating-architecture-v1.2--design.md`](2026-07-30--one-human-agent-team-operating-architecture-v1.2--design.md)

The redesigned diagrams are projections only. They must not:

- create a new role, authority, flow, artifact, state, or terminal outcome;
- weaken or reinterpret a normative guard;
- replace the normative contract with visual proximity or implied sequencing;
- present the target architecture as current runtime behavior.

If a visual conflicts with the normative document, the visual is wrong.

## Why the Current Visuals Fail

The problem is structural, not decorative:

- the main diagram is a large HTML table rendered through Graphviz;
- every sentence has nearly the same visual weight;
- the reader has no dominant left-to-right path;
- roles, activities, human authority, artifacts, guards, and exceptions compete in the same cells;
- the image is technically complete but unreadable at normal viewing scale;
- color fills divide table regions but do not establish an architecture grammar;
- long mixed-language labels make the result resemble a spreadsheet export rather than an operating model.

Changing colors, fonts, or rounded corners would only polish the wrong structure.

## Options Considered

### A. Executive Journey Map

A single horizontal journey with five macro stages and a human control rail.

Strength:

- fastest human comprehension;
- strong narrative and executive presentation.

Weakness:

- underspecifies ownership boundaries and subsystem relationships;
- risks looking like a process infographic rather than an architecture.

### B. Operating-System Architecture

Model the team as bounded subsystems containing Owner and Human Gate components. Use arrows for the next stage, boundary outputs for handoff evidence, and shared rails for state and failure handling.

Strength:

- answers what each stage does and what follows it;
- visually separates subsystem, component, authority, evidence, and exception semantics;
- supports both human comprehension and Agent traceability.

Weakness:

- requires stricter content discipline;
- cannot carry role-method details without becoming dense again.

Decision: **selected**.

### C. Mission-Control Circuit

A central Human authority core surrounded by an adaptive delivery loop and an independent incident loop.

Strength:

- communicates feedback and human governance strongly;
- visually distinctive.

Weakness:

- weakens explicit stage order and handoff evidence;
- makes detailed return routing harder to read.

## Selected Information Architecture

### Header

The title remains:

```text
ONE-HUMAN + AGENT TEAM
```

Supporting metadata:

```text
TARGET OPERATING ARCHITECTURE · V1.2
M0 · MANUAL CONTROL
Human-governed · Agent-executed · Evidence-driven
```

The header must make target/runtime status visible without competing with the architecture.

### Human Control Plane

A single cross-cutting rail sits above the team subsystems.

It shows only stable human authority categories:

- co-create value and direction;
- accept exact stage artifacts;
- invoke the next Owner;
- execute test deployment;
- execute production deployment;
- perform business acceptance and disposition.

It must not appear as a serial first stage.

### Five Team Subsystems

The main reading path is left to right.

#### 1. Product Definition System

Components:

- Product Director;
- Product Manager;
- Impact Owner;
- conditional UX Owner;
- conditional Architecture Owner.

Product Manager capability-level content must include:

- business actors;
- user-facing business entry points and touchpoints;
- main business flow;
- exception business flows;
- business objects;
- states;
- rules;
- permissions;
- acceptance criteria.

This is capability scope, not a project-specific business-flow instance.

Boundary output:

```text
Director Decision Case
Product Definition Package
Impact Freeze
```

#### 2. Proof and Plan System

Components:

- Test Design Owner;
- Tech Lead.

Boundary output:

```text
Test Design Package
Tech Lead Package
Bounded Task Packets
```

#### 3. Build System

Components:

- Development Owner;
- Developer;
- Code Fixer;
- Verifier;
- Code Reviewer;
- Human Test Deployment Gate.

Boundary output:

```text
Phase Success Baseline
Immutable Candidate
Test Deployment Manifest
Test Admission Package
Trustworthy Test Deployment Outcome
```

#### 4. Quality and Release System

Components:

- Quality Owner;
- QA Executor;
- Quality Analyst;
- Human Production Deployment Gate;
- Quality Owner production verification activity.

Boundary output:

```text
Release Package
Trustworthy Production Deployment Outcome
Production Verification Evidence
```

Quality must remain visually independent from Development. Quality components must never appear nested inside the Build System.

#### 5. Outcome System

Components:

- Human Business Acceptance;
- Product Director closeout recommendation;
- Human Phase and Demand disposition.

Boundary output:

```text
Business Acceptance Record
Closeout Recommendation
Phase Outcome
Demand Outcome
```

Deployment success must not visually imply product success.

### Boundary Handoffs

Every subsystem-to-subsystem arrow answers:

```text
What exact accepted output permits entry to the next subsystem?
```

Arrow labels remain short. Detailed guards stay in the normative document.

The visual grammar is:

- subsystem: bounded responsibility domain;
- component: Owner, execution group, or Human Gate;
- arrow: next valid subsystem;
- boundary output: evidence required for the handoff;
- dashed component: conditionally activated Owner;
- gold diamond or gold-accent component: human authority;
- red lane: failure or incident path.

### Shared State and Evidence Backbone

A separate rail below the main system path shows state that crosses subsystem boundaries:

- Phase Success Baseline;
- Candidate;
- Deployment Manifest;
- current Environment State;
- Finding Route.

These objects must not be shown as process stages.

### Failure and Incident Lane

A separate bottom lane shows the macro return law:

```text
failure or gap
→ diagnose the root-cause domain
→ return to the earliest wrong Owner
→ re-enter from every affected gate
```

The lane must also state:

- an operational Incident Case closes independently;
- product closeout does not close an incident;
- unknown cause remains diagnostic;
- failed or indeterminate environment action cannot enter the success path.

The main map does not display the full `R00`–`R10` route table.

## Role-Detail Boundary

The architecture uses three levels of detail:

### Architecture level

Shows:

- capability boundary;
- Owner;
- stable input and output class;
- next subsystem;
- human authority.

### Skill-contract level

Defined later in each role Skill:

- discovery method;
- questions and reasoning procedure;
- templates;
- detailed artifacts;
- GO gates;
- failure handling;
- evaluations.

### Demand-instance level

Created when the team runs:

- actual business entry points;
- the real business flow;
- actual states and rules;
- project-specific impact;
- concrete acceptance evidence.

Demand-instance details must never be hard-coded into the macro architecture.

## Supporting Views

The suite keeps one main map and three orthogonal supporting views.

### Authority and Team Topology

Question answered:

```text
Who may decide, who owns, who executes, and who must not cross the boundary?
```

Use three visual layers:

- Human Control Plane;
- Agent Owner subsystem containers;
- bounded Execution Agents.

### Artifacts, Versions, and State

Question answered:

```text
What is handed over, which identity is current, and what becomes stale?
```

Use a lifecycle and identity architecture, not a catalog table.

Keep distinct:

- package lifecycle;
- Phase Success Baseline;
- Candidate;
- Manifest;
- environment state;
- action evidence;
- Incident Case;
- Phase and Demand outcome.

### Failure Routing and Real Completion

Question answered:

```text
Where does failure return, what becomes invalid, and what counts as real completion?
```

Use swimlanes:

- diagnostic;
- corrective;
- environment and incident;
- terminal outcome.

Show `RT` as non-success and `R10` as the only product-success route.

## Visual Language

### Composition

- one dominant reading direction per diagram;
- whitespace separates semantic domains;
- architecture nodes replace spreadsheet cells;
- no paragraph-sized labels;
- supporting detail moves to the normative document.

### Typography

- one professional sans-serif family;
- no more than four text levels;
- English architecture terms may remain where they are more precise;
- Chinese explains business meaning;
- title, subsystem, component, and annotation must be visually distinct.

### Color

Use a restrained semantic palette:

- navy: system structure and primary authority context;
- blue: normal Agent subsystem flow;
- teal: evidence and verified state;
- gold: Human authority and gates;
- red: failure, blocked state, and incident handling;
- neutral gray: supporting structure.

Color must never be the only carrier of meaning.

### Lines and Shapes

- thin neutral structure lines;
- one primary flow style;
- dashed border only for conditional activation;
- diamond or gold-accent block only for Human Gates;
- no decorative gradients, shadows, icons, or connector styles without semantic purpose.

## Rendering Approach

Keep the existing deterministic delivery formats:

- editable source;
- SVG;
- 144-DPI PNG.

Preferred implementation:

- retain Graphviz for deterministic rendering;
- replace monolithic HTML table labels with real clusters, nodes, ranks, and edges;
- use semantic subsystem clusters and bounded labels;
- keep `.dot` readable enough for an Agent to audit projection intent.

Acceptance is not tool loyalty. If a proof render cannot reproduce the approved hierarchy without table-shaped density, the implementation must switch to a deterministic SVG template rather than weaken this design.

## Acceptance Criteria

### Main map

- a first-time reader identifies the five subsystems in under ten seconds;
- the reader can trace the normal path without reading the legend;
- each subsystem states its purpose and boundary output;
- Product Manager visibly owns business entry points/touchpoints and main/exception flows;
- Human Control Plane is visibly cross-cutting;
- Development and Quality are separate;
- shared state is not mistaken for a stage;
- failure and Incident handling are visually separate from the success path;
- target status and M0 manual control remain visible.

### Visual quality

- readable at a normal desktop viewing width without zooming into individual table cells;
- no text clipping, overlap, or edge crossing through labels;
- no block contains more than one short responsibility statement plus one output statement;
- visual hierarchy remains legible in grayscale;
- all four diagrams use the same visual grammar.

### Semantic integrity

- every component maps to a normative role, activity, Human Gate, or artifact class;
- every forward edge maps to an allowed macro transition;
- no optional Owner appears mandatory;
- no visual implies automatic cross-Owner invocation;
- no visual implies that deployment equals product success;
- no Incident evidence enters product success.

## Validation

Implementation validation must include:

- Graphviz or renderer parse success;
- deterministic byte comparison for SVG and PNG;
- XML validation for SVG;
- visual inspection at normal scale;
- comparison against the normative role, flow, artifact, route, and terminal contracts;
- local-link validation;
- repository quick regression;
- explicit reporting of unrelated repository-wide gate failures.

## Out of Scope

- changing normative architecture semantics;
- role Skill implementation;
- Product Manager method design;
- project-specific business flows;
- automated cross-Owner orchestration;
- runtime migration;
- the `qft-tenants` whole-chain acceptance case.
