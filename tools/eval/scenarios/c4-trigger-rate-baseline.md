# C4: Skill Description 触发率基线

> 采集时间: 2026-04-06
> 用途: 记录核心工作流 skill 的当前 description，定义触发/非触发 eval 查询，作为后续优化的基线

## 核心工作流 Skills 当前 Description

| Skill | Description |
|-------|-------------|
| product | 产品需求分析与 PRD 文档化。Use when 用户提出新需求、讨论产品方向、需要将想法转化为可执行的需求文档。 |
| design | 系统架构设计与技术方案输出。Use when PRD 完成后需要架构设计、模块划分、接口定义和技术选型。 |
| test-design | 需求驱动的测试用例设计。Use when 需求确认后、开发前需要设计测试用例和测试方案。 |
| tech-lead | 技术负责人评审设计并制定实施计划。Use when 架构设计完成后需要由技术负责人评审设计并制定实施计划。 |
| developer | TDD 驱动开发实现。Use when 开发计划中的 Task 需要代码实现。 |
| delivery-owner | 项目经理组织计划执行与全链路交付验收。Use when 实施计划确认后需要组织开发执行、代码审查、功能验收并完成交付。 |
| review | 深度代码审查与改进建议。Use when 需要审查代码变更、PR review、代码质量评估或想要第二双眼睛检查实现。 |
| qa | 端到端功能验收测试。Use when code-review 通过后需要从用户视角验证功能是否满足 PRD 验收标准。 |
| fix | 根因诊断与最小修复。Use when code-review/qa 报告 FAIL 或线上错误需要定位并处置。 |
| verify | Task 级 AC 覆盖与代码规范验收。Use when 开发完成后需要验收单个 Task 的 AC 实现和代码规范符合性。 |

## Eval 查询定义

按 skill-creator trigger-eval.json 格式。每个 skill 定义 3 个正向（should_trigger=true）+ 2 个负向（should_trigger=false）查询。

### product

```json
[
  {"query": "我有一个新的功能想法，帮我梳理需求写 PRD", "should_trigger": true},
  {"query": "用户反馈说登录太慢了，帮我分析下需求", "should_trigger": true},
  {"query": "帮我把这个想法整理成需求文档", "should_trigger": true},
  {"query": "帮我设计一下这个功能的技术方案", "should_trigger": false},
  {"query": "帮我写个登录功能的代码", "should_trigger": false}
]
```

### design

```json
[
  {"query": "PRD 写完了，帮我做架构设计", "should_trigger": true},
  {"query": "帮我设计一下这个系统的技术方案和接口", "should_trigger": true},
  {"query": "需要做模块划分和数据库 schema 设计", "should_trigger": true},
  {"query": "帮我写个登录功能的代码", "should_trigger": false},
  {"query": "帮我审查一下这段代码", "should_trigger": false}
]
```

### developer

```json
[
  {"query": "帮我按 Task-1 的 AC 实现登录功能", "should_trigger": true},
  {"query": "开始写代码吧，按 TDD 来", "should_trigger": true},
  {"query": "实现 GET /api/reports 接口", "should_trigger": true},
  {"query": "帮我做架构设计", "should_trigger": false},
  {"query": "帮我审查一下这段代码", "should_trigger": false}
]
```

### review

```json
[
  {"query": "帮我 review 一下刚写的代码", "should_trigger": true},
  {"query": "代码写完了，帮我做代码审查", "should_trigger": true},
  {"query": "看看这个 PR 有什么问题", "should_trigger": true},
  {"query": "帮我写个登录功能", "should_trigger": false},
  {"query": "帮我做 QA 验收", "should_trigger": false}
]
```

### qa

```json
[
  {"query": "code review 通过了，帮我做功能验收", "should_trigger": true},
  {"query": "从用户角度测试一下这个功能", "should_trigger": true},
  {"query": "帮我做 QA 验收测试", "should_trigger": true},
  {"query": "帮我 review 一下代码", "should_trigger": false},
  {"query": "帮我修一个 bug", "should_trigger": false}
]
```

## 测量方法

实际触发率测量需要使用 skill-creator 的 `run_eval.py` 基础设施：
1. 将上述查询转换为 `trigger-eval.json` 格式
2. 配置被测 skill 的 description
3. 运行 `run_eval.py` 每个查询 3 次取触发率
4. threshold=0.5 判定 PASS/FAIL

当前阶段仅记录 description 和查询定义作为基线，实际测量在评测基础设施成熟后执行。

## 已知风险

| 风险 | 说明 |
|------|------|
| 中文查询触发精度未知 | skill-creator 的 eval 主要面向英文查询，中文 description + 中文查询的匹配效果未验证 |
| 流程链 skill 容易混淆 | design/tech-lead/developer 在"帮我实现这个功能"类泛查询下可能互相触发 |
| disable-model-invocation 影响 | 部分 skill 设置了此标记，只能手动 /invoke 不能自动触发 |
