# Persona Skill Community 维护说明

## 目标

把 persona / distillation 类第三方 skill 统一维护在 `community/persona/skills/`，并通过现有安装链路分发到 Claude / Codex 运行时。

这些 skill 默认只允许手动调用，避免模型在普通任务中自动触发涉及个人资料、聊天记录、关系记忆或财富信号分析的能力。

## 纳入范围

| Skill 根目录 | 上游仓库 | 运行入口 |
|---|---|---|
| `colleague-skill` | `https://github.com/titanwings/colleague-skill` | `/dot-skill` |
| `nuwa-skill` | `https://github.com/alchaincyf/nuwa-skill` | `huashu-nuwa` |
| `yourself-skill` | `https://github.com/notdog1998/yourself-skill` | `/create-yourself` |
| `midas-skill` | `https://github.com/hermesnest/midas-skill` | `midas-skill` |

## 维护规则

- `community/SOURCES.yaml` 是来源锁；每个 persona 上游必须记录 `repo`、`ref`、`captured_at`、`scope` 和说明。
- `tools/community/sync_persona_skills_from_upstream.py` 负责按锁定 ref 重新同步。
- `tools/community/sync_persona_skills_from_upstream.py` 会删除未纳入范围的 persona 根目录，避免过时 skill 留在运行时源树。
- `install.sh` 负责复制 `community/persona/skills` 到运行时 staging。
- `install.sh` 对 persona 根目录下所有 `SKILL.md` 注入 `disable-model-invocation: true`，包含嵌套 examples。
- `colleague-skill` 上游 `SKILL.md` 缺少 opening frontmatter marker，同步脚本只补齐开头 `---`，不改业务正文。

## 验证方式

- `python3 tools/community/sync_persona_skills_from_upstream.py`
- `python3 tools/community/source_lock_check.py`
- `bash tests/test-single-source-layout.sh`
- `bash tests/test-community-tools.sh`
- 使用临时 HOME 执行 `install.sh --target codex --force --check quick` 后检查 persona skill frontmatter。
