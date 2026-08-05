# 一人 + Agent Team 架构

## Status

- Internal architecture level: `L0`; this is not part of the human-facing title.
- Baseline revision: `L0-R3`.
- Approved direction: one human, one provider-replaceable Agent Team, and five professional delivery stages.
- Written specification status: `APPROVED — final human review completed on 2026-08-03`.
- B+ L0 visual direction: `APPROVED — written projection contract approved by the Human on 2026-08-05`.
- Formal SVG/PNG projection status: `DRAFT — the current high-density candidate was rejected for forward publication and its bytes are not approved`.
- Runtime status: not implemented.
- Operating mode: `M0`, a temporary learning mode with manual cross-Owner activation and human-controlled deployment.
- Current authority: this document is the sole approved macro target-design baseline and the only source of architecture semantics. The approved B+ section below records how that architecture may be projected for human navigation; it does not create a second semantic source. It authorizes planning and implementing a replacement `DRAFT` SVG/PNG candidate through the existing projection path. It does not approve any SVG/PNG bytes or authorize publication, Owner implementation, Skill changes, or runtime automation.
- Supersession boundary: the 2026-07-30 V1.2 candidate and its R4 visual suite are historical design evidence, not current inputs for forward design or implementation.

## Decision

The selected architecture is:

> **one Human Governance Layer + one provider-replaceable Agent Team + five professional delivery stages + two human-controlled deployment boundaries + one shared coordination and assurance foundation + accountable return and stop laws**

The five stages are lifecycle boundaries, not five fixed Teams. `Agent Team` names the complete set of professional Agent roles only once at the organization level.

This is not a chain of chat sessions passing summaries, a collection of permanent Agent instances, or a fully autonomous multi-Agent runtime. Professional Owners remain accountable for their own conclusions; stage integration cannot overwrite those conclusions; the human controls consequential decisions without becoming the workflow router or the auditor of every professional detail.

## Goal

Enable one human to direct a replaceable Agent Team—from Codex, Claude, or another capable provider—from an ambiguous customer need to a truthful delivery or non-delivery product disposition and, when authorized, a truthful production outcome while preserving:

- human authority over value, material trade-offs, authorization, deployment actions, business acceptance, and final Phase/Demand disposition;
- human-Agent co-creation where product meaning or material architecture trade-offs require business judgment;
- professional separation between product definition, impact, proof design, planning, implementation, independent review, quality acceptance, production verification, and product closeout;
- autonomous execution inside bounded Owner domains without making the human coordinate executors, assemble professional results, or invent routes;
- minimum-sufficient, provider-neutral context and recoverable control state across Owners, sessions, and providers;
- explicit protection of existing behavior, compatibility obligations, and forbidden side effects;
- explicit responsibility, evidence invalidation, safe stopping, and no silent debt transfer downstream;
- manual learning before cross-Owner automation.

## Acceptance Scope

The architecture is acceptable only when a human and a fresh Agent can both determine, without relying on prior chat history:

1. why there is one Agent Team and why the five boxes are delivery stages rather than five Teams;
2. who owns each professional conclusion, who integrates each stage exit, and what neither may override;
3. what the human co-creates, authorizes, triggers, deploys, accepts, and finally decides;
4. who recommends the next Owner and prepares the next bounded context in `M0`;
5. what the current stage, Owner, authoritative revision, and—when applicable—release identity, deployment outcome, evidence-validity state, blocker, and return target are;
6. who owns current control-state continuity and who independently assures the Agent delivery system itself;
7. what permits forward movement, what forces return, and what causes safe stop or human escalation;
8. how target behavior, preserved behavior, forbidden behavior, and proof obligations remain connected;
9. why deployment, production verification, business acceptance, Phase success, and Demand completion are different facts.

The architecture is not accepted merely because all roles appear on a diagram. It must prevent unresolved upstream debt, stale evidence, context flooding, responsibility laundering, fake independence, failure washing, approval fatigue, and false completion.

## Scope Boundary

This baseline defines:

- the Human Governance Layer;
- the one-Agent-Team organization model and role types;
- five professional delivery stages and their result integrators;
- conditional UX and Architecture activation authority;
- the two human-controlled deployment boundaries;
- the shared coordination and assurance responsibilities;
- the minimum-sufficient cross-Owner handoff model;
- the normal forward path, accountable return law, and safe-stop law;
- truthful production and product closeout semantics;
- the acceptance contract for the single Chinese macro architecture map.

It deliberately does **not** define:

- Skill prompts, detailed internal methods, or role procedures beyond the explicitly approved Development TDD expectation;
- artifact schemas, file layouts, field names, IDs, token limits, persistence technology, or dependency algorithms;
- Task Packet format or executor dispatch protocol;
- exact UX or Architecture activation checklists;
- detailed finding taxonomies, route tables, state machines, retry counts, budgets, incident protocols, or recovery runbooks;
- automated cross-Owner orchestration;
- deployment tooling or provider-specific Codex/Claude behavior;
- portfolio strategy, market-wide opportunity prioritization, and roadmap governance before a selected Demand enters Product Director;
- project-specific requirements or the solution to the `qft-tenants` acceptance case.

Those are later designs. They may implement this baseline but may not silently expand or redefine it.

## Concept Model

### Organization concepts

- **Human Business Owner** — the human with final business authority, material trade-off authority, deployment authorization, business-acceptance authority, and final Phase/Demand disposition authority.
- **Agent Team** — the complete logical collection of provider-replaceable professional Agent roles. It is not five subteams, fixed staffing, or a promise that one running Agent can be replaced mid-task without loss.
- **Professional Owner** — a role accountable for one professional responsibility and its authoritative result. Product Director, Product Manager, Impact Owner, UX Owner, Architecture Owner, Test Design Owner, Tech Lead, Development Owner, Quality Owner, and Delivery Assurance Owner are all Professional Owners regardless of title suffix.
- **Executor** — a bounded role delegated by a Professional Owner. It does not own cross-Owner progression or redefine authoritative obligations.

### Workflow and responsibility concepts

- **Professional Delivery Stage** — a lifecycle boundary in the Demand-delivery path. Stage 1 evaluates the Demand and may form an authorized Active Phase; Stages 2–5 progress that Active Phase. A stage groups related professional outcomes for navigation; it is not an independently invocable Team.
- **Stage Result Integrator** — the named Professional Owner responsible for detecting missing, contradictory, stale, or mutually invalidated results; preparing the stage decision view; and recommending the next accountable route. The integrator cannot waive or rewrite another Owner's professional `GO`.
- **Owner Domain** — one Professional Owner's responsibility, bounded working context, authoritative result, delegated executors, and internal completion criteria.
- **Stage Exit Readiness** — a derived readiness view showing that every required underlying Owner result and external outcome is current and mutually consistent. It is not a new source of professional truth.

### Information concepts

- **Owner Authoritative Result** — the single current source for one Owner's accepted decisions, constraints, obligations, evidence limits, classified unknowns, and reopen conditions.
- **Recipient-Specific View** — a minimum-sufficient projection from one or more authoritative results for a named recipient. It is not a new truth and cannot silently rewrite the source.
- **Human Decision View** — a concise projection that states the one decision required, Agent recommendation, evidence strength, material risks and unknowns, next route, and invalidation effect. The human is not required to reconstruct these from full professional artifacts.
- **Delivery Control Record** — the lightweight cross-session control truth for the current Demand and, when one exists, Active Phase: current stage, active Owner, authoritative revisions, applicable release identity, deployment outcomes, valid or invalid downstream results, current finding custodian, blocker, recommended route, and pending human action. It references professional truth instead of copying it.

### Business concepts

- **Demand** — the broader customer problem or business investment object. It may contain no authorized Phase, one Phase, or multiple sequential Phases.
- **Active Phase** — the Product Director's currently authorized minimum independent value boundary. It is not one of the five delivery stages.

### Distinct control facts

The architecture never collapses these facts into a generic human `GO`.

Every cross-Owner transition uses:

```text
Producing Owner GO
        ↓ professional result is acceptable within that Owner's responsibility
Human AUTHORIZE
        ↓ business authority permits the recommended transition
Recipient ACCEPT
        ↓ the named recipient can work without inventing missing meaning
```

A delivery-stage exit additionally requires all mandatory Owner `GO`s, applicable external outcomes, and a current consistency check before `Stage Exit Readiness`. A deployment produces a separate `Deployment Outcome`. Final business closure produces separate Phase and Demand dispositions. None of these facts substitutes for another.

## Why This Structure Exists

The essential complexity is not code generation. It is preserving truth, independence, and responsibility while work moves through different professional concerns:

- the customer's sentence may describe a symptom or proposed solution rather than the real need;
- a small visible change may affect many business objects, data states, permissions, integrations, and preserved paths;
- impact knowledge grows as product, architecture, code, tests, and runtime expose new evidence;
- an implementation and its proof must not share one biased reasoning history;
- Agent roles need sufficient context, but complete upstream process creates noise and confirmation bias;
- separate Owner results do not by themselves reveal the current stage, exact version, invalidated evidence, or next route;
- deployment changes an environment but does not prove technical or business success;
- business value may require an observation period;
- the human must retain consequential authority without becoming a document assembler, technical auditor, workflow router, or incident diagnostician.

The selected structure separates organization, lifecycle, professional responsibility, control state, and evidence instead of forcing all five concepts into one kind of box.

## Architecture Topology

The architecture has five simultaneous structures:

1. **Human Governance Layer** — cross-cutting business authority and human-controlled external actions.
2. **One Agent Team** — Professional Owners and their bounded Executors.
3. **Professional delivery path** — five lifecycle stages from demand definition to truthful product disposition.
4. **Shared coordination and assurance foundation** — recoverable state, bounded context, release identity, permissions, isolation, trace, and Agent-workflow evaluation.
5. **Accountable return and stop network** — findings return to a specific accountable Owner; unsafe or non-progressing work stops rather than looping or guessing.

The dominant path is:

```text
Customer problem or business opportunity
        ↓
1. Product Definition Convergence
        ├─ DISCOVERY / NO-GO / PAUSE → truthful non-forward outcome
        ↓ Product Definition Readiness
2. Test Design & Implementation Planning
        ↓
3. Development Delivery
        ↓
Human-controlled test deployment boundary
        ↓
4. Independent Quality Acceptance
        ↓
Human-controlled production deployment boundary
        ↓
5. Production Verification & Product Stage Decision
        ↓
Truthful result: Phase success, observation pending, next Phase,
rework, Demand completion or continuation, pause, termination, or NO-GO
```

This dominant path is not a waterfall. Product definition converges through internal feedback, later evidence can reopen affected upstream truth, and failed work returns by responsibility rather than merely to the previous stage.

## Human Governance Layer

### Mission

The human is the Business Owner and final consequential authority, not the coordinator of Agent tasks or the substitute for missing professional accountability.

### Human authority

The human:

- co-creates product direction and material architecture choices;
- confirms business reality, value, constraints, and acceptable trade-offs;
- reviews a bounded Human Decision View and authorizes or rejects the recommended transition;
- manually triggers the named next Owner in `M0`;
- authorizes and executes an already prepared test or production deployment action;
- performs business acceptance;
- records the final Phase and Demand disposition.

The human does not have to prove impact completeness, architecture correctness, test-design sufficiency, code quality, or technical root cause. Human authorization does not convert an assumption into fact, a professional gap into `GO`, failed evidence into a pass, or an unknown business outcome into success.

### M0 manual-activation rule

`M0` is a temporary learning overlay used to prove role boundaries and outputs before automation. It is not the intended permanent operating burden.

- A producing Owner updates only its authoritative result and proposes a route.
- The current Stage Result Integrator is the sole Agent authority for the cross-Owner route recommendation, Human Decision View, Recipient-Specific View, and proposed Delivery Control Record transition.
- The human authorizes and manually triggers that recommendation; the human never resolves competing routes, assembles context, or calculates evidence invalidation.
- The recipient invocation begins with bounded intake. `ACCEPT` completes active-Owner transfer and permits the same invocation to continue; `CLARIFY` or `REJECT` stops professional work until the input is safe.
- Entry into a new delivery stage begins with that stage's Result Integrator, which establishes currentness and then routes to any required contributing Owner.
- An Owner autonomously coordinates its bounded Executors. The human never schedules Developer, Verifier, Code Reviewer, Code Fixer, or QA Executor loops.
- If the human is unavailable, work stops at the current safe boundary. No Agent may silently cross an Owner, test-deployment, or production-deployment boundary.

Cross-Owner automation may be considered only after repeated normal and failure-path runs show stable routing, reliable intake rejection, recoverable state, independent contexts, repeatable deployment, acceptable human load, and Agent-workflow evaluation evidence.

## One Agent Team

The Agent Team contains professional roles, not permanent Agent processes. A provider or model may fill different roles at different times, but role responsibility and context boundaries remain stable.

### Professional Owners

- Product Director
- Product Manager
- Impact Owner
- UX Owner, when activated
- Architecture Owner, when activated
- Test Design Owner
- Tech Lead
- Development Owner
- Quality Owner
- Delivery Assurance Owner, as a cross-cutting assurance role outside the five-stage professional outcome path

### Bounded execution roles

- Developer
- Verifier
- Code Reviewer
- Code Fixer or equivalent repair capability under Development Owner
- QA Executor

The exact decision to implement Code Fixer as a distinct Agent instance, a fresh repair context, or a Developer repair mode is deferred to the Development Owner design. Its responsibility remains inside Development; Quality never changes code.

### Independence rule

Logical role separation is insufficient. For the same change, Developer and the roles that certify it—Verifier, Code Reviewer, and Quality—must not share an implementation-polluted Workbench.

The same provider or model may be reused, but an independent role must start from a fresh bounded context and independently read authoritative obligations, the actual candidate, and relevant evidence. The implementer's full reasoning history and self-conclusion are not proof inputs.

Provider replaceability is guaranteed only at an accepted Owner boundary with recoverable authoritative results and a Delivery Control Record. Lossless replacement in the middle of an Owner's unfinished Workbench is not promised by L0.

### Cross-cutting assurance role

**Delivery Assurance Owner** independently owns the assurance baseline and evaluation conclusion for whether the Agent delivery system itself preserves routing accountability, control-state continuity, minimum-sufficient context, permission boundaries, context independence, traceability, safe stopping, and provider/Skill change stability.

It does not own product quality, business acceptance, professional stage conclusions, routing decisions, or code changes. It evaluates evidence produced by the operating chain from a fresh bounded context.

Delivery Assurance Owner owns the mandatory assurance activation and reopen conditions. A Stage Result Integrator must recommend assurance invocation when one is met; any Professional Owner or recipient may raise a suspected control breach, and a mandatory condition cannot be waived by the stage being evaluated. In `M0`, the human manually triggers the named Delivery Assurance Owner but does not design the evaluation.

Delivery Assurance Owner retains finding custody for an Agent-workflow assurance defect, may force a safe stop for a blocking control violation, routes correction to the specific Stage Result Integrator or Professional Owner accountable for the defective control, and independently re-evaluates after correction. It cannot perform that correction under the assurance role. If no corrective capability exists, the L0 responsibility model reopens.

Exact checkpoint frequency, evaluation cases, thresholds, and tooling are deferred, but this responsibility may not be silently assigned to the human or to the same Stage Result Integrator being evaluated.

## Five Professional Delivery Stages

### 1. Product Definition Convergence｜产品定义收敛

**Question:** Why should this be solved, for whom, what Active Phase—if any—should be authorized, through what product behavior, and with what known impact and preserved behavior?

**Stage Result Integrator:** Product Director.

**Entry:** A selected Demand signal and its available sources. The signal may be incomplete, solution-shaped, contradictory, or unsupported; it is evidence to investigate, not an accepted requirement.

**Professional ownership:**

- **Product Director** — owns the real problem, decision-relevant causal mechanism, value, investment logic, and Active Phase boundary.
- **Product Manager** — owns actors, scenarios, business objects, states, rules, permissions, target product behavior, and product acceptance within the authorized Phase.
- **Impact Owner** — owns evidence-backed coverage of relevant business and system impact, declared coverage limits, preserved behavior, and remaining coverage gaps.
- **UX Owner** — conditionally owns material experience-design obligations.
- **Architecture Owner** — conditionally owns material structural technical decisions.

**Convergence law:**

Product Director → Product Manager → Impact Owner is a responsibility discovery order, not a one-pass handoff chain. Current reality, provisional product definition, impact evidence, and conditional UX/Architecture results may reopen one another until they converge.

An Architecture or UX result that materially changes behavior must trigger relevant Product Manager and Impact Owner re-evaluation. New system, code, test, or runtime evidence may later reopen only the affected authoritative results.

**Behavior-obligation law:**

The accepted product baseline must distinguish and preserve all three classes:

1. target behavior that must change;
2. current behavior and business invariants that must remain true;
3. forbidden behavior and side effects that must not occur.

Each applicable obligation must remain traceable into impact, proof design, implementation, independent quality, and production verification. A small requested change does not imply a small impact surface.

**Stage exit:** `Product Definition Readiness` exists only when every required or activated Owner has `GO`, skips are explicit and reopenable, preserved and forbidden behavior is explicit, no blocking contradiction remains, and Product Director attests composite readiness without overriding another Owner.

### 2. Test Design & Implementation Planning｜测试设计与实施规划

**Question:** How will every accepted obligation be proved, and how will the solution be implemented, deployed, observed, and recovered safely?

**Stage Result Integrator:** Tech Lead.

**Entry:** Current Product Definition Readiness. Tech Lead first establishes stage currentness and routes Test Design Owner; Tech Lead produces the implementation plan only after the Test Design result is available.

**Professional ownership:**

- **Test Design Owner** — owns the complete proof obligations and how target, preserved, forbidden, boundary, regression, and risk behavior will be demonstrated.
- **Tech Lead** — owns the implementation plan, technical sequencing, deployment and migration approach, observability, recovery considerations, and material implementation trade-offs.

**Dependency law:**

- Test Design consumes current Product Director, Product Manager, Impact, and every activated or explicitly skipped UX/Architecture result.
- Tech Lead consumes the same authoritative baseline plus Test Design.
- Test Design obligations are not suggestions: Tech Lead and Quality may extend them but cannot silently remove or rewrite them.
- A plan that reveals an upstream contradiction, uncovered impact, unprovable obligation, or material architecture need returns to the accountable Owner and reopens affected results.

**Stage exit:** `Test Design & Implementation Planning Readiness` exists only when Test Design Owner and Tech Lead both have `GO`, their results are mutually consistent, deployment and recovery obligations are represented, and Tech Lead attests composite readiness without overriding Test Design.

The human co-creates or authorizes material architecture and risk trade-offs, but is not required to review every technical task.

### 3. Development Delivery｜开发交付

**Question:** Has the accepted solution been implemented correctly and proved enough to enter independent quality testing?

**Stage Result Integrator and accountable Owner:** Development Owner.

**Bounded roles:**

- **Developer** — implements with TDD and self-testing.
- **Verifier** — independently verifies applicable product obligations and acceptance behavior inside the Development domain.
- **Code Reviewer** — independently reviews code quality, risk, and maintainability.
- **Code Fixer / repair capability** — corrects confirmed implementation defects and triggers fresh evaluation of affected proof.

**Entry:** Development consumes the current Product Definition Readiness and Test Design & Implementation Planning Readiness. Executors may receive narrower task views, but Development Owner remains responsible for mapping every applicable upstream obligation to implementation and proof.

**Stage exit:** `Test-ready Release Identity & Development Evidence` exists only when planned work is complete, required tests pass, fresh-context verification and code review pass, no unresolved Development blocker remains, deployment preparation is executable, and the exact release identity is fixed.

Release identity is broader than a commit. It covers the build and every behavior-changing configuration, migration, feature flag, or dependency assumption required to make evidence and deployment claims truthful. Exact representation is deferred.

### Human-Controlled Test Deployment Boundary

- **Tech Lead** owns the approved deployment, migration, observability, and recovery design.
- **Development Owner** owns the exact test-ready release identity, executable deployment preparation, preconditions, and supporting evidence.
- **Human** authorizes and executes the already prepared deterministic action.
- **Quality Owner** independently confirms the actually deployed identity and the trustworthiness of the deployment outcome before quality work begins.

A failed, partial, mismatched, or unknown deployment outcome stops the success path. Development Owner initially retains finding custody and organizes bounded diagnosis until another accountable Owner or external capability `ACCEPT`s corrective responsibility. The human is not the default technical diagnostician.

### 4. Independent Quality Acceptance｜独立质量验收

**Question:** Does independent test execution in the test environment against the designated deployed release identity produce a trustworthy quality conclusion for production release?

**Stage Result Integrator and accountable Owner:** Quality Owner.

**Bounded role:**

- **QA Executor** — executes tests and records reproducible evidence under Quality Owner.

**Entry:** Quality consumes the current product and impact obligations, Test Design, exact test-ready release identity, Development evidence, and a trustworthy test-deployment outcome for that same identity.

Quality Owner may expand independent coverage but cannot waive Test Design obligations, accept an unresolved upstream blocker, or change code. A confirmed implementation defect returns to Development Owner. A proof-design gap returns to Test Design Owner. A product, impact, UX, or architecture defect returns to that specific Professional Owner.

**Stage exit:** `Release-ready Identity & Independent Quality Conclusion` exists only when the current identity has sufficient independent evidence, all blocking findings are closed through their accountable Owners, and Quality Owner records an honest release conclusion and residual risk.

Every behavior-changing release revision invalidates affected Quality evidence and requires the relevant upstream gates, human redeployment, and fresh Quality validation.

### Human-Controlled Production Deployment Boundary

- **Tech Lead** owns the approved production deployment, migration, observability, and recovery design.
- **Development Owner** owns the exact release-ready identity, executable production preparation, preconditions, and supporting evidence; it initially holds custody of an unknown technical deployment finding and organizes bounded diagnosis until another accountable Owner or external capability `ACCEPT`s it.
- **Human** authorizes, executes, and truthfully records the already prepared action.
- **Quality Owner** independently confirms the actually deployed identity and trustworthiness of the production-deployment outcome.

Production deployment success is only an environment-action fact. A failed, partial, mismatched, stale, or unknown result stops the success path.

Before production deployment begins, the human must be able to retain control until either deployment succeeds or recovery completes. Tech Lead and Development Owner must also provide a verified, scope-limited fail-safe containment, rollback, or isolation path that the human authorizes in advance. If the human becomes unavailable during an unsafe partial deployment, only that pre-authorized fail-safe may continue; no Agent may improvise broader action or resume normal progression. Exact incident mechanics remain deferred.

### 5. Production Verification & Product Stage Decision｜生产验证与产品阶段决策

**Question:** Did the exact approved production release behave correctly, produce sufficient business evidence, and reach an honest Phase/Demand disposition?

**Professional Stage Result Integrator:** Product Director. It owns closeout consistency, the observation plan and business-evidence sufficiency assessment, the recommendation, and control-state closure; it does not own the human's business judgment or final decision.

**Entry:** Product Director establishes stage currentness and then routes production verification. This stage consumes the current product and impact obligations, exact release-ready identity, Independent Quality Conclusion, and a trustworthy production-deployment outcome for that same identity.

**Distinct ownership:**

- **Quality Owner production verification** — owns fresh technical and operational evidence for the exact production identity, core paths, relevant data, permissions, integrations, and continued applicability of the release conclusion.
- **Human business acceptance** — owns the business judgment of whether observed production behavior addresses the intended problem under the accepted evidence limits.
- **Product Director closeout** — owns comparison with the original Demand and Active Phase, product-risk assessment, and the Phase/Demand recommendation.
- **Human final disposition** — owns the separate final decisions for the Active Phase and broader Demand.

Quality's production fact, the human's business acceptance, and Product Director's recommendation cannot overwrite one another. Product Director integrates them into a consistent decision view; the human records the final disposition.

Business value may require an observation period. Product Director owns the evidence-sufficiency assessment, observation plan, and next decision point. `PENDING` or `UNKNOWN` is a truthful non-success state while evidence is immature; elapsed time, deployment success, or technical verification cannot promote it to acceptance.

**Stage result:** `Truthful Production Result & Product Stage Decision` may express Phase success, observation pending, rework, next Phase, Demand completion or continuation, pause, termination, or another non-success disposition supported by evidence.

A successful Phase requires the exact approved identity to be deployed, production verification to pass, business acceptance to pass, and separate Phase/Demand dispositions to be recorded. Successful Phase completion does not by itself complete the Demand.

Product Director's integration responsibility continues until the final human dispositions have been checked for structural consistency with Quality facts and business acceptance and the Delivery Control Record is updated. An inconsistency returns to the human for a new disposition; Product Director cannot edit the human judgment or Quality facts. `OBSERVATION PENDING` remains in Stage 5 under Product Director's closeout responsibility. An authorized next Phase returns through Product Director to Stage 1 with the prior Phase's truthful result preserved.

## Conditional UX and Architecture Activation

Product Director, as Product Definition Stage Result Integrator, owns the formal activation-or-skip recommendation and its presentation to the human. That recommendation must cite Product Manager and Impact Owner evidence; an unresolved material concern from either Owner blocks a skip.

1. Product Manager and Impact Owner surface the applicable product, experience, and technical-impact evidence; Product Director integrates it into the accountable recommendation;
2. the human authorizes that recommendation or requests activation despite a skip recommendation;
3. the human manually triggers an activated Owner in `M0`;
4. a skip records a short rationale and a condition that would reopen it;
5. once activated, the Owner must reach `GO` before Product Definition Readiness;
6. later evidence matching a reopen condition invalidates the skip and the dependent readiness view.

Exact activation checklists remain deferred to the corresponding Owner designs.

## Shared Coordination and Assurance Foundation

This foundation is not a sixth delivery stage or a new professional Team. It provides cross-cutting operating properties that prevent the human and downstream Owners from reconstructing truth from chat history.

### 1. Recoverable control state

The Delivery Control Record must make the current operating position and applicable identity recoverable across sessions and providers, including before an Active Phase is authorized. It references Owner results, release identity when one exists, evidence validity, deployment outcomes, current finding custodian, recommended route, and pending human action without becoming a second professional truth.

Each producing Owner updates its authoritative result and submits a route proposal. The current Stage Result Integrator owns currentness of the Delivery Control Record during that stage, resolves the single recommended route under the architecture laws, prepares the decision and recipient views, and proposes the control transition. The recipient validates the input and currentness; its `ACCEPT` completes active-Owner transfer. On an accepted transition into a new stage, control-record currentness transfers to that stage's Result Integrator.

### 2. Minimum-sufficient information flow

```text
One or more Owner Authoritative Results
        ↓ recipient-specific projection
Recipient-Specific Minimum-Sufficient View
        ↓
Human Decision View → Human AUTHORIZE and manual trigger
        ↓
Recipient Intake: ACCEPT / CLARIFY / REJECT
        ↓ ACCEPT only
Professional work
```

Logical surfaces:

- **Owner Workbench** — exploration, chats, drafts, tool output, and rejected alternatives; not passed by default.
- **Owner Authoritative Result** — current professional truth for one responsibility.
- **Recipient-Specific View** — minimum-sufficient projection for one named recipient.
- **Human Decision View** — minimum-sufficient projection for one human decision.
- **Evidence Index** — precise, accessible references to material support; detailed evidence is pulled only when needed.
- **Process Archive** — non-authoritative work history; not loaded by default.
- **Recipient Intake Receipt** — `ACCEPT`, `CLARIFY`, or `REJECT` with a specific accountable return.

Complete means complete coverage of the recipient's obligations, not complete document transfer. Information belongs in the active view when removing it could change permitted action, constraints, proof, risk treatment, evidence interpretation, invalidation, or return route.

The recipient defines what is required to discharge its responsibility. Producing Owners provide source mappings; the current Stage Result Integrator assembles the projection without rewriting them. Missing, conflicting, stale, inaccessible, or unauthorized input is rejected rather than guessed. A clarification that changes approved semantics is a rejection and requires a new authoritative result.

A recipient rejection returns a specific reason and proposed accountable Owner to the current Stage Result Integrator. The integrator keeps the current active Owner unchanged, updates the Delivery Control Record, and applies the Return or Safe Stop Law; the human is not asked to invent the repair route.

Raw chats, full exploration history, chain-of-thought, obsolete revisions, complete logs, irrelevant documents, and repeated stable role rules are not passed by default. No summary-of-a-summary may silently replace binding business meaning.

### 3. Permission and context isolation

Every Owner and Executor receives only the tools, filesystem scope, network access, credentials, data, and evidence needed for its bounded responsibility. Sensitive data is minimized and referenced rather than broadcast. Each Professional Owner owns enforcement evidence inside its domain; the current Stage Result Integrator blocks stage exit when required evidence is absent.

Roles that require independent judgment use isolated Workbenches. Permission boundaries and context independence are separate controls: fresh context without least privilege is unsafe, while least privilege without fresh judgment does not create independent proof.

### 4. Trace and Agent-workflow evaluation

Product verification proves the delivered software. Delivery Assurance Owner independently owns the conclusion on whether Agent-workflow trace and evaluation prove that the delivery system itself routes correctly, rejects bad handoffs, preserves obligations, respects permissions, stops safely, and remains stable across model or Skill changes.

Exact tracing, evaluation cases, metrics, thresholds, and storage are later designs. Their architectural responsibility cannot be omitted simply because the first operating mode is manual.

## Forward Control Law

A cross-Owner transition, whether inside one stage or between stages, requires all of the following:

1. the producing Owner has `GO` within its responsibility;
2. no unresolved producer-owned blocker or unclassified unknown is hidden;
3. every required underlying result is current and mutually consistent;
4. the producing Owner submits a route proposal; the current Stage Result Integrator names the single recommended next Owner, prepares the route, and states invalidation and return effects;
5. the Delivery Control Record identifies the same current revisions and, when applicable, exact release identity;
6. the human `AUTHORIZE`s and manually triggers the named Owner in `M0`;
7. the recipient `ACCEPT`s the minimum-sufficient view;
8. any required deployment or external action has a trustworthy outcome for the exact identity.

No generic Team or Stage may be used as an ambiguous return address. The route must identify a specific accountable Professional Owner or a human-controlled external boundary.

## Accountable Return Law

Every finding is first recorded as reproducible evidence, then classified and returned to the earliest specific Owner accountable for the defective definition, decision, implementation, proof, or prepared external action:

- problem, value, investment, or Active Phase defect → Product Director;
- product actor, scenario, state, rule, permission, behavior, or acceptance defect → Product Manager;
- impact omission, preserved-behavior gap, or coverage overclaim → Impact Owner;
- experience-design defect → UX Owner;
- structural technical decision defect → Architecture Owner;
- proof-design defect → Test Design Owner;
- implementation-plan, deployment-design, migration, observability, or recovery-plan defect → Tech Lead;
- implementation, release preparation, or code-quality defect → Development Owner;
- test execution, evidence interpretation, quality judgment, or production-verification defect → Quality Owner;
- Delivery Control Record currentness, decision-view assembly, or cross-Owner route-preparation defect → the current Stage Result Integrator;
- permission or context-isolation enforcement defect → the Professional Owner of the affected domain;
- Agent-workflow assurance baseline, evaluation design, or assurance-conclusion defect → Delivery Assurance Owner;
- Agent-workflow control breach identified by Delivery Assurance → Delivery Assurance Owner retains finding custody and reverification; the named Stage Result Integrator or domain Owner accepts corrective responsibility;
- deployment authorization or execution-record defect → the corresponding Human-Controlled Deployment Boundary;
- business-acceptance or final-disposition inconsistency → Human Governance Layer;
- closeout comparison or recommendation defect → Product Director;
- unknown cause outside a deployment boundary → the discovering Stage Result Integrator retains finding custody and organizes bounded diagnosis until a specific accountable Owner accepts it;
- unknown cause at either deployment boundary → Development Owner initially retains finding custody and organizes bounded diagnosis until Tech Lead, another accountable Owner, or an external capability accepts it.

Before target acceptance, the discovering side retains **finding custody**: preserving evidence, keeping the issue visible, and preventing unsafe progression. The target Owner's `ACCEPT` transfers **corrective responsibility**; merely sending a finding does not. The original independent verification Owner retains **reverification responsibility** after correction. A routing dispute stops progression; it cannot be resolved by repeatedly throwing the finding between Owners or by making the human perform technical classification.

When a correction belongs to another delivery stage, control re-entry first passes through that stage's Result Integrator while the return record still names the specific corrective Owner. The integrator restores stage currentness and routes to that Owner; it cannot redirect, erase, or assume the named professional accountability without new evidence.

Business non-acceptance is first evaluated by Product Director against the original Demand and Active Phase to distinguish an unmet accepted obligation, a changed business fact, immature evidence, or a possible new Demand. It is not automatically labeled as a product defect or operational incident.

The human may change investment or accept declared residual risk, but cannot make failure, unknown, stale evidence, or an unmet obligation disappear. An approved baseline is never overwritten to wash away a failure: a material change creates a new revision, preserves the prior outcome, and causes each dependent Owner to re-evaluate affected evidence. When dependency is uncertain, reuse is not assumed.

Impact analysis is progressive, not a one-time promise of completeness. Product, architecture, code, test, or runtime evidence that reveals a new impact reopens the relevant authoritative results and only the downstream conclusions that depend on them.

## Safe Stop and Escalation Law

Non-`GO` is a legitimate result, not a workflow defect. Product Director may conclude `DISCOVERY` or `NO-GO`; later stages may remain blocked, paused, waiting for evidence, or terminated truthfully.

Every autonomous Owner loop must have a verifiable goal, bounded permissions and resources, failure thresholds, and a human escalation exit. Exact budgets and counts are detailed-design concerns, but these macro controls are mandatory:

- re-entry after a failure requires new evidence, a changed input, or an explicit new decision;
- repeated recurrence without new information, unresolved routing conflict, inaccessible mandatory evidence, or absence of an accountable capability stops the loop;
- a missing capability reopens the L0 responsibility model instead of being silently assigned to the human;
- human unavailability stops consequential progression at the current safe boundary;
- production safety risk prioritizes containment, rollback, or isolation over normal workflow completion;
- no Owner may lower obligations or fabricate completion merely to escape a loop.

## Truthful Completion Semantics

The architecture keeps these facts separate:

- commit is not Development completion;
- passing Developer tests is not independent verification or review;
- test deployment is not Quality acceptance;
- Quality acceptance is not release authorization;
- production deployment is not production verification;
- production verification is not business acceptance;
- business acceptance is not a recorded Phase/Demand disposition;
- Phase success does not necessarily complete the Demand;
- observation pending is not success or failure until the promised evidence matures.

Any failed, partial, stale, mismatched, or unknown outcome stops the success path and remains visible. Business non-acceptance is a truthful product result, not automatically an operational incident.

## Options Considered

### A. Five professional Teams

Rejected. The five lifecycle boxes are not structurally equivalent: the first two contain peer Professional Owners, the next two are Owner-led execution structures, and the fifth combines professional results with Human Governance outcomes. Calling all five `Team` obscures ownership and forces extra explanation without improving operation.

### B. One global end-to-end Agent coordinator

Rejected as the professional authority. It would combine product judgment, implementation narrative, proof, and release interpretation in one context, recreating confirmation bias and an accountability sink.

Mechanical storage or routing support may execute under the current Stage Result Integrator's authority, but it owns no professional or business conclusion and is not a new Professional Owner at L0.

### C. One Agent Team with five professional delivery stages

Selected. It separates the organization chart from the lifecycle, preserves specialized Owner accountability, gives each stage an integrator without collectivizing truth, and keeps the human in consequential control without assigning workflow assembly.

### D. Fully autonomous cross-Owner runtime

Rejected for `M0`. Automation before boundaries, state, evidence, failure routes, permissions, and human load are proven would make failures faster and harder to diagnose. Manual activation is retained as a temporary learning mechanism with explicit exit conditions.

### E. Detailed V1.2 flow and state model as the macro baseline

Rejected. The previous candidate fixed flow IDs, route IDs, package identities, state machines, incident mechanics, and cutover rules before the macro model and its human view were accepted. Those materials remain historical evidence only.

## Architecture Acceptance Tests

### Cold-reader test

The L0 map is a navigation view, not a role inventory or operating manual. A first-time Chinese-speaking business/product reader at normal desktop scale must be able to:

1. identify within 10 seconds one Human, one Agent Team, and five delivery stages in order;
2. identify within 60 seconds why each stage exists, which Stage Result Integrator advances it, and what observable fact must be true before the next party can take responsibility;
3. locate the two human-controlled deployment boundaries and distinguish deployment from Quality acceptance, production verification, business acceptance, and final Phase/Demand disposition;
4. explain the cross-Owner handoff sequence without interpreting human authorization as professional proof;
5. locate the shared support rules and the accountable return and safe-stop rule.

Detailed specialist ownership, artifacts, state fields, invalidation mechanics, and role procedures remain in this written specification and later Owner-domain designs. Their omission from L0 is deliberate visual prioritization, not semantic deletion.

No noun may simultaneously mean organization, workflow stage, responsibility, state, and artifact. If understanding L0 requires a glossary paragraph on the diagram, or if every professional detail is promoted to first-screen weight, the visual has failed.

### Golden target scenario

The reserved `qft-tenants` future-tenant request is a whole-chain acceptance scenario, not a design input or a solution to encode here. A successful future run must prove that the architecture causes the Agent Team—without human reminders—to:

- reconstruct the real need from the customer's incomplete sentence;
- distinguish new target behavior, preserved current-tenant behavior, and forbidden side effects;
- discover and trace broad business and system impact before planning while allowing later evidence to reopen it;
- map every applicable obligation through proof, implementation, quality, and production;
- preserve exact revision and release identity through repair and redeployment;
- route newly found gaps to the correct Professional Owner;
- separate technical production truth from business acceptance and final disposition.

If the human must remind the Agent not to affect the current tenant, identify that a release changed, assemble missing context, or choose the technical return route, the architecture or downstream Owner design fails.

### Required adversarial scenarios

The golden case is necessary but insufficient. The future complete-chain validation must also include:

- a legitimate `DISCOVERY` or `NO-GO` result;
- Quality discovering an upstream product or proof-design defect;
- a release revision invalidating prior verification or Quality evidence;
- a failed, partial, or unknown deployment;
- technical production verification passing while business acceptance fails or remains pending;
- a new session or provider recovering from current authoritative results and the Delivery Control Record;
- an autonomous loop reaching its stop or escalation boundary.

## Chinese Macro Architecture Map Contract

### B+ view boundary

The approved direction is **B+**: deliver one clean L0 map now. L0 answers four questions only:

1. what the Human retains and what the Agent Team performs;
2. what the five delivery stages are and why each exists;
3. who advances each stage and what observable completion fact permits handoff;
4. where human deployment control, shared support, accountable return, and safe stop sit around the main path.

L0 is not a complete role map, SOP, artifact catalogue, state machine, or assurance manual. Professional Owner and Executor details remain authoritative in this document even when they are not rendered as individual L0 cards.

The map must not show flow IDs, route IDs, schemas, state machines, detailed finding types, Task Packets, retry counts, incident subflows, automation mechanics, or the `qft-tenants` solution. It must not reintroduce those details through tiny footnotes, nested cards, hidden metadata, or a glossary embedded on the canvas.

### Exact visible content

The formal map uses the following Chinese-first copy. Canonical English role names may appear as secondary labels.

**Header**

- Title: `一人 + Agent Team 架构`
- Proposition: `一个人保留业务最终责任，一支 AI 专业团队分工完成分析、开发、验证和结果闭环`
- Status: `目标架构｜当前尚未运行`
- Initial operation: `首轮方式：跨专业交接先由人手动批准并启动`

**Human band**

- Band title: `人负责的决定和动作`
- Boundary: `不负责任务调度或替专业角色证明技术正确`
- Group 1: `一起定方向，决定重大取舍` / `产品方向 · 重大架构与风险取舍`
- Group 2: `批准下一步并执行部署` / `批准推荐的下一责任人 · 执行已准备好的测试/生产部署`
- Group 3: `验收业务结果并决定下一步` / `业务验收 · 分别决定本次范围和整体需求的去向`

**Cross-Owner handoff line**

```text
专业负责人确认结果可交接
→ 阶段负责人检查是否齐全一致并说明下一步
→ 人批准并启动
→ 下一负责人确认信息足够并接手
```

`阶段负责人` is the visible Chinese description of the applicable Stage Result Integrator. It checks currentness and consistency and recommends the next route; it cannot replace or rewrite a Professional Owner conclusion.

**Five-stage path**

| Stage | Why it exists | Stage Result Integrator | 本阶段完成标准 | Necessary secondary note |
|---|---|---|---|---|
| `01 产品定义收敛` | `确认为什么做、为谁做、本次做到哪里，以及必须改变、保持和禁止什么。` | `Product Director` | `必需专业结论及按需启用/跳过决定已确认且一致；本次范围、目标/保留/禁止行为和影响边界清楚，无阻塞问题。` | `也允许得出继续发现、暂停或不做。` |
| `02 测试设计与实施规划` | `先定义每项产品承诺怎么验证，再制定开发、部署、观察和恢复计划。` | `Tech Lead` | `验证要求与实施、部署、观察和恢复计划均已确认且一致；没有未解决的上游阻塞。` | `Test Design Owner 先定义验证要求，Tech Lead 再据此规划。` |
| `03 实现与开发验证` | `按计划实现，并在开发域内由独立上下文完成功能验证和代码审查。` | `Development Owner` | `计划工作和必需测试已完成；独立验证与代码审查通过，无开发阻塞；待测版本及影响行为的配置、迁移、开关和依赖已锁定，部署准备可执行。` | — |
| `04 独立质量验收` | `在测试环境独立验证实际版本，形成质量判断，而不是让开发自证。` | `Quality Owner` | `指定测试版本的必需独立验证已完成；阻塞问题已关闭；质量结论与剩余风险已记录。` | `Quality 只给质量结论，不自己改代码，也不替 Human 做发布授权。` |
| `05 生产验证与产品决策` | `核对线上真实结果，并分别形成技术事实、业务判断和最终决定。` | `Product Director` | `线上实际版本已核对；技术结果、业务验收、本次范围与整体需求的决定已分别记录；观察中或未知不算成功。` | `Quality 生产验证 · Human 业务验收 · Product Director 下一步建议 · Human 最终决定。` |

The prefix `本阶段完成标准` is visible on every stage card. Abstract labels such as `产品定义就绪`, `可提测发布身份`, `可发布身份`, or `真实结果与阶段处置` must not substitute for the observable facts above.

**Why the Stage 3 → 4 boundary exists**

`提测` is not a sixth stage, a ritual, or a completion status. The boundary exists to transfer one deterministic, development-proven candidate into an independent Quality judgment:

```text
Development Owner confirms the Stage 3 completion facts
→ Human approves and executes the prepared test-environment deployment
→ Quality confirms the actually deployed version and deployment evidence
→ Quality accepts responsibility and begins Stage 4
```

The visible test boundary uses:

- `Human｜批准并执行已准备好的测试环境部署`
- `Quality｜确认实际部署版本与部署证据`

The visible production boundary uses:

- `Human｜批准并执行已准备好的生产部署`
- `Quality｜确认线上实际版本与部署证据`

Deployment failure, partial success, version mismatch, or unknown identity stops the success path. Deployment never proves Quality acceptance, production behavior, or business success.

**Shared support and failure handling**

- Obligation trace: `要改变什么 · 必须保持什么 · 绝不能发生什么 → 先定义如何验证 → 开发并独立复核 → 测试环境独立验收 → 核对线上真实结果`
- Foundation title: `支撑全流程的共同规则`
- Foundation item 1: `当前进度与版本事实`
- Foundation item 2: `给下一负责人必需且足够的信息`
- Foundation item 3: `最小权限 · 独立检查使用全新上下文`
- Foundation item 4: `独立检查 Agent 协作机制是否可靠`
- Return rule: `问题处理｜交给最早能修正根因的专业负责人；修完仍由原独立检查方复验。`
- Stop rule: `停止条件｜证据不足、版本对不上、找不到负责者，或反复没有新证据 → 停止推进并请人决策。`

### Visual grammar and density budget

- Fixed implementation canvas: `1920×1080`, 16:9. Acceptance is performed from an actual `1440×810` render at 100% browser zoom, without horizontal scrolling, clipping, overlap, or text truncation.
- Chinese is the primary explanatory language. Canonical English role names are secondary labels, not the main sentence structure.
- The dominant scan path is: title and proposition → Human band → cross-Owner handoff → five stages left to right → shared support → return/stop.
- Visual priority is: five-stage path first, Human authority and deployment gates second, shared support and failure rules third.
- Repeated framed units are limited to the five stage cards and two deployment gates. Supporting regions may each use one containing frame; nested Owner/Executor card inventories are forbidden on L0. Removing a frame does not permit the same detail to return as unbounded text.
- At the accepted `1440×810` render, the actual displayed type sizes are at least: title `30px`; stage title `18px`; purpose and completion copy `14px`; secondary notes and metadata `12.5px`. A uniformly scaled 1920×1080 source therefore uses at least `40px`, `24px`, `19px`, and `17px` respectively.
- At `1440×810`, each stage card may use at most three rendered lines for purpose, two for the integrator, five for completion, and two for its optional note. Each Human group, foundation item, deployment-gate step, return rule, and stop rule may use at most two rendered lines. Text may not be shrunk to satisfy these limits.
- Density passes only when the actual render meets those line, size, overflow, and clipping limits and fresh readers pass the 10-second and 60-second tasks. Counting containers alone is never acceptance evidence.
- Blue carries the normal delivery path, gold carries Human authority and deployment control, purple carries shared support, and red is reserved for actual stop conditions. Color alone must not carry meaning.
- Defensive prose such as `不是 5 个 Team`, `不是第六阶段`, or `四个事实彼此独立` is forbidden. The layout must communicate hierarchy without arguing with the reader.
- SVG may contain structural markers for deterministic validation, but hidden prose, off-canvas text, zero-opacity content, or metadata-only semantics cannot satisfy a visible requirement.

### Deferred L1 views

No L1 view is in the current delivery scope. `阶段与责任` and `控制与失败` are named future problem-bounded views, not pre-authorized deliverables and not a fixed diagram suite. They may be designed only when the corresponding Owner-domain or M0 operating detail is mature enough to answer a real reader question without inventing missing semantics.

Any future L1 remains a non-normative projection of this specification. It cannot become an independent source of roles, responsibilities, gates, states, or completion rules.

### Projection options and trade-off

- **Dense all-in-one L0 — rejected.** It preserves detail but gives every item equal visual weight; the current 1920×1200 draft proved that semantic completeness can still produce an unreadable navigation map.
- **Prebuilt L0 plus a fixed L1 suite — rejected for now.** It would reduce L0 density but prematurely freeze detail that the Owner-domain and M0 designs have not yet proved.
- **B+ — selected and approved in writing.** One clean L0 is implemented now; focused L1 views are created later only against real questions and mature source material.

B+ deliberately trades first-screen completeness for truthful hierarchy. That trade-off is acceptable because the written specification remains the sole semantic source. Reopen B+ if readers cannot locate the five-stage path and Human gates, if critical omitted detail repeatedly causes wrong handoff decisions, or if a future L1 cannot be generated without changing L0 semantics.

## Risks, Unknowns, and Reopen Conditions

The L0 baseline does not pretend the following are solved:

- whether every role name and Stage Result Integrator mapping proves optimal in real project use;
- the detailed boundary between Product Director and Product Manager;
- exact Impact, UX, Architecture, Test Design, Development, Quality, and closeout methods;
- the physical form and size of authoritative results, recipient views, Human Decision Views, and the Delivery Control Record;
- how dependencies and selective evidence invalidation are represented and calculated;
- exact permissions, sandbox, secrets, trace, Agent-evaluation, resource, and stop thresholds;
- whether manual Owner activation creates excessive human load in repeated practice;
- which gates can later be automated without weakening human authority or professional evidence;
- how provider tool access and context behavior affect portability;
- concurrent Demands or multiple live release identities;
- whether the `qft-tenants` target and adversarial cases expose a missing responsibility or misplaced boundary.

Any evidence that a responsibility has no accountable Owner, a Stage Result Integrator routinely overrides specialists, a downstream role reconstructs upstream work, an independent role inherits producer bias, control truth depends on chat history, or the human coordinates executors or technical routing reopens this architecture instead of being patched inside a Skill.

## Design Sequence After B+ Written Approval

1. Write and obtain explicit approval of the B+ projection contract above — completed on 2026-08-05.
2. Invoke `writing-plans` to replace the rejected high-density candidate through the existing SVG/PNG/test path.
3. Implement a new `DRAFT` SVG/PNG candidate and prove structure, rendering, density, desktop readability, and fresh-context comprehension.
4. Obtain explicit human semantic and visual approval of the exact committed SVG/PNG bytes before publication.
5. Publish the accepted non-normative projection and close only the L0 visual gate.
6. Design each Professional Owner domain separately, starting with Product Director and its Product Manager intake boundary.
7. Search official and community Skill sources for each approved capability boundary.
8. Adapt or create provider-neutral Skills and validate them independently.
9. Run the complete manual chain against the golden and adversarial acceptance scenarios.
10. Consider cross-Owner automation only after repeated manual delivery proves the operating model.
