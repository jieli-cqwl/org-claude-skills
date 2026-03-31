# fix-1.md

## 输入分析

- 输入来源清单：
  - `docs/rules-reference-best-practice/phase-1/code-review-report.md`
  - `git diff --name-only`
  - `rg -n "shared/reference/description-spec\\.md|shared/reference/测试代码质量\\.md" docs`
  - `tests/test-runtime-integrity.sh`
  - `tests/test-single-source-layout.sh`
- work_dir 解析结果：`docs/rules-reference-best-practice/phase-1`
- 问题数量汇总：3

差异说明（N > 1 时 REQUIRED）:
- N = 1，本轮为首轮修复，无历史 fix 报告。

## 诊断阶段

### 环境快照
- 当前分支：`main`
- 工作树状态：存在用户未提交的 shared/rules、shared/reference、shared/skills 重构修改；本轮新增 `tests/test-doc-reference-integrity.sh`、`docs/rules-reference-best-practice/phase-1/fix-1.md`
- 最近 5 条提交：
  - `da55904 merge: bring phase1 shared authority cleanup into main`
  - `adce53f fix: align shared authority boundaries for phase1`
  - `1923980 release: v1.2.4`
  - `5ec1616 Merge branch 'solstice-xenoposeidon'`
  - `da0f175 fix: harden superpowers localization runtime and sync guardrails`
- 最近改动文件：
  - `docs/skill-standard/research-report.md`
  - `docs/skill-strongest-practice/research-report.md`
  - `docs/code-reuse-best-practices/research-report.md`
  - `docs/reports/tech-debt/2026-03-26_技术债扫描报告.md`
  - `docs/reviews/1.2.2/code-review-report.md`
  - `docs/hotfix-20260326-1548/fix-1.md`
  - `shared/rules/铁律.md`
  - `shared/rules/文档管理.md`
  - `tests/test-doc-reference-integrity.sh`
  - `tests/run-all.sh`

### 现象与复现
| # | 问题 | 复现步骤 | 现象 |
|---|------|---------|------|
| 1 | 活跃文档仍引用已迁移/删除的规范文件 | 运行 `rg -n "shared/reference/description-spec\\.md|shared/reference/测试代码质量\\.md" docs` | 命中多份 `docs/**` 活跃文档，引用已删除路径。 |
| 2 | 现有门禁未覆盖 `docs/**` 共享文档死链 | 阅读 `tests/test-runtime-integrity.sh` 与 `tests/test-single-source-layout.sh` | 两个测试都不扫描 `docs/**` 中的共享文档链接。 |
| 3 | 方案文档与 source 落地结果漂移 | 对照 `docs/rules-reference-best-practice-plan.md:116` 与 `shared/rules/文档管理.md:25` | 方案声明要改成相对路径，但 source 仍保留模板变量。 |

当前环境复现结论:
- 可复现：是
- 不可复现时环境差异证据：无

### 假设验证过程
| # | 问题 | 假设 | 验证方法 | 结果 |
|---|------|------|---------|------|
| 1 | 活跃文档仍引用已迁移/删除的规范文件 | H1: 只有 review 报告误报，实际活跃文档没有旧链接 | 运行 `rg -n "shared/reference/description-spec\\.md|shared/reference/测试代码质量\\.md" docs` | 排除，活跃 research/report/fix/code-review 文档均命中。 |
| 1 | 活跃文档仍引用已迁移/删除的规范文件 | H2: 这些文档应被视为归档历史，不需要更新 | 检查命中文档路径，均位于 `docs/archive/` 之外；结合 `shared/rules/文档管理.md` 的活跃文档同步要求判断 | 排除，当前仓库没有将这些文件归档。 |
| 2 | 现有门禁未覆盖 `docs/**` 共享文档死链 | H1: `tests/test-runtime-integrity.sh` 已覆盖 docs 链接完整性 | 阅读 `tests/test-runtime-integrity.sh:21-47` 的 `check_global_refs()` / `check_skill_refs()` | 排除，仅扫描 installed runtime 的 `rules/reference/skills`。 |
| 2 | 现有门禁未覆盖 `docs/**` 共享文档死链 | H2: `tests/test-single-source-layout.sh` 已覆盖 docs 层面的共享路径有效性 | 阅读 `tests/test-single-source-layout.sh:48-50` | 排除，仅拦截 `~/.claude` 运行时路径硬编码。 |
| 3 | 方案文档与 source 落地结果漂移 | H1: `{{RUNTIME_HOME}}` 在 `shared/rules/*.md` 中必须保留，方案本身错了 | 检查 `shared/rules/铁律.md`、`shared/rules/文档管理.md` 的用法；二者都是文档交叉引用，不依赖运行时替换 | 排除，可直接改为相对路径。 |
| 3 | 方案文档与 source 落地结果漂移 | H2: 方案正确，但实现只完成了 Why 补充，漏掉了相对路径收口 | 对照 `docs/rules-reference-best-practice-plan.md:116` 与 source 当前内容 | 确认。 |

### 根因结论
| # | 问题 | 根因定位 | 因果链摘要 | 语义关系确认证据 |
|---|------|---------|-----------|------------------|
| 1 | 活跃文档仍引用已迁移/删除的规范文件 | `docs/skill-standard/research-report.md:17`、`docs/code-reuse-best-practices/research-report.md:30` | 本轮 shared authority 重构把 `description-spec.md` 迁到 `shared/skills/new-skills/references/`，把测试三件套合并到 `shared/reference/测试规范.md`，但活跃文档没有同步更新链接，形成死链与错误 authority。 | `rg -n "description-spec\\.md|测试代码质量\\.md" docs shared`；迁移目标见 `shared/skills/new-skills/SKILL.md:14`、`shared/skills/developer/SKILL.md:90`。 |
| 2 | 现有门禁未覆盖 `docs/**` 共享文档死链 | `tests/test-runtime-integrity.sh:21`、`tests/test-single-source-layout.sh:48` | 现有完整性门禁只验证 runtime 产物与 shared source 中的运行时噪音，不验证 `docs/**` 到 shared 文档的引用有效性，所以 stale link 能漏过。 | 静态追踪现有测试脚本的扫描范围；新增门禁落点为 `tests/test-doc-reference-integrity.sh:14`。 |
| 3 | 方案文档与 source 落地结果漂移 | `docs/rules-reference-best-practice-plan.md:116`、`shared/rules/文档管理.md:25` | 方案明确要求把文档管理中的模板路径收口成相对路径，但实现遗漏，导致计划与 source 双写不一致。 | 对照 `docs/rules-reference-best-practice-plan.md:116` 与 `shared/rules/文档管理.md:25`，并同步检查 `shared/rules/铁律.md:43` 的同类交叉引用。 |

## 处置阶段

### 决策
- 处置策略：按最小必要原则修复活跃文档引用与 source 交叉引用，同时补充一个 repo-level docs 链接完整性门禁并接入 `tests/run-all.sh`。
- 优先级：
  1. 修正活跃文档 stale links
  2. 修复 source 与计划漂移
  3. 增加门禁防回归

失败分类:
| # | 问题 | failure_class | 后续动作 |
|---|---------|--------------|---------|
| 1 | 活跃文档仍引用已迁移/删除的规范文件 | FIXABLE | 更新到新 authority 路径。 |
| 2 | 现有门禁未覆盖 `docs/**` 共享文档死链 | FIXABLE | 新增 docs 引用完整性测试并接入全量回归。 |
| 3 | 方案文档与 source 落地结果漂移 | FIXABLE | 将文档交叉引用统一为相对路径。 |

### FAIL-1: 活跃文档 stale 引用与门禁缺口

| # | 问题 | 回答 |
|---|------|------|
| 1 | 根因是什么？ | `docs/skill-standard/research-report.md:17`、`docs/code-reuse-best-practices/research-report.md:30` 等活跃文档未跟随 `shared/reference` 重构同步迁移链接。 |
| 2 | 修复是否完整？ | 已更新所有 review 中列出的活跃命中文档，并用 `rg -n "shared/reference/description-spec\\.md|shared/reference/测试代码质量\\.md" docs` 复查，仅剩历史评审文本中的问题描述。 |
| 3 | 是否引入新问题？ | 主要风险是新增测试误报历史文档；通过将扫描范围限定为 markdown link target，避免把纯文本历史描述误判为死链。 |
| 4 | 是否需要补充测试覆盖？ | 需要。新增 `tests/test-doc-reference-integrity.sh`，补齐 `docs/** -> shared/reference|shared/skills/*/references` 的链接有效性检查。 |

RED:
- 修复前，`rg -n "shared/reference/description-spec\\.md|shared/reference/测试代码质量\\.md" docs` 命中活跃文档，且旧的 `bash tests/test-runtime-integrity.sh` / `bash tests/test-single-source-layout.sh` 仍通过，证明缺陷真实且门禁缺口存在。

GREEN:
- 修复后，`bash tests/test-doc-reference-integrity.sh` 通过。
- 修复后，`bash tests/run-all.sh` 全量通过。

## 产出

### 修复清单
| # | 问题 | 根因 | 修复文件 | 回归测试 |
|---|---------|------|---------|---------|
| 1 | 活跃文档 stale 引用 | 活跃文档未跟随 authority 重构同步迁移链接 | `docs/skill-standard/research-report.md`、`docs/skill-strongest-practice/research-report.md`、`docs/code-reuse-best-practices/research-report.md`、`docs/reports/tech-debt/2026-03-26_技术债扫描报告.md`、`docs/reviews/1.2.2/code-review-report.md`、`docs/hotfix-20260326-1548/fix-1.md` | `bash tests/test-doc-reference-integrity.sh` |
| 2 | docs 门禁缺口 | 现有测试不扫描 `docs/**` 共享文档链接 | `tests/test-doc-reference-integrity.sh`、`tests/run-all.sh` | `bash tests/test-doc-reference-integrity.sh`、`bash tests/run-all.sh` |
| 3 | 方案/实现漂移 | 文档交叉引用遗漏从模板路径切回相对路径 | `shared/rules/铁律.md`、`shared/rules/文档管理.md` | `bash tests/test-runtime-integrity.sh`、`bash tests/run-all.sh` |

### 全量测试结果
TEST_CMD: `bash tests/run-all.sh`
通过: 全部 / 失败: 0 / 跳过: 0

### 阻断清单（全部/部分非 FIXABLE 时必填）
- 无

### 交接项清单
- 根因分析结论与定位文件:行号已记录在上文根因表。
- 修复范围覆盖活跃文档 stale 链接、shared/rules 文档交叉引用与 repo-level docs 链接门禁。
- 当前无非 `FIXABLE` 阻断项。
