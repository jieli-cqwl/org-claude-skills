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

## HARD-GATE

- Use the official `lark-cli` command surface first. Do not switch to unofficial SDKs, browser cookies, reverse engineered endpoints, or community MCP tools unless the user explicitly changes the implementation direction.
- Stop when `lark-cli` is missing, unauthenticated, lacks scope, or lacks resource permission. Trigger: setup, authentication, scope, or permission failure; Read: `references/auth-and-config.md`; Expect: install, auth, scope, and permission remediation; Consume: blocker report; Evidence: CLI status or permission error; Sync: auth flow changes require updating this gate, playbooks, and evals.
- Never commit, print, or request app secrets, access tokens, session cookies, or bearer tokens.
- Before create, append, replace, insert, overwrite, section delete, document delete, file delete, or folder delete, show target, mode, content source, impact range, and command summary. Continue only after the user confirms in the current turn.
- 写入、覆盖和删除都必须先获得本轮用户确认；覆盖和删除还需要第二次确认目标标题或 token。
- For overwrite and delete, require a second explicit confirmation that names the target title or token.
- For async results, report task id and polling command. Do not claim the Feishu-side operation finished until the CLI reports a final success state.
- For Wiki links, resolve the Wiki node before document operations. Do not treat a Wiki token as a docx token.

## Goal

Goal: operate Feishu Docs/Wiki/Drive through official `lark-cli` with explicit permission, confirmation, and evidence boundaries. Completion boundary: read operations return source and capture limits; write/update/delete operations return confirmation evidence plus Feishu-side command status, object identity, and follow-up action.

## Workflow

流程表：

| Step | Input | Action | Output | Consumer | Acceptance | Failure state | Proof |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1. Classify | User request and target | Read intent and classify operation mode | Operation mode | setup/read/write route | Mode is read/create/update/delete/search/summarize | Stop and ask one clarification | classified mode |
| 2. Setup check | Local runtime | Run `lark-cli --version` and `lark-cli auth status` | Auth and tooling state | operation route | CLI exists and has required auth | Stop with remediation | command output |
| 3. Route playbook | Operation mode | Read the matching playbook | Command plan | user confirmation or read execution | Plan has target, object type, mode, and evidence needs | Stop on unresolved target or permission | playbook route evidence |
| 4. Confirm writes | Command plan | Show target, mode, content source, impact range, and command summary | User confirmation | write execution | Confirmation appears in current turn | Stop before write/delete | confirmation text |
| 5. Execute and verify | Confirmed command or read request | Run official `lark-cli` command or wrapper | Feishu result evidence | final response | Final CLI success or explicit blocker | Stop on async/pending/failure | command status, token, revision, task id |

Reference routes:

- Trigger: setup, authentication, scope, or permission diagnosis; Read: `references/auth-and-config.md`; Expect: install, auth, scope, identity, and remediation guidance; Consume: setup checks and blocker reports; Evidence: CLI status or permission error; Sync: auth flow changes require updating this route, scripts, and evals.
- Trigger: read, search, wiki resolution, fetch, or summarize; Read: `references/document-read-playbook.md`; Expect: safe read/fetch/search/summarize steps and capture limits; Consume: read command plan and summary output; Evidence: title, link, object identity, and not-captured notes; Sync: read behavior changes require updating this route, output contract, and evals.
- Trigger: create, append, replace, insert, overwrite, delete range, Drive delete, or folder delete; Read: `references/document-write-playbook.md`; Expect: confirmation language, command shape, write/delete evidence, and async handling; Consume: write command plan and final evidence; Evidence: confirmation text, command status, token, revision, or task id; Sync: write behavior changes require updating this route, output contract, and evals.

## Core Shortcuts

- Read: `lark-cli docs +fetch --doc "<doc_url_or_token>"`
- Search: `lark-cli docs +search --query "<name>"`
- Create: `lark-cli docs +create --title "<title>" --markdown "$(cat draft.md)"`
- Update: `lark-cli docs +update --doc "<doc_url_or_token>" --mode append|replace_range|insert_before|insert_after|delete_range|overwrite`

## Output Contract

Output format: Markdown evidence block in the conversation.
Consumer: user, future audit, and any downstream handoff that needs Feishu object identity.
Validation: command status, object identity, and permission/tooling notes must be present before claiming completion.

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

## Completion Check

- [ ] Operation mode and target object type are identified.
- [ ] `lark-cli` availability, authentication, and permission state are checked or reported as blockers.
- [ ] Write/update/delete operations have current-turn confirmation; overwrite/delete have second target confirmation.
- [ ] Final response includes title, link, object type, token or doc id, command status, revision or task id when available.
- [ ] Async operations are not reported complete until CLI returns a final success state.
