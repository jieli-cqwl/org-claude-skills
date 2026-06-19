# Task Plan: Standard-chain Review Design Guardrail

## Goal
Build an evidence-first research process that discovers what makes an agent Skill effective from authoritative sources, strong examples, failure evidence, and adversarial review, before deriving any evaluation dimensions for this repository's Skills.

## Current Phase
Phase 7

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
- [ ] Present the full review design draft for user approval, centered on controlled dogfood readiness.
- [ ] Wait for user approval before writing formal design doc.
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
- [ ] Ask user to review the design doc before implementation planning.
- **Status:** in_progress

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

## Errors Encountered
| Error | Attempt | Resolution |
|-------|---------|------------|

## Notes
- Scope is the review design for standard-chain process and key skill evaluation.
- Non-goals: no skill edits, no contract edits, no dogfood run, no actual multi-agent review execution.
- Design doc: `docs/superpowers/specs/2026-06-18--skill-best-practice-research--design.md`
- Verification: `git diff --check -- docs/superpowers/specs/2026-06-18--skill-best-practice-research--design.md task_plan.md findings.md progress.md`; `bash tests/run-all.sh --quick`
