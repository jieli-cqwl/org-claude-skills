# Permission Profiles

Trigger: Audit or optimize a Skill permission boundary, write path, script surface, or tool list.

Read: Target `SKILL.md` frontmatter, local rules, script manifest, hook adapter contract, and requested file scope.

Expect: A permission profile classifies runtime mode, allowed actions, blocked actions, escalation gate, and rollback proof.

Consume: `skill-audit.json.permission_profile`, `optimization-plan.json.file_boundaries`, hook adapter checks, and final verification evidence.

Evidence: Tool list line, user authorization text, script manifest entry, hook adapter field, and command output reference.

Sync: Update this file with permission classes only when a new consumer reads the class.

Consumer: audit runner, plan validator, hook adapter, and human reviewer.

Global rules delta: Skill-local rules narrow the global rules. They never replace, weaken, or bypass global rules.

FORBIDDEN weaken global rules: Any profile that grants a broader permission than global rules is invalid.

## Profiles

### audit/read

- Allowed: Read target files and list files.
- Blocked: Write, Edit, MultiEdit, raw Bash, commit, push, destructive shell actions, global hook registration.
- Gate: No user write authorization is needed because the mode is read-only.
- Output: `skill-audit.json` and rendered views generated from JSON.

### edit/refactor/fix

- Allowed: Change only files listed in accepted `optimization-plan.json.file_boundaries`.
- Blocked: Adjacent cleanup, global rules edits, global hook registry edits, unrelated Skill migration.
- Gate: Requires current-session authorization and exact file scope before any write action.
- Output: changed files plus `verification-result.json`.

### script/run

- Allowed: Run manifest-listed script ids through argv-only parameters.
- Blocked: Shell interpolation, hidden network actions, unbounded output, missing timeout, undeclared external commands.
- Gate: Requires a matching `manifest.json` entry and command arguments that pass allowed-argument, denied-argument, output-root, timeout, and exit-code checks.
- Output: bounded stdout/stderr, exit code meaning, and evidence ref.

### dangerous-action (commit/delete/deploy/external-write-api)

- Allowed: Commit, delete, deploy, or call external write APIs on exact named objects after explicit current-session authorization.
- Blocked: Automatic execution, bulk operations without enumerated scope, actions without rollback path or proving command.
- Gate: Requires current-session authorization + exact object/file/repo/API scope + rollback contract + proving command.
- Output: action evidence ref, rollback path, and verification command output.

### hook/adapter

- Allowed: Describe adapter fields and local lifecycle state transitions.
- Blocked: Direct registration into global hook registry from this Skill.
- Gate: Requires accepted adapter contract with owner, failure state, rollback, and output artifact.
- Output: hook contract finding or implementation plan entry.
