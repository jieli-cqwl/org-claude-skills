# Empirical Skill Lifecycle Eval Pilot

## 问题陈述

上一条 small-chain 已经建立 D9 存在合理性框架：每个标准链 Skill 有 `eval-type`、`evals/evals.json` 和 `evals/lifecycle-review.json`。但这些 review 仍停留在初始准备态，`capability_uplift` 还没有 with/without baseline 数据，`encoded_preference` 还没有偏好锚点保真度数据。

如果直接全量运行 12 个 Skill，会把模型执行成本、runner 能力缺口和 lifecycle 聚合规则混在一起。当前更需要先证明一条小而完整的经验评审链路：能运行样本 eval，能记录 with-skill 与 without-skill 差异，能按偏好锚点聚合保真度，能把结果写回生命周期 review，并且不会把 pilot 数据伪装成最终 retain/retire 结论。

## 目标与成功标准

目标：为标准链 Skill 生命周期评审补上首轮 empirical 数据流，先用 `product-manager` 与 `developer` 两个代表样本跑通可重复闭环。

成功标准：

1. Local eval runner 能显式区分 `with_skill` 与 `without_skill` run mode，输出 summary 中包含 run mode。
2. Judge 输出能记录 `expected_anchors` 的命中结果，并在 summary 中聚合偏好锚点保真度。
3. 新增 lifecycle 聚合器能读取 eval summary，计算 `capability_uplift` 与 `encoded_preference` 指标，并产出可写回的 review JSON。
4. `product-manager` 与 `developer` 的 lifecycle review 能记录 pilot empirical evidence，同时保留 `decision: "optimize"`，不伪造 retain/retire。
5. 变更有 deterministic tests 覆盖，不依赖真实模型调用来证明聚合逻辑正确；真实小样本执行只作为 evidence 附件，不替代单元与契约门禁。

## 方案

### 评审范围

本次只做两个代表 Skill：

- `product-manager`: `encoded_preference`，验证偏好锚点保真度链路。
- `developer`: `mixed`，验证 with/without uplift 与偏好锚点保真度同时存在的链路。

不全量运行 12 个 Skill。其他 Skill 的 `lifecycle-review.json` 保持首轮框架态，等聚合器和报告机制稳定后再批量推进。

### runner 扩展

现有 `tools/eval/scripts/run_standard_chain_local_eval.py` 已能执行 eval 并生成 `summary.json`。本次在既有模块内追加三个能力：

1. `--run-mode with_skill|without_skill`
   - `with_skill` 保持当前行为：临时 workspace 包含目标 Skill，executor prompt 要求读取并遵循 `SKILL.md`。
   - `without_skill` 不复制目标 Skill，executor prompt 明确要求不用该 Skill，只基于通用能力回答同一 eval prompt。
   - 每条 run summary 记录 `run_mode`，避免后续聚合时混淆来源。

2. 偏好锚点 metadata
   - `load_skill_evals` 将 `preference_anchors` 中被 case `expected_anchors` 引用的锚点定义附到 case。
   - `eval_metadata.json` 记录 `expected_anchors` 与对应 anchor 文案。

3. anchor-aware judge
   - judge prompt 要求对每个 expected anchor 给出 `passed/evidence`。
   - `grading.json` 增加 `anchor_results` 和 `preference_anchor_summary`。
   - `summary.json` 每条 run 增加 `anchor_passed`、`anchor_total`、`anchor_fidelity`。

### lifecycle 聚合器

新增一个轻量脚本：

`tools/eval/scripts/update_lifecycle_review.py`

职责：

- 输入：`--skill`、`--with-summary`、可选 `--without-summary`、`--output-review`、可选 `--write-review`。
- 读取 Skill 的 `evals/evals.json` 和当前 `evals/lifecycle-review.json`。
- 对 `encoded_preference`：聚合 with-skill summary 中的 anchor 命中率，写入 `encoded_preference.fidelity`、`measurement_status`、`sample_size`、`summary_refs`。
- 对 `mixed`：同时聚合 with/without pass rate，计算 `with_avg`、`without_avg`、`uplift`；若没有 without summary，保持 `needs_without_skill_baseline`，不输出 retain/retire。
- 决策规则：pilot 阶段只允许 `decision: "optimize"`。聚合器可以记录 `recommended_decision`，但不会自动把正式 `decision` 改成 `retain` 或 `retire`。

### pilot evidence

为了控制成本，本次只运行小样本：

- `product-manager`: `handoff-validation-first`
- `developer`: `ambiguous-missing-design`

每个样本先跑 `with_skill`。`developer` 再跑 `without_skill`，用于证明 uplift 输入链路。运行结果进入：

`tools/eval/results/skill-lifecycle-empirical-pilot-20260423/`

如果真实模型执行失败，不能把 deterministic fake runner 结果当作 empirical evidence。只能把失败记录进 verify report，并保留聚合器 deterministic tests 作为代码正确性证据。

## 备选方案

| 方案 | 描述 | 未选原因 |
| --- | --- | --- |
| 直接全量跑 12 个 Skill | 所有 lifecycle review 一次性改成 empirical 状态 | 成本高，失败面大，runner 能力缺口会和 Skill 质量混在一起 |
| 只写聚合器不跑样本 | 完全 deterministic，改动小 | 无法证明真实 local eval 输出能进入 lifecycle review |
| 修改 skill-creator benchmark 系统 | 复用更完整的 benchmark 基础设施 | 当前需求只需要标准链 local eval 的 lifecycle 聚合，改 skill-creator 会扩大范围 |

## 变更范围

| 变更对象 | 变更类型 | 影响范围 |
| --- | --- | --- |
| `tools/eval/scripts/standard_chain_local_eval/workspace.py` | 修改 | 增加 run mode workspace 与 executor prompt 差异 |
| `tools/eval/scripts/standard_chain_local_eval/grading.py` | 修改 | 增加 anchor-aware judge 和 grading summary |
| `tools/eval/scripts/standard_chain_local_eval/runner.py` | 修改 | 透传 run mode，并在 summary 中保留 anchor 与 run mode 数据 |
| `tools/eval/scripts/update_lifecycle_review.py` | 新增 | 聚合 eval summary 并生成 lifecycle review 更新 |
| `tests/test-standard-chain-local-eval-runner.sh` | 修改 | 验证 run mode、anchor metadata 与 summary 字段 |
| `tests/test-skill-lifecycle-empirical-review.sh` | 新增 | 验证 lifecycle 聚合器和 review 输出合同 |
| `shared/skills/product-manager/evals/lifecycle-review.json` | 修改 | 写入 pilot empirical preference fidelity |
| `shared/skills/developer/evals/lifecycle-review.json` | 修改 | 写入 pilot empirical uplift 与 preference fidelity |
| `docs/skill-lifecycle-eval/2026-04-23-empirical-lifecycle-eval/` | 新增 | small-chain design/tasks/plan/verify evidence |

## 不变量

- 不修改 12 个 Skill 的 `evals/evals.json` 语义，不把 pilot 样本扩展成全量评审。
- 不把 fake `codex` 测试结果当作真实 empirical evidence。
- 不自动把正式 `decision` 从 `optimize` 改成 `retain` 或 `retire`。
- 不删除或跳过现有 eval runner 契约测试。
- 不改变 `run_standard_chain_local_eval.py` 默认行为；默认仍是 `with_skill`。

## 下游影响

- `skill-harness` 可继续读取 D9 lifecycle review，并看到部分 Skill 已有 pilot empirical evidence。
- 后续 12 Skill 全量评审可以复用同一个聚合器，不需要重新定义 review JSON 写法。
- `tests/run-all.sh --quick` 需要覆盖新的 deterministic 聚合器测试，防止 lifecycle review schema 漂移。

## 风险

- 真实模型 eval 触发超时或输出格式不满足 runner 合同时，执行结果只记录为 empirical 阻塞，不降低 deterministic 聚合器验收标准。
- `without_skill` prompt 会继承仓库 AGENTS 与通用上下文约束。处理方式：summary 明确标注 run mode，并把 without-skill 仅作为 pilot baseline，不直接触发退役结论。
- Anchor judge 只用关键词命中会产生错误通过。处理方式：judge prompt 要求清晰行为证据，deterministic tests 验证字段聚合，最终 retain/retire 仍需人工确认。
