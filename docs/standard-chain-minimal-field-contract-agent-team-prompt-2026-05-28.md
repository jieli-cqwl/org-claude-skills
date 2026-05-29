# Standard-chain 最小字段合同 Agent Team 任务

工作区：`/Users/lijieli/org-claude-skills`

## 硬门

- 遵守根目录 `AGENTS.md`、`$HOME/.codex/rules/*`、`$HOME/.codex/reference/协作判断.md`。
- 必须使用 Claude Code agent team；不可用则停止。
- 首轮只写 `docs/standard-chain-minimal-field-contract-review-2026-05-28/` 报告。
- 首轮禁止修改 `contracts/`、`shared/`、`tests/`、`tools/`、`shared/runtime/`。
- 禁止 stage / commit / push。

## 终极目标

收敛 `product-director -> delivery-owner` 的最小字段合同。终局标准不可降级：

- 每个环节只看到必须输入、输出和判断的字段。
- 每个保留字段都有 `owner / consumer / write_time / purpose / verification`。
- 不需要的字段、旧概念、错误路径、自然语言测试契约从 active 上下文彻底删除。
- 链路能从 Director baseline 到 Delivery signoff，不靠模型猜字段。
- Accepted P0/P1 必须重新映射到字段合同：`mapped-to-field-gap / rejected-as-noise / needs-human-decision / follow-up-cleanup`。

## Active 范围

需要清理和复核：

- `contracts/**`
- `shared/skills/**`
- `shared/runtime/**`
- `tests/**`
- `tools/community/**`
- `tests/gate-plan.json`
- `docs/reports/**`、`docs/superpowers/**` 中作为当前事实或计划的内容

不为搜索清零而改历史：

- `docs/archive/**`
- `tools/eval/results/**`
- 历史 transcript / raw output，除非 active 测试或 runtime 消费它

## 裁决规则

字段裁决只允许：

- `keep`：驱动 gate / handoff / transform / recovery / freshness / evidence / state / decision。
- `delete`：无 consumer、重复、旧概念、错误路径、只增加上下文噪音。
- `derive`：可由 registry / digest / canonical refs / script 得出，不手写。
- `move`：字段必要，但当前 artifact/path 错。
- `needs-human-decision`：证据不足，等待用户裁决。

默认：

- 无 consumer => `delete`
- 只解释背景 => `delete`
- 可派生 => `derive`
- 测试不能发明字段路径
- 删除后不得保留旧字段提示、兼容说明或否定式提醒

重点复核：

- `locked_field_digest` 只能是 `director_confirmation.locked_field_digest`，不能是顶层 handoff 字段。
- `baseline_tasks_version_ref`、`active_tasks_version_ref` 的重复项必须裁决为 keep/delete/derive/move。
- 自然语言句子锁定测试必须改为结构、字段路径、消费关系或脚本行为验证。

## 输出行格式

所有 agent 输出同一格式：

`artifact | field_path | current_owner | proposed_owner | write_time | consumers | purpose | decision | evidence | delete_impact | verification`

要求：

- `evidence` 必须是当前仓库 `path:line`。
- `purpose` 只能取：`gate / handoff / transform / reference / recovery / freshness / evidence / state / decision`。
- `keep` 必须有 consumer 和 purpose。
- `delete` 必须列 active 搜索目标和同步删除面。
- `move` 必须写 from/to artifact path。
- 不确定写 `needs-human-decision`，不要猜。

## Agent Team

先并行 A-E；A-E 完成后运行 F；最后主控合并。

| Agent | 范围 | 输出 |
| --- | --- | --- |
| A Director/PM | `shared/skills/product-director/**`, `shared/skills/product-manager/**`, `contracts/standard-chain*.yaml` | `agent-a-director-pm-matrix.md` |
| B Design/Test/Tech | `shared/skills/design/**`, `shared/skills/test-design/**`, `shared/skills/tech-lead/**` | `agent-b-design-test-tech-matrix.md` |
| C Runtime Evidence | `shared/skills/developer/**`, `shared/skills/verify/**`, `shared/skills/review/**`, `shared/skills/qa/**` | `agent-c-runtime-evidence-matrix.md` |
| D Delivery Control | `shared/skills/delivery-owner/**`, `fix-result`, `consistency-audit-result` | `agent-d-delivery-control-matrix.md` |
| E Tests/Validators | `tests/**`, `tools/community/**`, `shared/runtime/**`, `contracts/**`, `tests/gate-plan.json` | `agent-e-test-validator-contract-matrix.md` |
| F Challenge | 读取 A-E 输出和其引用文件 | `agent-f-challenge-review.md` |

F 只做质疑：

- `keep` 是否真有 consumer 和决策用途。
- `delete` 是否误删 gate / recovery / freshness / evidence。
- `move` 是否只是换名堆叠。
- P0/P1 映射是否真实对应字段合同缺口。

F 输出分类：

- `challenge-supported`
- `challenge-rejected`
- `needs-human-decision`

## 主控输出

写入同一目录：

- `merged-field-decision-matrix.md`
- `p0-p1-remap.md`
- `conflicts-and-human-decisions.md`
- `implementation-order.md`
- `execution-summary.md`

主控要求：

- 合并 A-F 为唯一字段矩阵。
- 冲突项进入 `conflicts-and-human-decisions.md`，不折中。
- 覆盖 full review 报告中所有 accepted P0/P1 issue id。
- 结论只能是“字段矩阵待用户确认”，不得声明可实施或完成。

## 首轮验证

首轮结束前记录：

- `git status --short`
- `find docs/standard-chain-minimal-field-contract-review-2026-05-28 -maxdepth 1 -type f | sort`
- A-E 五份矩阵文件存在且列完整
- F 覆盖 A-E
- merged matrix 中每个 `keep` 都有 `owner / consumer / write_time / purpose / evidence / verification`
- `needs-human-decision` 只集中在 conflicts 文件

`git status --short` 中除本提示词和 `docs/standard-chain-minimal-field-contract-review-2026-05-28/` 报告外，不得出现首轮新增改动。

## 停止条件

- agent team 不可用。
- 任一 agent 输出缺少 `path:line` 证据。
- A-E 结论冲突且当前证据无法裁决。
- 继续需要修改首轮禁止范围内文件。
- 目标、成功标准或 active 范围需要改变。
