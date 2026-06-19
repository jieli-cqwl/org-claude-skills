# Task Plan: Standard-chain Review Design Guardrail

## Goal
Define an evidence-based review system that can decide whether the current standard-chain flow and its key skills are ready for controlled dogfood, and can identify the minimum blocker set that prevents or limits that dogfood readiness.

## Current Phase
Phase 5

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
- **Status:** in_progress

## Key Questions
1. Can the review system decide whether standard-chain is ready for a controlled real-task dogfood in its intended team-delivery scenario?
2. Can it distinguish flow defects from individual skill defects, contract defects, validation defects, and evidence gaps?
3. Can it identify the minimum blocker set that must be fixed before dogfood?
4. Can it reject unsupported "best practice" claims, including claims borrowed from gstack or superpowers without local fit evidence?
5. Can it produce conclusions that survive red-team attack on evidence, assumptions, severity, and reasoning?

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

## Errors Encountered
| Error | Attempt | Resolution |
|-------|---------|------------|

## Notes
- Scope is the review design for standard-chain process and key skill evaluation.
- Non-goals: no skill edits, no contract edits, no dogfood run, no actual multi-agent review execution.
