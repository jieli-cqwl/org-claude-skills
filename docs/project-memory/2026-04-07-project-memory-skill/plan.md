# project-memory skill 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task.

**Goal:** 创建 project-memory skill，通过分组共创模式为项目生成 CLAUDE.md 和 AGENTS.md 入口文档
**Architecture:** standalone skill（<=150 行），2 个 reference 文件（section-template.md + audit-checklist.md），注册到 install.sh 的 local_manual_only_skills
**Tech Stack:** Markdown (SKILL.md)、YAML (openai.yaml)、Shell (install.sh 注册)

---

## [T1] 创建 SKILL.md

**文件**: `shared/skills/project-memory/SKILL.md`（新建）

1. 创建目录结构：
```bash
mkdir -p shared/skills/project-memory/agents shared/skills/project-memory/references
```

2. 编写 SKILL.md，必须包含以下 5 个章节，总行数 <=150：

**Frontmatter:**
```yaml
---
name: project-memory
description: 项目级入口文档共创初始化与健康审计。Use when 需要为项目创建 CLAUDE.md/AGENTS.md 或检查已有入口文档健康度。
argument-hint: init | audit
user-invocable: true
---
```

**HARD-GATE（3 条）:**
```markdown
## HARD-GATE
1. NO 覆盖 without 用户确认 — 已有 CLAUDE.md 或 AGENTS.md 时停止，提示用 audit
2. NO 写入 without 用户确认 — 未经确认的草稿禁止写入文件
3. NO 修改 without init 模式 — audit 模式只读，禁止修改任何文件
```

**角色:** 项目记忆架构师。通过草稿激发用户的项目隐性知识来共创高质量的入口文档。锚点：生成的每个章节都必须反映项目的真实状态，而非泛泛的模板。

**流程:** 参数解析（init/audit/无参数 AskUserQuestion）→ init 4 步（扫描→架构级提问→分组共创→写入）或 audit 3 步（扫描→检查→输出）。复杂步骤用契约式引用指向 references/：
- init Step 1 扫描信号 + Step 3 草稿模板：`→ 读取 references/section-template.md 获取扫描信号、草稿模板和共创提问`
- audit Step 2 检查逻辑：`→ 读取 references/audit-checklist.md 获取 3 项检查逻辑`

**输出:** init 产出 CLAUDE.md + AGENTS.md（仅标题不同），audit 终端格式化输出（ERROR/WARN/OK）。

**完成校验:** 3-5 项可机械验证的 checklist。

3. 验证行数：
```bash
wc -l shared/skills/project-memory/SKILL.md
# 期望: <= 150
```

4. 提交：
```bash
git add shared/skills/project-memory/SKILL.md
git commit -m "feat(project-memory): 创建 SKILL.md"
```

---

## [T2] 创建 agents/openai.yaml

**文件**: `shared/skills/project-memory/agents/openai.yaml`（新建）

1. 编写内容：
```yaml
interface:
  display_name: "Project Memory"
  short_description: "Project entry doc init and audit"
  default_prompt: "Use $project-memory to initialize project entry docs or audit existing ones."
```

2. 验证 `short_description` 长度：
```bash
echo -n "Project entry doc init and audit" | wc -c
# 期望: 25-64 之间
```

3. 提交：
```bash
git add shared/skills/project-memory/agents/openai.yaml
git commit -m "feat(project-memory): 创建 openai.yaml"
```

---

## [T3] 创建 references/section-template.md

**文件**: `shared/skills/project-memory/references/section-template.md`（新建）

1. 编写内容，必须包含：

**架构级提问（3 个固定）:**
```markdown
## 架构级提问
1. 这个项目的核心职责是什么？（一句话概括）
2. 主要协作模式？（个人项目 / 小团队 / 开源社区）
3. 有哪些不看代码就不知道的重要约定或陷阱？
```

**3 组模板，每组包含：扫描信号 + 草稿模板 + 共创提问方向**

基础组（Commands + Environment）：
- 扫描信号：package.json、pom.xml/build.gradle、go.mod、Cargo.toml、pyproject.toml/requirements.txt、Dockerfile、Makefile、.env.example
- 草稿模板：Commands 表格（`| 命令 | 用途 |`）+ Environment 列表
- 共创提问："扫描到了以下命令和环境依赖，是否正确？有遗漏吗？"

架构组（Architecture + Code Style + Workflow）：
- 扫描信号：目录结构、.eslintrc/.prettierrc/editorconfig、.github/workflows/、.gitflow/分支命名
- 草稿模板：目录树 + 模块职责 + 代码风格约定 + 开发流程
- 共创提问："目录结构和风格配置已扫描到，有什么隐含约定或流程是配置文件看不出来的？"

质量组（Testing + Gotchas）：
- 扫描信号：jest.config/vitest.config/pytest.ini/go test、CI 配置中的测试步骤
- 草稿模板：测试框架 + 运行命令 + 策略 + Gotchas 列表
- 共创提问："测试配置已扫描到。有什么测试约定？你踩过哪些坑希望下一个人不要再踩？"

2. 验证覆盖 7 个章节名称：
```bash
grep -c '## \(Commands\|Architecture\|Code Style\|Environment\|Testing\|Gotchas\|Workflow\)' shared/skills/project-memory/references/section-template.md
# 期望: 7（或在草稿模板部分以其他方式覆盖）
```

3. 提交：
```bash
git add shared/skills/project-memory/references/section-template.md
git commit -m "feat(project-memory): 创建 section-template.md"
```

---

## [T4] 创建 references/audit-checklist.md

**文件**: `shared/skills/project-memory/references/audit-checklist.md`（新建）

1. 编写内容，必须包含 3 项检查逻辑：

**检查 1: 过时检测（ERROR）**
- 提取文档中所有 `反引号包裹的路径` 和 `命令`
- 路径检查：`test -d` 或 `test -f` 验证存在性
- 命令检查：解析 package.json scripts / Makefile targets / go.mod 等，比对文档中引用的命令/框架名是否一致
- 不做版本级检查（L2 深度）

**检查 2: 完整性检测（WARN）**
- 扫描文档中的 `## ` 标题
- 对比 7 个建议章节列表：Commands, Architecture, Code Style, Environment, Testing, Gotchas, Workflow
- 缺失章节报 WARN

**检查 3: 一致性检测（ERROR/WARN）**
- 若 CLAUDE.md 和 AGENTS.md 都存在：排除第一行（标题行）后做文本 diff，有差异报 ERROR
- 若只有一个存在：报 WARN，建议同步生成另一个

2. 提交：
```bash
git add shared/skills/project-memory/references/audit-checklist.md
git commit -m "feat(project-memory): 创建 audit-checklist.md"
```

---

## [T5] 注册到 install.sh

**文件**: `install.sh`（修改）

1. 在 `local_manual_only_skills()` 函数中添加 `"project-memory"`：
```bash
# 在 "rules-manager" 之后添加
    "rules-manager" \
    "project-memory"
```

注意：最后一项不带反斜杠续行符，倒数第二项需要加上反斜杠。

2. 验证安装：
```bash
bash install.sh
test -f ~/.claude/skills/project-memory/SKILL.md && echo "Claude OK"
test -f ~/.codex/skills/project-memory/SKILL.md && echo "Codex OK"
# 验证 Claude 侧 disable-model-invocation
grep -q "disable-model-invocation: true" ~/.claude/skills/project-memory/SKILL.md && echo "Claude manual-only OK"
# 验证 Codex 侧 openai.yaml 被移除
test ! -f ~/.codex/skills/project-memory/agents/openai.yaml && echo "Codex openai.yaml removed OK"
```

3. 提交：
```bash
git add install.sh
git commit -m "feat(project-memory): 注册到 install.sh local_manual_only_skills"
```

---

## [T6] 质量验收

1. Skill 质量标准 L2 检查（读取 `shared/reference/Skill质量标准.md`）：
```bash
# D1: 结构合规
grep -c '## HARD-GATE\|## 角色\|## 流程\|## 输出\|## 完成校验' shared/skills/project-memory/SKILL.md
# 期望: 5

# D1: 无 advisory language
grep -ciE '(should|recommend|consider|建议|应该)' shared/skills/project-memory/SKILL.md
# 期望: 0

# D1: 行数
wc -l shared/skills/project-memory/SKILL.md
# 期望: <= 150

# D3: I/O 契约 — references 引用一致性
grep 'references/' shared/skills/project-memory/SKILL.md
ls shared/skills/project-memory/references/
# 引用的文件都存在

# D5: 完成校验可机械验证
grep '完成校验' -A 10 shared/skills/project-memory/SKILL.md
# 每项都可用 Grep/Bash/文件存在性检查
```

2. 无 TBD/TODO/占位符：
```bash
grep -ciE '(TBD|TODO|FIXME|占位|待定)' shared/skills/project-memory/SKILL.md shared/skills/project-memory/references/*.md
# 期望: 0
```

3. 端到端验证（手动）：
- 在一个无 CLAUDE.md 的测试项目中运行 `/project-memory init`，验证共创流程完整走通
- 在该项目中运行 `/project-memory audit`，验证检查输出正确

4. 提交（如有修复）：
```bash
git add -A shared/skills/project-memory/
git commit -m "fix(project-memory): 质量验收修复"
```
