# S1: /design 自主执行场景

用途：Track 1（HARD-GATE Why A/B 对比）+ Track 2（架构思维框架自主触发）

## 场景概述

让 LLM agent 自主执行 /design 流程，以 weekly-report PRD 为输入，使用预定义的用户回应脚本保证每次输入一致。

## 输入文件

- PRD: `docs/weekly-report/prd.md`
- UNIT 文件: `docs/weekly-report/units/UNIT-*.md`（如存在）
- Constitution: 不存在（首次创建场景）
- 现有代码: 空项目（无已有实现）

## 执行变体

| 变体 | Skill 文件 | 说明 | 运行次数 |
|------|-----------|------|---------|
| A | `skill-variants/design-with-why.md` | 当前 skill（HARD-GATE 含 Why） | 3 |
| B | `skill-variants/design-no-why.md` | 修改 skill（HARD-GATE 不含 Why） | 3 |

## Executor Prompt 模板

```
你是一个自主执行 /design 流程的 agent。

## 任务
基于 docs/weekly-report/prd.md 执行完整的 /design 流程，产出 design.md 和相关文件。

## Skill 规则
{插入对应变体的 skill 内容}

## 共创模拟
本次执行中，用户回应由以下脚本预定义。当你到达需要用户输入的步骤时，使用对应的预定义回答，然后继续下一步。

{插入模拟用户回应脚本}

## 输出要求
- 所有输出文件写入 tools/eval/results/{scenario_id}/ 目录
- design.md 按 skill 要求的模板格式输出
- 完成后写一个 executor-notes.md 记录你在执行中的不确定项
```

## 模拟用户回应脚本

以下回答按 /design 流程步骤编排。executor 到达对应步骤时使用该回答。

### S1 读取输入（无需用户输入）

无。executor 自行读取 PRD。

### S2 扫描现状（无需用户输入）

无。executor 自行扫描（空项目，预期输出："新项目，无现有代码和依赖"）。

### S3 共创：问题拆解

当 executor 呈现 PRD 关键发现并提问时：

> 回答：PRD 已锁定技术栈 Python+FastAPI+React+TypeScript+Tailwind+SQLite，10-50 人内网应用，单体部署前后端分离。不用 ORM，原生 SQL 参数化查询。重点关注 5 个待设计决策（DD-001 到 DD-005）。没有其他隐含约束。

### S4 共创：决策点识别

当 executor 列出待决策清单并确认时：

> 回答：确认，按 PRD 的 5 个待设计决策展开：DD-001 JWT 存储、DD-002 API 契约、DD-003 数据库 schema、DD-004 路由守卫、DD-005 密码哈希。请逐个探索。

### S5 共创：逐项方案探索

对每个决策点，executor 给出方案后：

**DD-001 JWT 存储：**
> 回答：选 httpOnly cookie 方案。内网应用 CSRF 风险低于 XSS，cookie 更安全。

**DD-002 API 契约：**
> 回答：选你推荐的 RESTful 方案，标准 JSON 响应格式就行。

**DD-003 数据库 schema：**
> 回答：按 PRD 的业务对象定义来，users 表和 reports 表。display_name NOT NULL。created_at 用 SQLite 的 datetime 默认值。

**DD-004 路由守卫：**
> 回答：选 React Router loader + redirect 方案，简单直接。

**DD-005 密码哈希：**
> 回答：选 bcrypt，成熟稳定，Python 生态支持好。

### S6 共创：边界与接口共识

当 executor 分段呈现边界定义时：

> 回答：确认，边界和接口定义合理。继续。

### S7 共创：质量与演进闭环

当 executor 呈现迁移/回滚/风险时：

> 回答：确认。新项目无迁移需求，回滚策略和风险识别合理。继续。

### S8 共创：实施约束收口

当 executor 整理待计划约束时：

> 回答：确认，约束清单完整。继续。

### S9 跨职能评审（无需用户输入）

无。executor 自行调用 3 个 reviewer agent。

### S10 用户确认并输出

当 executor 呈现设计收口结果时：

> 回答：确认，输出最终设计文件。

## 评分

每次执行完成后，分别调用：
1. `graders/hard-gate-grader.md` → 输出 `grading-1.json`
2. `graders/arch-framework-grader.md` → 输出 `grading-2.json`

## 结果目录

```
results/
├── s1-a-run-1/
│   ├── design.md
│   ├── design-cross-review.md
│   ├── design/adr/ADR-*.md
│   ├── executor-notes.md
│   ├── grading-1.json
│   └── grading-2.json
├── s1-a-run-2/
├── s1-a-run-3/
├── s1-b-run-1/
├── s1-b-run-2/
└── s1-b-run-3/
```
