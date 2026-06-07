# Pre-Audit Alignment

Use this reference before starting a formal audit. Alignment is a gate, not a verdict and not a second report.

## Success Standard

The audit can enter formal scoring only after it has a validated alignment artifact that separates:

- target capability claims: what the Skill is being evaluated against.
- current capability profile: what current evidence proves the Skill can or cannot do.
- evidence: current paths, commands, schemas, scripts, tests, runtime entries, or user-supplied scope.
- assumptions or unknowns: items that cannot become supported capability evidence.
- capability gaps: the match between confirmed targets and current capability evidence.
- user confirmation: G0/G1/G2/G3 status and confirmed target capability ids.

## Source Boundary

Target Skill self-description and historical audit/self-audit/lifecycle material can seed `declared_claim` or `inferred` target claims. They cannot prove `current_capability_profile.status: supported`.

`supported` requires current evidence: `path_line`, `command`, `schema`, `script`, `test`, or `runtime`. User scope, self-claims, old transcripts, and prior lifecycle notes are not current capability proof.

## Confirmation Levels

| Level | Use When | Allowed To Continue |
| --- | --- | --- |
| G0 | Light scan, explicit user target, or repo contract fully defines the audit target. | Continue without interrupting only if no unknown affects verdict, severity, or repair priority. |
| G1 | Default assumption from user request or repo contract is sufficient. | Continue only when confirmed targets are `user_supplied` or `repo_contract`. |
| G2 | One material target, consumer, or success standard is ambiguous. | Ask one question with at most three options; no formal audit until answered. |
| G3 | New Skill, conflicting target, evidence conflict, or unclear use case. | Stop for deeper co-creation before formal audit. |

If target capability is mainly model-inferred or copied from the target Skill's own self-description, G1 is not enough for team-readiness formal audit.

## Pre-Confirmation Boundary

Before confirmation, do not output:

- readiness verdict.
- score or scorecard.
- severity or P0/P1/P2/P3 findings.
- report validator PASS claim.
- final audit wording.

Allowed before confirmation:

- evidence excerpts.
- unranked risk hypotheses.
- missing evidence.
- assumptions.
- one recommended audit scenario and one confirmation question.

## Human Projection

Keep the projection to one screen. Show only:

1. Recommended audit scenario.
2. Current evidence-backed capability profile.
3. Key unknowns or conflicts.
4. One confirmation question.
5. Up to three options.

The structured JSON is the machine baseline. The projection is only a human decision surface.

## Formal Trace

A formal finding must reference `confirmed_gap_refs`. A confirmed gap must point to a confirmed target capability and current evidence. Items outside the confirmed baseline belong in residual risk, not severity findings.
