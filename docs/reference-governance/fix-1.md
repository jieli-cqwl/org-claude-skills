# fix-1.md

## 输入分析

- 输入来源清单：
  - `docs/reference-governance/phase-1/code-review-report.md`
  - `git diff --name-only -- shared/protocols shared/reference/影响文件格式.md shared/reference/影响范围分析.md shared/skills/tech-lead/references/templates/plan-template.md install.sh tools/migration/retire-dot-claude.sh tests/test-single-source-layout.sh tests/test-skill-output-and-gate-contract.sh tests/test-doc-reference-integrity.sh docs/reference-governance`
  - `rg -n "shared/reference/(phase-selection-protocol|review-fix-loop-protocol|review-iteration-protocol)\\.md|skills/tech-lead/references/templates/plan-template\\.md" docs shared tests tools install.sh`
  - `bash tests/test-single-source-layout.sh`
  - `bash tests/test-skill-output-and-gate-contract.sh`
  - `bash tests/test-runtime-integrity.sh`
- work_dir 解析结果：`docs/reference-governance`
- 问题数量汇总：2

差异说明（N > 1 时 REQUIRED）:
- N = 1，本轮为首轮修复，无历史 fix 报告。

## 诊断阶段

### 环境快照
- 当前分支：`main`
- 工作树状态：存在用户未提交的 reference/rules/skills 重构改动；本轮新增 `shared/protocols/`、`shared/reference/影响文件格式.md` 与若干回归测试收口。
- 最近 5 条提交：
  - `da55904 merge: bring phase1 shared authority cleanup into main`
  - `adce53f fix: align shared authority boundaries for phase1`
  - `1923980 release: v1.2.4`
  - `5ec1616 Merge branch 'solstice-xenoposeidon'`
  - `da0f175 fix: harden superpowers localization runtime and sync guardrails`
- 最近改动文件：
  - `shared/protocols/phase-selection-protocol.md`
  - `shared/protocols/review-fix-loop-protocol.md`
  - `shared/protocols/review-iteration-protocol.md`
  - `shared/reference/影响文件格式.md`
  - `shared/reference/影响范围分析.md`
  - `shared/skills/tech-lead/references/templates/plan-template.md`
  - `install.sh`
  - `tools/migration/retire-dot-claude.sh`
  - `tests/test-single-source-layout.sh`
  - `tests/test-skill-output-and-gate-contract.sh`
  - `tests/test-doc-reference-integrity.sh`

### 现象与复现
| # | 问题 | 复现步骤 | 现象 |
|---|------|---------|------|
| 1 | `impact_files` 格式定义由上游 shared reference 反向依赖 tech-lead 下游模板 | 阅读 `shared/reference/影响范围分析.md:113` 与 `shared/skills/tech-lead/references/templates/plan-template.md:1` | `影响范围分析.md` 把格式 authority 指向 `plan-template.md`，形成 `reference -> skill-local template` 反向依赖。 |
| 2 | 3 份 skill-specific 协议混放在 `shared/reference/` | 静态追踪 `shared/reference/phase-selection-protocol.md:1`、`shared/reference/review-fix-loop-protocol.md:1`、`shared/reference/review-iteration-protocol.md:1` 以及 `docs/rules-reference-best-practice-plan.md:243` | 协议文档与通用参考共处同层，source 语义混杂；仅靠“全中文命名”不能解决目录职责问题。 |

当前环境复现结论:
- 可复现：是
- 不可复现时环境差异证据：无

### 假设验证过程
| # | 问题 | 假设 | 验证方法 | 结果 |
|---|------|------|---------|------|
| 1 | `impact_files` 反向依赖 | H1: `plan-template.md` 仍是 tech-lead 私有模板，被 shared reference 指向问题不大 | 运行 `bash tests/test-project-manager-phase3-contract.sh`，并做静态追踪 `tests/test-project-manager-phase3-contract.sh:14` | 排除；测试脚本直接把 `shared/skills/tech-lead/references/templates/plan-template.md` 作为 `project-manager` 合约输入，它已是跨 skill 消费对象。 |
| 1 | `impact_files` 反向依赖 | H2: 只把格式说明内联到 `影响范围分析.md` 即可，无需独立共享契约 | 对比 `shared/reference/影响范围分析.md:72-113` 与 `shared/skills/tech-lead/references/templates/plan-template.md:29-74` | 部分确认；最小可行方案可内联，但独立共享契约更稳，可同时被 `影响范围分析.md` 和 `plan-template.md` 引用。 |
| 2 | 协议混层 | H1: 仅保持 `shared/reference/` 原位并加 `skill-specific` 标签就足够 | 阅读 `docs/rules-reference-best-practice-plan.md:243-256`，并做引用追踪 `install.sh:507-508`、`tests/test-single-source-layout.sh:16-22` | 排除；标签只能解释现状，不能恢复目录语义，source 层仍会把协议与通用 reference 混在一起。 |
| 2 | 协议混层 | H2: 把协议移到 `shared/protocols/` 会打断 runtime `reference/...` 兼容 | 静态追踪安装链路 `install.sh:507-508`、`install.sh:533-534` 与退役脚本 `tools/migration/retire-dot-claude.sh:85-87` | 排除；只要安装时把 `shared/protocols` 汇入 staging `reference/`，runtime 兼容可以保留。 |

### 根因结论
| # | 问题 | 根因定位 | 因果链摘要 | 语义关系确认证据 |
|---|------|---------|-----------|------------------|
| 1 | `impact_files` 反向依赖 | `shared/reference/影响范围分析.md:113`、`shared/skills/tech-lead/references/templates/plan-template.md:94` | 共享参考文档直接把格式 authority 指向下游模板，导致 `reference` 层反向依赖 skill 局部实现；后续一旦模板移动或被其他 skill 共享消费，authority 会漂移。 | 通过静态追踪和引用追踪确认 `影响范围分析.md` 的格式出口只有这一处，而 `plan-template.md` 已被 `project-manager` 合约测试消费。 |
| 2 | 协议混层 | `shared/protocols/phase-selection-protocol.md:1`、`shared/protocols/review-fix-loop-protocol.md:1`、`shared/protocols/review-iteration-protocol.md:1`、`install.sh:507-508` | 协议最初为了 runtime 全局可见性被放进 `shared/reference`，但 source 层缺少“协议”这一独立层，导致通用按需知识与 workflow 协议职责耦合。 | 通过静态追踪 source 布局和安装链路确认：runtime 需要的是 `reference/...` 暴露面，不要求 source 必须放在 `shared/reference/`。 |

## 处置阶段

### 决策
- 处置策略：按最小必要原则拆 source 层、保持 runtime 兼容。
- 优先级：
  1. 上提 `impact_files` 共享格式契约，移除 `reference -> skill template` 反向依赖
  2. 引入 `shared/protocols/` 承载 3 个 workflow 协议
  3. 同步安装、迁移脚本与回归门禁，避免 source/runtime 再漂移

失败分类:
| # | 问题 | failure_class | 后续动作 |
|---|------|--------------|---------|
| 1 | `impact_files` 反向依赖 | FIXABLE | 新建 shared reference 契约文档，并让 `影响范围分析.md` 与 `plan-template.md` 共同引用。 |
| 2 | 协议混层 | FIXABLE | 将协议迁到 `shared/protocols/`，安装时继续渲染到 runtime `reference/`。 |

### FAIL-1: `impact_files` 共享契约缺位

| # | 问题 | 回答 |
|---|------|------|
| 1 | 根因是什么？ | `shared/reference/影响范围分析.md:113` 把格式 authority 指向下游 `plan-template.md`，而不是 shared 层契约。 |
| 2 | 修复是否完整？ | 已新增 `shared/reference/影响文件格式.md:1`，并让 `shared/reference/影响范围分析.md:113` 与 `shared/skills/tech-lead/references/templates/plan-template.md:94` 共同指向它。 |
| 3 | 是否引入新问题？ | 主要风险是新契约没有被门禁锁住；已在 `tests/test-skill-output-and-gate-contract.sh:85-98` 增加存在性与反向引用回归检查。 |
| 4 | 是否需要补充测试覆盖？ | 已补充，无需新增测试文件。 |

RED:
- 修复前，`shared/reference/影响范围分析.md:113` 直接引用 `skills/tech-lead/references/templates/plan-template.md`。

GREEN:
- 修复后，`shared/reference/影响文件格式.md:1` 成为共享 authority。
- 修复后，`bash tests/test-skill-output-and-gate-contract.sh` 通过。

### FAIL-2: 协议 source 层混入 `shared/reference`

| # | 问题 | 回答 |
|---|------|------|
| 1 | 根因是什么？ | runtime 需要全局 `reference/...` 暴露面，但 source 侧没有单独协议层，导致 3 份 workflow 协议长期滞留在 `shared/reference/`。 |
| 2 | 修复是否完整？ | 已迁移到 `shared/protocols/*.md`，并通过 `install.sh:507-508`、`install.sh:533-534` 保持 runtime `reference/...` 兼容；`tools/migration/retire-dot-claude.sh:85-87` 也已同步。 |
| 3 | 是否引入新问题？ | 主要风险是 source / runtime 路径再次漂移；已用 `tests/test-single-source-layout.sh:16-22` 与 `tests/test-doc-reference-integrity.sh:25` 锁住。 |
| 4 | 是否需要补充测试覆盖？ | 已补充 source 分层与 docs 引用两类回归。 |

RED:
- 修复前，协议文件位于 `shared/reference/*.md`，目录职责和文档命名问题耦合。

GREEN:
- 修复后，`shared/protocols/phase-selection-protocol.md:1`、`shared/protocols/review-fix-loop-protocol.md:1`、`shared/protocols/review-iteration-protocol.md:1` 成为 source 真源。
- 修复后，`bash tests/test-single-source-layout.sh`、`bash tests/test-runtime-integrity.sh`、`bash tests/test-doc-reference-integrity.sh` 通过。

## 产出

### 修复清单
| # | 问题 | 根因 | 修复文件 | 回归测试 |
|---|------|------|---------|---------|
| 1 | `impact_files` 反向依赖 | shared reference 缺少独立格式 authority | `shared/reference/影响文件格式.md`、`shared/reference/影响范围分析.md`、`shared/skills/tech-lead/references/templates/plan-template.md`、`tests/test-skill-output-and-gate-contract.sh` | `bash tests/test-skill-output-and-gate-contract.sh` |
| 2 | 协议混层 | source 缺少协议层，runtime 兼容诉求挤占 `shared/reference` | `shared/protocols/*.md`、`install.sh`、`tools/migration/retire-dot-claude.sh`、`tests/test-single-source-layout.sh`、`tests/test-doc-reference-integrity.sh` | `bash tests/test-single-source-layout.sh`、`bash tests/test-runtime-integrity.sh`、`bash tests/test-doc-reference-integrity.sh` |

### 全量测试结果
TEST_CMD: `git diff --check`
通过: 是 / 失败: 0 / 跳过: 0

TEST_CMD: `bash tests/run-all.sh`
通过: 全部 / 失败: 0 / 跳过: 0

### 阻断清单（全部/部分非 FIXABLE 时必填）
- 无

### 交接项清单
- 共享协议 source 真源现位于 `shared/protocols/`；runtime 仍通过 `reference/...` 消费。
- `impact_files` 的 shared authority 已收口到 `shared/reference/影响文件格式.md`。
- 最新审查结论见 `docs/reference-governance/phase-1/code-review-report.md`。
