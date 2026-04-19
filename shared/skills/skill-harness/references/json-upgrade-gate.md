# JSON Upgrade Gate

Trigger: Use this before creating JSON artifacts, declaring JSON as a fact source, or rejecting Markdown as insufficient.
Read: The requested output, named downstream consumer, validation command, prior round state need, and report generation path.
Expect: Markdown remains the default human audit output unless a machine consumer or cross-round state requires JSON.
Consume: Validators, hooks, runners, release gates, Darwin gates, or derived reports may consume JSON after this gate passes.
Evidence: Record the consumer, read purpose, validation, and drop condition in the audit finding or implementation plan.
Sync: Update this file when machine consumers, validation commands, or artifact retention rules change.

## Required Fields

- consumer: Name the exact tool, hook, runner, release gate, Darwin gate, or report that reads JSON.
- read purpose: State what decision or state transfer depends on the JSON fields.
- validation: Provide the fresh command or schema check that proves the JSON can be consumed.
- drop condition: State when the JSON artifact can be removed or returned to Markdown-only output.

## Fact Source Rule

If this gate passes, JSON becomes the machine fact source and Markdown/HTML become derived views. If the gate does not pass, structured Markdown findings remain the fact source and no JSON artifact is required.

## Rejection Cases

- JSON is requested only for polish, reporting convenience, or habit.
- No machine consumer reads the fields.
- The consumer is named but no validation command exists.
- Markdown or HTML would continue as the machine fact source after JSON upgrade.
