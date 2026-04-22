# Anthropic Skill-Creator Adapter

File responsibility: document the local wrapper that runs Anthropic
`skill-creator` workflows without modifying the upstream mirror.

This adapter keeps `community/anthropic/skills/skill-creator` read-only and
adds local orchestration for the `shared/skills/developer` pilot.

## Commands

```bash
bash tools/eval/anthropic_skill_creator/run_developer_improvement.sh --dry-run
bash tools/eval/anthropic_skill_creator/run_developer_improvement.sh --eval-only
bash tools/eval/anthropic_skill_creator/run_developer_improvement.sh --trigger-only --model claude-sonnet-4-5
bash tools/eval/anthropic_skill_creator/run_developer_improvement.sh --model claude-sonnet-4-5
```

Use `--output-dir <path>` to write results outside the default
`tools/eval/results/anthropic-skill-creator/developer` directory.

## Outputs

The eval loop writes Anthropic-compatible artifacts:

- `iteration-N/eval-*/old_skill/run-1/outputs/response.md`
- `iteration-N/eval-*/new_skill/run-1/grading.json`
- `iteration-N/benchmark.json`
- `iteration-N/benchmark.md`
- `iteration-N/review.html`

The trigger loop writes:

- `trigger/eval-set.json`
- `trigger/results/<timestamp>/results.json`
- `trigger/results/<timestamp>/report.html`

Optimized descriptions are reported as candidates only. This adapter never
writes the result back to `shared/skills/developer/SKILL.md`.
