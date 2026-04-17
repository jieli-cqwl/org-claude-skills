# Permission And Script Contract

Trigger: Use this when auditing tools, script execution, `$ARGUMENTS`, `!command`, or dangerous actions.
Read: Skill frontmatter, command parameters, scripts, `scripts/manifest.json`, hook adapter contract, and install tests.
Expect: Read-only audit by default; write and dangerous actions require exact scope and current authorization.
Consume: Contract tests, manifest validator, eval runner, and hook adapter contract consume this file.
Evidence: Tool list, denied action fixture, manifest validation output, and fresh command result.
Sync: Update manifest, permission rules, and tests in the same change.

## Permission Profiles

| Profile | Allowed | Blocked |
| --- | --- | --- |
| read/review/audit/explain | Read, Glob, Grep | Write, Edit, raw Bash, commit, delete, deploy |
| edit/refactor/fix | Exact write scope after user request | Unscoped file changes |
| script run | Manifest-approved command id | Raw shell from input |
| commit/delete/deploy/external-write-api | Current-session authorization + exact object/file/repo/API scope + rollback/proving command | Automatic execution |

## Manifest Fields

Each script entry records path, allowed args, denied args, external commands, timeout, output limit, exit code meanings, shell parameter strategy, failure message, and verification command.
