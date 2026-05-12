# skill-refiner triad audit

目的：用 `skill-creator` 风格的三臂评测判断 `skill-refiner` 是否足以从 `optimize` 推进到 `retain`。

三臂：

- `baseline`：不用专门 Skill。
- `skill_creator`：只用通用 `skill-creator`。
- `skill_refiner`：用本地 `skill-refiner`。

运行：

```bash
python3 shared/skills/skill-refiner/evals/triad-skill-creator-audit-2026-05-12/scripts/run_triad_eval.py --max-workers 3
python3 shared/skills/skill-refiner/evals/triad-skill-creator-audit-2026-05-12/scripts/grade_triad_eval.py <run-dir>
```

裁决口径：

- 高复杂场景中 `skill_refiner` 应显著胜出。
- 简单新建/description 场景中 `skill_refiner` 应正确分流给 `skill_creator`。
- `skill_refiner` 不得提前改文件、不得提前冻结 create/split/rewrite/optimize。
- retain 需要三臂结果、断言评分和人工反馈都闭合。

当前关键 run：

- `runs/run-20260512-063819`：打磨后最终全量复评，`skill_refiner` 206/209，baseline 209/209。
- `skill-refiner-result-2026-05-12.json`：本轮 refinement 的可验证结果 JSON。

解释：runner 已补充较强输出合同，baseline 达到满分；因此该三臂评测只能证明 `skill_refiner` 已接近合同满分，不能单独证明可升级 `retain`。retain 仍需要 blind pairwise eval 或真实使用 pilot。
