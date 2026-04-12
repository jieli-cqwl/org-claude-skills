# Phase 选择协议

> 类型：skill-specific 协议（非通用按需知识）。

## 适用范围

- `/design`、`/test-design`、`/tech-lead`、`/delivery-owner`（标准流程下游 skill）

## 不适用

- `/research`：独立流程，使用 `docs/{feature}/` 平铺路径

## 选择规则

1. 读取 `docs/{feature}/brief.md` 中的「交付计划」章节
2. 若当前编辑路径包含 `phase-{N}/`，优先选择该 Phase
3. 否则找到第一个状态不为 `DONE` 的 Phase（覆盖 NOT_STARTED 和 IN_PROGRESS）
4. 仅处理该 Phase 包含的 UNIT 子集

选择优先级：显式目标/当前编辑路径 > 第一个非 DONE Phase > fallback。

单 Phase 项目直接处理全部 UNIT，无选择开销。

## 状态流转

```
NOT_STARTED → IN_PROGRESS → DONE
```

| 状态 | 转换条件 |
|------|---------|
| IN_PROGRESS | 入口条件满足且下游 skill 开始处理 |
| DONE | 该 Phase 所有 UNIT 通过 `/delivery-owner` QA 验收 |

## 工作区路径

设计工件和执行工件分两级存放：

```
Phase 工作区: docs/{feature}/phase-{N}/
UNIT 工作区:  docs/{feature}/phase-{N}/unit-{N}/
```

| 工件类型 | 存放位置 | 产出 skill |
|---------|---------|-----------|
| design.md、design/、plan.md、design/adr/ADR-*.md | Phase 工作区 | /design、/tech-lead |
| code-review-report.md、qa-report.md、waivers.md、acceptance-summary.md 等 Phase 级交付工件 | Phase 工作区 | /delivery-owner |
| test-cases.md、dev-report.md 等 UNIT 级执行工件 | UNIT 工作区 | /test-design、/delivery-owner |

目录骨架与工作区路径以对应 workflow skill、template 与 brief.md/plan 工件中的约定为准。
