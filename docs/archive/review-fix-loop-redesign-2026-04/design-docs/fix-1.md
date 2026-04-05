# fix-1.md

## 输入分析
- 输入来源清单：
  - `docs/review-fix-loop/2026-04-03-redesign/2026-04-04_评审意见.md`
  - `docs/review-fix-loop/2026-04-03-redesign/2026-04-04_二次复审意见.md`
  - 当前活跃实现：`claude/skills/code-review-fix/SKILL.md`、`claude/skills/doc-review-fix/SKILL.md`
  - 当前门禁：`tests/test-review-fix-redesign-contract.sh`、`tests/test-single-source-layout.sh`、`tests/run-all.sh`
  - 设计基线：`docs/review-fix-loop/2026-04-03-redesign/design.md`
- work_dir 解析结果：`docs/review-fix-loop/2026-04-03-redesign`
- 问题数量汇总：4

差异说明（N > 1 时 REQUIRED）:
- N=1，本轮为首次系统化修复。

## 诊断阶段

### 环境快照
- 当前分支: `feature/review-fix-redesign`
- 工作树状态:
  - 旧 skill/agent 删除中
  - 新 skill、archive 和 redesign 测试未提交
- 最近 5 条提交:
  - `5f33532 fix: localize review reporting and align reviewer prompt contracts`
  - `5e85c83 feat: wire agent-team-patterns into skill creator workflow`
  - `d4cc24d refactor: 分层评审简化为原生 agent team 模式`
  - `fbda35c fix: satisfy shellcheck in single-source layout test`
  - `6fc2930 Merge branch 'thorn-brick'`
- 最近改动文件:
  - `claude/skills/code-review-fix/SKILL.md`
  - `claude/skills/doc-review-fix/SKILL.md`
  - `tests/test-review-fix-redesign-contract.sh`
  - `tests/test-review-fix-redesign-scenarios.sh`
  - `tests/test-single-source-layout.sh`
  - `tests/run-all.sh`
  - `docs/review-fix-loop/2026-04-03-redesign/fix-1.md`

### 现象与复现
| # | 问题 | 复现步骤 | 现象 |
|---|------|---------|------|
| 1 | `code-review-fix` 契约过薄 | 对照 `design.md:102-144` 与 `claude/skills/code-review-fix/SKILL.md:13-39` | 运行时 skill 只剩骨架，缺失评审引擎、异常矩阵、收敛和报告契约 |
| 2 | `doc-review-fix` 契约过薄 | 对照 `design.md:146-220` 与 `claude/skills/doc-review-fix/SKILL.md:13-42` | 文档评审缺少 codex/self-review 双路径契约、统一 schema、跨轮追踪和最终报告要求 |
| 3 | redesign 测试无法证明能力成立 | 对照 `tests/run-all.sh:96-97` 与 `tests/test-review-fix-redesign-contract.sh:32-55` | 总入口只跑一个浅层关键词测试，负路径矩阵没有机械验证 |
| 4 | layout 门禁仍允许旧对象回流 | 检查 `tests/test-single-source-layout.sh:57-67` | 测试仍把 `codex-doc-review`、`review-fix-loop`、`codex-doc-reviewer.md` 当作可接受对象 |

当前环境复现结论:
- 可复现/不可复现: 可复现
- 不可复现时环境差异证据: 不适用

### 假设验证过程
每个问题至少 2 个已验证假设（结果为排除/确认/未决）。
| # | 问题 | 假设 | 验证方法 | 结果 |
|---|------|------|---------|------|
| 1 | `code-review-fix` 契约过薄 | 设计要求已通过引用文件承接，只是 SKILL.md 简写 | 检查 `claude/skills/code-review-fix/` 仅有 `SKILL.md`，无额外契约 reference | 排除 |
| 1 | `code-review-fix` 契约过薄 | 迁移时只保留关键词骨架，导致设计条款未落盘 | 对照 `design.md:106-144` 与 `claude/skills/code-review-fix/SKILL.md:13-39` | 确认 |
| 2 | `doc-review-fix` 契约过薄 | DECEPTION 参考文档已覆盖主要运行时约束 | 检查 `deception-patterns.md` 仅提供背景知识，不包含循环/收敛/报告语义 | 排除 |
| 2 | `doc-review-fix` 契约过薄 | 迁移时只保留动态维度和 DECEPTION 提示，丢失主循环契约 | 对照 `design.md:161-220` 与 `claude/skills/doc-review-fix/SKILL.md:13-42` | 确认 |
| 3 | redesign 测试无法证明能力成立 | 新增 contract test 已覆盖设计负路径矩阵，只是没有端到端模拟 | 检查 `tests/test-review-fix-redesign-contract.sh:32-55` 仅做文件和关键词存在性断言 | 排除 |
| 3 | redesign 测试无法证明能力成立 | 旧测试移除后没有等价的契约/负路径替代门禁 | 对照 `tests/run-all.sh:96-97` 与 `design.md:269-283` | 确认 |
| 4 | layout 门禁仍允许旧对象回流 | 其他运行时测试已完全覆盖 source-tree 回流风险 | 检查 `tests/test-runtime-integrity.sh`、`tests/test-install-smoke.sh`，它们聚焦 runtime/staging，不校验源码树白名单 | 排除 |
| 4 | layout 门禁仍允许旧对象回流 | single-source layout 的 allowlist 未随 redesign 收紧 | 检查 `tests/test-single-source-layout.sh:58-66` | 确认 |

### 根因结论
| # | 问题 | 根因定位 | 因果链摘要 | 语义关系确认证据 |
|---|------|---------|-----------|------------------|
| 1 | `code-review-fix` 契约过薄 | `claude/skills/code-review-fix/SKILL.md:13` | 迁移阶段先完成目录切换与测试 runner 迁移，但把运行时状态机压缩成关键词，导致设计条款无法被 skill 直接执行 | `design.md:102-144 -> code-review-fix/SKILL.md:13-39` 的跨工件契约追踪 |
| 2 | `doc-review-fix` 契约过薄 | `claude/skills/doc-review-fix/SKILL.md:13` | 文档链路只保留动态维度/DECEPTION 提示，丢失统一 Finding schema、跨轮追踪和报告语义 | `design.md:161-220 -> doc-review-fix/SKILL.md:13-42` 的跨工件契约追踪 |
| 3 | redesign 测试无法证明能力成立 | `tests/test-review-fix-redesign-contract.sh:32` | 旧回归测试移除后，仅以关键词存在性充当 contract gate，导致设计里的负路径矩阵没有落为可执行断言 | `tests/run-all.sh:96-97 -> tests/test-review-fix-redesign-contract.sh:32-55` 的测试入口静态追踪 |
| 4 | layout 门禁仍允许旧对象回流 | `tests/test-single-source-layout.sh:58` | source-tree 白名单保留旧 skill/agent 名称，未来若把旧对象放回活跃树，布局门禁不会报警 | `tests/test-single-source-layout.sh:57-67` 的 allowlist 静态追踪 |

## 处置阶段

### 决策
先收紧门禁制造 RED，再补齐 skill 契约到设计要求，最后跑 targeted + full regression 并做二次复审。

失败分类:
| # | 问题 | failure_class | 后续动作 |
|---|------|--------------|---------|
| 1 | `code-review-fix` 契约过薄 | FIXABLE | 扩写 `SKILL.md`，内联关键状态机和最终报告契约 |
| 2 | `doc-review-fix` 契约过薄 | FIXABLE | 扩写 `SKILL.md`，补齐文档评审循环、schema、跨轮追踪和 DECEPTION 处置 |
| 3 | redesign 测试无法证明能力成立 | FIXABLE | 先增强 contract test 断言，再以 RED/GREEN 驱动 skill 补齐 |
| 4 | layout 门禁仍允许旧对象回流 | FIXABLE | 收紧 source-tree allowlist，禁止旧 skill/agent 名称回流 |

### FAIL-1: 运行时契约与门禁不一致

| # | 问题 | 回答 |
|---|------|------|
| 1 | 根因是什么？ | `claude/skills/code-review-fix/SKILL.md:13`、`claude/skills/doc-review-fix/SKILL.md:13`、`tests/test-review-fix-redesign-contract.sh:32`、`tests/test-single-source-layout.sh:58` 的实现没有完整承接 `design.md` 契约 |
| 2 | 修复是否完整？ | 需要同时覆盖 2 个新 skill、1 个 redesign contract test、1 个 layout gate；单改任何一个都无法闭环 |
| 3 | 是否引入新问题？ | 风险主要是把 SKILL.md 写得过长或把测试写得过脆，需要控制在 skill 质量门槛和稳定关键词断言之间 |
| 4 | 是否需要补充测试覆盖？ | 需要；至少补齐 codex/self-review、schema、收敛、最终报告、旧对象回流等断言 |

RED:
- `bash tests/test-review-fix-redesign-contract.sh`
- 结果：FAIL
- 关键证据：`missing content in /Users/lijieli/org-claude-skills/claude/skills/doc-review-fix/SKILL.md: codex exec --json`
- 旁证：`bash tests/test-single-source-layout.sh` 同步 PASS，说明最先暴露的是 redesign contract 缺口而非 layout 误报

GREEN:
- `bash tests/test-review-fix-redesign-contract.sh` -> PASS
- `bash tests/test-review-fix-redesign-scenarios.sh` -> PASS（dirty tree、clean tree、stash conflict、non-json、missing field、max-round、不收敛、user abort 全部通过）
- `bash tests/test-single-source-layout.sh` -> `[PASS] single-source layout`
- `bash -n tests/test-review-fix-redesign-contract.sh` -> PASS
- `shellcheck -x tests/test-review-fix-redesign-contract.sh` -> PASS
- `python3 tools/community/check_task_plan_consistency.py docs/review-fix-loop/2026-04-03-redesign/tasks.md docs/review-fix-loop/2026-04-03-redesign/plan.md` -> `[PASS] tasks-plan consistency (4 tasks, 27 plan steps)`
- `bash tests/run-all.sh` -> `All tests passed`

## 产出

### 修复清单
| # | 问题 | 根因 | 修复文件 | 回归测试 |
|---|------|------|---------|---------|
| 1 | `code-review-fix` 契约过薄 | skeleton 化导致设计条款丢失 | `claude/skills/code-review-fix/SKILL.md` | `tests/test-review-fix-redesign-contract.sh` |
| 2 | `doc-review-fix` 契约过薄 | skeleton 化导致主循环契约丢失 | `claude/skills/doc-review-fix/SKILL.md` | `tests/test-review-fix-redesign-contract.sh` |
| 3 | redesign 测试无法证明能力成立 | contract test 过浅 | `tests/test-review-fix-redesign-contract.sh` | `bash tests/test-review-fix-redesign-contract.sh` |
| 4 | layout 门禁仍允许旧对象回流 | allowlist 未收紧 | `tests/test-single-source-layout.sh` | `bash tests/test-single-source-layout.sh` |
| 5 | 负路径矩阵缺少机械化验证 | 仅有关键词断言不足以覆盖 dirty tree / stash conflict / fail-close / max-round 等场景 | `tests/test-review-fix-redesign-scenarios.sh`; `tests/run-all.sh` | `bash tests/test-review-fix-redesign-scenarios.sh`; `bash tests/run-all.sh` |

### 全量测试结果
TEST_CMD: `bash tests/run-all.sh`
通过: 24 / 失败: 0 / 跳过: 0

补充验证:
- `bash -n tests/test-review-fix-redesign-contract.sh`
- `shellcheck -x tests/test-review-fix-redesign-contract.sh`
- `bash tests/test-review-fix-redesign-scenarios.sh`
- `python3 tools/community/check_task_plan_consistency.py docs/review-fix-loop/2026-04-03-redesign/tasks.md docs/review-fix-loop/2026-04-03-redesign/plan.md`

### 阻断清单（全部/部分非 FIXABLE 时必填）
- 本轮无非 `FIXABLE` 阻断项。

### 交接项清单
- 根因分析结论与定位文件:行号
- 修复范围与回归测试清单
- 二次/三次复审结论与剩余风险
- 本轮 RED/GREEN 证据与 full-suite 结果
