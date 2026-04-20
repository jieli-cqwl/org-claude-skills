# Trigger Cases

Positive: "帮我优化现有 review skill 的触发和验证链路" routes to `skill-auditor`.
Negative: "帮我从零创建一个 PDF skill" routes to `skill-creator`.
Boundary: "这个 Skill 的 `$ARGUMENTS` 和 `!command` 是否安全" routes to permission and script audit.
Consumer: `tests/test-skill-auditor-evals.sh` and audit report use these cases.

| Case | Expected |
| --- | --- |
| optimize existing Skill | trigger |
| audit a Skill draft | trigger |
| create new Skill | reject and route |
| inspect `$ARGUMENTS` shell path | trigger permission audit |
| inspect `!command` context injection | trigger script audit |
