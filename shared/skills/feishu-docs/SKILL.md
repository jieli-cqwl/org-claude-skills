---
name: feishu-docs
user-invocable: true
disable-model-invocation: true
description: 飞书文档读写与沉淀 Skill。Use when 用户手动要求通过官方 lark-cli 读取、创建、追加、替换、覆盖、删除或总结飞书 Docs/Wiki/Drive 文档，尤其是把 Claude Code 或 Codex 产出的开发文档写入飞书，或基于飞书文档链接、文档名、Wiki 链接获取内容并分析。
allowed-tools: Read, Bash, Grep
---

# Feishu Docs

## What This Skill Does

Use this skill only when the user explicitly invokes `$feishu-docs` or asks to operate Feishu documents through Feishu/Lark CLI. It coordinates official `lark-cli` commands for reading, creating, updating, and deleting Feishu documents, then reports Feishu-side evidence.

## Hard Gates

- Use the official `lark-cli` command surface first. Do not switch to unofficial SDKs, browser cookies, reverse engineered endpoints, or community MCP tools unless the user explicitly changes the implementation direction.
- Stop when `lark-cli` is missing, unauthenticated, lacks scope, or lacks resource permission. Report the remediation from `references/auth-and-config.md`.
- Never commit, print, or request app secrets, access tokens, session cookies, or bearer tokens.
- Before create, append, replace, insert, overwrite, section delete, document delete, file delete, or folder delete, show target, mode, content source, impact range, and command summary. Continue only after the user confirms in the current turn.
- 写入、覆盖和删除都必须先获得本轮用户确认；覆盖和删除还需要第二次确认目标标题或 token。
- For overwrite and delete, require a second explicit confirmation that names the target title or token.
- For async results, report task id and polling command. Do not claim the Feishu-side operation finished until the CLI reports a final success state.
- For Wiki links, resolve the Wiki node before document operations. Do not treat a Wiki token as a docx token.

## Workflow

- Classify the request: read, create, append, section replace, full overwrite, section delete, document delete, search, or summarize.
- Check setup with `lark-cli --version` and `lark-cli auth status`. For setup details, read `references/auth-and-config.md`.
- Route reads to `references/document-read-playbook.md`.
- Route creates, appends, replacements, overwrites, and deletes to `references/document-write-playbook.md`.
- Use `scripts/feishu_doc.py --help` when a deterministic dry-run command summary, confirmation guard, redaction check, or CLI execution wrapper is useful.
- Finish with evidence: Feishu title, link, object type, doc id or token, revision, task id, command status, and media/table limitations.

## Core Shortcuts

- Read: `lark-cli docs +fetch --doc "<doc_url_or_token>"`
- Search: `lark-cli docs +search --query "<name>"`
- Create: `lark-cli docs +create --title "<title>" --markdown "$(cat draft.md)"`
- Update: `lark-cli docs +update --doc "<doc_url_or_token>" --mode append|replace_range|insert_before|insert_after|delete_range|overwrite`

## Output Contract

For reads and summaries:

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

For writes, updates, and deletes:

```markdown
## Target
- Title:
- Link:
- Object:
- Mode:

## Confirmation

## Result Evidence
- Command:
- Status:
- Doc ID or Token:
- Revision:
- Task ID:

## Follow-up
```

## Reference Loading

- Read `references/auth-and-config.md` when installing, checking authentication, choosing user or bot identity, diagnosing scope, or diagnosing resource permission.
- Read `references/document-read-playbook.md` for docx links, wiki links, document-name search, content fetch, and summarization.
- Read `references/document-write-playbook.md` for create, append, replace range, overwrite, delete range, Drive delete, confirmation text, and evidence reporting.
