# 用例分析与资源规划

> 创建 Skill 前的需求分析方法。借鉴自官方 skill-creator Step 1-2。

## 用例分析提问框架

逐步收集 3-5 个具体使用场景，每个场景回答：

1. 触发语 — 用户会说什么来触发此 Skill？（直接用于 description 的 `Use when` 部分）
2. 重复操作 — 哪些代码/步骤每次都要重写？（候选 scripts/）
3. 参考知识 — 执行时需要查阅哪些文档/规范？（候选 references/）
4. 产出模板 — 输出是否依赖固定模板/资源文件？（候选 assets/）

避免一次问太多问题，从最关键的触发语开始，逐步深入。

## 三类资源判断表

| 资源类型 | 何时使用 | 判断标准 | 示例 |
|---------|---------|---------|------|
| scripts/ | 确定性操作 / 重复代码 / 门禁检查 | 同一代码每次重写 or 需要确定性可靠 or 完成门禁 | validate.sh, completion_check.sh |
| references/ | 执行时参考知识 | 运行时按需查阅但不必总在上下文中 | schema.md, api-docs.md, patterns.md |
| assets/ | 产出物依赖的文件 | 不加载进上下文，用于最终输出 | template.html, logo.png, boilerplate/ |

判断优先级：先问"这个信息/代码是每次都需要吗？" → 是 → scripts/ 或 SKILL.md 内嵌。再问"需要但不是每次？" → references/。最后"只用于输出？" → assets/。

> **scripts/ 双重职责**：scripts/ 同时承担两种角色——(1) helper 脚本（供 LLM 调用完成重复操作）和 (2) gate 脚本（completion_check.sh，作为门禁检查在 Stop hook 或显式执行时运行）。LLM 应先运行 `script --help` 了解用法，而非直接阅读源码——脚本作为黑盒使用，减少 context 污染。

## 资源规划 checklist

- [ ] 至少收集 3 个具体触发场景
- [ ] 每个场景已识别重复操作 → 候选 scripts/
- [ ] 每个场景已识别参考知识 → 候选 references/
- [ ] 确认无多余目录（不需要的不创建）
- [ ] description 包含从触发场景提取的关键词
