# 代码质量审核员提示模板

分派代码质量审核员子代理时使用此模板。

**目的：** 验证实施是否构建良好（干净、经过测试、可维护）

**仅在规格合规性审核通过后才发货。**

```
Task tool (superpowers:code-reviewer):
  Use template at requesting-code-review/code-reviewer.md

  WHAT_WAS_IMPLEMENTED: [from implementer's report]
  PLAN_OR_REQUIREMENTS: Task N from [plan-file]
  BASE_SHA: [commit before task]
  HEAD_SHA: [current commit]
  DESCRIPTION: [task summary]
```

**除了标准代码质量问题之外，审阅者还应该检查：**
- 每个文件是否都有明确的职责和定义良好的接口？
- 单元是否已分解以便可以独立理解和测试？
- 实施是否遵循计划中的文件结构？
- 此实现是否创建了已经很大的新文件，或者显着增加了现有文件？ （不要标记预先存在的文件大小 - 重点关注此更改的贡献。）

**代码审查员返回：** 优势、问题（关键/重要/次要）、评估
