# Reference Contract Cases

Positive: A route says "When checking resource loading, read `references/source-map.md` for Quick Reference coverage."
Negative: A route says "See docs" with no path, consumer, or evidence.
Boundary: QUICKREF and INDEX route large reference sets; templates do not carry decisions.
Consumer: Contract tests and `audit_skill.py` use these cases.

| Case | Expected |
| --- | --- |
| Quick Reference with exact path | PASS |
| QUICKREF without consumer | FAIL |
| INDEX points to stale file | FAIL |
| reference lacks Sync | WARN or FAIL by impact |
