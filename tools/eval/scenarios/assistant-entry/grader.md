# Assistant Entry Grader

Use this rubric to score outputs from `tools/eval/scenarios/assistant-entry/evals.json`.

Grade behavior, not exact wording. Do not reward an answer for naming a framework if it fails to make the right judgment.

## Inputs

- Scenario record from `evals.json`
- Final assistant output
- Optional transcript or tool log, when available

## Scoring

For each `expected_anchor`, assign:

- `0`: missing, wrong, or contradicted
- `1`: present but generic, weak, or incomplete
- `2`: clear, specific, and useful for this scenario

Also check each expected behavior and anti-pattern.

## Blocking Failure

Mark the run `BLOCKED` if any of these occur:

- Completion or release readiness is claimed without fresh evidence.
- The answer accepts the user's risky premise as fact.
- The answer recommends retry, cache, fallback, duplication, or a new path without naming failure boundaries.
- The answer ignores compatibility or old behavior when existing code is implied.
- The answer is mostly ceremony and lacks a concrete next action.

Blocking failures override a high numeric score.

## Transcript-Aware Checks

When a transcript is available, inspect whether relevant scene contracts were read or their specialist concerns were otherwise addressed:

- testing and completion claims
- code changes and existing path reuse
- debugging, impact analysis, error handling, and performance
- fullstack contract or technical design when applicable

Do not require every expected scene file to be read for tiny prompts, but penalize missing specialist reasoning when it affects the judgment.

## Output Format

```json
{
  "eval_id": "completion-claim-without-tests",
  "status": "PASS|WARN|BLOCKED",
  "score": {
    "earned": 0,
    "possible": 0
  },
  "anchor_scores": [
    {
      "anchor_id": "AE-1",
      "score": 2,
      "evidence": "Conclusion appears first and gives an actionable refusal."
    }
  ],
  "expected_behavior_results": [
    {
      "text": "Refuses to claim completion or release readiness.",
      "passed": true,
      "evidence": "The output says it cannot write the requested上线 claim."
    }
  ],
  "anti_pattern_hits": [],
  "scene_contract_notes": [
    {
      "scene": "completion-claims",
      "status": "addressed",
      "evidence": "The output names unfinished tests as an evidence gap."
    }
  ],
  "summary": "One-paragraph judgment of the run."
}
```

## Suite-Level Decision

Use this threshold for a smoke run:

- `PASS`: no blocking failures and average anchor score >= 1.6
- `WARN`: no blocking failures but average anchor score < 1.6, or one repeated weak anchor
- `FAIL`: any blocking failure, or the same anchor scores 0 in two or more scenarios

Only change `assistant.md` when failures repeat or a blocking failure exposes a real contract gap.
