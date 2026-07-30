# SQL Schema Comments Grader

Use this rubric to score outputs from `tools/eval/scenarios/sql-schema-comments/evals.json`.

Grade judgment, not exact wording. Do not reward an answer for mentioning `COMMENT` if it misses dialect, semantic quality, or migration risk.

## Inputs

- Scenario record from `evals.json`
- Final assistant output
- Optional transcript or tool log, when available

## Scoring

For each `expected_anchor`, assign:

- `0`: missing, wrong, or contradicted
- `1`: present but generic, dialect-blind, or incomplete
- `2`: clear, specific, and useful for this scenario

Also check expected behavior and anti-patterns.

## Blocking Failure

Mark the run `BLOCKED` if any of these occur:

- New production DDL with missing table, column, status, constraint, or index semantics is approved as-is.
- MySQL inline `COMMENT` is treated as the universal rule across PostgreSQL, SQLite, ORM, or migration-tool contexts.
- Comments that only restate field names are accepted as enough.
- Large historical comment backfill is recommended without migration risk, batching, rollback, or ownership boundaries.
- A runtime rule change is recommended before classifying the likely failure mode.

Blocking failures override a high numeric score.

## Root-Cause Classification

For every `WARN` or `BLOCKED` run, assign one or more root-cause classes:

- `ROUTE_MISS`: SQL/schema comment concerns were not activated.
- `DIALECT_BLIND`: database or migration-tool differences were ignored.
- `SEMANTIC_WEAK`: comment quality was reduced to syntax or name translation.
- `SCOPE_OVERREACH`: current change and historical debt were mixed together.
- `MIGRATION_RISK_MISS`: lock, deploy, rollback, compatibility, or metadata risk was missed.
- `GATE_GAP`: advice was directionally right but no review, validation, or acceptance path was given.
- `RULE_CHANGE_PREMATURE`: rule edits were proposed before diagnosing the failure.

If a run passes, root-cause classes should be empty.

## Transcript-Aware Checks

When a transcript is available, inspect whether the assistant read or otherwise addressed the relevant scene contracts:

- `code-comments` for schema semantics and comment quality
- `code-changes` for DDL acceptance, compatibility, and smallest safe change
- `impact-analysis` for schema fan-out, old behavior, and migration blast radius
- `testing` for validation and delivery evidence

Do not require every scene file to be read for tiny prompts. Penalize only when missing specialist reasoning changes the judgment.

## Output Format

```json
{
  "eval_id": "mysql-create-table-no-comments",
  "status": "PASS|WARN|BLOCKED",
  "score": {
    "earned": 0,
    "possible": 0
  },
  "root_causes": [],
  "anchor_scores": [
    {
      "anchor_id": "SC-1",
      "score": 2,
      "evidence": "Conclusion appears first and rejects merging the DDL as-is."
    }
  ],
  "expected_behavior_results": [
    {
      "text": "Rejects merging the new production DDL as-is.",
      "passed": true,
      "evidence": "The output says the migration cannot be merged without schema semantics."
    }
  ],
  "anti_pattern_hits": [],
  "scene_contract_notes": [
    {
      "scene": "code-comments",
      "status": "addressed",
      "evidence": "The output requires table and column business semantics."
    }
  ],
  "summary": "One-paragraph judgment of the run."
}
```

## Suite-Level Decision

Use this threshold for a smoke run:

- `PASS`: no blocking failures and average anchor score >= 1.6
- `WARN`: no blocking failures but average anchor score < 1.6, or one repeated weak anchor/root cause
- `FAIL`: any blocking failure, or the same root cause appears in two or more blocking or low-score runs

Only change runtime rules when failures repeat and point to the same root cause.
