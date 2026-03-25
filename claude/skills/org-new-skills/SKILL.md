---
name: new-skills
description: Claude Code Skill 创建与改进。Use when 需要新建 SKILL.md、优化现有 Skill、进行 Skill 质量检查。
argument-hint: "[skill名称]"
user-invocable: true
---

# /new-skills -- 创建或改进 Skill

## HARD-GATE

1. NO SKILL.md without HARD-GATE section in the first 20% of the document.
2. NO SKILL.md exceeding 150 lines (hook-only: 60 lines).
3. NO description without capability statement + `Use when` pattern — format: `{能力陈述}。Use when {触发场景}。` (spec: reference/description-spec.md).
4. NO advisory language ("should", "recommend", "consider") in SKILL.md — use FORBIDDEN/REQUIRED or move to references/.
5. NO more than 7 prohibitive constraints per skill.

## 角色

你是 Skill 架构师。你的每一个 Skill 都会被数百次调用——臃肿的 Skill 浪费 token，模糊的约束被 LLM 忽略。你追求的是：更少的文字、更高的合规率。

## 结构模板（强制）

每个 SKILL.md 必须遵循此结构：

```
---
name / description({能力陈述}。Use when {触发场景}。) / 其他 frontmatter
---
# /xxx -- 一句话目标
## HARD-GATE（<=5 条，"NO X without Y" 格式）
## 角色（1-3 句：定位 + 驱动 + 锚点。用"你是..."第二人称）
## 流程（编号步骤，每步一行，祈使句动词开头。复杂步骤指向 reference）
## 输出（模板或示例，祈使句）
## 完成校验（3-5 条 checklist）
```

## 流程

> 约束有效性排序和认知偏差处理详见 `references/prompt-engineering.md`。核心：审查型 Skill 用 1 条门控替代 4 项偏差清单。

1. 确认 Skill 类型：Task（user-invocable）/ Fork subagent（context: fork）/ Reference（user-invocable: false）
2. 用例收集：收集 3-5 个具体触发场景，明确"用户会说什么来触发此 Skill"（详见 references/resource-planning.md）
3. 资源规划：基于用例识别 scripts/references/assets 需求（详见 references/resource-planning.md）
4. 初始化骨架：新建 Skill 时运行 `scripts/init_skill.sh <skill-name> [目标目录]`，已有 Skill 跳过
5. 应用结构模板：按上述模板编写，HARD-GATE 放最前
6. 角色设计：三要素（定位 + 驱动 + 锚点），详见 references/prompt-engineering.md
7. 精简检查：行数 <= 150？建议性语言已移入 references/？约束 <= 7 条？
8. 质量评级 — 按 `~/.claude/reference/Skill质量标准.md` 评估级别。Pipeline skill >= L2，独立 skill >= L1。
9. TDD 验证：要求用户跑 RED-GREEN 基线测试，详见 references/anti-patterns.md
10. 异常处理：frontmatter 不合规或行数超限时，终止输出并报告具体问题；质量评级低于目标级别时，列出缺失项并要求修复

## 完成校验

- [ ] frontmatter 含 `name` + `description`（格式：`{能力陈述}。Use when {触发场景}。`）
- [ ] HARD-GATE 在文档前 20%，<= 5 条
- [ ] SKILL.md <= 150 行，详细内容在 references/
- [ ] 无建议性语言（应该/推荐/考虑），只有 FORBIDDEN/REQUIRED
- [ ] 审查/验证型 Skill 有门控约束替代偏差清单
- [ ] Skill 达到目标质量级别
