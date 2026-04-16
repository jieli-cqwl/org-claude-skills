# fix-2.md

## 输入分析
- 输入来源清单：
  - fresh proving 准备提交时执行 `bash tests/test-product-eval-contract.sh` 的失败输出
  - `docs/product-role-split-20260414/evidence-and-eval-plan.md`
  - `tests/test-product-eval-contract.sh`
  - `tools/eval/scenarios/product-split-benchmark-evals.json`
  - `tools/eval/results/product-split-benchmark-20260415/iteration-1/`
- work_dir 解析结果：`docs/product-role-split-20260414`
- 问题数量汇总：1

差异说明（N > 1 时 REQUIRED）:
- N=2。已读取 `docs/product-role-split-20260414/fix-1.md`。
- `fix-1.md` 处理的是 runtime hook、Manager gate、compat skill、template 与 eval runner 接线问题。
- 本轮不是重复修上一轮问题，而是在 fresh proving 阶段补齐“严格 eval 计划”与测试契约之间的新漂移。

## 诊断阶段

### 环境快照
- 当前分支：`main`
- 工作树状态：
  - 已修改：`contracts/skill-chain.yaml`
  - 已修改：`docs/product-role-split-20260414/evidence-and-eval-plan.md`
  - 已修改：`shared/skills/product-director/SKILL.md`
  - 已修改：`shared/skills/product-manager/SKILL.md`
  - 已修改：`shared/skills/product-manager/references/prd-reviewer-prompt.md`
  - 已修改：`shared/skills/product/SKILL.md`
  - 已修改：`tests/test-product-eval-contract.sh`
  - 已修改：`tests/test-product-role-split-contract.sh`
  - 已修改：`tests/test-product-stability-guidance-contract.sh`
  - 未跟踪：`shared/skills/product-shared/references/playbook-map.md`
  - 未跟踪：`tools/eval/results/product-split-benchmark-20260415/`
  - 未跟踪：`tools/eval/scenarios/product-split-benchmark-evals.json`
  - 未跟踪：`tools/eval/scripts/`
- 最近 5 条提交：
  - `af7346f docs: remove stale planning artifacts`
  - `a9076fc refactor: centralize eval track definitions`
  - `fb0bdbf fix: close product role split review findings`
  - `5096a0f test: migrate product role split validation assets`
  - `8738cff feat: wire product role split runtime`

### 现象与复现
| # | 问题 | 复现步骤 | 现象 |
|---|------|---------|------|
| 1 | `product eval contract` 仍绑定旧 scenario 文案 | `bash tests/test-product-eval-contract.sh` | 失败并报错：`missing pattern in docs/product-role-split-20260414/evidence-and-eval-plan.md: 场景 ID：\`product-director-p1-clear-single-phase\`` |

当前环境复现结论:
- 可复现：是
- 不可复现时环境差异证据：不适用

### 假设验证过程
| # | 问题 | 假设 | 验证方法 | 结果 |
|---|------|------|---------|------|
| 1 | `product eval contract` 失败 | `tests/test-product-eval-contract.sh` 仍断言旧的 6 个 Director/Manager scenario ID，而计划文档已切到新的 benchmark case ID | 对照 `tests/test-product-eval-contract.sh:41-46` 与 `docs/product-role-split-20260414/evidence-and-eval-plan.md:73-109` | 确认 |
| 1 | `product eval contract` 失败 | 文档误改，应该回退到旧 scenario ID，而不是调整测试 | 检查文档新增的“严格验证边界 / 4 层证据 / Case 1-6 / benchmark 结果目录”结构，以及新增 `tools/eval/scenarios/product-split-benchmark-evals.json` 与 benchmark 脚本 | 排除 |
| 1 | `product eval contract` 失败 | eval runner / grader / scenario 资产本身失效，导致计划文案之外也需要改实现 | 保留 `tests/test-product-eval-contract.sh` 后半段 runner/scenario 断言，修正计划文案断言后重新运行 `bash tests/test-product-eval-contract.sh` | 排除 |

### 根因结论
| # | 问题 | 根因定位 | 因果链摘要 | 语义关系确认证据 |
|---|------|---------|-----------|------------------|
| 1 | `product eval contract` 失败 | `tests/test-product-eval-contract.sh:21-24,41-61` | 测试通过 `PLAN_DOC` 直接读取 `docs/product-role-split-20260414/evidence-and-eval-plan.md`，但仍把旧 scenario ID 当作计划真源；当前文档已经改为严格 benchmark case 结构，导致测试在 runner 验证前提前失败 | `PLAN_DOC` 在 `tests/test-product-eval-contract.sh:21` 绑定到目标文档；`assert_present` 在 `:41-61` 直接消费该文件；对照文档 `docs/product-role-split-20260414/evidence-and-eval-plan.md:11-22,65-71,73-122` 可确认计划语义已切换 |

## 处置阶段

### 决策
- 只修测试契约，不回退已成型的严格 eval 计划。
- 保留旧 runner / grader / scenario 的回归断言，避免把“文案更新”误修成“删掉既有评测资产”。
- 新增 benchmark 结果目录断言，确保计划里提到的原始 benchmark 资产至少已经落盘。

失败分类:
| # | 问题 | failure_class | 后续动作 |
|---|------|--------------|---------|
| 1 | `product eval contract` 仍绑定旧 scenario 文案 | FIXABLE | 先用现有失败测试作为 RED，再最小更新 `tests/test-product-eval-contract.sh` 的计划断言与 benchmark 结果断言，随后回归相关合同测试 |

### FAIL-1: `product eval contract` 的计划断言滞后

| # | 问题 | 回答 |
|---|------|------|
| 1 | 根因是什么？ | `tests/test-product-eval-contract.sh:41-46` 仍要求旧 `product-director-* / product-manager-*` 场景 ID 出现在计划文档里，但文档已在 `docs/product-role-split-20260414/evidence-and-eval-plan.md:73-109` 切换为 `Case 1-6 + benchmark case ID`。 |
| 2 | 修复是否完整？ | 已把测试更新为同时校验：严格验证边界、6 个 benchmark case ID、benchmark 结果目录、原有 runner/grader/scenario 资产和 `check/status/summary` 输出。 |
| 3 | 是否引入新问题？ | 影响面只在 `tests/test-product-eval-contract.sh`。文档、skill 和 runner 实现未被改写。 |
| 4 | 是否需要补充测试覆盖？ | 已补 benchmark 结果目录和 executor log 计数断言，避免后续只改计划文案、不落实际 benchmark 资产时再次漏检。 |

RED:
- `bash tests/test-product-eval-contract.sh`
- 失败输出：`[FAIL] missing pattern in /Users/lijieli/org-claude-skills/docs/product-role-split-20260414/evidence-and-eval-plan.md: 场景 ID：\`product-director-p1-clear-single-phase\``

GREEN:
- `bash tests/test-product-eval-contract.sh`
- 结果：`[PASS] product eval contract`

## 产出

### 修复清单
| # | 问题 | 根因 | 修复文件 | 回归测试 |
|---|------|------|---------|---------|
| 1 | `product eval contract` 仍绑定旧 scenario 文案 | 计划文档已切到严格 benchmark case，但测试仍断言旧 scenario ID | `tests/test-product-eval-contract.sh` | `bash tests/test-product-eval-contract.sh`、`bash tests/test-product-role-split-contract.sh`、`bash tests/test-product-stability-guidance-contract.sh`、`python3 tools/community/check_task_plan_consistency.py docs/product-role-split-20260414/tasks.md docs/product-role-split-20260414/plan.md` |

### 全量测试结果
TEST_CMD:
- `bash tests/test-product-role-split-contract.sh`
- `bash tests/test-product-stability-guidance-contract.sh`
- `bash tests/test-product-eval-contract.sh`
- `python3 tools/community/check_task_plan_consistency.py docs/product-role-split-20260414/tasks.md docs/product-role-split-20260414/plan.md`
- `git diff --check`

通过: 5 / 失败: 0 / 跳过: 0

补充说明：
- 诊断阶段额外执行过 `bash tests/test-skill-output-and-gate-contract.sh`，当前因 `docs/qa-test-v2/2026-04-11-best-practice-rebuild/replay-scenarios.md` 缺少 `多步骤表单 / 向导 / 下单流` 断言而失败。该失败发生在本轮修复目标之外，且不属于 `docs/product-role-split-20260414/tasks.md` 的验收命令范围，本轮未扩大范围处理。

### 阻断清单
- 无。本轮问题为 `FIXABLE`，且目标回归已恢复。

### 交接项清单
- 当前严格 eval 计划与 `product eval contract` 已重新对齐。
- benchmark 相关 Python 源文件与场景清单仍是新增未提交资产，提交前应确认是否纳入本次提交范围。
- `tools/eval/scripts/__pycache__/` 下的 `.pyc` 属于生成物，建议不要纳入提交。
