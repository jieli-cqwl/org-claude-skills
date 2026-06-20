# Task Plan: Skill Best-practice Research

## Goal
Build an evidence-first research process that discovers what makes an agent Skill effective from authoritative sources, strong examples, failure evidence, and adversarial review, before deriving any evaluation dimensions for this repository's Skills.

## Current Phase
Phase 8

## Phases

### Phase 1: Scope And Acceptance Lock
- [x] Capture the user's current request.
- [x] Define the task as review-design guardrail, not execution.
- [x] Record acceptance criteria and non-goals.
- **Status:** complete

### Phase 2: Design Gap Review
- [x] Re-read the current design concept.
- [x] Check for missing review dimensions.
- [x] Check for ambiguity in agent roles, evidence rules, severity, and final decisions.
- [x] Record findings in findings.md.
- **Status:** complete

### Phase 3: Tightened Proposal
- [x] Produce a concise revised design outline.
- [x] Separate must-have corrections from optional improvements.
- [x] Ask the user to approve before writing any formal design doc.
- **Status:** complete

### Phase 4: Delivery Check
- [x] Verify the response stays within the requested guardrail scope.
- [x] Report remaining open risks or questions.
- **Status:** complete

### Phase 5: Formal Review Design Draft
- [x] Re-read plan and findings before drafting.
- [x] Cancel controlled dogfood-readiness draft after user scope correction.
- [x] Replace this direction with Skill best-practice evidence research.
- **Status:** blocked by scope correction

### Phase 6: Skill Best-practice Model Alignment
- [x] Stop incorrect standard-chain dogfood-readiness research direction.
- [x] Align on the real target: discover Skill best-practice criteria from source-backed evidence before deriving dimensions.
- [x] Design source-backed research plan for Skill best-practice criteria.
- [x] Wait for user approval before dispatching new research agents.
- **Status:** complete

### Phase 7: Design Doc Written And User Review
- [x] Write formal design doc.
- [x] Self-review for placeholders, contradictions, ambiguity, and scope drift.
- [x] Run fresh verification.
- [x] Ask user to review the design doc before implementation planning.
- **Status:** complete

### Phase 8: Execution Plan Prepared
- [x] Write execution plan for the approved Skill best-practice research design.
- [x] Keep the plan limited to evidence-first research, not current Skill assessment.
- [x] Include source inventory, claim extraction, failure-mode mapping, counterexample testing, adversarial review, and provisional model packaging.
- [x] Run fresh verification for the plan and planning-file updates.
- [x] Commit the execution plan and planning-file updates.
- **Status:** complete

## Key Questions
1. Which authoritative or high-signal sources can legitimately inform what makes a Skill effective?
2. What claims do those sources make about Skill structure, behavior control, workflow, validation, and failure handling?
3. Which claims are source-backed facts, which are cross-source inferences, and which remain unknown?
4. Which candidate dimensions survive evidence review, counterexamples, and red-team challenge?
5. How should validated dimensions later be applied to this repository's Skills without subjective taste or external-authority bias?

## Decisions Made
| Decision | Rationale |
|----------|-----------|
| Treat this turn as review-design guardrail only | User asked to check for omissions and ambiguity, not to execute review or edit skills. |
| Use planning files at repo root | The invoked planning-with-files skill requires project-directory planning files when none exist. |
| Do not write formal design doc yet | Brainstorming flow still requires user approval of the design before documentation. |
| Continue with full review design draft | User approved the guardrail corrections and asked to continue. |
| Redefine goal around trustworthiness and blocker discovery | User flagged the previous goal as insufficiently clear; the stronger target is a decision system, not merely a review-design document. |
| Demote the target from team-ready to dogfood-ready | First-principles review shows static evaluation cannot prove team adoption readiness without real-run evidence. |
| Center the design on a dogfood readiness gate | The next useful decision is whether one controlled real requirement can safely exercise the chain. |
| Correct scope to Skill best-practice model first | User clarified that the immediate research target is what a best-practice Skill is, not standard-chain dogfood readiness. |
| Move from predefined rubric to bottom-up evidence discovery | User clarified that unknown or weak areas should be researched from authoritative evidence before deriving dimensions. |
| Wrote formal design doc before dispatching agents | The approved next artifact is a research design, not execution. |
| Write an execution plan before running research | User approved the design direction; execution still needs a bounded, reviewable plan before agents or inline research start. |
| Include local/runtime Skill-writing guidance as evidence sources | Current runtime guidance can expose concrete Skill-format and validation constraints, but must be treated as evidence rather than authority. |

## Errors Encountered
| Error | Attempt | Resolution |
|-------|---------|------------|
| Quick regression failed at `skill-runtime-surface-contract` because auto `agent-browser` source still declared `hidden: true` | Reproduced with `bash tests/run-all.sh --quick` and isolated with `bash tests/test-skill-runtime-surface-contract.sh` | Removed stale `hidden: true` from `community/vercel/skills/agent-browser/SKILL.md`; contract and quick regression passed |

## Notes
- Scope is the evidence-first research process for defining Skill best-practice criteria.
- Non-goals: no current Skill assessment, no standard-chain readiness verdict, no skill edits, no contract edits, no dogfood run, no actual research execution before choosing execution mode.
- Design doc: `docs/superpowers/specs/2026-06-18--skill-best-practice-research--design.md`
- Execution plan: `docs/superpowers/plans/2026-06-19--skill-best-practice-research.md`
- Verification: `git diff --check -- docs/superpowers/specs/2026-06-18--skill-best-practice-research--design.md task_plan.md findings.md progress.md`; `bash tests/run-all.sh --quick`
