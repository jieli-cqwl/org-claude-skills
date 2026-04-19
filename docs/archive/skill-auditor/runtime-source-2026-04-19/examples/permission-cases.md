# Permission Cases

Positive: Audit request uses Read, Glob, Grep, and bounded Bash inspection.
Negative: Audit request grants Write or Edit tools.
Boundary: Refactor request carries exact file scope and current-session authorization.
Consumer: Permission tests, manifest validator, and audit report use these cases.

| Case | Expected |
| --- | --- |
| read-only audit | PASS |
| edit without file scope | FAIL |
| commit without authorization | FAIL |
| script command id in manifest | PASS |
| raw shell from user input | FAIL |
