## 审查轮次记录
| 轮次 | 审查 commit SHA | FAIL 数 | delta |
|------|----------------|---------|-------|
| R1 | 4f58ed9 | 3 | — |

## 代码审查（Code Review）

### 摘要
范围仅含以下 4 个文件：
- `shared/skills/product/references/conversation-guide.md`
- `shared/skills/design/SKILL.md`
- `shared/skills/tech-lead/SKILL.md`
- `tests/test-subagent-context-contract.sh`

结论：当前文案本身未发现“把 sub agent 当运行时概念讲解”的直接残留，`design` / `tech-lead` 的主 Agent 裁决语义仍在；但回潮门禁仍有 3 个实质缺口，当前应判定为 `REQUEST_CHANGES`。

### 审查-A: 安全与正确性

#### 发现（Findings）
| # | 置信度 | 严重度 | 位置 | 维度 | 问题 | 修复方向 | 验证状态 |
|---|--------|--------|------|------|------|---------|---------|
| 1 | 99 | 高（High） | `tests/test-subagent-context-contract.sh:151-156` | CS-1 正确性 | 这份“subagent context contract”门禁脚本当前仍未纳入 git 跟踪。`tests/test-subagent-context-contract.sh:151-156` 表明它被设计成正式 gate（调用 `validate-contracts.sh` 并输出 `[PASS]`），但 `git status --short -- tests/test-subagent-context-contract.sh` 返回 `?? tests/test-subagent-context-contract.sh`，`git ls-files --error-unmatch tests/test-subagent-context-contract.sh` 返回 `git_ls_files_rc=1`。结果是：本地手动运行可通过，但仓库、CI、他人检出环境都拿不到这道门，无法真正阻断回潮。 | 先把该测试纳入版本控制，再确认默认测试入口会执行它。 | 已验证（Verified） |

#### 已排除的潜在问题
| # | 调查内容 | 排除证据 |
|---|---------|---------|
| 1 | `product` reference 是否仍直接讲解 sub agent / runtime dispatch | `shared/skills/product/references/conversation-guide.md:18-20,58` 仅保留“候选线索”与“回到用户追问”；`product_forbidden_hits=0`（命令：`rg -n 'sub agent|subagent|子代理|Context Scan Agent|Problem Hypothesis Agent|静默降噪' shared/skills/product/references/conversation-guide.md | wc -l`）。 |
| 2 | `tech-lead` 主 Agent 裁决语义是否被去噪误删 | `shared/skills/tech-lead/SKILL.md:89,102-103` 仍明确“主 Agent 统一发起/统一回收/保留职责/冻结证据”；`techlead_main_agent_hits=3`。 |

#### 结论
REVIEW_A_ISSUE

---

### 审查-B: 设计与可维护性

#### 发现（Findings）
| # | 置信度 | 严重度 | 位置 | 维度 | 问题 | 修复方向 | 验证状态 |
|---|--------|--------|------|------|------|---------|---------|
| 1 | 96 | 中（Medium） | `tests/test-subagent-context-contract.sh:142-146` | TC-1 测试覆盖 | `product` 文案回潮检查仍是少量字面量黑名单，不足以挡住同义回潮。脚本只禁止 `Context Scan Agent`、`Problem Hypothesis Agent` 和带空格的 `sub agent`；`product_variant_guard_subagent=0`、`product_variant_guard_zh=0` 说明它没有任何 `subagent` 或 `子代理` 变体门禁。当前 `bash tests/test-subagent-context-contract.sh` 会通过，但这些变体重新出现在 `conversation-guide.md` 时不会被拦住。 | 把 `product` 的回潮门禁从单个固定词扩成完整变体集合，至少覆盖 `subagent` / `sub agent` / `子代理` 等同义写法。 | 已验证（Verified） |
| 2 | 94 | 中（Medium） | `tests/test-subagent-context-contract.sh:128-139` | TC-1 测试覆盖 | `design` 的主 Agent 裁决语义当前还在，但测试没有直接守护它。`shared/skills/design/SKILL.md:130,167-168,201` 明确要求“只采证并回收给主 Agent / 主 Agent 负责收敛冻结 / ADR 由主 Agent 转写”，但测试文件里 `design_skill_direct_asserts=0`；相对地，`techlead_skill_direct_asserts=2`，且 `tests/test-subagent-context-contract.sh:128,130` 只直接检查了 `tech-lead`。这意味着若后续去噪误删 `design/SKILL.md` 的主 Agent 裁决句，当前脚本仍可继续 PASS。 | 为 `shared/skills/design/SKILL.md` 增加直接断言，至少覆盖 S2/S5/S10 的主 Agent 裁决语义。 | 已验证（Verified） |

#### 已排除的潜在问题
| # | 调查内容 | 排除证据 |
|---|---------|---------|
| 1 | `design` 主 Agent 裁决语义是否已被误删 | `shared/skills/design/SKILL.md:130,167-168,201` 均保留主 Agent 收敛/冻结/转写职责；`design_main_agent_hits=5`。 |
| 2 | `product` 候选线索是否已经越权写成最终结论 | `shared/skills/product/references/conversation-guide.md:19-20,58` 明确写明“候选线索不直接写入最终结论”“不能替代追问”。 |

#### 结论
REVIEW_B_ISSUE

---

### 审查-C: 性能与可观测性

#### 发现（Findings）
无。

#### 已排除的潜在问题
| # | 调查内容 | 排除证据 |
|---|---------|---------|
| 1 | 本轮去噪改动是否引入可观测性退化 | 范围内 4 个文件均为文档/测试脚本；未引入运行时路径、日志或指标采集逻辑。 |
| 2 | 本轮去噪改动是否引入性能回退 | 范围内没有执行路径改动；唯一运行脚本 `tests/test-subagent-context-contract.sh` 为静态文本断言和一次 `validate-contracts.sh` 调用。 |

#### 结论
REVIEW_C_OK

---

### 最终结论
需修改（REQUEST_CHANGES）

## 验证汇总（Verification）

| 送检数 | 已验证（Verified） | 误报（False Positive） | 待定（Inconclusive） |
|--------|--------------------|-------------------------|--------------------|
| 3 | 3 | 0 | 0 |

## 执行证据

- `bash tests/test-subagent-context-contract.sh` → `[PASS] subagent context contract`
- `git status --short -- tests/test-subagent-context-contract.sh shared/skills/product/references/conversation-guide.md shared/skills/design/SKILL.md shared/skills/tech-lead/SKILL.md`
  - 输出：`?? tests/test-subagent-context-contract.sh`
- `git ls-files --error-unmatch tests/test-subagent-context-contract.sh`
  - 输出：`git_ls_files_rc=1`
- `rg -n "assert_absent 'sub agent'|assert_absent 'subagent'|assert_absent '子代理'" tests/test-subagent-context-contract.sh`
  - 输出仅命中 `assert_absent 'sub agent'`
- `rg -n "shared/skills/design/SKILL\\.md" tests/test-subagent-context-contract.sh | wc -l`
  - 输出：`0`
