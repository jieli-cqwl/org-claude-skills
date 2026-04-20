# Feishu Docs Skill Design

## Why

用户需要在 Claude Code 与 Codex 中手动调用一个飞书文档 Skill，把日常开发过程中的 PRD、设计、计划、复盘和问题分析沉淀到飞书，并能按飞书链接或文档名读取内容进行总结分析。若没有统一 Skill，AI 会在飞书 CLI、MCP、OpenAPI、SDK 和第三方工具之间临场选择，带来权限混乱、误写入、误删除和不可验证的完成结论。

## Scope

- In scope: 创建 `feishu-docs` first-party Skill 的设计，覆盖读取、创建、追加、章节替换、全文覆盖、章节删除、文档删除、权限检查和结果证据。
- In scope: 以官方 `lark-cli` 作为执行底座，设计 Claude Code 与 Codex 共用的 manual-only Skill。
- In scope: 明确目录结构、运行流程、错误处理、安全边界、安装影响和验证方式。
- Out of scope: 本阶段不创建 `shared/skills/feishu-docs/`，不修改 `install.sh`，不安装或登录 `lark-cli`，不调用真实飞书 API。
- Out of scope: 第一版不接入第三方 `feishu-docx`、社区 Feishu MCP、官方 OpenAPI MCP 或自研完整 SDK。

## Approach

`feishu-docs` 作为安全编排层，不重新实现飞书 OpenAPI。Skill 读取用户输入后，先判断目标是读取、写入、更新还是删除，再按风险等级进入不同流程。

读操作默认允许执行，但需要先解析目标对象。`/docx/` 链接直接进入文档读取；`/wiki/` 链接先通过 Wiki node 解析真实 `obj_type` 与 `obj_token`；文档名先走 `docs +search`，同名时列候选让用户选择。读取后，Skill 输出标题、链接、内容摘要、结构要点、缺失素材说明和权限问题。

写操作必须先确认目标位置、文档标题、内容来源和写入模式。新建使用 `lark-cli docs +create`；追加和章节替换使用 `lark-cli docs +update` 的 `append`、`replace_range`、`insert_before`、`insert_after`；全文覆盖使用 `overwrite`，但必须二次确认。写入完成后，Skill 必须汇报 `doc_id`、文档链接、任务 ID、revision 或 CLI JSON 中的飞书侧证据。

删除操作分为内容删除和文件删除。章节或块删除使用 `docs +update --mode delete_range`；文档、文件或文件夹删除使用 Drive 删除能力。删除前必须展示目标、范围、影响和命令摘要，并要求用户确认。没有确认时停止。

Skill 本体放在 `shared/skills/feishu-docs/`，设置 `disable-model-invocation: true` 并加入安装器 manual-only 列表。Codex 运行面安装后保留 `SKILL.md`，移除 `agents/openai.yaml`，保证它只由用户手动调用。

## Components

| Component | Responsibility |
| --- | --- |
| `SKILL.md` | 触发边界、HARD-GATE、读写删主流程、完成校验和资源路由 |
| `agents/openai.yaml` | 源态 Codex adapter；安装到 Codex 后因 manual-only 被移除 |
| `references/auth-and-config.md` | `lark-cli` 安装、配置、认证、身份选择、scope 和权限处理 |
| `references/document-read-playbook.md` | 链接解析、名称搜索、Wiki 解析、读取与总结流程 |
| `references/document-write-playbook.md` | 新建、追加、章节替换、覆盖、删除、权限和证据流程 |
| `scripts/manifest.json` | 约束脚本参数、超时、失败状态和安全边界 |
| `scripts/feishu_doc.py` | 可选的确定性命令包装器，用于统一解析 CLI JSON、脱敏和错误归一化 |
| `evals/evals.json` | 覆盖读、写、更新、删除保护、权限不足、重名文档等触发样例 |

## Data Flow

读流程：

1. 用户手动调用 `$feishu-docs` 并提供链接、token 或文档名。
2. Skill 检查 `lark-cli` 是否可用和认证状态是否满足读取目标。
3. Skill 解析对象类型：docx 直读，wiki 先解析，名称先搜索。
4. Skill 调用 `lark-cli docs +fetch` 或对应对象读取命令。
5. Skill 汇总标题、链接、摘要、结构要点、表格/媒体缺失和权限问题。

写流程：

1. 用户手动调用 `$feishu-docs` 并指定内容来源。
2. Skill 读取本地文件或整理对话产物为 Markdown。
3. Skill 展示目标位置、标题、写入模式和内容摘要。
4. 用户确认后，Skill 调用 `lark-cli docs +create` 或 `docs +update`。
5. Skill 解析 CLI JSON 输出，汇报飞书链接、doc id、任务 ID、revision 或警告。

删除流程：

1. 用户手动请求删除章节、块、文档或文件夹。
2. Skill 读取目标元信息并展示删除范围。
3. 用户二次确认后，Skill 执行 `delete_range` 或 Drive 删除。
4. Skill 汇报飞书侧删除结果或异步任务 ID。

## Error Handling

| Error | Handling |
| --- | --- |
| `lark-cli` 未安装 | 停止，提示安装官方 `@larksuite/cli`，不改用第三方工具 |
| 未认证或 scope 缺失 | 停止，输出 `lark-cli auth status` / `auth login --scope` 指引，不静默切换身份 |
| app 或 user 无资源权限 | 停止，说明需要把应用或用户加入文档、文件夹或知识库权限 |
| Wiki token 未解析 | 停止，提示先解析 Wiki node；禁止把 wiki token 当 docx token 使用 |
| 文档名命中多个对象 | 输出候选，等待用户选择 |
| 写入返回异步任务 | 输出 task id 和轮询命令，未轮询成功前不声称写入完成 |
| 覆盖或删除未确认 | 停止执行 |
| CLI 输出包含 token/secret | 只输出脱敏摘要和必要证据 |

## Alternatives Considered

| Option | Pros | Cons | Verdict |
| --- | --- | --- | --- |
| 官方 `lark-cli` + 本地 Skill | 官方维护，Agent 原生，覆盖 Docs/Wiki/Drive，便于 Claude/Codex 共用 | 需要本机安装和授权；权限模型需要明确引导 | Chosen |
| 官方 OpenAPI MCP | 官方 MCP，可按工具暴露 API | Beta；工具面大；直接文档编辑能力边界弱于 CLI | Rejected for first version |
| 第三方 `feishu-docx` | Markdown 导出和写回能力强 | 第三方依赖，部分路径依赖浏览器，安全和维护链路弱于官方 CLI | Deferred enhancement |
| 社区 Feishu MCP | 社区能力完整，文档块 CRUD 覆盖较多 | 第三方封装厚，权限和安全审计成本高 | Backup only |
| 自研 SDK | 控制力最高 | 需要维护认证、限流、转换、错误和安装链路 | Rejected |

## Key Decisions

- D1: Skill 命名为 `feishu-docs`。Reason: 名称直指飞书文档读写，不与 `skill-creator` 的“创建 Skill”职责冲突。
- D2: 第一版执行底座只采用官方 `lark-cli`。Reason: 官方维护、覆盖目标能力、AI Agent 适配成熟，减少自研 API 风险。
- D3: Skill 设置为 manual-only。Reason: 飞书文档包含私有数据，且写入、覆盖、删除会改变外部系统状态。
- D4: 写入与删除必须确认目标和影响范围。Reason: 外部写 API 需要本轮明确授权和精确范围。
- D5: Wiki 链接必须先解析 node。Reason: Wiki token 不是实际 docx token，错误使用会导致读取失败或误操作。
- D6: 第一版不把 `feishu-docx` 作为硬依赖。Reason: 先用官方 CLI 完成主流程，格式增强在真实痛点出现后接入。

## Goals & Success Criteria

| Goal | Success Criteria | Verification |
| --- | --- | --- |
| Claude Code 与 Codex 共用 | `feishu-docs` 从 `shared/skills` 安装到 `~/.claude/skills` 和 `~/.codex/skills` | `bash tests/test-install-smoke.sh`; `bash tests/test-runtime-integrity.sh` |
| 手动触发 | `SKILL.md` 有 `disable-model-invocation: true`，Codex runtime 不保留 `agents/openai.yaml` | `bash tests/test-single-source-layout.sh`; `bash tests/test-codex-skill-adapter.sh` |
| 安全写入 | 写入流程要求目标、内容来源、模式和用户确认；覆盖全文二次确认 | `evals/evals.json` + skill contract test |
| 安全删除 | 删除章节、文档或文件夹前必须展示目标和影响范围，并等待确认 | `evals/evals.json` + skill contract test |
| 可验证完成 | 写入、更新、删除完成汇报包含飞书链接、doc id、revision、task id 或 CLI JSON 证据 | skill contract test; real integration smoke when credentials are available |
| 读文档总结 | 给定 docx/wiki 链接或文档名时，Skill 能解析对象、读取内容并输出摘要与结构分析 | manual eval with non-sensitive fixture document |
| 权限失败可解释 | 缺少 `lark-cli`、认证、scope、资源权限、重名候选时停止并输出修复路径 | negative evals |

## Change Scope

| File or Area | Change Type | Size |
| --- | --- | --- |
| `shared/skills/feishu-docs/SKILL.md` | create | medium |
| `shared/skills/feishu-docs/agents/openai.yaml` | create | small |
| `shared/skills/feishu-docs/references/` | create | medium |
| `shared/skills/feishu-docs/scripts/manifest.json` | create | small |
| `shared/skills/feishu-docs/scripts/feishu_doc.py` | create | medium |
| `shared/skills/feishu-docs/evals/evals.json` | create | small |
| `install.sh` | modify | small |
| `tests/test-single-source-layout.sh` | modify | small |
| `tests/test-install-smoke.sh` | modify | small |
| `tests/test-codex-skill-adapter.sh` | modify | small |
| `tests/test-runtime-integrity.sh` | modify | small |
| `README.md` | modify | small |

## Invariants

- `shared/skills/` remains the first-party Skill source.
- `community/*` vendored Skill sources are not modified for this feature.
- Claude and Codex installation semantics remain shared through `install.sh`.
- Secrets, app IDs, app secrets, tenant tokens and user tokens are never committed.
- `skill-creator` remains responsible for creating or improving Skill definitions; `feishu-docs` only operates Feishu documents.
- `skill-harness` remains responsible for auditing Skill quality; `feishu-docs` does not self-certify quality.
- Existing manual-only behavior for other low-frequency or high-risk skills remains unchanged.

## Downstream Impact

| Consumer | Impact | Propagation Needed |
| --- | --- | --- |
| Claude runtime | New manual Skill appears under `~/.claude/skills/feishu-docs` | yes; install smoke must prove presence |
| Codex runtime | New manual Skill appears under `~/.codex/skills/feishu-docs` without auto adapter | yes; adapter tests must prove `agents/openai.yaml` removal |
| Users | They can manually call `$feishu-docs` to read/write Feishu documents | yes; README needs a concise mention |
| Install tests | Need awareness of new manual-only Skill | yes; add smoke and runtime assertions |
| Skill quality checks | Need context budget and routing checks for new Skill | yes; include evals and contract checks |

## Risks

| Risk | Impact | Mitigation |
| --- | --- | --- |
| AI writes to the wrong document | External documentation corruption | Require target confirmation with title, link, token and mode before writes |
| AI deletes or overwrites valuable content | Data loss | Require second confirmation for overwrite and delete; prefer local section updates |
| Permission model confuses user | Failed reads/writes or empty results | Separate `--as bot` and `--as user`; output missing scope or resource permission guidance |
| Wiki token used as docx token | Failed command or wrong object operation | Force Wiki node resolution before content operations |
| Secrets leak in logs | Credential exposure | Read secrets only through `lark-cli`; redact token-like output |
| CLI output changes | Skill parsing breaks | Prefer official shortcut JSON; wrapper script normalizes errors and evidence |
| Third-party tools increase surface area | Maintenance and security risk | Keep first version on official `lark-cli`; defer optional enhancements |

