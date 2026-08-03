# One-Human + Agent Team L0 Operating Architecture

## Status

- Architecture level: `L0` macro operating architecture.
- Baseline revision: `L0-R1`.
- Content status: approved through human co-creation on 2026-08-03.
- Written specification status: pending final human review.
- Runtime status: not implemented.
- Operating mode: `M0`, with manual cross-Owner invocation and human-executed deployment.
- Current semantic source: this document is the only current macro baseline for the next visual and per-Owner designs.
- Supersession boundary: the 2026-07-30 V1.2 candidate and its R4 visual suite are historical design evidence, not current inputs for forward design or implementation.

## Decision

The team is organized as:

> **one Human Control Plane + five professional outcome systems + two human deployment gates + one accountable return law**

This is not a chain of Agents passing documents and it is not a fully autonomous multi-Agent runtime. It is a human-governed operating architecture in which professional systems produce accepted outcomes, use bounded execution context, and return defects to the earliest accountable system.

## Goal

Enable one human to direct a replaceable Agent team—from Codex, Claude, or another capable provider—from an ambiguous customer need to a truthful production and product outcome while preserving:

- human authority over value, material trade-offs, stage authorization, deployment, business acceptance, and final Phase/Demand disposition;
- professional separation between product definition, proof design, planning, development, independent quality, production verification, and product closeout;
- autonomous execution loops inside each Owner domain without making the human coordinate individual executors;
- minimum-sufficient, provider-neutral context between Owners;
- explicit responsibility for upstream defects and no silent debt transfer downstream;
- manual control before any automation is designed.

## Acceptance Scope

The L0 architecture is acceptable only when a human and a fresh Agent can both determine:

1. what the five professional systems are and what outcome each owns;
2. who co-creates, who authorizes, who executes, and who independently verifies;
3. what permits forward movement and who invokes the next Owner in `M0`;
4. where test and production deployment occur and why they remain human gates;
5. what crosses an Owner boundary and what remains out of downstream context;
6. where a discovered problem returns and which evidence must be re-evaluated;
7. why deployment, production verification, business acceptance, Phase success, and Demand completion are different facts.

The architecture is not accepted merely because every role appears on a diagram. Its boundaries and control laws must prevent unresolved upstream problems, stale evidence, context flooding, responsibility laundering, and false completion.

## Scope Boundary

This baseline defines:

- the Human Control Plane;
- the five professional outcome systems;
- conditional UX and Architecture activation authority;
- the two human deployment gates;
- the minimum-sufficient cross-Owner handoff model;
- the normal forward path;
- the generic accountable return law;
- truthful production and product closeout semantics;
- the content contract for the single Chinese L0 team battle map.

It deliberately does **not** define:

- Skill prompts, detailed internal methods, or role procedures beyond the explicitly approved Development TDD expectation;
- artifact fields, schemas, file layouts, IDs, token limits, or storage;
- Task Packet format or executor dispatch protocol;
- exact UX or Architecture activation checklists;
- detailed finding taxonomies, route tables, state machines, incident protocols, retries, or recovery algorithms;
- automated cross-Owner orchestration;
- deployment implementation;
- provider-specific Codex or Claude behavior;
- project-specific requirements or the `qft-tenants` acceptance case.

Those are later designs. They may satisfy this baseline but may not silently expand or redefine it.

## Why This Structure Exists

The essential complexity is not code generation. It is preserving truth and responsibility while work moves through different professional concerns:

- the initial customer statement may not express the real need;
- a small request may affect many business and system surfaces;
- implementation and independent proof should not share one biased narrative;
- quality findings may originate in product, impact, UX, architecture, proof design, code, or environment;
- an Agent needs enough context to act correctly, but full upstream process creates noise and confirmation bias;
- deployment changes the environment but does not prove technical or business success;
- the human must retain high-consequence authority without becoming a task coordinator.

The selected structure puts each unavoidable complexity behind one accountable system boundary and keeps unresolved details evolvable.

## L0 Topology

The architecture has three simultaneous structures:

1. **Human Control Plane** — cross-cutting authority and human-executed external actions.
2. **Professional outcome path** — five systems that move the work from demand to truthful closeout.
3. **Accountable return network** — failures return to the earliest system that owns the defective definition, decision, implementation, proof, or environment action.

The dominant forward path is:

```text
Customer problem or business opportunity
        ↓
1. Product Definition System
        ↓
2. Proof & Planning System
        ↓
3. Development Delivery System
        ↓
Human: approve test entry and execute test deployment
        ↓
4. Quality Acceptance System
        ↓
Human: approve release and execute production deployment
        ↓
5. Production Outcome & Product Closeout System
        ├─ Quality Owner: production verification
        ├─ Human: business acceptance
        ├─ Product Director: closeout recommendation
        └─ Human: separate Phase / Demand disposition
                    ↓
Truthful outcome: successful Phase close, completed or continuing Demand,
next Phase, rework, pause, or termination
```

This dominant path is not a waterfall. Forward movement is conditional on professional acceptance; failed or invalid inputs return through accountability, not merely to the previous box.

## Human Control Plane

### Mission

The human is the Business Owner and final authority, not the coordinator of individual Agent tasks.

### Human authority

The human:

- co-creates product direction and key architecture choices;
- accepts or rejects the Owner boundary results required for forward movement;
- authorizes and manually invokes the next Owner in `M0`;
- authorizes conditional UX and Architecture activation or skip;
- executes test deployment and production deployment;
- performs business acceptance;
- makes the final Phase and Demand disposition.

Human approval authorizes progression. It does not convert an assumption into fact, a professional gap into a pass, or a failed deployment into a trustworthy outcome.

### M0 invocation rule

- The human invokes the named professional Owner at every cross-Owner handoff, including handoffs between Owners inside the same professional system.
- That single invocation begins with the recipient's bounded intake check; `ACCEPT` permits the same invocation to continue into professional work, while `CLARIFY` or `REJECT` stops before that work begins.
- That Owner autonomously coordinates its bounded executors.
- The human does not schedule Developer, Verifier, Code Reviewer, Code Fixer, or QA Executor loops.
- Cross-Owner autonomous invocation is deferred until the manual operating model has been proven.

## Professional Outcome Systems

A named system boundary result is a human-accepted composition of the current authoritative results owned by its contributing Owners and any required external outcome. It is a boundary view, not a new shared truth. Each underlying conclusion remains the responsibility of its original Owner, and human acceptance does not replace that professional responsibility or the next recipient's intake acceptance.

### 1. Product Definition System

**Question:** Why should this be solved, for whom, in what current boundary, through what product solution, and with what impact understood?

**Roles:**

- **Product Director** — co-creates the real problem, root need, value, and current Phase boundary.
- **Product Manager** — defines product actors, scenarios, product solution, and product acceptance.
- **Impact Owner** — establishes whether relevant business and system impact has been understood completely enough to proceed.
- **UX Owner** — conditionally resolves material experience design obligations.
- **Architecture Owner** — conditionally resolves material technical architecture obligations.

**Boundary result:** `Approved Product & Solution Baseline`.

The macro responsibility order is Product Director → Product Manager → Impact Owner → conditional UX/Architecture resolution → consolidated Product Definition `GO`. This order assigns responsibility; it does not define the internal method of any role.

The boundary result covers the approved product definition and business-success criteria, an accepted impact-completeness conclusion with declared coverage limits and no known blocking omission, and either an accepted UX/Architecture result or an explicit justified skip. Every activated role must reach `GO`. A downstream-affecting unresolved issue or unclassified unknown cannot be passed to Proof & Planning.

### 2. Proof & Planning System

**Question:** How will success be proved, and how will the accepted solution be implemented safely?

**Roles:**

- **Test Design Owner** — defines how the full accepted baseline will be proved.
- **Tech Lead** — defines how the baseline will be implemented under the proof obligations and accepted constraints.

**Dependency rule:**

- Test Design consumes Product, Impact, and every activated or explicitly skipped UX/Architecture result.
- Tech Lead consumes the complete upstream baseline and Test Design; planning cannot reduce or rewrite either.
- A missing, contradictory, or materially changed upstream obligation returns to its owning system.

**Boundary result:** `Approved Verification Design & Development Plan`.

The human reviews whether the proposed proof, material risk, and trade-offs are acceptable. The human is not expected to review every technical task.

### 3. Development Delivery System

**Question:** Has the accepted solution been implemented correctly and proved enough to enter independent quality testing?

**Accountable role:**

- **Development Owner** — owns the pre-test outcome and orchestrates the development loop; it is not defined as the primary coder.

**Bounded execution roles:**

- **Developer** — implements with TDD and self-testing.
- **Verifier** — verifies product obligations, acceptance behavior, and scope independently from the implementer inside the Development domain.
- **Code Reviewer** — reviews code quality, risk, and maintainability independently from the implementer inside the Development domain.
- **Code Fixer** — corrects confirmed implementation defects and triggers re-evaluation of affected proof.

Verifier and Code Reviewer are separate proof surfaces from the implementer, but neither owns the independent release-quality `GO`. They consume the authoritative obligations and relevant evidence, not the Developer's full reasoning history.

**Boundary result:** `Test-ready Candidate & Development Evidence`.

**Entry boundary:** Development consumes the complete `Approved Product & Solution Baseline` and `Approved Verification Design & Development Plan`. A bounded executor may receive a narrower task-specific view, but every applicable upstream obligation must remain mapped and provable through the Development Owner.

The result may leave this system only when planned work is complete, required tests pass, verification and code review pass, no unresolved development blocker remains, and the exact candidate is fixed. The human then decides whether to deploy that candidate to the test environment.

### 4. Quality Acceptance System

**Question:** Does independent evidence for the exact deployed candidate support production release?

**Roles:**

- **Quality Owner** — owns quality scope, evidence sufficiency, finding classification, and the pre-release conclusion.
- **QA Executor** — executes tests and records evidence under the Quality Owner.

**Entry boundary:** Quality consumes the Product & Solution Baseline, Verification Design, exact test-ready candidate, and a trustworthy test-deployment result for that same candidate.

Quality does not change code. A confirmed implementation defect returns to Development. Every candidate change invalidates affected Quality evidence and requires the relevant Development gates, human redeployment, and Quality revalidation.

**Boundary result:** `Release-ready Candidate & Independent Quality Conclusion`.

The human accepts or rejects the release conclusion and, if accepted, executes production deployment.

### 5. Production Outcome & Product Closeout System

**Question:** Did the exact approved version run correctly in production, deliver accepted business value, and reach an honest product-stage disposition?

**Entry boundary:** This system consumes the current Product & Solution Baseline, the exact `Release-ready Candidate`, its Independent Quality Conclusion, and a trustworthy production-deployment result for that same candidate.

**Activities and authority:**

- **Quality Owner production verification** — independently verifies the exact approved production version, core paths, relevant data, permissions, integrations, risks, and continued applicability of the release conclusion. This is an activity of the existing Quality Owner, not a new Owner and not a code-changing role.
- **Human business acceptance** — judges whether the production result solves the intended business problem. This is distinct from technical production verification.
- **Product Director closeout** — consumes the original goal and Phase, production verification, business acceptance, and open product risks; recommends the Phase/Demand outcome and possible next Phase.
- **Human final disposition** — records separate but consistent dispositions for the current Phase and the broader Demand, including successful Phase close, Demand completion or continuation, next Phase authorization, rework, pause, or termination.

No new Production Owner is introduced. Technical production truth remains with Quality Owner, product recommendation remains with Product Director, and final business authority remains with the human.

**Boundary result:** `Truthful Production Result & Product Stage Decision`.

This boundary result does not exist until production verification, human business acceptance, Product Director closeout recommendation, and the human's separate Phase/Demand dispositions have all produced truthful outcomes.

A Phase is successful only when the exact approved version is deployed, production verification passes, human business acceptance passes, and the human records the Phase and Demand dispositions. A successful Phase does not by itself mean the entire Demand is complete.

## Conditional UX and Architecture Activation

Conditional activation follows one macro control:

1. the Agent identifies the need and recommends activation or skip with evidence;
2. the human authorizes the decision and manually invokes an activated Owner in `M0`;
3. the human may request activation even when the Agent recommends skip;
4. a skip preserves a short rationale and a condition that would reopen the decision;
5. once activated, the Owner must reach `GO` before the Product Definition System can complete.

The exact activation checklists are intentionally deferred to the corresponding Owner designs.

## Minimum-Sufficient Cross-Owner Handoff

The architecture rejects a universal “Owner Handoff Package.” That container would mix authoritative truth, downstream context, executor instructions, evidence, and history until it became either incomplete or noisy.

The selected interface is:

```text
Owner Authoritative Result Source
        ↓ recipient-specific projection
Recipient-Specific Minimum-Sufficient View
        ↓
Human accepts the outcome, authorizes, and invokes the named recipient
        ↓
Invocation begins with bounded Recipient Intake: ACCEPT / CLARIFY / REJECT
        ↓ ACCEPT only
The same invocation proceeds into professional work
```

### Logical surfaces

- **Owner Workbench** — exploration, chats, drafts, tool output, and rejected alternatives; not passed by default.
- **Owner Authoritative Result Source** — the Owner's current accepted decisions, constraints, obligations, risks, material assumptions, classified unknowns, reopen conditions, and evidence references; the single truth for that responsibility.
- **Recipient-Specific Minimum-Sufficient View** — a projection from one or more authoritative sources for one recipient; never a new truth.
- **Evidence Sources** — the discoverable, precisely addressable support for material conclusions; pulled only when the recipient needs to verify them.
- **Process Archive** — chats, drafts, rejected experiments, raw tool output, and other work history; non-authoritative and not loaded by default.
- **Recipient Intake Receipt** — `ACCEPT` means safe to proceed beyond intake; `CLARIFY` means retrieving or clarifying already referenced information without changing approved semantics; `REJECT` means the input is missing, conflicting, stale, inaccessible, unauthorized, or otherwise unsafe to consume.

`Task Packet` exists only inside an Owner domain for bounded executors and is outside L0 cross-Owner architecture.

### Sufficiency rule

“Complete” means complete coverage of the recipient's obligations, not full-document transfer. Information belongs in the active handoff only when removing it could change the recipient's permitted action, constraints, proof, risk treatment, or return route.

The recipient defines what is required to discharge its responsibility. The producer maps current authoritative truth to that requirement. The recipient must reject missing, conflicting, stale, inaccessible, or unauthorized input rather than guessing.

Any clarification that changes approved semantics is not `CLARIFY`; it becomes `REJECT` and returns to the responsible Owner for a new authoritative result.

Raw chats, full exploration history, chain-of-thought, obsolete revisions, complete logs, irrelevant documents, and repeated stable role rules are not passed by default. When a rejected alternative creates a surviving downstream constraint, only the decision, short rationale, and impact are passed.

Human `GO` and recipient `ACCEPT` are different facts: the former grants authority; the latter confirms professional sufficiency.

## Forward and Return Control Laws

### Forward law

A cross-Owner transition, whether inside one professional system or between systems, requires all of the following:

1. the current Owner's boundary result is professionally acceptable;
2. no unresolved producer-owned blocker or unclassified unknown is hidden in the handoff;
3. the human accepts the result, authorizes the named next Owner, and invokes its bounded intake;
4. the recipient accepts the current minimum-sufficient view;
5. required human external action, such as deployment, has a trustworthy result for the exact candidate.

### Return law

Every finding is first recorded, classified, and returned to the earliest system accountable for the defective definition, decision, implementation, proof, or environment action:

- product goal, scenario, scope, or acceptance defect → Product Definition System;
- impact omission → Impact Owner within Product Definition;
- UX or architecture defect → the corresponding conditional Owner;
- proof-design defect → Test Design Owner;
- implementation or code-quality defect → Development Delivery System;
- test execution or quality-judgment defect → Quality Acceptance System;
- deployment or environment anomaly → stop at the corresponding human deployment boundary, preserve the truthful outcome, classify the cause, and return correction to the professional or external capability actually accountable for code, deployment definition, architecture, or environment;
- unknown cause → diagnosis first; no guessed fix.

The human deployment boundary owns authorization, execution, and truthful recording—not automatic technical diagnosis or repair. When an external action fails without a known cause, the professional Owner that proposed that action owns or commissions bounded diagnosis until an accountable correction route is named. If classification reveals no accountable capability, the L0 responsibility model must be reopened rather than making the human silently fill the gap.

The downstream system may not repair an upstream responsibility or continue with an unresolved upstream blocker. A substantive upstream change invalidates only the downstream results and handoff views that actually depend on it; those dependencies must be re-evaluated before reuse.

## Truthful Completion Semantics

The architecture keeps these facts separate:

- commit is not development completion;
- passing developer tests is not independent quality acceptance;
- test deployment is not Quality `GO`;
- production deployment is not production verification;
- production verification is not human business acceptance;
- business acceptance is not a recorded Phase/Demand disposition;
- Phase success does not necessarily complete the Demand.

Any failed, partial, stale, or unknown outcome stops the success path, is classified, and returns through the accountable return law. Business rejection is not automatically an operational incident; incident treatment is a later detailed design triggered by actual environment safety or operational risk.

## Options Considered

### A. One end-to-end Agent coordinator

Rejected for the target architecture. It minimizes visible roles but combines product judgment, implementation, proof, and release judgment in one context. That increases confirmation bias, hidden responsibility transfer, and human dependence on one Agent's narrative.

It may be suitable for low-risk prototypes where independent acceptance is not required.

### B. Fully autonomous multi-Agent runtime

Rejected for `M0`. Automation before the role boundaries and evidence contracts are proven would make failures faster but harder to diagnose. It also weakens the human's ability to learn where professional boundaries are wrong.

It may become suitable after repeated manual runs show stable inputs, outputs, gates, return routes, and acceptable human load.

### C. Human-governed professional systems with bounded Owner domains

Selected. It keeps one human in control of consequential decisions while allowing autonomous executor loops inside bounded Owner domains. Manual cross-Owner invocation is a learning and safety mechanism, not the final automation model.

### D. Detailed V1.2 flow/state architecture as the macro baseline

Rejected for the current phase. The previous candidate prematurely fixed flow IDs, route IDs, package identities, state machines, incident mechanics, and cutover rules before the macro team architecture and visual comprehension were accepted. Those materials remain historical evidence and may be reconsidered only during the relevant detailed designs.

## Risks, Unknowns, and Reopen Conditions

The L0 baseline does not pretend the following are solved:

- whether every role name and grouping is optimal in real project use;
- the precise boundary between Product Director and Product Manager;
- exact Impact, UX, Architecture, Test Design, and Quality methods;
- the physical form and size of authoritative results and recipient views;
- how dependent downstream results are identified and invalidated;
- whether manual Owner invocation creates excessive human load;
- which gates can later be automated without weakening authority or evidence;
- how Codex, Claude, and other providers differ in tool access and context behavior;
- whether the `qft-tenants` target scenario exposes a missing system or misplaced responsibility.

Any evidence that a responsibility has no accountable system, two systems own the same final decision, a downstream role must routinely reconstruct upstream work, or the human must coordinate executor loops reopens this architecture rather than being patched inside a Skill.

## Chinese L0 Team Battle Map Contract

The next visual implementation is one Chinese L0 architecture map. It must show:

- a cross-cutting Human Control Plane;
- five professional systems in the dominant left-to-right order;
- each system's purpose, accountable roles, and boundary result;
- UX Owner and Architecture Owner as conditional roles;
- the human test-deployment gate between Systems 3 and 4;
- the human production-deployment gate between Systems 4 and 5;
- Product Director and human closeout at the end of System 5;
- the shared minimum-sufficient handoff rule;
- one generic accountable return law;
- explicit target status: `M0 manual control · not runtime-active`.

The L0 map must not show flow IDs, route IDs, schemas, state machines, incident subflows, automation mechanics, detailed finding types, Task Packets, or the `qft-tenants` case.

Visual success requires a first-time Chinese-speaking reader at normal desktop scale to identify within seconds:

1. what each system does;
2. who owns it;
3. what comes next;
4. where the human co-creates, authorizes, deploys, and decides;
5. where a defect returns.

If those questions require zooming into paragraph nodes or reading a separate specification, the visual has failed regardless of graphical polish.

## Design Sequence After Written Approval

1. Plan and implement the single Chinese L0 team battle map from this document only.
2. Obtain human semantic and visual acceptance of that map.
3. Design each Owner domain separately, starting with Product Director and its Product Manager intake boundary.
4. Search official and community Skill sources for each approved capability boundary.
5. Adapt or create provider-neutral Skills and validate them independently.
6. Run the complete manual chain against the `qft-tenants` target scenario.
7. Consider cross-Owner automation only after repeated manual delivery proves the operating model.
