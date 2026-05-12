# skill-refiner 的 skill-creator 视角审计

审计日期：2026-05-12

## 结论

`skill-refiner` 是本仓库 first-party Skill，已具备“评测 + 优化既有 Skill”的可用闭环，但当前证据只能支持 `optimize`，不能支持 `retain`。

可作为专属 Skill 打磨的主工具试点；不能作为批量自动优化器，也不能宣称已经充分成熟。

## 审计口径

本次用 `skill-creator` 的外部口径反审 `skill-refiner`：

- 是否有真实用户意图和触发边界。
- 是否有 realistic test prompts。
- 是否有 with-skill / baseline 对照。
- 是否有可量化断言或偏好锚点。
- 是否有用户可审的输出证据。
- 是否能基于反馈迭代，而不是自证完成。

本轮不修改 `skill-refiner` 本体。

## 证据

| 项 | 证据 | 审计判断 |
| --- | --- | --- |
| first-party 承载 | `shared/skills/skill-refiner/SKILL.md` | PASS |
| eval 样本 | `shared/skills/skill-refiner/evals/evals.json` 有 6 个 eval，均包含 `with_skill/without_skill` | PASS |
| 偏好锚点 | `evals.json` 有 12 个 `SA-*` anchor | PASS |
| live pilot | `tools/eval/results/skill-refiner-final-operation-create-gate-live-with/summary.json` pass rate 1.0；without pass rate 0.5 | PASS，但样本只有 1 |
| comparative evidence | `effect-evidence.json` 覆盖 5 个 fixture-backed 场景，current 全部赢 baseline | PASS，但不是 live LLM benchmark |
| 完成门禁 | `completion_check.sh` + `validate_refinement_result.py` + schema | PASS |
| 生命周期裁决 | `lifecycle-review.json` 当前 decision 为 `optimize` | 正确，不应升级为 retain |

## 通过项

1. 不是空壳 Skill：有流程、合同、validator、dogfood、effect evidence。
2. 不是纯主观判断：有 `evals.json`、偏好锚点、with/without 对照、结构化结果门禁。
3. 能约束关键失败模式：禁止提前 create/optimize/split/rewrite，要求场景确认、策略冻结、验证证据。
4. 能处理真实 Skill 治理问题：旧测试固化噪音、历史残留、职责漂移、外部实践覆盖不足。

## 未通过或证据不足

1. live 样本太少：当前 live baseline 只有 1 个样本，不能证明稳定泛化。
2. 缺少 `skill-creator` 三臂对照：目前主要是 `skill-refiner` vs `without_skill`，还没有系统比较 `skill-refiner` vs 通用 `skill-creator` 流程。
3. 人类 review 证据不完整：没有看到 `skill-creator` reviewer/feedback 风格的人工逐项反馈闭环作为主证据。
4. 历史 dogfood 存在 schema 漂移：部分旧 dogfood 结果不符合当前 v3 validator，相关测试通过定制断言保留历史价值，但不能当当前完成证据。
5. 成本边界未闭合：复杂流程适合高价值 Skill 改造，但轻量触发描述优化、新建简单 Skill、局部文案调整应分流给 `skill-creator` 或普通编辑流程。

## 裁决

当前裁决：`optimize`

使用策略：

- 复杂既有 Skill 改造：用 `skill-refiner`。
- 纯新建 Skill：用 `skill-creator`。
- 触发 description 优化：优先用 `skill-creator`。
- 批量自动优化：暂不允许。
- 每次优化前必须有真实场景事实，策略确认前不得改目标 Skill。

## 下一轮证明实验

要把 `skill-refiner` 从 `optimize` 推到 `retain`，需要做一轮 `skill-creator` 风格三臂评测：

三组：

- baseline：不用专门 Skill。
- generic：只用 `skill-creator`。
- target：用 `skill-refiner`。

建议 5 个场景：

1. 用户要求新建 code-review Skill，但仓库已有 review 能力。
2. implementation Skill 噪音多，混入 runtime gate、旧资源头、LLM 基础教学。
3. 旧测试要求保留已确认噪音。
4. 大而全 Skill 需要判断是拆分、优化、替换还是删除。
5. 简单触发描述优化，预期 `skill-refiner` 应分流而不是重流程介入。

retain 门槛：

- 高复杂场景中 `skill-refiner` 至少赢 4/5。
- 简单场景中能正确分流，不制造过度流程。
- 每组输出都有可读报告、断言评分和人工反馈。
- 结果通过 validator，不依赖旧 schema dogfood。

## 本轮验证

已运行：

```bash
bash tests/test-skill-refiner-effect-evidence.sh
bash tests/test-skill-refiner-supersedes-drift-gate.sh
bash tests/test-skill-refiner-github-radar-external-practice.sh
bash tests/test-skill-refiner-live-baseline-pilot.sh
bash tests/test-skill-effectiveness-eval-framework.sh
```

全部通过。
