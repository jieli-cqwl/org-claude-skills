## Response

应路由到 `github-repo-radar`。

理由：你的任务是“找适合采用的 GitHub repo”，并且明确要求输出 `discard/watch/trial/adopt` 动作状态。这正命中当前 `research` Skill 的硬分流规则：GitHub 仓库发现、评估、比较、采用，并需要这些动作状态时，优先交给 `github-repo-radar`，不能用通用 `research` 直接替代。

我不会在当前 `research` 流程里编造仓库清单或动作状态。下一步应由 `github-repo-radar` 接手，并至少确认：目标问题域、采用场景、技术栈/约束、评估维度。

## Self Check
- route: `github-repo-radar`
- mode: GitHub repo discovery / adoption radar
- presentation_profile: `decision`
- artifacts_required: 由 `github-repo-radar` 决定；当前 `research` 不落盘 `docs/{feature}/research-report.md`