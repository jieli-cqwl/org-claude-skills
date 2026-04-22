# fix-2: runtime gate mktemp stability

## Context

- Review source: verifier review after `174ecd8`
- Failing command: `bash tests/test-install-systematic.sh`
- Failing output: `[FAIL] codex installed product-manager gate should accept valid canonical fixture`
- Root output: `mktemp: mkstemp failed on .../canonical-product.XXXXXX.json: File exists`

## Root Cause

Runtime gate scripts used `mktemp` templates with a suffix after `XXXXXX`, for example:

```bash
mktemp "${TMPDIR:-/tmp}/canonical-product.XXXXXX.json"
```

On BSD/macOS `mktemp`, the replacement token must be at the end of the template. With the suffix present, repeated runs can reuse the literal path and fail after a stale file remains.

## Fix

Removed suffixes after `XXXXXX` in runtime gate temporary JSON files:

- `shared/skills/product-manager/scripts/completion_check.sh`
- `shared/skills/product-director/scripts/completion_check.sh`
- `shared/skills/developer/scripts/completion_check.sh`
- `shared/skills/qa/scripts/completion_check.sh`
- `shared/skills/design/scripts/completion_check.sh`

The scripts still write JSON content; the filename extension is not part of any schema or validator contract.

## Verification

- `rg -n 'mktemp .*XXXXXX\.[A-Za-z0-9]' shared/skills` -> no matches
- `bash -n shared/skills/product-manager/scripts/completion_check.sh shared/skills/product-director/scripts/completion_check.sh shared/skills/developer/scripts/completion_check.sh shared/skills/qa/scripts/completion_check.sh shared/skills/design/scripts/completion_check.sh` -> PASS
- `bash tests/test-install-systematic.sh` -> `Systematic tests passed: 20, skipped: 0`
- `bash tests/run-all.sh` -> `All tests passed`

## Result

The verifier-reported failure is fixed and the full small-chain verification is green again.
