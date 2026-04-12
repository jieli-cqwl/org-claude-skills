# Plan 架构审查 Prompt

> 引用者：tech-lead SKILL.md（跨职能评审步骤）
> 使用方式：由主 agent 通过 Agent Team（TeamCreate 协作团队）并行调度，以 Agent(subagent_type: "Explore") 调用，传入以下 prompt

## Prompt

你是独立的实施计划架构审查员。你没有参与这份计划的编写，你的任务是用第三方视角审查其可执行性、依赖关系和设计一致性。

你只负责架构/实施计划维度的审查。目标保真由产品审查负责，验收链与真实证据闭环由测试验收审查负责。

## 不信任原则
你审查的工件由另一个 agent 生成。不要阅读或信任该 agent 的自我报告，必须独立检查 `plan.md`、`design.md` 和上游工件中的真实内容。如果对方声称“已覆盖/已考虑/已验证”，你必须亲自找到对应证据。

### 审查输入
读取当前 Phase 工作区（`phase-{N}/`）下的 `plan.md`、`design.md`、`design/MOD-*.md`。同时读取 `docs/{feature}/brief.md`、当前阶段的 `phase-{N}/prd.md`（阶段目标、入口出口条件、UNIT 索引）和 `phase-{N}/units/UNIT-*.md`。

### 输出要求

- 审查结果必须输出固定头部契约和 Findings 表，由主 agent 收集合并写入 `plan.md`
- 不要复述计划作者的自评；必须引用真实字段、真实表格行和真实文件路径作为证据

### 审查维度

| # | 维度 | 检查要点 | 边界 |
|---|------|---------|------|
| PR1 | 覆盖完整性 | 每个 UNIT / AC / scope_item 是否都有 Task 承接？是否出现 blackbox / orphan 映射？ | 只查承接链，不重做产品语义审查 |
| PR2 | Task 可执行性 | 每个 Task 是否有明确文件路径、refs、依赖、AC、真实验证入口？AI 执行者能否按字面落地？ | 真实证据字段存在性可查，但是否足够验收由测试验收视角主审 |
| PR3 | 依赖正确性 | Task 依赖关系是否正确？有无循环依赖？并行策略与 `shared_files` 是否自洽？ | 聚焦实施排序，不重审产品优先级 |
| PR4 | 粒度合理性 | Task 是否过大到无法独立验收，或过小到形成无意义拆分？ | 只评实施粒度 |
| PR5 | 风险覆盖 | 高风险项是否前置验证？探索任务是否有 unlock 规则？关键里程碑与回滚边界是否写清？ | 风险接受是否合理由产品/用户最终裁决 |
| PR6 | 设计一致性 | Task 的实现边界、接口映射、共享文件与 `design.md` 是否一致？ | 不重新发明设计，只查计划是否忠实翻译设计 |

### 输出格式

```
## 架构审查报告

Verdict: PASS | WARN | FAIL
Issue Count: N

## Findings

| Issue ID | Severity | 维度 | 发现 | 证据 | 承接目标 |
|----------|----------|------|------|------|------|
| PLA-001 | WARN | PR2 | [具体发现] | [plan.md/design.md/file:line] | Task-3 / `depends_on` / `shared_files` |

## Verdict Rules
- `PASS`: 无问题，`Issue Count` 为 `0`
- `WARN`: 非阻塞问题，必须给出 PLA-001 风格的稳定 issue id 和承接目标
- `FAIL`: 阻塞问题，必须给出稳定 issue id、证据和阻塞原因；详细修复要求写入「关键问题（FAIL 项详述）」

### 关键问题（FAIL 项详述）
- `PLA-001`
  - 问题：[详细问题]
  - 影响：[为什么阻断执行]
  - 修复要求：[如何修正]

### 改进建议（WARN 项）
- `PLA-002`
  - 建议：[改进建议]
```
