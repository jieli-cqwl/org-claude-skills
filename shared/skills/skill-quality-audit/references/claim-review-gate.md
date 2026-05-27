# Claim Review Gate

Use this gate before keeping any P0 or P1 finding.

## Purpose

P0/P1 findings are not opinions. They are supported claims whose required premises survive current-file evidence checks and severity calibration.

## Required Checks

1. Claim decomposition: list the premises that must all be true for the finding to hold.
2. Evidence verification: cite current `path:line` evidence for the finding and check direct refutations in runtime, install, contract, test, eval, or downstream files.
3. Severity calibration: prove the impact reaches team use, runtime behavior, output correctness, validation, or downstream handoff.

## Outcomes

- Keep the finding only when all required claims are supported and no direct refutation exists.
- Downgrade when the defect is real but does not reach the claimed severity.
- Delete when a required premise is false.
- Return `blocked` when target files are moving or required evidence cannot be inspected.

## Formal JSON Fields

For each P0/P1 finding:

- `claim_review.required_claims`: the premises required for the finding.
- `claim_review.refutation_check`: a file-line statement of the strongest checked refutation or why no refutation was found.
- `claim_review.status`: `supported`; `refuted` or `blocked` cannot enter the final P0/P1 list.
- `severity_calibration.calibrated_severity`: must match the final severity.
- `severity_calibration.team_use_impact`: concrete impact on team use, runtime, output, validation, or downstream handoff.
- `severity_calibration.rationale`: why the final severity is not inflated.
