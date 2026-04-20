# Document Read Playbook

## Target Resolution

- `/docx/` or `/doc/` link: use `lark-cli docs +fetch --doc "<target>"`.
- Doc token: use `lark-cli docs +fetch --doc <token>`.
- `/wiki/` link: resolve the Wiki node first with `lark-cli wiki spaces get_node --params '{"token":"<wiki_token>"}'`, then use the returned `obj_type` and `obj_token`.
- Document name: run `lark-cli docs +search --query "<name>"` and show candidates when more than one result matches.

## Fetch Flow

- Confirm `lark-cli` is installed and authenticated.
- Resolve the object type.
- Fetch JSON content with `docs +fetch`; use `--format pretty` when the user needs human-readable output.
- Summarize title, source link, section outline, key decisions, action items, and content gaps.

## Large Documents

Use pagination when output indicates more content:

```bash
lark-cli docs +fetch --doc <token_or_url> --offset 0 --limit 50
```

Continue with the next offset until the CLI output shows no remaining pages.

## Media, Tasks, and Rich Blocks

Report when the CLI output contains media tags or content that needs another command:

- Images, files, and whiteboards can appear as HTML-like tags with tokens.
- Task cards can appear as `<task task-id="..."></task>` and need task CLI lookup for details.
- Comments and some collaboration metadata are not reconstructed by a plain fetch.

## Read Output

Use this structure:

```markdown
## Source
- Title:
- Link:
- Object:
- Identity:

## Summary

## Structure

## Not Captured

## Permission Or Tooling Notes
```
