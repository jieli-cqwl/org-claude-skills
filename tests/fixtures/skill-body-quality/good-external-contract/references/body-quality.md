# Body Quality Contract

Trigger: Use when the static checker sees a delegated body quality resource route.
Read: `tests/fixtures/skill-body-quality/good-external-contract/references/body-quality.md`.
Expect: The resource provides the body quality rules delegated by `SKILL.md`.
Consume: `check_skill_body_quality.py` consumes this contract to avoid false progressive-loading warnings.
Evidence: `tests/test-skill-body-quality-static-audit.sh` asserts the fixture has no findings.
Sync: Update this file with the fixture `SKILL.md` and checker resource-contract parser.
