# Anthropic Skill-Creator Official Adapter Design

## Purpose

本次变更让 `/Users/lijieli/org-claude-skills` 具备与 Anthropic `skill-creator` 对齐的 skill 评估闭环能力，用于验收现有 skill。第一阶段以 `shared/skills/developer` 为 pilot，验证本仓库能按官方方式完成 existing skill improvement loop。

目标不是重新设计评测体系，也不是合并本仓库已有 `standard-chain` runner。目标是保留 Anthropic 官方方法、产物语义和脚本用法，只增加本地薄适配层，让官方能力能稳定复跑。

## Scope

首批操作对象：

- 被测 skill：`shared/skills/developer`
- 官方工具源：`community/anthropic/skills/skill-creator`
- 本地适配层：`tools/eval/anthropic_skill_creator/`
- 结果目录：`tools/eval/results/anthropic-skill-creator/developer/`

第一阶段必须支持：

- existing skill snapshot：为 `developer` 生成 `old_skill` 快照。
- candidate run：用当前 `developer` 作为 `new_skill`。
- eval execution：按 `developer/evals/evals.json` 执行 old/new 两组 run。
- grading：为每个 run 生成 Anthropic-compatible `grading.json`。
- benchmark：调用官方 `aggregate_benchmark.py` 生成 `benchmark.json` 和 `benchmark.md`。
- review：调用官方 `eval-viewer/generate_review.py --static` 生成 `review.html`。
- feedback：支持用户提供的 `feedback.json`，iteration 2 起展示 previous workspace。
- trigger eval：调用官方 `run_eval.py` 评估 `description` 触发准确性。
- description loop：调用官方 `run_loop.py` 生成 `best_description` 和优化报告。

第一阶段明确不做：

- 不修改 `community/anthropic/skills/skill-creator` 官方目录。
- 不重写 Anthropic 方法论。
- 不接入 `tests/run-all.sh`。
- 不扩展到所有 standard-chain skill。
- 不自动写回 optimized description。
- 不伪造 `feedback.json`。
- 不把 `without_skill` 作为 pilot 主线；`developer` 是已有 skill，按 Anthropic existing-skill improvement 使用 `old_skill` baseline。

## Architecture

新增本地薄 wrapper：

```text
tools/eval/anthropic_skill_creator/
  README.md
  run_developer_improvement.sh
  configs/
    developer.json
  scripts/
    paths.py
    prepare_workspace.py
    run_existing_skill_eval.py
    grade_runs.py
    run_trigger_loop.py
```

职责边界：

- `community/anthropic/skills/skill-creator` 是 upstream source，只读使用。
- `tools/eval/anthropic_skill_creator` 是本地适配层，只负责编排、路径转换和格式对齐。
- `shared/skills/developer/evals/evals.json` 是 pilot 的 eval 输入源。
- `tools/eval/results/anthropic-skill-creator/developer/` 是运行结果和人审材料输出源。

`run_developer_improvement.sh` 只做命令编排，不承载复杂业务逻辑。Python 脚本拆分职责，避免单文件膨胀。

## Alternatives Considered

1. 改造现有 `tools/eval/scripts/run_standard_chain_local_eval.py`
   - 放弃原因：会把本地 standard-chain 评测语义与 Anthropic `skill-creator` 官方语义混在一起，失败来源难以定位。

2. 只写运行文档，不新增 wrapper
   - 放弃原因：只能说明人可以手工执行，不能证明仓库具备可复跑能力。

3. 修改 `community/anthropic/skills/skill-creator`
   - 放弃原因：会破坏 upstream 镜像边界，后续同步官方更新时难以审查差异。

最终选择薄 wrapper：保留官方目录只读，新增本地编排层，最大限度复用 Anthropic 已验证的流程和脚本。

## Workspace Layout

每次运行生成一个 iteration：

```text
tools/eval/results/anthropic-skill-creator/developer/
  iteration-1/
    skill-snapshot/
    eval-<id>/
      eval_metadata.json
      old_skill/
        run-1/
          outputs/
            response.md
            transcript.md
          grading.json
          timing.json
      new_skill/
        run-1/
          outputs/
            response.md
            transcript.md
          grading.json
          timing.json
    benchmark.json
    benchmark.md
    review.html
  trigger/
    eval-set.json
    results/
      <timestamp>/
        results.json
        report.html
        log.txt
```

目录结构保持官方 `aggregate_benchmark.py` 和 `generate_review.py` 可消费。若官方脚本期望 `eval-*` 目录、配置目录和 `outputs/`，本地 wrapper 必须适配到该结构，而不是修改官方脚本。

## Data Flow

1. Read config
   - 读取 `configs/developer.json`。
   - 校验 `shared/skills/developer/SKILL.md`、`shared/skills/developer/evals/evals.json`、官方 `skill-creator` 路径存在。

2. Prepare workspace
   - 创建下一轮 `iteration-N`。
   - 为每个 eval 生成 `eval_metadata.json`。
   - 记录 `snapshot_source`，说明 old/new 来源。

3. Snapshot old skill
   - 如果 `shared/skills/developer` 在工作区有改动，old snapshot 来自 `git HEAD`。
   - 如果没有改动，old snapshot 来自当前文件系统快照。
   - new skill 始终来自当前工作区。

4. Execute old/new runs
   - 对每个 eval 分别运行 `old_skill/run-1` 与 `new_skill/run-1`。
   - 每个 run 至少输出 `outputs/response.md` 和可审计 transcript。
   - 执行失败不得伪装为评分失败；必须记录为 infra failure。

5. Grade runs
   - 依据 eval 的 `expectations` 和实际输出生成 `grading.json`。
   - 字段必须使用官方兼容形状：`expectations[].text`、`expectations[].passed`、`expectations[].evidence`、`summary.pass_rate`。

6. Aggregate and review
   - 在官方 `skill-creator` 目录下调用 `python -m scripts.aggregate_benchmark <iteration-dir> --skill-name developer`。
   - 调用 `eval-viewer/generate_review.py <iteration-dir> --skill-name developer --benchmark <iteration-dir>/benchmark.json --static <iteration-dir>/review.html`。
   - iteration 2 起传入 `--previous-workspace`。

7. Trigger and description loop
   - 从 developer trigger eval set 生成 `trigger/eval-set.json`。
   - 调用官方 `python -m scripts.run_eval` 产出 trigger results。
   - 调用官方 `python -m scripts.run_loop` 产出 `best_description` 和 report。
   - 不自动写回 `SKILL.md`。

## Execution Semantics

`developer` pilot 是 existing skill improvement，不是新 skill 创建。因此 baseline 语义为：

- `old_skill`：改动前快照。
- `new_skill`：当前候选版本。

本阶段通过标准不要求 `new_skill` 优于 `old_skill`。第一阶段验收的是本仓库是否具备 Anthropic-style eval 能力。后续真实优化任务可以基于同一能力追加质量门禁，例如新版本不得低于旧版本、硬门禁 expectation 不得回退。

## Invariants

- 官方 `community/anthropic/skills/skill-creator` 目录保持只读。
- Anthropic 产物字段名保持兼容，不引入本地同义字段替代 `text / passed / evidence / pass_rate`。
- `feedback.json` 只来自用户真实审阅或 viewer 导出，不由 wrapper 生成占位反馈。
- optimized description 只作为候选产物输出，不自动改写 `shared/skills/developer/SKILL.md`。
- infra failure 与质量评分分开记录，不把运行失败写成低分通过评分管线。

## Downstream Impact

- 对 `shared/skills/developer`：第一阶段只读取 skill 与 evals，不自动修改运行时 skill。
- 对 `community/anthropic/skills/skill-creator`：只读调用官方脚本，不产生本地补丁。
- 对 `tools/eval/results`：新增 Anthropic-style 结果目录，供人审和后续计划引用。
- 对 `tests/run-all.sh`：第一阶段不接入，避免把 pilot 能力变成全仓门禁。
- 对后续 standard-chain skill：设计保留 config 扩展点，但本阶段不承诺扩展范围。

## Error Handling

- 官方 `skill-creator` 路径不可读：停止执行并报告。
- `developer/evals/evals.json` 不存在或 JSON 无效：停止执行并报告。
- old snapshot 无法生成：停止执行并报告。
- 单个 run 执行失败：写入 infra failure，不用 0 分替代真实失败。
- grader 输出不符合官方字段：停止聚合，报告 schema 错误。
- 官方 benchmark/viewer/trigger 脚本执行失败：停止后续依赖步骤并报告。

## Verification

设计完成后的实现验收命令按层级执行：

```bash
python3 community/anthropic/skills/skill-creator/scripts/quick_validate.py community/anthropic/skills/skill-creator
```

证明官方 `skill-creator` 目录可被校验。

```bash
bash tools/eval/anthropic_skill_creator/run_developer_improvement.sh --dry-run
```

证明 config、路径、evals 和 workspace 规划可解析，不产生真实 run。

```bash
bash tools/eval/anthropic_skill_creator/run_developer_improvement.sh
```

证明 developer pilot 能完整生成 iteration workspace、old/new outputs、grading、benchmark 和 review HTML。

```bash
test -s tools/eval/results/anthropic-skill-creator/developer/iteration-1/benchmark.json
test -s tools/eval/results/anthropic-skill-creator/developer/iteration-1/review.html
```

证明关键官方产物存在且非空。

```bash
bash tools/eval/anthropic_skill_creator/run_developer_improvement.sh --trigger-only
```

证明 trigger eval 和 description optimization 能运行并输出报告。

## Risks

- Claude/Codex 执行环境差异会影响 trigger eval。第一阶段以官方 `claude -p` 能力为对齐对象；Codex 原生触发观测不纳入 pilot。
- 当前工作区存在未提交改动时，wrapper 必须只读取相关 skill 路径并记录 snapshot source，不得回滚用户改动。
- 评测运行成本高。pilot 只覆盖 `developer`，并保留 dry-run。
- `feedback.json` 依赖用户真实审阅。没有用户反馈时不生成假反馈，只证明 review HTML 支持反馈导出。

## Success Criteria

- 本地新增适配层，不修改官方 `community/anthropic/skills/skill-creator`。
- `developer` pilot 能按 Anthropic existing-skill improvement loop 生成 old/new run。
- 每个 run 生成可消费的 `grading.json`。
- 官方 `aggregate_benchmark.py` 成功生成 `benchmark.json`。
- 官方 `generate_review.py --static` 成功生成 `review.html`。
- trigger eval 能调用官方 `run_eval.py`。
- description loop 能调用官方 `run_loop.py` 并输出 `best_description`。
- optimized description 不自动写回 `SKILL.md`。
- 所有失败以明确错误或 infra failure 记录，不伪造成质量评分。
