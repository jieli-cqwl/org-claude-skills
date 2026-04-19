# overview skill 优化报告

## 总览

- 优化对象：`shared/skills/overview/SKILL.md`
- 优化分支：`codex/auto-optimize-overview-20260418-2323`
- 优化轮次：3
- 保留改进：2/3
- 回滚次数：1
- 评估模式：dry-run 独立复评

## 分数变化

| Skill | Before | After | Delta |
| --- | ---: | ---: | ---: |
| overview | 76 | 84 | +8 |

## 轮次记录

| Round | Commit | Dimension | Score | Evidence |
| --- | --- | --- | ---: | --- |
| Baseline | - | - | 76 | with_skill dry-run 明显优于 baseline，但边界条件分散 |
| 1 | `5954101` | 边界条件 | 82 | 新增阻塞硬门槛、输入与阻塞处理、脚本参数化扫描和完成校验 |
| 2 | `d3d7717` | Frontmatter质量 | 84 | 扩展 description 触发词，覆盖项目概览、架构概览、新人入门和关键文件 |
| 3 | `97ccd94` / `8154c33` | 资源整合度 | 78 | 项目类型表补齐尝试被独立复评判定脚本对齐不足，已 revert |

## 主要改进

1. 明确路径不可读、脚本失败、`{{RUNTIME_HOME}}` 未解析、无写入权限和用户未确认时必须阻塞。
2. 将 `project-detect.sh <项目路径>` 与 `dir-tree.sh <项目路径> 3` 写入主流程和完成校验，减少静默降级。
3. 扩展 frontmatter 触发词，让“项目概览”“架构概览”“新人入门”“先看哪些关键文件”等常见请求更容易命中。

## 验证证据

- `jq empty shared/skills/overview/test-prompts.json`
- `awk -F '\t' 'NF!=9 { bad=1 } END { exit bad }' docs/skill-quality-audit/20260419/results.tsv`
- `git diff --check -- shared/skills/overview/SKILL.md shared/skills/overview/test-prompts.json docs/skill-quality-audit/20260419/results.tsv docs/skill-quality-audit/20260419/overview-optimization-report.md`
- `bash tests/test-skill-output-and-gate-contract.sh`

## 残余风险

- `项目类型识别` 表与 `project-detect.sh` 仍可单独做脚本级对齐，但本轮尝试已按棘轮规则回滚。
- 评估采用 dry-run，未真实执行 `/overview` 写入 `docs/项目概览.md`，因为本任务目标是优化 skill 本身而不是对某个项目生成概览。
