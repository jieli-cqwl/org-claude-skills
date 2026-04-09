---
name: new-skills
description: Skill 创建与改进。Use when 需要新建 SKILL.md、优化现有 Skill、进行 Skill 质量检查。
argument-hint: "[skill名称]"
user-invocable: true
---

# /new-skills -- 创建或改进 Skill

## HARD-GATE

1. NO SKILL.md without HARD-GATE section in the first 20% of the document.
2. NO SKILL.md exceeding its category line limit (Pipeline <=250, 独立 <=150, 工具 <=100; hook-only: 60 lines). Category baselines defined in `{{RUNTIME_HOME}}/reference/Skill质量标准.md`.
3. NO description without capability statement + `Use when` pattern — format: `{能力陈述}。Use when {触发场景}。` (spec: `references/description-spec.md`，含第三人称要求、禁止项和好坏示例).
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

当设计角色身份或约束排序时：
→ 读取 `references/prompt-engineering.md` 获取 7 项实证技巧（HARD-GATE 门控、角色三要素、约束前置、竞争框架、Few-shot 对比、结构化输出、文档位置优化）

1. 确认 Skill 类型：Task（user-invocable）/ Fork subagent（context: fork）/ Reference（user-invocable: false）
2. 用例收集：收集 3-5 个具体触发场景，明确"用户会说什么来触发此 Skill"
   当收集用例和规划资源时：
   → 读取 `references/resource-planning.md` 获取用例分析提问框架（触发语、重复操作、参考知识、产出模板）和三类资源判断表（scripts/references/assets）
3. 资源与协作规划：基于用例识别 scripts/references/assets 需求。涉及多 agent 协作时：
   → 读取 `{{RUNTIME_HOME}}/reference/agent-team-patterns.md` 获取四种协作模式（竞争假设、分层评审、模块化开发、规划-审批）及选择原则
   主文档必须写清模式选择触发点、用户共创节点、推荐路径、主代理职责和最大 agent 数，禁止只写“用户明确要求时”
   在流程步骤中直接描述（不引用外部协议文件）
4. 初始化骨架：新建 Skill 时运行 `scripts/init_skill.sh <skill-name> [目标目录]`，已有 Skill 跳过
5. 应用结构模板：按上述模板编写，HARD-GATE 放最前。多 agent 协作步骤用描述性指令（~10-15 行），模式选择必须写在主流程，禁止引用外部协议编排
6. 角色设计：三要素（定位 + 驱动 + 锚点），按 `references/prompt-engineering.md` 任务类型-身份匹配表选择
7. 精简检查：行数符合分类基线（Pipeline <=250, 独立 <=150, 工具 <=100）？建议性语言已移入 references/？约束 <= 7 条？
8. 质量评级：
   当评估 Skill 质量级别时：
   → 读取 `{{RUNTIME_HOME}}/reference/Skill质量标准.md` 获取 7 维度评估体系（结构合规、闭环自治、I/O 契约、角色与对抗、验证即证据、Token 效率、跨模型适配）和 L1/L2/L3 三级标准
   Pipeline skill >= L2，独立 skill >= L1。
9. TDD 验证：要求用户跑 RED-GREEN 基线测试
   当识别反模式或验证质量时：
   → 读取 `references/anti-patterns.md` 获取 14 项反模式清单（身份单薄、约束后置、缺少反例等）、反合理化条款和 TDD 三阶段流程
10. 异常处理：frontmatter 不合规或行数超限时，终止输出并报告具体问题；质量评级低于目标级别时，列出缺失项并要求修复

## 完成校验

- [ ] frontmatter 含 `name` + `description`（格式：`{能力陈述}。Use when {触发场景}。`）
- [ ] HARD-GATE 在文档前 20%，<= 5 条
- [ ] SKILL.md 行数符合分类基线（Pipeline <=250, 独立 <=150, 工具 <=100），详细内容在 references/
- [ ] 无建议性语言（应该/推荐/考虑），只有 FORBIDDEN/REQUIRED
- [ ] 审查/验证型 Skill 有门控约束替代偏差清单
- [ ] Skill 达到目标质量级别
