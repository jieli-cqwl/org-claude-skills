**阻断结果**
我已按 [`shared/skills/review/SKILL.md`](/Users/lijieli/org-claude-skills/shared/skills/review/SKILL.md) 做预检，但这次只能停在前置检查，不能进入正式 review。

- 缺少有效审查范围：没有 `commit range`、文件列表或可用的 diff 基线，无法确定本轮变更边界。
- 缺少当前 feature / UNIT 工作区路径：当前工作区里也没有可用于定位的正式 `brief.json` / `artifact-registry.json` / `plan.json` / `tasks.json` / `developer-report.json`。
- 我只在仓库里找到 `tests/fixtures/...` 下的样例 JSON，不是这次审查可用的正式工件。
- 因此不能猜测范围，不能进入 A/B/C 评审，也不会落任何审查产物；本次全程未联网、未改文件。

**下一步**
- 给我 `commit range` 或文件列表。
- 再给我当前 feature / UNIT 的工作区路径，或直接提供 `brief.json` 和 `artifact-registry.json` 的位置。

补齐这些后，我再按 skill 继续。