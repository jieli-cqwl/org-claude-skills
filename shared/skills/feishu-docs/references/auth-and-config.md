# Auth and Config

## Required CLI

Use the official package:

```bash
npm install -g @larksuite/cli
lark-cli --version
```

If the command is unavailable, stop and ask the user to install `@larksuite/cli`. Do not switch tools.

## Authentication Checks

Run:

```bash
lark-cli auth status
```

When auth is missing, guide the user through:

```bash
lark-cli config init
lark-cli auth login
```

Choose identity deliberately:

- `--as user`: for documents the user can already open in Feishu.
- `--as bot`: for app-managed knowledge bases, folders, and automation.

## Permission Rules

Authentication is not enough. The chosen identity also needs access to the document, folder, or Wiki space. If a command returns permission denied, ask the user to add the user or app to the Feishu resource permission list.

For user identity, missing scope is fixed with a scoped login:

```bash
lark-cli auth login --scope "<missing_scope>"
```

For bot identity, missing scope is fixed in the Feishu developer console. Do not run `auth login` for bot-only access.

## Secret Hygiene

Do not request raw app secrets, access tokens, cookies, or bearer tokens. Use `lark-cli` managed auth and redact token-like output before reporting logs.

If CLI output includes an update notice, complete the user's requested operation first, then tell the user the CLI reported an available update.
