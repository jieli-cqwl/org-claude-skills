# Phase 选择协议

## 适用范围

- `/design`、`/test-design`、`/tech-lead`（标准流程下游 skill）

## 不适用

- `/research`：独立流程，使用 `docs/{feature}/` 平铺路径
- `/project-manager`：已通过 `{work_dir}` 机制处理，无需本协议

## 选择规则

1. 读取 `docs/{feature}/prd.md` 中的「交付计划」章节
2. 找到第一个状态不为 `DONE` 的 Phase（覆盖 NOT_STARTED 和 IN_PROGRESS）
3. 仅处理该 Phase 包含的 UNIT 子集

单 Phase 项目直接处理全部 UNIT，无选择开销。

## 状态流转

```
NOT_STARTED → IN_PROGRESS → DONE
```

| 状态 | 转换条件 |
|------|---------|
| IN_PROGRESS | 入口条件满足且下游 skill 开始处理 |
| DONE | 该 Phase 所有 UNIT 通过 `/project-manager` QA 验收 |

## 工作区路径

设计工件和执行工件分两级存放：

```
Phase 工作区: docs/{feature}/phase-{N}/
UNIT 工作区:  docs/{feature}/phase-{N}/unit-{N}/
```

| 工件类型 | 存放位置 | 产出 skill |
|---------|---------|-----------|
| design.md、design/、design-cross-review.md | Phase 工作区 | /design |
| test-cases.md、plan.md、dev-report.md 等 | UNIT 工作区 | /test-design、/tech-lead、/project-manager |

与 `reference/文档规范.md` 定义的目录结构一致。
