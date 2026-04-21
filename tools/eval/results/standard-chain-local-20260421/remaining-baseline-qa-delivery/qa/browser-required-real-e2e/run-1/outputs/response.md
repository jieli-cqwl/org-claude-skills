我理解的是：这条 UNIT 被交接成 `QA_B` 且 `execution_mode=browser_required`，验收对象是 **Web 登录重定向的真实用户旅程**，不是接口或脚本本身。你给的 `expected outcome` 和 [qa skill](/Users/lijieli/org-claude-skills/tools/eval/results/standard-chain-local-20260421/remaining-baseline-qa-delivery/_workspaces/qa/shared/skills/qa/SKILL.md) 一致。

按 skill，验收要这样做：

1. 先读齐验收基线：`brief.json`、`phase-prd.json`、`UNIT-*.json`、`test-cases.json`，确认 `QA_B` 交接契约里确实标了 `browser_required`。
2. 启动**真实服务**，拿到真实入口 URL。
3. 用**浏览器 E2E** 跑完整旅程：登录 → 重定向 → 落地页/目标页，并补验异常恢复和关键 UX 反馈。
4. 在 phase 级 `qa-result.json` 里写入 `browser_tool`、`entry_url`、`browser_evidence`，同时保留 `baseline_plan_version_ref`、`baseline_tasks_version_ref`、`gate_result`、`release_recommendation`、`residual_risk`、`uncovered_boundary`、`issue_ledger`、`not_executed_reason`。
5. 不能用 API、CLI、单接口响应来替代浏览器证据。

当前工作区里我**没有找到** `docs/...` 下的这些基线工件，所以这轮**不能进入正式 QA 执行**，也**不能产出有效的 `qa-result.json`**。按 skill 规则，这里应当**阻断**，并回到 `test-design` / `delivery-owner` 补齐前置工件与真实服务入口。

下一步只有一个：补齐上述 canonical 输入后，再按浏览器 E2E 继续验收。