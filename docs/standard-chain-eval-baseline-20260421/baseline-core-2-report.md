# Standard-Chain Eval Baseline 2026-04-21

## Scope

本轮评测覆盖 5 个核心标准链路 skill：

- `product-director`
- `product-manager`
- `developer`
- `qa`
- `delivery-owner`

评测目标不是证明所有 skill 已经最终完美，而是把噪音分成三类：真实 skill 质量问题、eval 口径问题、评测基础设施问题。

## Baseline

正式基线输出目录：

`tools/eval/results/standard-chain-local-20260421/baseline-core-2`

结果：

| 指标 | 数值 |
| --- | ---: |
| eval cases | 15 |
| expectations | 60 |
| failed expectations | 5 |
| infra failures | 0 |
| pass rate | 0.9167 |

分布：

| Skill | 结果 |
| --- | --- |
| product-director | 12/12 passed |
| product-manager | 12/12 passed |
| developer | 11/12 passed |
| qa | 12/12 passed |
| delivery-owner | 8/12 passed |

## Failure Attribution

| Case | Baseline result | Attribution | Decision |
| --- | ---: | --- | --- |
| developer / happy-path-canonical-task | 3/4 | skill 输出段没有足够显式地带出 `tdd_evidence_index` 与 `reviewable_anchor`；后续复测又暴露报告类 AC 没有显式 REFACTOR | 修 skill，并同步 eval 口径 |
| delivery-owner / dispatch-with-canonical-state | 0/4 | eval 口径与 runner 输入冲突：空 workspace + 无 canonical fixture 下，skill 正确阻断，judge 却期待实际读取 plan 并派发 | 修 eval 为 canonical-state preflight；正向派发另建 fixture-backed eval |
| product-director / director-baseline-no-prd finding | n/a | judge 提示“推荐 A/B”带有引导性，但该 case 4/4 passed，属于低优先级 wording 风险 | 本轮不改，后续可单独优化中立追问措辞 |

## Changes Made

1. `tools/eval/scripts/run_standard_chain_local_eval.py`
   - 保留原 CLI 入口，具体实现拆分到 `tools/eval/scripts/standard_chain_local_eval/`，避免 runner 单文件继续膨胀。
   - 区分 graded failure 与 infra failure。
   - infra failure 的 `pass_rate` 改为 `null`，summary markdown 显示 `N/A`。
   - `--allow-failures` 下 workspace setup failure 也会写入 summary。
   - 支持 eval case `files`，把声明的 fixture 文件复制到临时 workspace。
   - executor sandbox 改为 `workspace-write`，仅允许写临时 eval workspace 内产物。
   - 默认清理 `_workspaces`，并通过 `.gitignore` 防止临时 workspace 再次进入提交范围。

2. `tests/test-standard-chain-local-eval-runner.sh`
   - 覆盖 executor 非零退出的 infra failure。
   - 覆盖 workspace setup failure。
   - 断言 infra failure 不再被写成 0 分。
   - 断言默认不保留 `_workspaces`。

3. `shared/skills/developer/SKILL.md`
   - 在输出段显式要求 `evidence_refs`、`reviewable_anchor`、`file_changes`、`tdd_evidence_index`、`task_scope`。
   - 明确报告类 / 证据索引类 AC 也要记录 RED/GREEN/REFACTOR；无可重构项写 `REFACTOR: no-op` 并重跑校验。

4. `shared/skills/developer/evals/evals.json` 与 `shared/skills/developer/test-prompts.json`
   - 把 happy path eval 调整为 fixture-backed sample-feature 输入。
   - 评测目标从“空 workspace 里真实读取不存在文件”改为“解析 fixture、说明前置读取、在临时 eval workspace 限制下给出执行计划和报告字段”。

5. `shared/skills/delivery-owner/evals/evals.json`
   - 把原 `dispatch-with-canonical-state` 改为 `dispatch-requires-canonical-state`。
   - 当前 local eval 只验证 preflight 边界：不能用口头 Phase 确认替代 canonical JSON + active registry。

## Retest Evidence

| Command | Result |
| --- | --- |
| `bash tests/test-standard-chain-skill-evals.sh` | PASS |
| `bash tests/test-standard-chain-local-eval-runner.sh` | PASS |
| `python3 -m py_compile tools/eval/scripts/run_standard_chain_local_eval.py tools/eval/scripts/standard_chain_local_eval/*.py` | PASS |
| `shellcheck -x tests/test-standard-chain-local-eval-runner.sh` | PASS |
| `python3 tools/eval/scripts/run_standard_chain_local_eval.py --skills developer --eval-ids happy-path-canonical-task --runs-per-eval 1 --output-dir tools/eval/results/standard-chain-local-20260421/developer-report-fields-fix-run-3 --timeout-sec 360 --allow-failures` | 4/4 passed, infra failures 0 |
| `python3 tools/eval/scripts/run_standard_chain_local_eval.py --skills delivery-owner --eval-ids dispatch-requires-canonical-state --runs-per-eval 1 --output-dir tools/eval/results/standard-chain-local-20260421/delivery-owner-canonical-state-fix-run-1 --timeout-sec 360 --allow-failures` | 4/4 passed, infra failures 0 |

## Remaining Work

1. 为 `delivery-owner` 增加真正的 fixture-backed positive dispatch eval：提供 `plan.json`、`tasks.json`、`design.json`、`test-cases.json`、`artifact-registry.json`，验证它能按批次和并行策略组织执行，并维护 `delivery-state.json`。
2. 把本轮临时 eval 结果目录收敛为可提交证据，只保留 summary 与必要 grading，不提交 `_workspaces` 和大日志。
3. 对全 10 个 standard-chain skill 跑同一套 local eval baseline；当前本轮正式覆盖 5 个核心 skill。
