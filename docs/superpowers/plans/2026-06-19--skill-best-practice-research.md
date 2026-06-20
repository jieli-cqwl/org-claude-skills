# Skill Best-practice Research Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce a source-backed, challenge-tested model for what makes an agent Skill effective, without predefining quality dimensions or judging this repository's current Skills.

**Architecture:** Execute the approved research design as a staged evidence pipeline: source inventory, atomic claim extraction, failure-mode mapping, counterexample testing, adversarial review, and final provisional model packaging. Each stage produces a reviewable artifact under `docs/reports/skill-best-practice-research-2026-06-19/` and must preserve source-backed facts separately from inference and unknowns.

**Tech Stack:** Markdown research artifacts, source-backed citations, local repository inspection with `rg`/`sed`, web research for public sources, optional parallel research agents, and existing quick validation via `git diff --check` plus targeted doc review.

## Global Constraints

- Do not assess `product-director`, `product-manager`, `design`, `test-design`, `tech-lead`, or `delivery-owner`.
- Do not decide `standard-chain` flow quality or dogfood readiness.
- Do not edit any Skill, contract, schema, test, fixture, or runtime config.
- Do not treat gstack, Superpowers, OpenAI, Anthropic, or this repository as automatic authority.
- Do not start from a predefined rubric and search for evidence that supports it.
- No quality dimension may appear before source-backed claim extraction.
- Every candidate principle must have source refs and a failure-mode rationale.
- Unknowns remain unknown; do not convert weak evidence into standards.

---

## Source Of Truth

- Design spec: `docs/superpowers/specs/2026-06-18--skill-best-practice-research--design.md`
- Planning context: `task_plan.md`, `findings.md`, `progress.md`
- Existing local audit reference, for evidence only: `shared/skills/skill-quality-audit/SKILL.md`
- Existing local audit dimensions, for evidence only: `shared/skills/skill-quality-audit/references/audit-dimensions.md`
- Local/runtime skill-writing guidance, for evidence only: `/Users/lijieli/.codex/skills/.system/skill-creator/SKILL.md`, `/Users/lijieli/.agents/skills/skill-creator/SKILL.md`, `/Users/lijieli/.agents/skills/writing-skills/SKILL.md`

## File Responsibility Map

- Create `docs/reports/skill-best-practice-research-2026-06-19/source-inventory.md`: source classes, selected sources, authority level, scope, and exclusion reasons.
- Create `docs/reports/skill-best-practice-research-2026-06-19/claim-extraction.md`: atomic claims copied from sources as claims, not as principles.
- Create `docs/reports/skill-best-practice-research-2026-06-19/failure-mode-map.md`: agent failure modes and source claims tied to each mode.
- Create `docs/reports/skill-best-practice-research-2026-06-19/counterexamples.md`: bad or misleading Skill examples and what candidate principles catch or miss.
- Create `docs/reports/skill-best-practice-research-2026-06-19/adversarial-review.md`: red-team attacks on candidate principles and resolution states.
- Create `docs/reports/skill-best-practice-research-2026-06-19/provisional-model.md`: validated principles, rejected ideas, scenario-specific limits, and later-use guidance.
- Modify `progress.md`: record execution milestones and verification results.
- Modify `findings.md`: add only high-level decisions and final artifact pointers, not the full research content.
- Modify `task_plan.md`: mark this research execution phase and completion status.

## Task 1: Create Research Workspace And Source Inventory

**Files:**
- Create: `docs/reports/skill-best-practice-research-2026-06-19/source-inventory.md`
- Modify: `task_plan.md`
- Modify: `progress.md`

**Interfaces:**
- Consumes: `docs/superpowers/specs/2026-06-18--skill-best-practice-research--design.md`
- Produces: a bounded source inventory that Task 2 uses for claim extraction.

- [ ] **Step 1: Re-read the design spec**

Run:

```bash
sed -n '1,260p' docs/superpowers/specs/2026-06-18--skill-best-practice-research--design.md
```

Expected: the output includes the fixed research order beginning with source collection and ending with provisional model derivation.

- [ ] **Step 2: Create the report directory**

Run:

```bash
mkdir -p docs/reports/skill-best-practice-research-2026-06-19
```

Expected: command exits 0.

- [ ] **Step 3: Write `source-inventory.md` with source classes and candidate sources**

Create this exact structure:

```markdown
# Skill Best-practice Source Inventory

## Scope

This inventory selects sources for discovering what makes an agent Skill effective. It does not judge this repository's Skills.

## Source Selection Rules

- Prefer official or primary sources.
- Treat community workflows as mechanism examples, not authorities.
- Include local formal systems only as evidence of this repository's current assumptions.
- Include empirical failure evidence when it exposes actual agent or Skill failure modes.
- Exclude sources that only provide popularity, marketing claims, or unsourced opinions.

## Sources

| Source ID | Source | Class | Why Included | Scope Limit | Status |
| --- | --- | --- | --- | --- | --- |
| SRC-001 | `https://developers.openai.com/codex/skills` | Official source | Official Codex guidance for agent skills, progressive disclosure, invocation, and skill structure | OpenAI/Codex-specific unless cross-source supported | selected |
| SRC-002 | `https://developers.openai.com/codex/learn/best-practices` | Official source | Official Codex guidance for turning repeatable work into skills | OpenAI/Codex-specific unless cross-source supported | selected |
| SRC-003 | `https://agentskills.io/specification` | Official source | Open Agent Skills format specification for `SKILL.md`, optional directories, and progressive disclosure | Format-focused; not a complete behavior-quality model | selected |
| SRC-004 | `https://code.claude.com/docs/en/skills` | Official source | Official Claude Code guidance for creating and using skills | Claude Code-specific unless cross-source supported | selected |
| SRC-005 | `https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview` | Official source | Official Claude API Agent Skills overview for skill purpose, packaging, and usage | Anthropic API-specific unless cross-source supported | selected |
| SRC-006 | `https://github.com/obra/superpowers` | High-signal workflow | Maintained workflow skill set with explicit process discipline | Workflow-specific, not universal authority | selected |
| SRC-007 | `https://github.com/garrytan/gstack` | High-signal workflow | Agentic coding workflow with role/process mechanisms | Workflow-specific, not universal authority | selected |
| SRC-008 | `shared/skills/skill-quality-audit/SKILL.md` | Local formal system | Local formal audit method for Skill readiness | May encode local bias | selected |
| SRC-009 | `shared/skills/skill-quality-audit/references/audit-dimensions.md` | Local formal system | Local candidate dimensions and evidence levels | Must be treated as evidence, not pre-approved rubric | selected |
| SRC-010 | `docs/reports/standard-chain-flow-instruction-control-full-review-2026-05-28.md` | Empirical failure evidence | Prior evidence-backed review of flow and instruction-control failures | Context-specific; must not overgeneralize | selected |
| SRC-011 | `/Users/lijieli/.codex/skills/.system/skill-creator/SKILL.md` | Local/runtime formal system | Codex runtime guidance for skill structure, progressive disclosure, resources, validation, and iteration | Runtime-specific; may reflect product assumptions | selected |
| SRC-012 | `/Users/lijieli/.agents/skills/skill-creator/SKILL.md` | Local/runtime formal system | Agent skill creation guidance for trigger design, test prompts, evaluation, and iteration | Runtime-specific; may reflect local workflow assumptions | selected |
| SRC-013 | `/Users/lijieli/.agents/skills/writing-skills/SKILL.md` | Local/runtime formal system | Skill-writing guidance focused on pressure scenarios, discovery, trigger descriptions, token efficiency, and validation | Superpowers-specific; must not become an unchallenged rubric | selected |
```

- [ ] **Step 4: Verify source accessibility and line refs**

Use web open for public sources and `nl -ba` for local sources. Update `source-inventory.md` with access dates for URLs and line ranges for local files.

Expected: every selected source has an access date or local `path:line` range in `source-inventory.md`.

- [ ] **Step 5: Update progress**

Append to `progress.md`:

```markdown
### Skill Best-practice Research - Task 1
- **Status:** complete
- Created `docs/reports/skill-best-practice-research-2026-06-19/source-inventory.md`.
- Source inventory distinguishes official, high-signal workflow, local formal system, and empirical failure evidence.
```

- [ ] **Step 6: Verify Task 1**

Run:

```bash
rg -n "UNRESOLVED_SOURCE_REF|STATUS_UNRESOLVED" docs/reports/skill-best-practice-research-2026-06-19/source-inventory.md
git diff --check -- docs/reports/skill-best-practice-research-2026-06-19/source-inventory.md progress.md task_plan.md
```

Expected: first command returns no matches after source refs are verified; second command exits 0.

## Task 2: Extract Atomic Claims Without Creating Principles

**Files:**
- Create: `docs/reports/skill-best-practice-research-2026-06-19/claim-extraction.md`
- Modify: `progress.md`

**Interfaces:**
- Consumes: `docs/reports/skill-best-practice-research-2026-06-19/source-inventory.md`
- Produces: atomic source-backed claims for Task 3.

- [ ] **Step 1: Read the source inventory**

Run:

```bash
sed -n '1,260p' docs/reports/skill-best-practice-research-2026-06-19/source-inventory.md
```

Expected: sources are classified and exact refs are present.

- [ ] **Step 2: Create `claim-extraction.md`**

Create this exact structure:

```markdown
# Skill Best-practice Claim Extraction

## Rule

This file extracts claims. It does not define quality dimensions or score Skills.

## Claims

| Claim ID | Source ID | Source Ref | Source Class | Claim | Surface | Failure Mode Reduced | Scope | Evidence Strength | Limits |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
```

- [ ] **Step 3: Extract claims from each source**

For each selected source, add atomic rows. Each row must satisfy:

- `Claim` is a source-backed assertion or demonstrated mechanism.
- `Surface` is one of: `format`, `trigger`, `workflow`, `behavior-control`, `validation`, `runtime`, `maintenance`, `failure-handling`.
- `Failure Mode Reduced` names a concrete agent failure, such as over-triggering, premature execution, skipped gate, fake completion, stale evidence, output unusable by downstream consumer, or context overload.
- `Evidence Strength` is one of: `direct-source`, `cross-source-candidate`, `empirical`, `inferred`, `unknown`.
- `Limits` states where not to generalize.

- [ ] **Step 4: Check no principles were introduced**

Run:

```bash
rg -n "Principle|Dimension|Rubric|Best practice:|should always|must always" docs/reports/skill-best-practice-research-2026-06-19/claim-extraction.md
```

Expected: no matches except the heading rule if the wording appears there. If a match is a premature principle, rewrite it as a source claim or move it out.

- [ ] **Step 5: Update progress**

Append to `progress.md`:

```markdown
### Skill Best-practice Research - Task 2
- **Status:** complete
- Created `claim-extraction.md` with atomic source-backed claims only.
- No quality dimension or scoring rubric was introduced in this task.
```

- [ ] **Step 6: Verify Task 2**

Run:

```bash
git diff --check -- docs/reports/skill-best-practice-research-2026-06-19/claim-extraction.md progress.md
```

Expected: exits 0.

## Task 3: Build Failure-mode Map And Candidate Principle Register

**Files:**
- Create: `docs/reports/skill-best-practice-research-2026-06-19/failure-mode-map.md`
- Modify: `docs/reports/skill-best-practice-research-2026-06-19/provisional-model.md`
- Modify: `progress.md`

**Interfaces:**
- Consumes: `claim-extraction.md`
- Produces: failure-mode coverage and a provisional candidate register for counterexample testing.

- [ ] **Step 1: Create `failure-mode-map.md`**

Create:

```markdown
# Skill Best-practice Failure-mode Map

## Purpose

Map extracted claims to the agent failures they reduce. A failure mode without source-backed claims remains unknown.

## Failure Modes

| Failure Mode ID | Failure Mode | Supporting Claim IDs | Source Coverage | Remaining Unknowns |
| --- | --- | --- | --- | --- |
```

- [ ] **Step 2: Fill failure modes from claims**

Use only failure modes already present in `claim-extraction.md`. Do not invent new dimensions. Add rows for repeated failure modes and mark source coverage as `single-source`, `multi-source`, `empirical`, or `unknown`.

- [ ] **Step 3: Create initial `provisional-model.md` candidate register**

Create:

```markdown
# Provisional Skill Quality Model

## Status

This is a candidate register until counterexample testing and adversarial review are complete.

## Candidate Principle Register

| Principle ID | Candidate Principle | Derived From Claim IDs | Failure Mode Rationale | Status | Scope | Limits | Counterexample Status | Red-team Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |

## Rejected Or Non-principles

| Item | Why Rejected Or Deferred |
| --- | --- |
```

- [ ] **Step 4: Promote only eligible candidate principles**

Promote a claim group only if it satisfies one of the gates from the design spec:

- multiple independent high-signal sources
- official source guidance without conflict
- recurring empirical failure mode
- necessary for runtime safety, handoff correctness, or evidence integrity

Set `Status` only to `source-backed`, `cross-source-supported`, `empirically-supported`, `scenario-specific`, `contested`, `weak`, or `rejected`.

- [ ] **Step 5: Update progress**

Append to `progress.md`:

```markdown
### Skill Best-practice Research - Task 3
- **Status:** complete
- Created `failure-mode-map.md`.
- Created the candidate principle register in `provisional-model.md`.
- Candidate principles remain provisional pending counterexample and red-team review.
```

- [ ] **Step 6: Verify Task 3**

Run:

```bash
rg -n "source-backed|cross-source-supported|empirically-supported|scenario-specific|contested|weak|rejected" docs/reports/skill-best-practice-research-2026-06-19/provisional-model.md
git diff --check -- docs/reports/skill-best-practice-research-2026-06-19/failure-mode-map.md docs/reports/skill-best-practice-research-2026-06-19/provisional-model.md progress.md
```

Expected: first command shows candidate statuses; second exits 0.

## Task 4: Counterexample Testing

**Files:**
- Create: `docs/reports/skill-best-practice-research-2026-06-19/counterexamples.md`
- Modify: `docs/reports/skill-best-practice-research-2026-06-19/provisional-model.md`
- Modify: `progress.md`

**Interfaces:**
- Consumes: candidate principle register in `provisional-model.md`
- Produces: counterexample evidence and updated candidate statuses.

- [ ] **Step 1: Create `counterexamples.md`**

Create:

```markdown
# Skill Best-practice Counterexamples

## Purpose

Test whether candidate principles can identify misleading or failing Skills. Counterexamples are used to weaken or reject principles that only describe polished documents.

## Counterexamples

| Counterexample ID | Source Ref | Failure Type | Why It Looks Acceptable | Actual Failure | Principles That Catch It | Principles That Miss It | Model Update |
| --- | --- | --- | --- | --- | --- | --- | --- |
```

- [ ] **Step 2: Collect at least five counterexamples**

Include these failure types:

- clear format but unreliable behavior
- detailed process but weak failure handling
- over-triggering or stealing adjacent work
- output no downstream consumer can use
- prose used where deterministic checks are needed

Counterexamples may come from local historical reports, public examples, or synthetic examples clearly labeled as synthetic. Synthetic examples cannot alone reject a principle; they can only identify a question for red-team review.

- [ ] **Step 3: Update candidate principle register**

For each counterexample, update `Counterexample Status` in `provisional-model.md`:

- `passes-counterexample`
- `weakened`
- `misses-counterexample`
- `not-applicable`

If a principle misses a relevant counterexample, change `Status` to `contested` or `weak` unless a clear scope limit explains why.

- [ ] **Step 4: Update progress**

Append to `progress.md`:

```markdown
### Skill Best-practice Research - Task 4
- **Status:** complete
- Created `counterexamples.md`.
- Updated candidate principle counterexample status in `provisional-model.md`.
```

- [ ] **Step 5: Verify Task 4**

Run:

```bash
rg -n "passes-counterexample|weakened|misses-counterexample|not-applicable" docs/reports/skill-best-practice-research-2026-06-19/provisional-model.md
git diff --check -- docs/reports/skill-best-practice-research-2026-06-19/counterexamples.md docs/reports/skill-best-practice-research-2026-06-19/provisional-model.md progress.md
```

Expected: first command shows updated statuses; second exits 0.

## Task 5: Adversarial Review And Final Model Package

**Files:**
- Create: `docs/reports/skill-best-practice-research-2026-06-19/adversarial-review.md`
- Modify: `docs/reports/skill-best-practice-research-2026-06-19/provisional-model.md`
- Modify: `findings.md`
- Modify: `task_plan.md`
- Modify: `progress.md`

**Interfaces:**
- Consumes: `source-inventory.md`, `claim-extraction.md`, `failure-mode-map.md`, `counterexamples.md`, candidate register in `provisional-model.md`
- Produces: final research package and readiness for a later, separate Skill assessment plan.

- [ ] **Step 1: Create `adversarial-review.md`**

Create:

```markdown
# Skill Best-practice Adversarial Review

## Purpose

Attack the candidate model before it can be used as a rubric.

## Challenges

| Challenge ID | Attack Role | Target Principle ID | Challenge | Evidence Or Reasoning | Resolution | Model Update |
| --- | --- | --- | --- | --- | --- | --- |
```

- [ ] **Step 2: Run the five attack roles**

For each candidate principle in `provisional-model.md`, challenge it from these roles where applicable:

- Authority-bias attacker
- Circularity attacker
- Predictive-validity attacker
- Generalization attacker
- Verification attacker

Set `Resolution` to `closed`, `accepted-risk`, `blocked`, or `rejected`.

- [ ] **Step 3: Finalize `provisional-model.md`**

Add these sections below the candidate register:

```markdown
## Validated Principles

Only principles with acceptable source support, counterexample handling, and red-team status are listed here.

## Scenario-specific Principles

These principles apply only under stated contexts.

## Rejected Ideas

These ideas must not be used as scoring standards.

## Unknowns

These areas need more evidence before they can become standards.

## Later Application Guidance

This model may be used to evaluate a repository Skill only after confirming the target Skill's intended job. Contested or unknown principles must remain non-scoring context.
```

- [ ] **Step 4: Update findings and progress**

Append artifact pointers to `findings.md`:

```markdown
## Skill Best-practice Research Package
- Source inventory: `docs/reports/skill-best-practice-research-2026-06-19/source-inventory.md`
- Claim extraction: `docs/reports/skill-best-practice-research-2026-06-19/claim-extraction.md`
- Failure-mode map: `docs/reports/skill-best-practice-research-2026-06-19/failure-mode-map.md`
- Counterexamples: `docs/reports/skill-best-practice-research-2026-06-19/counterexamples.md`
- Adversarial review: `docs/reports/skill-best-practice-research-2026-06-19/adversarial-review.md`
- Provisional model: `docs/reports/skill-best-practice-research-2026-06-19/provisional-model.md`
```

Append to `progress.md`:

```markdown
### Skill Best-practice Research - Task 5
- **Status:** complete
- Created adversarial review and finalized the provisional model package.
```

- [ ] **Step 5: Final verification**

Run:

```bash
rg -n "TBD|TODO|UNRESOLVED_SOURCE_REF|STATUS_UNRESOLVED" docs/reports/skill-best-practice-research-2026-06-19
git diff --check -- docs/reports/skill-best-practice-research-2026-06-19 docs/superpowers/plans/2026-06-19--skill-best-practice-research.md findings.md progress.md task_plan.md
bash tests/run-all.sh --quick
```

Expected:

- First command has no unresolved placeholders in final research artifacts.
- `git diff --check` exits 0.
- Quick tests pass.

- [ ] **Step 6: Commit**

Run:

```bash
git add docs/reports/skill-best-practice-research-2026-06-19 docs/superpowers/plans/2026-06-19--skill-best-practice-research.md findings.md progress.md task_plan.md
git commit -m "docs: add skill best-practice research package"
```

Expected: commit succeeds and includes only the research package, execution plan, and planning-file updates.
