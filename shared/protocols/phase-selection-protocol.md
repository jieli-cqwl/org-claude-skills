# Phase 选择协议

> 类型：skill-specific 协议（非通用按需知识）。

## 适用范围

- `/design`、`/test-design`、`/tech-lead`、`/delivery-owner`（标准流程下游 skill）

## 不适用

- `/research`：独立流程，使用 `docs/{feature}/` 平铺路径

## 选择规则

1. 读取 `docs/{feature}/brief.json` 的 `delivery_plan` 与 `phase_index`
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
| `phase-prd.json`、`design.json`、`plan.json`、`tasks.json`、`delivery-state.json`、`artifact-registry.json`、`signoff-package.json`、`qa-result.json`、`code-review-result.json` | Phase 工作区 | `/product-director`、`/product-manager`、`/design`、`/tech-lead`、`/review`、`/qa`、`/delivery-owner` |
| `test-cases.json`、`developer-report.json`、`verify-result.json` | UNIT / Task 工作区 | `/test-design`、`/developer`、`/verify` |
| `phase-operational.html`、`phase-operational.projection-manifest.json` | `views/` 子目录 | projection / replay / readiness gate |

目录骨架与工作区路径以 `contracts/skill-chain.yaml`、`shared/runtime/standard-chain-catalog.json` 与对应 canonical template 为准。
