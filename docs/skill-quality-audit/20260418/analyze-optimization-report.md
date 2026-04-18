# analyze skill 优化报告

## 总览

- 优化对象：`shared/skills/analyze/SKILL.md`
- 优化分支：`auto-optimize/20260418-0902`
- 优化轮次：3
- 保留改进：3/3
- 回滚次数：0
- 评估模式：3 次完整独立复评

## 分数变化

| Skill | Before | After | Delta |
| --- | ---: | ---: | ---: |
| analyze | 66 | 83 | +17 |

## 轮次记录

| Round | Commit | Dimension | Score | Evidence |
| --- | --- | --- | ---: | --- |
| Baseline | - | - | 66 | with skill 6.3/10，baseline 6.0/10 |
| 1 | `3ce1a89` | 边界条件 | 77 | `partial`、`blocked/skipped`、`tool_warning`、`Task/AC-like` fallback |
| 2 | `359d73f` | 指令具体性 | 82 | `T1/T2`、`Task N`、勾选项、tasks/fix 状态冲突 WARNING |
| 3 | `fd5863b` | 资源整合度 | 83 | 串联 `extract-artifacts.sh` 与 `coverage-matrix.sh`，并以文件扫描校验脚本输出 |

## 主要改进

1. 缺少标准工件时不再硬阻塞，改为 `partial` 模式并显式列出 `blocked/skipped`。
2. 无标准 UNIT 时生成 `Task/AC-like` 追踪矩阵，覆盖 `T1/T2`、`Task N` 和勾选项。
3. 脚本矩阵为空或与文件事实冲突时标记 `tool_warning`，避免把空矩阵当作无问题。

## 验证证据

- `jq empty shared/skills/analyze/test-prompts.json`
- `git diff --check -- shared/skills/analyze/SKILL.md docs/skill-quality-audit/20260418/results.tsv`
- `awk -F '\t' 'NF!=9 { bad=1 } END { exit bad }' docs/skill-quality-audit/20260418/results.tsv`
- `test $(wc -c < shared/skills/analyze/SKILL.md) -le 3868`

## 残余风险

- `coverage-matrix.sh` 对轻量目录仍可能返回空矩阵或误导性覆盖状态；当前 skill 已要求交叉核对，但脚本自身尚未修复。
- Round 3 是默认最大轮次的最后一轮；下一步若继续优化，建议单独进入脚本修复任务。
