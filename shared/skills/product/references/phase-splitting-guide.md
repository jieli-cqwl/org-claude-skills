# Phase 拆分指南

> 一句话原则：一个 Phase 是 LLM 能在单次高质量执行中完成的最大范围。

## 阈值

| 指标 | 推荐 | 硬上限 | 依据 |
|------|------|--------|------|
| UNIT 数/Phase | 2-3 | 5 | Cowan 4±1 + LLM 注意力稀释 |

辅助参考（非主决策条件）：

| 指标 | 参考值 | 说明 |
|------|--------|------|
| AC 总数/Phase | ≤ 25 | UNIT 数达标时通常自动满足 |
| 预估文件数/Phase | ≤ 30 | Task ≤5 文件 × UNIT 内 Task 数 |

## 决策规则

```
UNIT 数 ≤ 3
  → 单 Phase

UNIT 数 4-5
  ├─ 有自然分组（依赖/优先级）→ 按分组拆 Phase
  └─ 紧耦合无法分组 → 单 Phase（允许到上限 5）

UNIT 数 > 5
  → 必须拆分
```

## 分组优先级

拆分时按以下优先级将 UNIT 分配到 Phase：

1. 依赖顺序：上游 UNIT 所在 Phase 必须先行
2. 优先级：MVP UNIT 优先进入早期 Phase
3. 功能内聚：相关 UNIT 尽量同 Phase

## 目录创建

无论拆分结果如何，/product S8 完成时必须创建所有 `phase-{N}/` 目录：
- 单 Phase 项目 → 创建 `phase-1/`
- 多 Phase 项目 → 创建 `phase-1/`、`phase-2/` ...

PRD 交付计划中必须明确列出所有 `phase-{N}/unit-{N}/` 工作区路径。`phase-{N}/` 是设计与集成工件（design.md、plan.md、code-review-report.md、qa-report.md 等）的存放位置，`phase-{N}/unit-{N}/` 是 UNIT 专属执行工件（test-cases.md、dev-report.md 等）的存放位置。

## 反模式

- 不要为了拆分而引入跨 Phase 依赖——如果拆分后 Phase 2 的 UNIT 强依赖 Phase 1 的未完成 UNIT，说明分组不当
- 不要按"均匀分配"拆分——Phase 大小可以不均等，以自然边界为准
