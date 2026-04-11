# fix-1.md

## 输入分析
- 输入来源清单:
  - 用户提供的 3 条 review findings
  - `bash /Users/lijieli/org-claude-skills/tests/test-review-convergence-gates.sh`
  - `bash /Users/lijieli/org-claude-skills/tests/test-skill-output-and-gate-contract.sh`
- work_dir 解析结果: `docs/hotfix-20260411-1945-review-convergence-gates`
- 问题数量汇总: 3

差异说明（N > 1 时 REQUIRED）:
- 首轮修复，无历史 `fix-N.md`

## 诊断阶段

### 环境快照
- 当前分支: `main`
- 工作树状态:
  - 仓库存在用户/历史未提交变更
  - 本轮相关修改集中在 `shared/hooks/lib/common.sh`、3 个模板、2 个测试文件
- 最近 5 条提交:
  - `7b74b0c fix: relax assistant confirmation flow`
  - `1a28a52 feat: align codex hook runtime and refine research skill outputs`
  - `9b973b5 feat: unify Claude and Codex hooks from a shared runtime registry`
  - `2517550 fix: trim low-frequency assistant runtime references`
  - `1360cbb fix: sanitize stale codex probe hooks during install`
- 最近改动文件:
  - `shared/hooks/lib/common.sh`
  - `shared/skills/product/references/templates/brief-template.md`
  - `shared/skills/design/references/templates/design-template.md`
  - `shared/skills/test-design/references/templates/test-cases-template.md`
  - `tests/test-review-convergence-gates.sh`
  - `tests/test-skill-output-and-gate-contract.sh`

### 现象与复现
| # | 问题 | 复现步骤 | 现象 |
|---|------|---------|------|
| 1 | `ASK_USER` 非粘性 | 先把 `tests/test-review-convergence-gates.sh` 补成 `R2=ASK_USER` 后直接 `R3=PASS`，再运行该脚本 | 测试最初失败在 `ask_user must stay sticky without user decision: expected failures`，说明 gate 未拦截 |
| 2 | `BLOCKED` 非粘性 | 在同一测试中补 `R3=BLOCKED` 后追加 `R4=PASS` | 修复前可通过，说明历史 `BLOCKED` 可被后续行绕过 |
| 3 | 幽灵 Issue 可被接受 | 在同一测试中补 `PR-001,AR-999` 但台账只保留 `PR-001` | 修复前函数无失败，说明未关闭 Issue 列表未反向闭包到台账 |

当前环境复现结论:
- 可复现: 是
- 不可复现时环境差异证据: 不适用

### 假设验证过程
| # | 问题 | 假设 | 验证方法 | 结果 |
|---|------|------|---------|------|
| 1 | `ASK_USER` 非粘性 | 只看 `latest_action`，没有“暂停后必须有用户裁决才能继续”的状态机 | 检查 [common.sh](/Users/lijieli/org-claude-skills/shared/hooks/lib/common.sh:957) 到 [common.sh](/Users/lijieli/org-claude-skills/shared/hooks/lib/common.sh:987) 修复前逻辑，并用 RED 测试复现 | 确认 |
| 1 | `ASK_USER` 非粘性 | 是测试样例错误，不是实现缺陷 | 把场景转成显式 `R2 ASK_USER -> R3 PASS` 的最小文档，再运行测试 | 排除 |
| 2 | `BLOCKED` 非粘性 | 只在最后一行 `BLOCKED` 时阻断，历史 `BLOCKED` 不会持续生效 | 检查 [common.sh](/Users/lijieli/org-claude-skills/shared/hooks/lib/common.sh:1158) 到 [common.sh](/Users/lijieli/org-claude-skills/shared/hooks/lib/common.sh:1163) 的最终阻断逻辑，并用 RED 测试复现 | 确认 |
| 2 | `BLOCKED` 非粘性 | `3 轮未关闭` 的 streak 计算本身出错 | 检查 [common.sh](/Users/lijieli/org-claude-skills/shared/hooks/lib/common.sh:1145) 到 [common.sh](/Users/lijieli/org-claude-skills/shared/hooks/lib/common.sh:1156) 并验证 `R3 BLOCKED` 仍能正确触发 | 排除 |
| 3 | 幽灵 Issue 漏检 | 只校验“台账 -> 收敛表”，没有“收敛表 -> 台账” | 检查 [common.sh](/Users/lijieli/org-claude-skills/shared/hooks/lib/common.sh:1106) 到 [common.sh](/Users/lijieli/org-claude-skills/shared/hooks/lib/common.sh:1143) 修复前后逻辑，并用 `AR-999` 场景测试 | 确认 |
| 3 | 幽灵 Issue 漏检 | Issue ID 正则无法覆盖真实 ID 形态，导致误判 | 检查 `extract_issue_ids_from_text` 与现有技能/模板中的 ID 形式 | 排除 |

### 根因结论
| # | 问题 | 根因定位 | 因果链摘要 | 语义关系确认证据 |
|---|------|---------|-----------|------------------|
| 1 | `ASK_USER` 非粘性 | [shared/hooks/lib/common.sh:957](/Users/lijieli/org-claude-skills/shared/hooks/lib/common.sh:957) | `completion_check.sh` 统一调用 `validate_review_convergence_policy`，但旧逻辑只看最后一轮 action，没有“暂停 -> 用户裁决 -> 解锁”的闭环状态 | [product completion_check.sh:820](/Users/lijieli/org-claude-skills/shared/skills/product/scripts/completion_check.sh:820)、[design completion_check.sh:594](/Users/lijieli/org-claude-skills/shared/skills/design/scripts/completion_check.sh:594)、[test-design completion_check.sh:621](/Users/lijieli/org-claude-skills/shared/skills/test-design/scripts/completion_check.sh:621) 都直接调用该 helper |
| 2 | `BLOCKED` 非粘性 | [shared/hooks/lib/common.sh:1046](/Users/lijieli/org-claude-skills/shared/hooks/lib/common.sh:1046) 与 [shared/hooks/lib/common.sh:1158](/Users/lijieli/org-claude-skills/shared/hooks/lib/common.sh:1158) | `BLOCKED` 会被记录成当前轮 action，但如果后续再补一行非阻断 action，旧逻辑只看 latest row，导致硬阻断失效 | 同上，三端 gate 共享同一 helper |
| 3 | 幽灵 Issue 漏检 | [shared/hooks/lib/common.sh:1106](/Users/lijieli/org-claude-skills/shared/hooks/lib/common.sh:1106) | 旧逻辑只检查台账中的 issue 是否出现在对应轮次；未检查收敛表中的 Issue ID 是否存在于台账，因此可伪造 `未关闭 Issue IDs` | 同上，三端 gate 共享同一 helper |

## 处置阶段

### 决策
- 处置策略选择:
  - 在共享 helper 中引入显式 `用户裁决记录` 解析与解锁校验
  - 将 `ASK_USER/BLOCKED` 改成粘性状态，后续轮次必须有用户裁决记录才能继续
  - 增补 `收敛轮次摘要 -> 审查问题台账` 的反向闭包校验
  - 通过模板契约把新增证据位固化到 `product / design / test-design`
- 优先级排序:
  1. 先补 RED 测试
  2. 再改共享 helper
  3. 最后补模板与合同测试

失败分类:
| # | 问题 | failure_class | 后续动作 |
|---|------|--------------|---------|
| 1 | `ASK_USER` 非粘性 | FIXABLE | 共享 helper 加入粘性暂停与用户裁决解锁 |
| 2 | `BLOCKED` 非粘性 | FIXABLE | 共享 helper 加入粘性阻断与用户裁决解锁 |
| 3 | 幽灵 Issue 漏检 | FIXABLE | 共享 helper 增加收敛表到台账的反向闭包校验 |

### FAIL-1: 收敛 gate 可被无证据解锁

| # | 问题 | 回答 |
|---|------|------|
| 1 | 根因是什么？ | [shared/hooks/lib/common.sh:957](/Users/lijieli/org-claude-skills/shared/hooks/lib/common.sh:957) 起的状态推进逻辑缺少“触发轮次 -> 用户裁决 -> 后续轮次”的显式证据链 |
| 2 | 修复是否完整？ | 已在共享 helper 里补 `用户裁决记录` 解析、触发轮次匹配、合法决定枚举、时间校验、Issue 集合一致性校验；三端 gate 自动继承 |
| 3 | 是否引入新问题？ | 需要模板同步新增 `### 用户裁决记录`，否则写作契约与 gate 契约会漂移；已一并补齐 |
| 4 | 是否需要补充测试覆盖？ | 需要；已补 `ASK_USER`/`BLOCKED` 粘性 RED/GREEN 场景，以及模板合同测试 |

RED:
- `bash /Users/lijieli/org-claude-skills/tests/test-review-convergence-gates.sh`
  - 失败输出: `[FAIL] ask_user must stay sticky without user decision: expected failures`
- `bash /Users/lijieli/org-claude-skills/tests/test-skill-output-and-gate-contract.sh`
  - 失败输出: `[FAIL] missing pattern in ... brief-template.md: ^### 用户裁决记录$`

GREEN:
- `bash /Users/lijieli/org-claude-skills/tests/test-review-convergence-gates.sh`
  - 通过输出: `[PASS] review convergence gates`
- `bash /Users/lijieli/org-claude-skills/tests/test-skill-output-and-gate-contract.sh`
  - 通过输出: `[PASS] skill output/gate contract`

## 产出

### 修复清单
| # | 问题 | 根因 | 修复文件 | 回归测试 |
|---|------|------|---------|---------|
| 1 | `ASK_USER` 非粘性 | 未建模用户裁决解锁 | `shared/hooks/lib/common.sh` | `tests/test-review-convergence-gates.sh` |
| 2 | `BLOCKED` 非粘性 | 历史阻断不具粘性 | `shared/hooks/lib/common.sh` | `tests/test-review-convergence-gates.sh` |
| 3 | 幽灵 Issue 漏检 | 缺少反向闭包校验 | `shared/hooks/lib/common.sh` | `tests/test-review-convergence-gates.sh` |
| 4 | 模板/契约缺少裁决证据位 | 文档契约未跟上新 gate | `shared/skills/*/references/templates/*.md`、`tests/test-skill-output-and-gate-contract.sh` | `tests/test-skill-output-and-gate-contract.sh` |

### 全量测试结果
TEST_CMD: `bash /Users/lijieli/org-claude-skills/tests/run-all.sh`
通过: 33 / 失败: 0 / 跳过: 0

### 阻断清单（全部/部分非 FIXABLE 时必填）
- 本轮无非 `FIXABLE` 阻断

### 交接项清单
- 根因分析结论与定位文件:行号已记录在上文根因结论表
- 修复范围涵盖共享 gate、3 个模板与 2 份测试
- 新增 `用户裁决记录` 后，`ASK_USER/BLOCKED` 必须带显式用户裁决证据才能离开暂停/阻断态
