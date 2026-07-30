# SQL Schema Comments Eval

Purpose: replay realistic SQL and schema design prompts against the installed runtime entry and diagnose whether database schema semantics are preserved in the right place, with the right dialect and without fake compliance.

This suite is a behavior diagnostic. It is not a quick/full gate and must not assert exact natural-language wording from runtime instruction files.

## What It Proves

- SQL/schema prompts route to comment and schema-semantics judgment.
- The assistant distinguishes "schema semantics must be traceable" from "MySQL `COMMENT` is always required."
- Table, column, enum/status, constraint, index, amount, and time semantics are considered when relevant.
- The assistant rejects low-value comments that only translate names.
- Migration risk and historical debt are separated from new DDL acceptance.
- Repeated failures can be mapped to a root-cause class before editing rules.

It does not prove that every downstream project has an enforceable SQL linter. Use it before changing `shared/reference/code-comments.md`, database-specific rule templates, or runtime entry routing.

## Files

- `evals.json`: scenario prompts, expected behavior, anti-patterns, anchors, and root-cause classes.
- `grader.md`: rubric for scoring final output and classifying failures.

## Recommended Flow

1. Run 3-5 scenarios for a smoke check, or all scenarios before changing SQL/schema rules.
2. Run each prompt in a fresh non-interactive session with the installed runtime entry.
3. Save final output under `tools/eval/results/sql-schema-comments-<date>/`.
4. Grade each run with `grader.md`.
5. Change rules only for repeated root-cause classes, not one-off taste differences.

## Example Command

```bash
RESULT_DIR="$PWD/tools/eval/results/sql-schema-comments-smoke"
mkdir -p /tmp/org-sql-schema-comments-eval "$RESULT_DIR"
codex exec \
  --ephemeral \
  --skip-git-repo-check \
  -C /tmp/org-sql-schema-comments-eval \
  --sandbox read-only \
  --output-last-message "$RESULT_DIR/mysql-create-table-no-comments.out" \
  "只做判断，不要改文件。MySQL migration 新增订单表，DDL 只有字段名和类型，没有表注释、字段 COMMENT。这个能不能合并？回答控制在 260 字以内。"
```

## Promotion Rule

Treat a failure as actionable only when one of these is true:

- The same root-cause class appears in two or more scenarios.
- A blocking failure appears: unsafe DDL approval, dialect-blind advice, fake semantic comment acceptance, or migration-risk blindness.
- The assistant repeatedly recommends a rule change before diagnosing whether behavior, route, dialect, or gate is the actual problem.

If a scenario fails because it is unclear, unrealistic, or too tool-specific, fix the scenario first.
