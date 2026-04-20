# Document Write Playbook

## Write Modes

Create a document from Markdown content:

```bash
lark-cli docs +create --title "<title>" --markdown "$(cat draft.md)"
```

Create in a folder or Wiki target:

```bash
lark-cli docs +create --title "<title>" --folder-token <folder_token> --markdown "$(cat draft.md)"
lark-cli docs +create --title "<title>" --wiki-node <wiki_node_token_or_url> --markdown "$(cat draft.md)"
lark-cli docs +create --title "<title>" --wiki-space <space_id_or_my_library> --markdown "$(cat draft.md)"
```

Update an existing document:

```bash
lark-cli docs +update --doc "<doc_id_or_url>" --mode append --markdown "$(cat draft.md)"
lark-cli docs +update --doc "<doc_id_or_url>" --mode replace_range --selection-by-title "## Section" --markdown "$(cat draft.md)"
lark-cli docs +update --doc "<doc_id_or_url>" --mode insert_before --selection-with-ellipsis "anchor text" --markdown "$(cat draft.md)"
lark-cli docs +update --doc "<doc_id_or_url>" --mode insert_after --selection-with-ellipsis "anchor text" --markdown "$(cat draft.md)"
lark-cli docs +update --doc "<doc_id_or_url>" --mode delete_range --selection-by-title "## Deprecated"
lark-cli docs +update --doc "<doc_id_or_url>" --mode overwrite --markdown "$(cat draft.md)"
```

Prefer local updates: `append`, `replace_range`, `insert_before`, `insert_after`, or `delete_range`. Use `overwrite` only when the user confirms that replacing the entire document is intended.

## Confirmation Text

Before writes, show:

- target title and link
- object type and token
- identity: `--as user` or `--as bot`
- mode
- source file or generated Markdown summary
- affected section or full document impact
- command summary without secrets

Before overwrite or delete, require a second confirmation that includes the target title or token.

## Evidence

Report fields from CLI JSON when present:

- `doc_id`
- `doc_url`
- `success`
- `mode`
- `revision`
- `task_id`
- `log_id`
- `permission_grant`
- warnings

If the operation returns a task id, provide the polling command and state that the Feishu-side operation is still pending until final status is returned.

## Markdown Safety

- Do not duplicate the document title as a first-level heading when `--title` is already provided.
- Do not escape Feishu XML-like tags such as `<whiteboard type="blank"></whiteboard>` when intentionally creating rich blocks.
- Avoid `overwrite` when the document contains images, comments, task cards, whiteboards, or attachments that cannot be reconstructed from Markdown.

## Delete Flow

- For section deletion, prefer `docs +update --mode delete_range` with `--selection-by-title` or `--selection-with-ellipsis`.
- For whole-file or folder deletion, inspect `lark-cli drive --help`, preview the exact command, and require second confirmation.
- Report whether the file was moved to recycle bin or deleted by a Drive task id, based on CLI output.
