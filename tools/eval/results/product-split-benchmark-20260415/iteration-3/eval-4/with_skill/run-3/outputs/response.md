按当前工作区文档看，split 后 reviewer team 的闭环没有丢，`/product-manager` 要把它收成固定流水线：三视角并行独立审查，三位 reviewer 直接看 `brief.md`、`phase-{N}/prd.md`、`UNIT-*.md` 和 lock snapshot，不看自报；首轮结束后强制再跑一轮 `CONFIRMATION`，只重提 FAIL 视角，不重跑已 PASS 视角；结果写回 `brief.md` 的审查结论、审查汇总、审查问题台账、收敛轮次摘要。若发现范围/规则要变，直接回 `/product-director`。

必须显式保留的规则：
- 产品视角保留 `R1~R6 + R13 + PR-C1`，其中 `R1` 要查 UNIT 与根问题一致性，以及 `brief.lock.json / phase-{N}/prd.lock.json` 和 D-G1 快照一致性。
- `Issue Count` 只算未关闭稳定 issue，某视角 `PASS` 时必须是 `0`。
- 稳定 issue 用 `PR-/AR-/TR-`，已关闭痕迹改 `HIS-*`，`Review Round` 只写首次出现轮次。
- `审查问题台账` 不能留空，首轮全 PASS 也要留 1 条 `HIS-*`。
- 连续 2 轮 FAIL 数不减少就 `ASK_USER`，同一 issue 连续 3 轮未关闭才 `BLOCKED`；`WARN` 必须显式承接，`ASK_USER/BLOCKED` 才写用户裁决记录，lock 漂移直接 `FAIL`。
- 不能跳过 UNIT、AC、完整性扫描或三方评审，也不能改写 Director lock；上游阻断未关时不能宣称完成。

对应内部步就是 `M-S8` 三方评审加 `M-G1` 裁决门。

依据：[product-manager/SKILL.md](file:///Users/lijieli/org-claude-skills/tools/eval/results/product-split-benchmark-20260415/iteration-3/workspaces/with_split/shared/skills/product-manager/SKILL.md) [playbook-map.md](file:///Users/lijieli/org-claude-skills/tools/eval/results/product-split-benchmark-20260415/iteration-3/workspaces/with_split/shared/skills/product-shared/references/playbook-map.md) [brief-template.md](file:///Users/lijieli/org-claude-skills/tools/eval/results/product-split-benchmark-20260415/iteration-3/workspaces/with_split/shared/skills/product-shared/references/templates/brief-template.md) [prd-reviewer-prompt.md](file:///Users/lijieli/org-claude-skills/tools/eval/results/product-split-benchmark-20260415/iteration-3/workspaces/with_split/shared/skills/product-manager/references/prd-reviewer-prompt.md)