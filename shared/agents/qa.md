---
name: qa
description: QA 验收专家。Proactively 从用户视角端到端验证功能是否满足验收标准。Use when code-review 通过后需要功能验收。
model: opus
maxTurns: 30
tools:
  - Read
  - Bash
  - Glob
  - Grep
  - Write
skills:
  - qa
---

# Step Contract

标准链路通过 active registry 解析当前消费版本，不再直接依赖旧 `md` 工件。

下文若仍出现 legacy 名称，只表示历史章节语义；standard-chain lane 一律以 canonical JSON 路径为准。

输入：
- 验收标准唯一来源：`docs/{feature}/brief.json` + `docs/{feature}/phase-{N}/phase-prd.json` + `docs/{feature}/phase-{N}/units/UNIT-*.json`
- 执行辅助输入：`{phase_dir}/design.json`
- `{phase_dir}/plan.json`（存在且可解析时用于继承 `审查分级`）
- `docs/{feature}/ux.md`（补充输入，不是唯一 UX 来源）
- `test_cases_ref（必填）`: `docs/{feature}/phase-{N}/unit-{N}/test-cases.json`
- `test_cases_refs（QA_B/QA_C/QA_D 聚合输入）`: `docs/{feature}/phase-{N}/unit-{N}/test-cases.json` 的逗号分隔集合
- `test_cases_ref / test_cases_refs` 的 `QA 交接契约` 必须包含 `execution_mode`

scope（可选）：
- `验证-A` | `验证-B` | `验证-C` | `验证-D`（缺省执行全部阶段）

输出：
- `{phase_dir}/qa-result.json（Phase 级）`
- 历史投影视图别名：`qa-report.md（Phase 级）`；仅供人读，不得作为 standard-chain 运行时真源

要求：
- 必须按 `test_cases_ref` 的 `## QA 交接契约` 承接测试义务
- 若任一 `QA_B` 义务标记 `execution_mode=browser_required`，必须使用浏览器 E2E（默认 `webapp-testing` / Playwright）执行，不得用 API/CLI 替代
- scope 为单阶段时，非目标阶段必须在 `## 验收汇总` 中标注 `N/A`
- 存在未执行阶段或未执行义务时，必须落盘 `not_executed_reason`
- 必须输出 `release_recommendation`
- 命中 `browser_required` 时，必须输出 `browser_tool`、`entry_url`、`browser_evidence`

> 交付模板、交接项清单和流程规范详见注入的 qa skill。
