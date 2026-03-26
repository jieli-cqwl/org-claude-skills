# 文档规范

> rules/文档管理.md 定义核心原则。本文件定义目录结构、命名规则、创建条件。

## 目录结构

| 目录 | 用途 | 产出方式 |
|------|------|---------|
| `{task}/` | 开发任务全生命周期 | /product ~ /qa（完整功能）或 /refactor（简单任务） |
| `reports/tech-debt/` | 代码健康度定期报告 | /scan |
| `reports/security/` | 安全审计定期报告 | /security |
| `archive/` | 过时文档隔离（Claude 不参考） | 归档规则 |

docs/ 根目录仅允许：项目概览.md（/overview）、README.md + 任务目录 + 系统目录（reports/、archive/）。

## 命名规则

| 对象 | 规则 | 示例 |
|------|------|------|
| 任务目录 | 中文描述性名称，由 /product 或 /refactor 确定 | `登录功能/`、`重构-认证模块/` |
| 任务内文件 | 由 skills 定义（英文内容描述命名），不受中文命名约束 | `prd.md`、`design.md` |
| 报告文件 | `[YYYY-MM-DD]_报告类型.md` | `2026-03-09_技术债扫描报告.md` |
| 根目录文件 | 中文（README.md 例外） | `项目概览.md` |

## 创建条件

| 规模 | 文档要求 |
|------|---------|
| 简单（≤3 文件） | 只更新 CHANGELOG |
| 中等（3-10 文件） | CHANGELOG + 推荐计划文档 |
| 复杂（>10 文件） | 必须创建 `docs/{task}/plan.md` |

例外：配置/格式/注释修改无需文档。

## 术语约定（范围边界）

- 范围边界术语统一使用 `本期不交付`，表示本次迭代明确不交付的能力范围。
- `排除项` 用于可测试的“不应发生”断言；`影响范围` 用于记录受影响对象及处理决策。
- 新增或更新活跃文档时，范围边界术语必须保持上述分工，避免混用。

## 强调格式边界

- `**` 仅用于硬信号：强制约束、风险提示、最终结论。
- 禁止用 `**` 承担结构职责：如 `**定义**：`、`**示例**：`、`1. **步骤**：`、表格装饰性加粗。
- 代码围栏与行内代码中的 `**` 视为代码内容，不纳入文档强调规则。

推荐保留词：`必须`、`禁止`、`严禁`、`不可`、`仅限`、`终止`、`暂停`、`高风险`、`BLOCKED`、`PASS`、`FAIL`、`结论`。

## 项目目录结构

> 所有项目统一使用 `phase-{N}/unit-{N}/` 结构。由 PRD 交付计划定义路径，下游从 PRD 读取。

### 全局文件（始终在 `docs/{feature}/` 根）

- `prd.md` — PRD 文档
- `units/UNIT-*.md` — UNIT 定义文件
- `constitution.md` — 跨阶段共享架构决策
- `product-cross-review.md` — /product 跨职能审查（产品/架构/测试三视角合并）
- `process-notes.md` — 可选，过程改进记录

### Phase 文件（在 `phase-{N}/` 下）

- `design.md`、`design/`（MOD、ADR、REF）— /design 产出
- `design-cross-review.md` — /design 跨职能审查
- `plan.md` — /tech-lead 产出，覆盖 Phase 内所有 UNIT 的任务拆分
- `design-review-N.md` — /tech-lead 产出，评审 Phase 级 design.md
- `code-review-report.md` — /project-manager Phase 3，审查整个 Phase 代码
- `qa-report.md` — /project-manager Phase 3，验收整个 Phase 功能
- `acceptance-summary.md` — /project-manager 签收报告
- `waivers.md` — /project-manager 豁免记录（如有）
- `equivalence/` — 迁移项目等价性报告（如有）

### UNIT 文件（在 `phase-{N}/unit-{N}/` 下）

- `test-cases.md` — /test-design 产出
- `testdesign-cross-review.md` — /test-design 跨职能审查
- `dev-report.md` — /project-manager Phase 2 产出，每个 UNIT 独立
- `developer-report-Task-N.md` — developer 子代理 Task 级报告

```
docs/{feature}/
├── prd.md                              # Feature 级（/product 产出）
├── units/UNIT-*.md                     # Feature 级（/product 产出）
├── product-cross-review.md             # Feature 级（/product 跨职能审查）
├── constitution.md                     # Feature 级（跨 Phase 共享架构决策）
├── process-notes.md                    # Feature 级（可选）
├── phase-1/                            # /product S8 创建目录骨架
│   ├── design.md                       # Phase 级（/design 产出）
│   ├── design/                         # Phase 级（/design 产出）
│   │   ├── MOD-001.md
│   │   ├── adr/ADR-001.md
│   │   └── REF-001-*.md
│   ├── design-cross-review.md          # Phase 级（/design 跨职能审查）
│   ├── plan.md                         # Phase 级（/tech-lead 产出）
│   ├── design-review-N.md              # Phase 级（/tech-lead 评审不通过时）
│   ├── code-review-report.md           # Phase 级（/project-manager Phase 3）
│   ├── qa-report.md                    # Phase 级（/project-manager Phase 3）
│   ├── acceptance-summary.md           # Phase 级（/project-manager 签收）
│   ├── waivers.md                      # Phase 级（/project-manager 豁免，如有）
│   ├── equivalence/                    # Phase 级（迁移项目，如有）
│   │   └── equivalence-report.md
│   ├── unit-1/                         # UNIT 执行工件
│   │   ├── test-cases.md               # UNIT 级（/test-design）
│   │   ├── testdesign-cross-review.md  # UNIT 级（/test-design 跨职能审查）
│   │   ├── dev-report.md               # UNIT 级（/project-manager Phase 2）
│   │   └── developer-report-Task-N.md  # UNIT 级（developer 子代理）
│   └── unit-2/
│       └── ...（同结构）
├── phase-2/
│   └── ...（同结构）
```

### Phase 内 UNIT 间的共享决策

Phase 内所有 UNIT 共享同一个 `phase-{N}/design.md`，无需额外共享机制。跨 Phase 共享的架构决策写入 `docs/{feature}/constitution.md`。

### 前序 Phase 回溯修改

- 后续 Phase 设计发现前序 Phase 设计需变更时，在当前 `design.md` 中创建「跨阶段设计修正」章节
- 前序已归档文件不做物理修改，用 `supersedes: phase-{N}/design.md#章节名` 声明覆盖
- 涉及已交付代码时，在当前 `plan.md` 增加回溯修复 Task
- `constitution.md` 同步更新

## 命名补充

| 对象 | 规则 | 示例 |
|------|------|------|
| Phase 目录 | `phase-{N}`（kebab-case，N 为阶段编号） | `phase-1/`、`phase-2/` |
| UNIT 工作区目录 | `unit-{N}`（kebab-case，N 为 UNIT 编号，位于 `phase-{N}/` 下） | `phase-1/unit-1/` |
| ad-hoc 参考文件 | `REF-NNN-描述.md`（存放在 `phase-{N}/design/` 下） | `REF-001-code-inventory.md` |
| 过程改进文件 | `process-notes.md`（feature 根目录） | `docs/{feature}/process-notes.md` |
| 归档子目录 | `{feature}-phase-{N}`（保持原结构） | `docs/archive/登录功能-phase-1/` |

## 交叉引用

- 使用相对 Markdown 链接引用同 feature 内文件：`[design](./phase-1/design.md)`
- 跨 Phase 引用时指向 constitution.md，禁止直接引用其他 `phase-{N}/` 下的设计文件
- 引用格式：`[见 constitution.md#章节名](../constitution.md#章节名)`

## 归档条件

| 触发 | 操作 |
|------|------|
| Phase 内所有 UNIT QA PASS | `phase-{N}/` 整目录移至 `docs/archive/{feature}-phase-{N}/` |
| 全部 Phase 完成 | 整个 `docs/{feature}/` 归档至 `docs/archive/{feature}/` |
| 旧版测试报告、重复文档 | 移至 docs/archive/ + 加归档头 |

归档头：`<!-- ARCHIVED: YYYY-MM-DD | 仅供追溯，不作为当前参考 -->`

- 归档时保持原目录结构
- 禁止在活跃区（`docs/{feature}/`）建 `archive/` 子目录
- UNIT 归档时，所有评审文件随 UNIT 一起归档

## 参考文件

- `REF-NNN-*.md` 存放在 `phase-{N}/design/` 下
- 用途：代码盘点、技术调研、数据分析等临时参考
- 归档时随 Phase 目录一起归档

## 过程改进文件

- `process-notes.md` 放 feature 根目录（`docs/{feature}/process-notes.md`）
- 用途：记录过程中的改进观察、流程优化建议等
- 非必需文件，仅在有改进观察时创建

## 计划文档模板

必含章节：改动原因、改动方案、执行步骤（checklist）、关键代码位置、测试验证。
可选：相关 Commit、经验总结。
