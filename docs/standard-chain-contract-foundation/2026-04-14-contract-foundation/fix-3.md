## 输入分析
- 输入来源清单：`verify-change` fresh proving 过程中新增暴露的 gate failures：
  - `bash tests/test-delivery-owner-phase3-contract.sh`
  - `bash tests/test-qa-browser-gate-contract.sh`
- work_dir 解析结果：`/Users/lijieli/org-claude-skills/docs/standard-chain-contract-foundation/2026-04-14-contract-foundation`
- 问题数量汇总：3

差异说明（N > 1 时 REQUIRED）:
- `fix-1.md` 和 `fix-2.md` 主要修的是 readiness / validator 主链路。
- 本轮不是继续扩 contract foundation，而是在 `verify-change` fresh gate 中补齐两个技能合同缺口和一个回归测试环境缺口，确保 `Definition of Done` 里的最后几条 gate 真能跑通。

## 诊断阶段

### 环境快照
- 当前分支：`codex/standard-chain-contract-foundation`
- 工作树状态：
  - `M shared/skills/delivery-owner/SKILL.md`
  - `M shared/skills/qa/SKILL.md`
  - `M tests/test-qa-browser-gate-contract.sh`
- 最近 5 条提交：
  - `6cf26f5 fix: close remaining standard-chain validator gaps`
  - `c17ca80 fix: tighten standard-chain readiness gate`
  - `5c3ef5a feat: complete standard-chain canonical cutover`
  - `ab27358 feat: add standard chain projection and replay`
  - `28f4240 feat: add standard chain user decision writer`
- 最近改动文件：
  - `/Users/lijieli/org-claude-skills/.worktrees/standard-chain-contract-foundation/shared/skills/delivery-owner/SKILL.md`
  - `/Users/lijieli/org-claude-skills/.worktrees/standard-chain-contract-foundation/shared/skills/qa/SKILL.md`
  - `/Users/lijieli/org-claude-skills/.worktrees/standard-chain-contract-foundation/tests/test-qa-browser-gate-contract.sh`

### 现象与复现
| # | 问题 | 复现步骤 | 现象 |
|---|------|---------|------|
| 1 | delivery-owner phase3 contract 缺少 REPLAN 暂停文案 | 运行 `bash tests/test-delivery-owner-phase3-contract.sh` | 失败信息：`delivery-owner skill missing replan pause rule` |
| 2 | QA skill 缺少 gate contract 要求的字段声明 | 运行 `bash tests/test-qa-browser-gate-contract.sh` | 首个失败信息：`missing pattern in shared/skills/qa/SKILL.md: plan_version_value` |
| 3 | qa-browser gate 回归测试未开启 legacy markdown hooks，导致错误地直接放行 | 在当前环境复现 `tests/test-qa-browser-gate-contract.sh` 的 fixture 并直接调用 `shared/skills/qa/scripts/completion_check.sh` | 返回 `{"decision":"allow","reason":"skip: legacy markdown qa hook disabled; standard-chain uses canonical JSON artifacts"}`，后续 `browser_required` 校验根本没执行。 |

当前环境复现结论:
- 可复现：是。三个问题都能在当前 worktree 稳定复现。
- 不可复现时环境差异证据：无。

### 假设验证过程
| # | 问题 | 假设 | 验证方法 | 结果 |
|---|------|------|---------|------|
| 1 | delivery-owner phase3 contract 失败 | `test-delivery-owner-phase3-contract.sh` 误检，skill 文案已经包含等价语义。 | 检查 `/Users/lijieli/org-claude-skills/.worktrees/standard-chain-contract-foundation/tests/test-delivery-owner-phase3-contract.sh:264-268` 与 `/Users/lijieli/org-claude-skills/.worktrees/standard-chain-contract-foundation/shared/skills/delivery-owner/SKILL.md:170-172`。 | 排除。skill 有 `REPLAN` 字段要求，但没有测试要求的“等待刷新后的 \`plan.md\`”显式暂停语句。 |
| 2 | qa-browser gate 第一跳失败 | QA template 或 gate 脚本缺 `plan_version_value`。 | 检查 `/Users/lijieli/org-claude-skills/.worktrees/standard-chain-contract-foundation/shared/skills/qa/references/templates/qa-report-template.md` 与 `/Users/lijieli/org-claude-skills/.worktrees/standard-chain-contract-foundation/shared/skills/qa/scripts/completion_check.sh`。 | 排除。模板和 gate 脚本都已要求 `plan_version_value`，缺的是 QA skill 文案。 |
| 3 | qa-browser gate 仍放行 | `browser_required` 分支逻辑有 bug，没识别 `test_cases_ref` 或 `execution_mode`。 | 阅读 `/Users/lijieli/org-claude-skills/.worktrees/standard-chain-contract-foundation/shared/skills/qa/scripts/completion_check.sh:307-464`，并用同测试 fixture 单独调用脚本。 | 排除为首因。脚本在本次复现里根本没走到 `validate_browser_required_evidence()`，而是因为 legacy hooks 默认关闭提前 `allow`。 |
| 4 | qa-browser gate 仍放行 | 回归测试缺少和同类 legacy markdown gate 测试一致的环境开关。 | 检查 `/Users/lijieli/org-claude-skills/.worktrees/standard-chain-contract-foundation/tests/test-skill-output-and-gate-contract.sh:4` 与 `tests/test-qa-browser-gate-contract.sh:1-12`。 | 确认。前者显式 `export ORG_ENABLE_LEGACY_MARKDOWN_HOOKS=1`，后者没有。 |

### 根因结论
| # | 问题 | 根因定位 | 因果链摘要 | 语义关系确认证据 |
|---|------|---------|-----------|------------------|
| 1 | delivery-owner phase3 contract 缺少 REPLAN 暂停文案 | `/Users/lijieli/org-claude-skills/.worktrees/standard-chain-contract-foundation/shared/skills/delivery-owner/SKILL.md:170-172` | skill 已定义 `REPLAN` 控制动作和必填字段，但缺少测试要求的“等刷新后的 `plan.md` 才能恢复派发”的显式暂停规则，因此 phase3 contract 失败。 | `tests/test-delivery-owner-phase3-contract.sh:268` 直接 grep `"等待刷新后的 \`plan.md\`"`；修复点位于 `SKILL.md:172`。 |
| 2 | QA skill 缺少 gate contract 要求的字段声明 | `/Users/lijieli/org-claude-skills/.worktrees/standard-chain-contract-foundation/shared/skills/qa/SKILL.md:125-157` | QA template 和 completion_check 已以 `plan_version_ref + plan_version_value + issue_ledger_anchor` 为门禁合同，但 QA skill 的“必填内容/完成校验”没有同步这些字段，导致 qa-browser contract 第一跳就失败。 | `tests/test-qa-browser-gate-contract.sh:193-201` 直接 grep QA skill；修复点位于 `QA/SKILL.md:128-157`。 |
| 3 | qa-browser gate 回归测试未开启 legacy markdown hooks | `/Users/lijieli/org-claude-skills/.worktrees/standard-chain-contract-foundation/tests/test-qa-browser-gate-contract.sh:1-4` | QA completion check 在 canonical-only 默认配置下会跳过 legacy markdown hook；该测试实际是在验证 legacy markdown gate 行为，但没像同类测试那样显式开启 `ORG_ENABLE_LEGACY_MARKDOWN_HOOKS=1`，导致脚本提前 `allow`，掩盖了后续 `browser_required` 校验。 | 等效静态追踪：`tests/test-qa-browser-gate-contract.sh` 调用 `shared/skills/qa/scripts/completion_check.sh`；后者在 `79-80` 行遇到默认关闭的 legacy hooks 时直接 `allow`。 |

## 处置阶段

### 决策
处置策略：
1. 对 `delivery-owner/SKILL.md` 补上测试要求的 `REPLAN` 暂停规则，不改 canonical-only 运行语义。
2. 对 `qa/SKILL.md` 补齐已由 template/gate 落地的 `plan_version_value` 与 `issue_ledger_anchor` 字段。
3. 对 `tests/test-qa-browser-gate-contract.sh` 显式开启 legacy markdown hooks，使其验证目标与 `qa/completion_check.sh` 的默认行为边界一致。

失败分类:
| # | 问题 | failure_class | 后续动作 |
|---|------|--------------|---------|
| 1 | delivery-owner phase3 contract 缺少 REPLAN 暂停文案 | FIXABLE | 补 skill 文案并重跑 phase3 contract |
| 2 | QA skill 缺少 gate contract 字段声明 | FIXABLE | 补 QA skill 文案并重跑 qa-browser contract |
| 3 | qa-browser gate 回归测试未开启 legacy markdown hooks | FIXABLE | 补测试环境开关并重跑 qa-browser contract |

### FAIL-1: delivery-owner phase3 contract 缺少 REPLAN 暂停文案

| # | 问题 | 回答 |
|---|------|------|
| 1 | 根因是什么？ | `delivery-owner/SKILL.md:172` 缺少“等待刷新后的 `plan.md`”这句显式暂停规则。 |
| 2 | 修复是否完整？ | 已把暂停当前批次、等待刷新计划、再恢复派发的语义写入同一条 `REPLAN` 规则，不改变已有 `plan.json` canonical 真源表述。 |
| 3 | 是否引入新问题？ | 风险很低，仅补强文案合同。 |
| 4 | 是否需要补充测试覆盖？ | 现有 `tests/test-delivery-owner-phase3-contract.sh` 已覆盖，无需新增。 |

RED: `bash /Users/lijieli/org-claude-skills/.worktrees/standard-chain-contract-foundation/tests/test-delivery-owner-phase3-contract.sh`
GREEN: 同命令修复后通过。

### FAIL-2: QA skill 缺少 gate contract 字段声明

| # | 问题 | 回答 |
|---|------|------|
| 1 | 根因是什么？ | `qa/SKILL.md` 的必填内容和完成校验列表没有同步 template/gate 已经要求的 `plan_version_value` 与 `issue_ledger_anchor`。 |
| 2 | 修复是否完整？ | 已在两个列表里同时补齐字段，避免“必填内容”与“完成校验”再次漂移。 |
| 3 | 是否引入新问题？ | 风险很低，仅补技能文案合同。 |
| 4 | 是否需要补充测试覆盖？ | 现有 `tests/test-qa-browser-gate-contract.sh` 已覆盖，无需新增。 |

RED: `bash /Users/lijieli/org-claude-skills/.worktrees/standard-chain-contract-foundation/tests/test-qa-browser-gate-contract.sh`
GREEN: 同命令修复后通过。

### FAIL-3: qa-browser gate 回归测试未开启 legacy markdown hooks

| # | 问题 | 回答 |
|---|------|------|
| 1 | 根因是什么？ | `tests/test-qa-browser-gate-contract.sh` 没有像同类 legacy gate 测试那样显式 `export ORG_ENABLE_LEGACY_MARKDOWN_HOOKS=1`。 |
| 2 | 修复是否完整？ | 已在测试头部显式导出环境变量，让测试真正进入 legacy markdown gate 分支；未放宽 QA completion check 默认的 canonical-only 行为。 |
| 3 | 是否引入新问题？ | 不会影响生产行为，只影响该测试自身环境。 |
| 4 | 是否需要补充测试覆盖？ | 现有 `tests/test-qa-browser-gate-contract.sh` 自身即为回归覆盖。 |

RED: 用同测试 fixture 单独调用 `shared/skills/qa/scripts/completion_check.sh`，在默认环境下返回 `skip: legacy markdown qa hook disabled`
GREEN: `bash /Users/lijieli/org-claude-skills/.worktrees/standard-chain-contract-foundation/tests/test-qa-browser-gate-contract.sh`

## 产出

### 修复清单
| # | 问题 | 根因 | 修复文件 | 回归测试 |
|---|------|------|---------|---------|
| 1 | delivery-owner phase3 contract 缺少 REPLAN 暂停文案 | skill 文案少了显式暂停规则 | `/Users/lijieli/org-claude-skills/.worktrees/standard-chain-contract-foundation/shared/skills/delivery-owner/SKILL.md` | `tests/test-delivery-owner-phase3-contract.sh` |
| 2 | QA skill 缺少 gate contract 字段声明 | QA skill 与 template/gate 合同漂移 | `/Users/lijieli/org-claude-skills/.worktrees/standard-chain-contract-foundation/shared/skills/qa/SKILL.md` | `tests/test-qa-browser-gate-contract.sh` |
| 3 | qa-browser gate 回归测试未开启 legacy markdown hooks | 测试环境没有显式启用 legacy gate 分支 | `/Users/lijieli/org-claude-skills/.worktrees/standard-chain-contract-foundation/tests/test-qa-browser-gate-contract.sh` | `tests/test-qa-browser-gate-contract.sh` |

### 全量测试结果
TEST_CMD:
- `bash /Users/lijieli/org-claude-skills/.worktrees/standard-chain-contract-foundation/tests/test-delivery-owner-phase3-contract.sh`
- `bash /Users/lijieli/org-claude-skills/.worktrees/standard-chain-contract-foundation/tests/test-qa-browser-gate-contract.sh`
- `bash /Users/lijieli/org-claude-skills/.worktrees/standard-chain-contract-foundation/tests/test-runtime-integrity.sh`
- `bash /Users/lijieli/org-claude-skills/.worktrees/standard-chain-contract-foundation/tests/test-skill-output-and-gate-contract.sh`

通过: 4 / 失败: 0 / 跳过: 0

### 交接项清单
- 根因分析结论与定位文件:行号：
  - `/Users/lijieli/org-claude-skills/.worktrees/standard-chain-contract-foundation/shared/skills/delivery-owner/SKILL.md:170-172`
  - `/Users/lijieli/org-claude-skills/.worktrees/standard-chain-contract-foundation/shared/skills/qa/SKILL.md:125-157`
  - `/Users/lijieli/org-claude-skills/.worktrees/standard-chain-contract-foundation/tests/test-qa-browser-gate-contract.sh:1-4`
- 修复范围与回归测试清单：delivery-owner/qa 技能合同 + qa-browser test env
- 非 FIXABLE 问题的后续处理动作：无。本轮问题均归类为 `FIXABLE`
