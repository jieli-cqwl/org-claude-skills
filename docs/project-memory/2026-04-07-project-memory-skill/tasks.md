# project-memory skill 验收清单

## T1: 创建 SKILL.md

- [ ] `shared/skills/project-memory/SKILL.md` 存在
- [ ] frontmatter 包含 `name: project-memory`、`description`（含 Use when 触发格式）、`argument-hint: init | audit`、`user-invocable: true`
- [ ] HARD-GATE 章节在文档前 20% 内，包含 3 条门禁
- [ ] 角色章节：1-3 句，包含定位+驱动力+锚点
- [ ] 流程章节：参数解析（init/audit/无参数）+ init 4 步 + audit 3 步，复杂步骤指向 references/
- [ ] 输出章节：init 产出 CLAUDE.md + AGENTS.md 格式示例，audit 终端输出格式示例
- [ ] 完成校验章节：3-5 项可机械验证的检查项
- [ ] 行数 <= 150 行

## T2: 创建 agents/openai.yaml

- [ ] `shared/skills/project-memory/agents/openai.yaml` 存在
- [ ] `short_description` 25-64 字符
- [ ] `default_prompt` 包含 `$project-memory`

## T3: 创建 references/section-template.md

- [ ] `shared/skills/project-memory/references/section-template.md` 存在
- [ ] 包含 3 个固定架构级提问
- [ ] 包含 3 组（基础组/架构组/质量组）的：扫描信号 + 草稿模板 + 共创提问方向
- [ ] 草稿模板覆盖 7 个章节：Commands, Architecture, Code Style, Environment, Testing, Gotchas, Workflow

## T4: 创建 references/audit-checklist.md

- [ ] `shared/skills/project-memory/references/audit-checklist.md` 存在
- [ ] 包含 3 项检查逻辑：过时检测（ERROR）、完整性检测（WARN）、一致性检测（ERROR）
- [ ] 过时检测定义了 L2 深度的比对规则（路径存在性 + 命令/框架名称一致性）
- [ ] 完整性检测列出 7 个建议章节名称
- [ ] 一致性检测定义了排除标题行后 diff 的策略

## T5: 注册到 install.sh

- [ ] `local_manual_only_skills()` 函数中包含 `"project-memory"`
- [ ] 运行 `install.sh` 后 `~/.claude/skills/project-memory/SKILL.md` 存在
- [ ] 运行 `install.sh` 后 `~/.codex/skills/project-memory/SKILL.md` 存在
- [ ] Claude 侧 SKILL.md frontmatter 包含 `disable-model-invocation: true`
- [ ] Codex 侧 `agents/openai.yaml` 被移除（manual-only 行为）

## T6: 质量验收

- [ ] SKILL.md 通过 Skill 质量标准 L2 评级（5 节完整、无 advisory language、行数达标、角色三要素、机械可验证的完成校验）
- [ ] 无 TBD/TODO/占位符
- [ ] references/ 文件与 SKILL.md 的契约式引用一致（SKILL.md 引用的文件都存在，引用描述与实际内容匹配）
